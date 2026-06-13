const { onDocumentCreated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onRequest, onCall } = require("firebase-functions/v2/https");
const {
  handleSubscribeInit,
  handleSubscribeCallback,
  handleSubscribeWebhook,
} = require("./subscription");
const { recordPoolIAP } = require("./pool");
const { initializeApp } = require("firebase-admin/app");
const { FieldValue, getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const {
  buildTripStartedMessageForGroup,
  buildReturneeTripNotification,
  fetchYesterdayNotComingMemberIds,
} = require("./weather");
const {
  buildDriverApproachingMessage,
  buildDriverDelayMessage,
  buildDriverDelayNotification,
  buildTripEndedMessage,
  buildTripEndedNotification,
  buildTripStartedMessage,
} = require("./notifications");
const { evaluateGroupBoarding } = require("./boarding");
const { MORNING_SESSION, reconcileGroupMorningRoute } = require("./routeLearning");

initializeApp();

const APPROACH_RADIUS_METERS = 300;

function distanceMeters(lat1, lon1, lat2, lon2) {
  const earthRadius = 6371000;
  const toRadians = (value) => (value * Math.PI) / 180;
  const dLat = toRadians(lat2 - lat1);
  const dLon = toRadians(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRadians(lat1)) *
      Math.cos(toRadians(lat2)) *
      Math.sin(dLon / 2) ** 2;
  return 2 * earthRadius * Math.asin(Math.sqrt(a));
}

function istanbulDateKey(reference = new Date()) {
  return reference.toLocaleDateString("en-CA", { timeZone: "Europe/Istanbul" });
}

function isHolidayModeActive(holidayModeEndDate, reference = new Date()) {
  if (!holidayModeEndDate) {
    return false;
  }
  const todayKey = istanbulDateKey(reference);
  return todayKey <= holidayModeEndDate;
}

/** Uygulamadaki effectiveAttendance ile aynı (tatilde seçim yoksa gelmiyorum). */
function effectiveAttendanceStatus(rawStatus, holidayActive) {
  const status = rawStatus || "unknown";
  if (!holidayActive) {
    return status;
  }
  if (status === "coming" || status === "notComing") {
    return status;
  }
  return "notComing";
}

/**
 * Gelmiyorum (veya tatilde seçim yok → effective gelmiyorum) → bildirim yok.
 * Normal modda belirsiz/geliyorum → bildirim var.
 */
function shouldNotifyPassengerOnTripStart(memberData, attendanceStatus) {
  const holidayActive = isHolidayModeActive(memberData.holidayModeEndDate);
  const effective = effectiveAttendanceStatus(attendanceStatus, holidayActive);
  return effective !== "notComing";
}

function passengerMembers(membersSnapshot, attendanceResponses) {
  const passengers = [];
  for (const doc of membersSnapshot.docs) {
    const member = doc.data();
    if (member.role !== "passenger" || !member.fcmToken) {
      continue;
    }
    const rawStatus = attendanceResponses[doc.id]?.status;
    if (!shouldNotifyPassengerOnTripStart(member, rawStatus)) {
      console.log("[notifyTripStarted] skip", doc.id, {
        holidayModeEndDate: member.holidayModeEndDate || null,
        holidayActive: isHolidayModeActive(member.holidayModeEndDate),
        rawStatus: rawStatus || "unknown",
        effective: effectiveAttendanceStatus(
          rawStatus,
          isHolidayModeActive(member.holidayModeEndDate)
        ),
      });
      continue;
    }
    passengers.push({
      memberID: doc.id,
      token: member.fcmToken,
    });
  }
  return passengers;
}

function membersWithTokens(membersSnapshot) {
  return membersSnapshot.docs
    .filter((doc) => doc.data().fcmToken)
    .map((doc) => ({
      memberID: doc.id,
      token: doc.data().fcmToken,
      role: doc.data().role || "passenger",
    }));
}

exports.notifyTripStarted = onDocumentCreated(
  "groups/{groupId}/tripEvents/{eventId}",
  async (event) => {
    const data = event.data?.data();
    if (!data || data.type !== "started") {
      return;
    }

    const groupId = event.params.groupId;
    const driverName = data.driverName || "Şoför";
    const db = getFirestore();

    const tripDateKey = data.date || istanbulDateKey();
    const [membersSnapshot, attendanceSnapshot] = await Promise.all([
      db.collection("groups").doc(groupId).collection("members").get(),
      db.collection("groups").doc(groupId).collection("attendance").doc(tripDateKey).get(),
    ]);

    await Promise.all(
      membersSnapshot.docs.map((memberDoc) =>
        memberDoc.ref.set(
          { lastApproachNotificationSessionKey: FieldValue.delete() },
          { merge: true }
        )
      )
    );

    const attendanceResponses = attendanceSnapshot.data()?.responses || {};
    const passengers = passengerMembers(membersSnapshot, attendanceResponses);

    console.log(
      "[notifyTripStarted] recipients:",
      passengers.length,
      "of",
      membersSnapshot.docs.filter((doc) => doc.data().role === "passenger").length,
      "passengers"
    );

    if (passengers.length === 0) {
      return;
    }
    const [defaultNotification, returneeYesterday] = await Promise.all([
      buildTripStartedMessageForGroup(db, groupId, driverName),
      fetchYesterdayNotComingMemberIds(db, groupId, tripDateKey),
    ]);

    const returneeNotification = buildReturneeTripNotification(driverName);

    const messages = passengers.map(({ memberID, token }) => {
      const isReturnee = returneeYesterday.has(memberID);
      return buildTripStartedMessage({
        token,
        groupId,
        memberID,
        notification: isReturnee ? returneeNotification : defaultNotification,
        returnee: isReturnee,
      });
    });

    const result = await getMessaging().sendEach(messages);
    const failed = result.responses.filter((r) => !r.success).length;
    if (failed > 0) {
      console.warn(
        "[notifyTripStarted] FCM failures:",
        failed,
        "returnees:",
        returneeYesterday.size
      );
    } else {
      console.log(
        "[notifyTripStarted] sent:",
        messages.length,
        "returnees:",
        returneeYesterday.size
      );
    }
  }
);

exports.notifyDriverDelay = onDocumentCreated(
  "groups/{groupId}/tripEvents/{eventId}",
  async (event) => {
    const data = event.data?.data();
    if (!data || data.type !== "delay_notice") {
      return;
    }

    const groupId = event.params.groupId;
    const serviceKey = data.serviceKey;
    const minutes = Number(data.minutes);
    const driverName = data.driverName || "Şoför";
    const allowedMinutes = [5, 10, 15, 30];

    if (!serviceKey || !allowedMinutes.includes(minutes)) {
      console.warn("[notifyDriverDelay] invalid payload", data);
      return;
    }

    const db = getFirestore();
    const noticeRef = db
      .collection("groups")
      .doc(groupId)
      .collection("delayNotices")
      .doc(serviceKey);

    const alreadySent = await db.runTransaction(async (tx) => {
      const existing = await tx.get(noticeRef);
      if (existing.exists) {
        return true;
      }
      tx.set(noticeRef, {
        minutes,
        driverName,
        serviceKey,
        createdAt: FieldValue.serverTimestamp(),
        eventId: event.params.eventId,
      });
      return false;
    });

    if (alreadySent) {
      console.log("[notifyDriverDelay] duplicate skipped:", serviceKey);
      return;
    }

    const [membersSnapshot, attendanceSnapshot] = await Promise.all([
      db.collection("groups").doc(groupId).collection("members").get(),
      db.collection("groups").doc(groupId).collection("attendance").doc(serviceKey).get(),
    ]);

    const attendanceResponses = attendanceSnapshot.data()?.responses || {};
    const passengers = passengerMembers(membersSnapshot, attendanceResponses);

    console.log(
      "[notifyDriverDelay] recipients:",
      passengers.length,
      "service:",
      serviceKey,
      "minutes:",
      minutes
    );

    if (passengers.length === 0) {
      return;
    }

    const notification = buildDriverDelayNotification(driverName, minutes);
    const messages = passengers.map(({ memberID, token }) =>
      buildDriverDelayMessage({ token, groupId, memberID, notification, minutes })
    );

    const result = await getMessaging().sendEach(messages);
    const failed = result.responses.filter((response) => !response.success).length;
    if (failed > 0) {
      console.warn("[notifyDriverDelay] FCM failures:", failed);
    } else {
      console.log("[notifyDriverDelay] sent:", messages.length);
    }
  }
);

exports.notifyTripEnded = onDocumentCreated(
  "groups/{groupId}/tripEvents/{eventId}",
  async (event) => {
    const data = event.data?.data();
    if (!data || data.type !== "ended") {
      return;
    }

    const groupId = event.params.groupId;
    const driverName = data.driverName || "Şoför";
    const endReason = data.endReason || "manual";
    const db = getFirestore();

    const membersSnapshot = await db
      .collection("groups")
      .doc(groupId)
      .collection("members")
      .get();

    const recipients = membersWithTokens(membersSnapshot);
    console.log(
      "[notifyTripEnded] recipients:",
      recipients.length,
      "of",
      membersSnapshot.docs.length,
      "members",
      "reason:",
      endReason
    );

    if (recipients.length === 0) {
      return;
    }

    const notification = buildTripEndedNotification(driverName, endReason);
    const messages = recipients.map(({ memberID, token }) =>
      buildTripEndedMessage({
        token,
        groupId,
        memberID,
        notification,
        endReason,
      })
    );

    const result = await getMessaging().sendEach(messages);
    const failed = result.responses.filter((response) => !response.success).length;
    if (failed > 0) {
      console.warn("[notifyTripEnded] FCM failures:", failed);
    } else {
      console.log("[notifyTripEnded] sent:", messages.length);
    }
  }
);

exports.notifyDriverApproachingPickup = onDocumentWritten(
  "groups/{groupId}/live/current",
  async (event) => {
    const after = event.data?.after;
    if (!after?.exists) {
      return;
    }

    const live = after.data();
    if (!live?.isActive) {
      return;
    }

    const driverLat = Number(live.latitude);
    const driverLng = Number(live.longitude);
    const tripDate = live.tripDate;
    const approachSessionKey =
      live.approachSessionKey || `${tripDate || "trip"}-${live.updatedAt?.seconds || ""}`;

    if (!Number.isFinite(driverLat) || !Number.isFinite(driverLng) || !tripDate) {
      return;
    }

    const groupId = event.params.groupId;
    const db = getFirestore();

    const [membersSnapshot, attendanceSnapshot] = await Promise.all([
      db.collection("groups").doc(groupId).collection("members").get(),
      db.collection("groups").doc(groupId).collection("attendance").doc(tripDate).get(),
    ]);

    const responses = attendanceSnapshot.data()?.responses || {};
    const pickupsSnapshot = await db
      .collection("groups")
      .doc(groupId)
      .collection("morningPickups")
      .get();

    const pickupByMember = new Map(
      pickupsSnapshot.docs.map((doc) => [doc.id, doc.data()])
    );

    const messaging = getMessaging();

    for (const memberDoc of membersSnapshot.docs) {
      const member = memberDoc.data();
      if (member.role !== "passenger") {
        continue;
      }

      const memberID = memberDoc.id;
      const attendanceStatus = responses[memberID]?.status;
      if (attendanceStatus === "notComing") {
        continue;
      }

      const pickup = pickupByMember.get(memberID);
      if (!pickup) {
        continue;
      }

      const pickupLat = Number(pickup.latitude);
      const pickupLng = Number(pickup.longitude);
      if (!Number.isFinite(pickupLat) || !Number.isFinite(pickupLng)) {
        continue;
      }

      const meters = distanceMeters(driverLat, driverLng, pickupLat, pickupLng);
      if (meters > APPROACH_RADIUS_METERS) {
        continue;
      }

      if (member.lastApproachNotificationSessionKey === approachSessionKey) {
        continue;
      }

      const token = member.fcmToken;
      if (!token) {
        continue;
      }

      await messaging.send(
        buildDriverApproachingMessage({ token, groupId, memberID })
      );

      await memberDoc.ref.set(
        { lastApproachNotificationSessionKey: approachSessionKey },
        { merge: true }
      );
    }
  }
);

exports.evaluatePassengerBoarded = onDocumentWritten(
  "groups/{groupId}/tripActivity/{activityDocId}",
  async (event) => {
    const groupId = event.params.groupId;
    await evaluateGroupBoarding(getFirestore(), groupId);
  }
);

exports.evaluatePassengerBoardedOnTelemetry = onDocumentWritten(
  "groups/{groupId}/tripTelemetry/{telemetryId}",
  async (event) => {
    if (event.params.telemetryId !== "driver") return;
    const groupId = event.params.groupId;
    await evaluateGroupBoarding(getFirestore(), groupId);
  }
);

const subscribeRuntime = {
  region: "europe-west1",
  cors: true,
  secrets: ["IYZICO_API_KEY", "IYZICO_SECRET_KEY"],
};

exports.subscribeInit = onRequest(subscribeRuntime, async (req, res) => {
  if (req.method !== "GET" && req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return;
  }
  await handleSubscribeInit(getFirestore(), req, res);
});

exports.subscribeCallback = onRequest(
  { ...subscribeRuntime, cors: false },
  async (req, res) => {
    if (req.method !== "GET" && req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }
    await handleSubscribeCallback(getFirestore(), req, res);
  }
);

exports.subscribeWebhook = onRequest(
  { ...subscribeRuntime, cors: false },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }
    await handleSubscribeWebhook(getFirestore(), req, res);
  }
);

exports.recordPoolIAP = onCall(
  { region: "europe-west1" },
  async (request) => recordPoolIAP(request)
);

exports.reconcileMorningCanonicalRoute = onDocumentCreated(
  "groups/{groupId}/routeHistory/{tripId}",
  async (event) => {
    const data = event.data?.data();
    if (!data || data.session !== MORNING_SESSION) {
      return;
    }

    const groupId = event.params.groupId;
    try {
      await reconcileGroupMorningRoute(getFirestore(), groupId);
    } catch (error) {
      console.error("[reconcileMorningCanonicalRoute] failed", groupId, error);
      throw error;
    }
  }
);
