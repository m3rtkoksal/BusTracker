/**
 * Binde tespiti — pickup + motion örtüşmesi + sürücü duraklama (hız telemetrisi).
 * Bir yolcu bindi → tüm servise (gelmeyenler hariç) bildirim.
 */

const { FieldValue, getFirestore, Timestamp } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { buildPassengerBoardedMessage } = require("./notifications");

const WINDOW_MS = 8 * 60 * 1000;
const MIN_AUTOMOTIVE_SECONDS = 4 * 60;
const MIN_OVERLAP_SECONDS = 4 * 60;
const MIN_DRIVER_AUTOMOTIVE_SECONDS = 3 * 60;
const PICKUP_REACH_MAX_AGE_MS = 20 * 60 * 1000;

/** Zayıf motion yolu — kısa biniş + net duraklama. */
const MIN_AUTOMOTIVE_WEAK_SECONDS = 2 * 60;
const MIN_OVERLAP_WEAK_SECONDS = 2 * 60;

/** Sürücü pickup'ta durdu mu? (~7 km/h altı). */
const STOP_SPEED_MPS = 2;
const MIN_STOP_SECONDS = 60;
const STOP_WINDOW_AFTER_REACH_MS = 10 * 60 * 1000;
const SAMPLE_GAP_CAP_MS = 15 * 1000;

function toDate(value) {
  if (!value) return null;
  if (value instanceof Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  if (typeof value === "number") return new Date(value);
  return null;
}

function parseSegments(data) {
  const raw = data?.segments;
  if (!Array.isArray(raw)) return [];
  const cutoff = Date.now() - WINDOW_MS;
  return raw
    .map((entry) => {
      const startAt = toDate(entry.startedAt);
      const endAt = toDate(entry.endedAt);
      const isAutomotive = entry.isAutomotive === true;
      if (!startAt || !endAt || endAt.getTime() < cutoff) return null;
      return {
        startAt,
        endAt,
        isAutomotive,
      };
    })
    .filter(Boolean)
    .sort((a, b) => a.startAt - b.startAt);
}

function parseTelemetrySamples(data) {
  const raw = data?.samples;
  if (!Array.isArray(raw)) return [];
  const cutoff = Date.now() - WINDOW_MS;
  return raw
    .map((entry) => {
      const sampledAt = toDate(entry.sampledAt);
      const speedMps = Number(entry.speedMps);
      if (!sampledAt || !Number.isFinite(speedMps)) return null;
      if (sampledAt.getTime() < cutoff) return null;
      return { sampledAt, speedMps };
    })
    .filter(Boolean)
    .sort((a, b) => a.sampledAt - b.sampledAt);
}

function automotiveSecondsInWindow(segments) {
  const cutoff = Date.now() - WINDOW_MS;
  return segments
    .filter((segment) => segment.isAutomotive && segment.endAt >= cutoff)
    .reduce((total, segment) => {
      const start = Math.max(segment.startAt.getTime(), cutoff);
      const end = segment.endAt.getTime();
      return total + Math.max(0, (end - start) / 1000);
    }, 0);
}

function overlapAutomotiveSeconds(driverSegments, passengerSegments) {
  const driverAuto = driverSegments.filter((segment) => segment.isAutomotive);
  const passengerAuto = passengerSegments.filter((segment) => segment.isAutomotive);
  let totalMs = 0;

  for (const passengerSegment of passengerAuto) {
    for (const driverSegment of driverAuto) {
      const start = Math.max(
        passengerSegment.startAt.getTime(),
        driverSegment.startAt.getTime()
      );
      const end = Math.min(
        passengerSegment.endAt.getTime(),
        driverSegment.endAt.getTime()
      );
      if (end > start) {
        totalMs += end - start;
      }
    }
  }

  return totalMs / 1000;
}

/**
 * pickupReach sonrası sürücünün düşük hızda kaldığı süre (saniye).
 */
function stoppedSecondsAfterPickup(reachedAt, telemetrySamples) {
  const reachMs = reachedAt.getTime();
  const windowEnd = reachMs + STOP_WINDOW_AFTER_REACH_MS;
  const inWindow = telemetrySamples.filter((sample) => {
    const t = sample.sampledAt.getTime();
    return t >= reachMs && t <= windowEnd;
  });

  if (inWindow.length === 0) return 0;

  let totalMs = 0;
  for (let i = 0; i < inWindow.length; i++) {
    const sample = inWindow[i];
    if (sample.speedMps >= STOP_SPEED_MPS) continue;

    const next = inWindow[i + 1];
    let spanEnd;
    if (next) {
      spanEnd = Math.min(next.sampledAt.getTime(), windowEnd);
      const gap = spanEnd - sample.sampledAt.getTime();
      if (gap > SAMPLE_GAP_CAP_MS) {
        spanEnd = sample.sampledAt.getTime() + SAMPLE_GAP_CAP_MS;
      }
    } else {
      spanEnd = Math.min(sample.sampledAt.getTime() + 5000, windowEnd);
    }
    totalMs += Math.max(0, spanEnd - sample.sampledAt.getTime());
  }

  return totalMs / 1000;
}

function evaluatePassengerBoarding({
  pickupReach,
  driverActivity,
  passengerActivity,
  driverTelemetry,
}) {
  const reachedAt = toDate(pickupReach?.reachedAt);
  if (!reachedAt) return false;
  if (Date.now() - reachedAt.getTime() > PICKUP_REACH_MAX_AGE_MS) return false;

  const driverSegments = parseSegments(driverActivity);
  const passengerSegments = parseSegments(passengerActivity);
  const telemetrySamples = parseTelemetrySamples(driverTelemetry);

  const passengerAutoSeconds = automotiveSecondsInWindow(passengerSegments);
  const driverAutoSeconds = automotiveSecondsInWindow(driverSegments);
  const overlapSeconds = overlapAutomotiveSeconds(driverSegments, passengerSegments);
  const stoppedSeconds = stoppedSecondsAfterPickup(reachedAt, telemetrySamples);

  const stopOk = stoppedSeconds >= MIN_STOP_SECONDS;

  const strictMotion =
    passengerAutoSeconds >= MIN_AUTOMOTIVE_SECONDS &&
    driverAutoSeconds >= MIN_DRIVER_AUTOMOTIVE_SECONDS &&
    overlapSeconds >= MIN_OVERLAP_SECONDS;

  const weakMotion =
    passengerAutoSeconds >= MIN_AUTOMOTIVE_WEAK_SECONDS &&
    driverAutoSeconds >= MIN_DRIVER_AUTOMOTIVE_SECONDS &&
    overlapSeconds >= MIN_OVERLAP_WEAK_SECONDS;

  return stopOk && (strictMotion || weakMotion);
}

async function markBoarded(db, groupId, tripDate, memberID) {
  const attendanceRef = db
    .collection("groups")
    .doc(groupId)
    .collection("attendance")
    .doc(tripDate);

  const snap = await attendanceRef.get();
  const responses = snap.data()?.responses || {};
  const existing = responses[memberID] || {};
  if (existing.boardedAt) return null;

  const nextResponses = { ...responses };
  nextResponses[memberID] = {
    ...existing,
    boardedAt: FieldValue.serverTimestamp(),
  };

  await attendanceRef.set(
    {
      updatedAt: FieldValue.serverTimestamp(),
      responses: nextResponses,
    },
    { merge: true }
  );

  return existing.name || memberID;
}

async function notifyPassengerBoarded(db, groupId, tripDate, boardedMemberID, boardedName) {
  const [membersSnap, attendanceSnap] = await Promise.all([
    db.collection("groups").doc(groupId).collection("members").get(),
    db.collection("groups").doc(groupId).collection("attendance").doc(tripDate).get(),
  ]);

  const responses = attendanceSnap.data()?.responses || {};
  const displayName =
    boardedName ||
    membersSnap.docs.find((doc) => doc.id === boardedMemberID)?.data()?.name ||
    "Yolcu";

  const messaging = getMessaging();
  const sends = [];

  for (const memberDoc of membersSnap.docs) {
    const member = memberDoc.data();
    if (member.role !== "passenger") continue;

    const memberID = memberDoc.id;
    const status = responses[memberID]?.status;
    if (status === "notComing") continue;

    const token = member.fcmToken;
    if (!token) continue;

    sends.push(
      messaging.send(
        buildPassengerBoardedMessage({
          token,
          groupId,
          boardedMemberID,
          boardedName: displayName,
        })
      )
    );
  }

  if (sends.length > 0) {
    await Promise.allSettled(sends);
  }
}

/**
 * @param {import("firebase-admin/firestore").Firestore} db
 * @param {string} groupId
 */
async function evaluateGroupBoarding(db, groupId) {
  const liveSnap = await db
    .collection("groups")
    .doc(groupId)
    .collection("live")
    .doc("current")
    .get();

  const live = liveSnap.data();
  if (!live?.isActive) return;

  const tripDate = live.tripDate;
  if (!tripDate) return;

  const groupRef = db.collection("groups").doc(groupId);
  const [activitySnap, attendanceSnap, membersSnap, telemetrySnap] = await Promise.all([
    groupRef.collection("tripActivity").get(),
    groupRef.collection("attendance").doc(tripDate).get(),
    groupRef.collection("members").get(),
    groupRef.collection("tripTelemetry").doc("driver").get(),
  ]);

  const driverActivity = activitySnap.docs.find((doc) => doc.id === "activity_driver")?.data();
  if (!driverActivity) return;

  const driverTelemetry = telemetrySnap.data();
  const responses = attendanceSnap.data()?.responses || {};
  const passengerIDs = membersSnap.docs
    .filter((doc) => doc.data().role === "passenger")
    .map((doc) => doc.id);

  for (const memberID of passengerIDs) {
    const status = responses[memberID]?.status;
    if (status === "notComing" || responses[memberID]?.boardedAt) continue;

    const pickupReach = activitySnap.docs.find((doc) => doc.id === `pickupReach_${memberID}`)?.data();
    const passengerActivity = activitySnap.docs
      .find((doc) => doc.id === `activity_passenger_${memberID}`)
      ?.data();

    if (!pickupReach || !passengerActivity) continue;

    if (
      !evaluatePassengerBoarding({
        pickupReach,
        driverActivity,
        passengerActivity,
        driverTelemetry,
      })
    ) {
      continue;
    }

    const boardedName = await markBoarded(db, groupId, tripDate, memberID);
    if (boardedName) {
      await notifyPassengerBoarded(db, groupId, tripDate, memberID, boardedName);
    }
  }
}

module.exports = {
  evaluateGroupBoarding,
};
