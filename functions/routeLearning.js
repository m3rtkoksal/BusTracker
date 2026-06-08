/**
 * Sabah servisi rota öğrenme — routeHistory → OSRM → canonicalRoutes/morning
 *
 * - Yalnızca session === "am"
 * - Son 7 günde en az 5 sabah seferi (yoksa son 5 sabah seferi)
 * - Her yeni sabah kaydı veya haftalık pencerede kaynak seti değişince güncelle
 */

const { FieldValue, Timestamp } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const {
  buildCanonicalRouteReadyMessage,
  buildCanonicalRouteReadyNotification,
} = require("./notifications");

const MORNING_SESSION = "am";
const MIN_TRIPS = 5;
const WEEK_MS = 7 * 24 * 60 * 60 * 1000;
const MAX_OSRM_COORDS = 50;
const RESAMPLE_COUNT = 80;
const ROUTE_WAYPOINTS = 24;

const DEFAULT_OSRM_BASE_URL = "https://router.project-osrm.org";

function osrmBaseUrl() {
  return (process.env.OSRM_BASE_URL || DEFAULT_OSRM_BASE_URL).replace(/\/$/, "");
}

function haversineMeters(lat1, lon1, lat2, lon2) {
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

function parsePoint(raw) {
  const latitude = Number(raw?.latitude);
  const longitude = Number(raw?.longitude);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    return null;
  }
  return { latitude, longitude };
}

function parseRoutePoints(data) {
  const rawPoints = data?.points;
  if (!Array.isArray(rawPoints)) return [];
  return rawPoints.map(parsePoint).filter(Boolean);
}

function toDate(value) {
  if (!value) return null;
  if (value instanceof Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  if (typeof value.toDate === "function") return value.toDate();
  return null;
}

function downsampleUniform(points, maxCount) {
  if (points.length <= maxCount) return points;
  if (maxCount < 2) return [points[0]];

  const result = [];
  for (let i = 0; i < maxCount; i++) {
    const index = Math.round((i * (points.length - 1)) / (maxCount - 1));
    result.push(points[index]);
  }
  return result;
}

function cumulativeDistances(points) {
  const distances = [0];
  for (let i = 1; i < points.length; i++) {
    const prev = points[i - 1];
    const current = points[i];
    distances.push(
      distances[i - 1] +
        haversineMeters(
          prev.latitude,
          prev.longitude,
          current.latitude,
          current.longitude
        )
    );
  }
  return distances;
}

function interpolatePoint(points, distances, targetDistance) {
  if (points.length === 0) return null;
  if (targetDistance <= 0) return points[0];
  const total = distances[distances.length - 1];
  if (targetDistance >= total) return points[points.length - 1];

  let upperIndex = distances.findIndex((distance) => distance >= targetDistance);
  if (upperIndex <= 0) return points[0];

  const lowerIndex = upperIndex - 1;
  const segmentStart = distances[lowerIndex];
  const segmentEnd = distances[upperIndex];
  const ratio =
    segmentEnd === segmentStart
      ? 0
      : (targetDistance - segmentStart) / (segmentEnd - segmentStart);

  const a = points[lowerIndex];
  const b = points[upperIndex];
  return {
    latitude: a.latitude + (b.latitude - a.latitude) * ratio,
    longitude: a.longitude + (b.longitude - a.longitude) * ratio,
  };
}

function resampleByDistance(points, targetCount) {
  if (points.length === 0) return [];
  if (points.length === 1) return Array.from({ length: targetCount }, () => points[0]);

  const distances = cumulativeDistances(points);
  const total = distances[distances.length - 1];
  if (total === 0) return Array.from({ length: targetCount }, () => points[0]);

  const result = [];
  for (let i = 0; i < targetCount; i++) {
    const targetDistance = (total * i) / (targetCount - 1);
    result.push(interpolatePoint(points, distances, targetDistance));
  }
  return result;
}

function averageRoutes(routes, sampleCount) {
  const resampled = routes
    .filter((route) => route.length >= 2)
    .map((route) => resampleByDistance(route, sampleCount));

  if (resampled.length === 0) return [];

  const averaged = [];
  for (let i = 0; i < sampleCount; i++) {
    let latitude = 0;
    let longitude = 0;
    for (const route of resampled) {
      latitude += route[i].latitude;
      longitude += route[i].longitude;
    }
    averaged.push({
      latitude: latitude / resampled.length,
      longitude: longitude / resampled.length,
    });
  }
  return averaged;
}

async function fetchOsrmJson(url) {
  const response = await fetch(url, {
    headers: { Accept: "application/json" },
  });
  if (!response.ok) {
    throw new Error(`OSRM HTTP ${response.status}`);
  }
  return response.json();
}

function geometryToPoints(geometry) {
  const coordinates = geometry?.coordinates;
  if (!Array.isArray(coordinates)) return [];
  return coordinates
    .map(([longitude, latitude]) => parsePoint({ latitude, longitude }))
    .filter(Boolean);
}

async function osrmMatch(points) {
  if (points.length < 2) return points;

  const sampled = downsampleUniform(points, MAX_OSRM_COORDS);
  const coordString = sampled
    .map((point) => `${point.longitude},${point.latitude}`)
    .join(";");

  const url =
    `${osrmBaseUrl()}/match/v1/driving/${coordString}` +
    "?geometries=geojson&overview=full&steps=false&gaps=ignore";

  try {
    const data = await fetchOsrmJson(url);
    if (data.code !== "Ok" || !data.matchings?.length) {
      console.warn("[routeLearning] OSRM match no result, using sampled GPS");
      return sampled;
    }
    const longest = data.matchings.reduce((best, current) =>
      (current.distance || 0) > (best.distance || 0) ? current : best
    );
    const matched = geometryToPoints(longest.geometry);
    return matched.length >= 2 ? matched : sampled;
  } catch (error) {
    console.warn("[routeLearning] OSRM match failed:", error.message);
    return sampled;
  }
}

async function osrmRoute(waypoints) {
  if (waypoints.length < 2) return waypoints;

  const sampled = downsampleUniform(waypoints, ROUTE_WAYPOINTS);
  const coordString = sampled
    .map((point) => `${point.longitude},${point.latitude}`)
    .join(";");

  const url =
    `${osrmBaseUrl()}/route/v1/driving/${coordString}` +
    "?geometries=geojson&overview=full&steps=false";

  try {
    const data = await fetchOsrmJson(url);
    if (data.code !== "Ok" || !data.routes?.length) {
      console.warn("[routeLearning] OSRM route no result, using averaged points");
      return waypoints;
    }
    const routed = geometryToPoints(data.routes[0].geometry);
    return routed.length >= 2 ? routed : waypoints;
  } catch (error) {
    console.warn("[routeLearning] OSRM route failed:", error.message);
    return waypoints;
  }
}

async function fetchMorningTrips(db, groupId) {
  const snapshot = await db
    .collection("groups")
    .doc(groupId)
    .collection("routeHistory")
    .where("session", "==", MORNING_SESSION)
    .orderBy("endedAt", "desc")
    .limit(20)
    .get();

  const now = Date.now();
  const weekCutoff = now - WEEK_MS;

  const trips = snapshot.docs
    .map((doc) => {
      const data = doc.data();
      const points = parseRoutePoints(data);
      const endedAt = toDate(data.endedAt);
      return {
        id: doc.id,
        points,
        pointCount: points.length,
        tripDate: data.tripDate || null,
        endedAt,
        endedAtMs: endedAt?.getTime() || 0,
      };
    })
    .filter((trip) => trip.points.length >= 5);

  const weeklyTrips = trips.filter((trip) => trip.endedAtMs >= weekCutoff);
  const selected =
    weeklyTrips.length >= MIN_TRIPS
      ? weeklyTrips.slice(0, MIN_TRIPS)
      : trips.slice(0, MIN_TRIPS);

  return {
    allCount: trips.length,
    weeklyCount: weeklyTrips.length,
    selected,
    window: weeklyTrips.length >= MIN_TRIPS ? "weekly" : "all_time",
  };
}

function shouldSkipReconcile(existing, selectedTrips) {
  if (!existing?.exists) return false;

  const data = existing.data() || {};
  const reconciledAt = data.reconciledAt?.toMillis?.() || 0;
  const daysSince = (Date.now() - reconciledAt) / (24 * 60 * 60 * 1000);

  const nextIds = selectedTrips
    .map((trip) => trip.id)
    .sort()
    .join(",");
  const prevIds = (data.sourceTripIds || []).slice().sort().join(",");

  return daysSince < 7 && nextIds === prevIds && data.status === "ready";
}

async function notifyCanonicalRouteReady(db, groupId) {
  const membersSnapshot = await db
    .collection("groups")
    .doc(groupId)
    .collection("members")
    .get();

  const recipients = membersSnapshot.docs
    .filter((doc) => doc.data().fcmToken)
    .map((doc) => ({
      memberID: doc.id,
      token: doc.data().fcmToken,
    }));

  console.log(
    "[routeLearning] notify canonical ready:",
    groupId,
    "recipients:",
    recipients.length
  );

  if (recipients.length === 0) {
    return;
  }

  const notification = buildCanonicalRouteReadyNotification();
  const messages = recipients.map(({ memberID, token }) =>
    buildCanonicalRouteReadyMessage({
      token,
      groupId,
      memberID,
      notification,
    })
  );

  const result = await getMessaging().sendEach(messages);
  const failed = result.responses.filter((response) => !response.success).length;
  if (failed > 0) {
    console.warn("[routeLearning] canonical route FCM failures:", failed);
  } else {
    console.log("[routeLearning] canonical route FCM sent:", messages.length);
  }
}

async function writeCollectingStatus(canonicalRef, tripSummary) {
  await canonicalRef.set(
    {
      session: MORNING_SESSION,
      status: "collecting",
      collectedTripCount: tripSummary.allCount,
      weeklyTripCount: tripSummary.weeklyCount,
      requiredTripCount: MIN_TRIPS,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

/**
 * @param {import("firebase-admin/firestore").Firestore} db
 * @param {string} groupId
 */
async function reconcileGroupMorningRoute(db, groupId) {
  const tripSummary = await fetchMorningTrips(db, groupId);
  const canonicalRef = db
    .collection("groups")
    .doc(groupId)
    .collection("canonicalRoutes")
    .doc("morning");

  console.log("[routeLearning] group:", groupId, {
    all: tripSummary.allCount,
    weekly: tripSummary.weeklyCount,
    selected: tripSummary.selected.length,
    window: tripSummary.window,
  });

  if (tripSummary.selected.length < MIN_TRIPS) {
    await writeCollectingStatus(canonicalRef, tripSummary);
    return;
  }

  const existing = await canonicalRef.get();
  const wasAlreadyReady =
    existing.exists && existing.data()?.status === "ready";

  if (shouldSkipReconcile(existing, tripSummary.selected)) {
    console.log("[routeLearning] skip unchanged canonical", groupId);
    return;
  }

  const matchedRoutes = [];
  for (const trip of tripSummary.selected) {
    const matched = await osrmMatch(trip.points);
    if (matched.length >= 2) {
      matchedRoutes.push(matched);
    }
  }

  if (matchedRoutes.length < MIN_TRIPS) {
    console.warn("[routeLearning] insufficient matched routes", groupId);
    await writeCollectingStatus(canonicalRef, tripSummary);
    return;
  }

  const averaged = averageRoutes(matchedRoutes, RESAMPLE_COUNT);
  const finalPoints = await osrmRoute(averaged);
  const pointsData = finalPoints.map((point) => ({
    latitude: point.latitude,
    longitude: point.longitude,
  }));

  const tripDates = tripSummary.selected
    .map((trip) => trip.tripDate)
    .filter(Boolean)
    .sort();

  await canonicalRef.set({
    session: MORNING_SESSION,
    status: "ready",
    points: pointsData,
    pointCount: pointsData.length,
    sourceTripCount: tripSummary.selected.length,
    sourceTripIds: tripSummary.selected.map((trip) => trip.id),
    selectionWindow: tripSummary.window,
    windowStartDate: tripDates[0] || null,
    windowEndDate: tripDates[tripDates.length - 1] || null,
    collectedTripCount: tripSummary.allCount,
    weeklyTripCount: tripSummary.weeklyCount,
    requiredTripCount: MIN_TRIPS,
    reconciledAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
    version: FieldValue.increment(1),
  });

  console.log(
    "[routeLearning] canonical updated",
    groupId,
    "points:",
    pointsData.length
  );

  if (!wasAlreadyReady) {
    await notifyCanonicalRouteReady(db, groupId);
  }
}

module.exports = {
  MORNING_SESSION,
  MIN_TRIPS,
  reconcileGroupMorningRoute,
};
