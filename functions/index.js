const { onDocumentCreated, onDocumentWritten } = require("firebase-functions/v2/firestore");
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
  buildTripStartedMessage,
} = require("./notifications");
const { evaluateGroupBoarding } = require("./boarding");

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
