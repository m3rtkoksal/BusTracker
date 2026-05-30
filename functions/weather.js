/** Open-Meteo — iOS/Android ortak, API key yok. */

const OPEN_METEO_URL = "https://api.open-meteo.com/v1/forecast";
const COLD_TEMP_C = 6;
const HOT_TEMP_C = 31;
const WET_MM = 0.15;

const TRIP_CHECKLIST_LINES = [
  "Çantanı hazırla, anahtar ve cüzdanı unutma.",
  "Anahtar, cüzdan, çanta — üçlü kontrol.",
  "Çantanı al; anahtar ve cüzdan cebinde olsun.",
  "Bro, çanta + anahtar + cüzdan. Hepsi tamam mı?",
];

const TRIP_TITLE_CASUAL = "Bro, servis yola çıktı!";
const TRIP_TITLE_NORMAL = "Servis yola çıktı";

/**
 * @param {number} lat
 * @param {number} lng
 * @returns {Promise<{ tempC: number, precipitation: number, rain: number } | null>}
 */
async function fetchWeatherAt(lat, lng) {
  const url = new URL(OPEN_METEO_URL);
  url.searchParams.set("latitude", String(lat));
  url.searchParams.set("longitude", String(lng));
  url.searchParams.set("current", "temperature_2m,precipitation,rain");
  url.searchParams.set("timezone", "auto");

  try {
    const res = await fetch(url, { signal: AbortSignal.timeout(8000) });
    if (!res.ok) {
      console.warn("[weather] Open-Meteo HTTP", res.status);
      return null;
    }
    const json = await res.json();
    const cur = json?.current;
    if (!cur || typeof cur.temperature_2m !== "number") {
      return null;
    }
    return {
      tempC: cur.temperature_2m,
      precipitation: Number(cur.precipitation) || 0,
      rain: Number(cur.rain) || 0,
    };
  } catch (err) {
    console.warn("[weather] fetch failed:", err?.message || err);
    return null;
  }
}

/**
 * @param {{ tempC: number, precipitation: number, rain: number }} weather
 * @returns {string | null}
 */
function weatherAccessoryHint(weather) {
  const wet = weather.precipitation >= WET_MM || weather.rain >= WET_MM;
  if (wet) {
    return "Yağmur var — şemsiyeni kap.";
  }
  if (weather.tempC <= COLD_TEMP_C) {
    return "Hava soğuk — bere takmadan çıkma.";
  }
  if (weather.tempC >= HOT_TEMP_C) {
    return "Hava cehennem gibi — şapka tak, su al.";
  }
  return null;
}

function pickRandom(items) {
  return items[Math.floor(Math.random() * items.length)];
}

/**
 * @param {string} driverName
 * @param {string | null} weatherHint
 */
function buildTripStartedNotification(driverName, weatherHint) {
  const checklist = pickRandom(TRIP_CHECKLIST_LINES);
  const who = driverName?.trim() || "Şoför";

  if (weatherHint) {
    return {
      title: TRIP_TITLE_CASUAL,
      body: `${who} başlattı. ${weatherHint} ${checklist}`,
    };
  }

  return {
    title: TRIP_TITLE_NORMAL,
    body: `${who} servisi başlattı. ${checklist}`,
  };
}

/**
 * Sürücü konumu (live/current), yoksa ilk sabah biniş noktası.
 * @param {import("firebase-admin/firestore").Firestore} db
 * @param {string} groupId
 */
async function resolveWeatherCoordinates(db, groupId) {
  const liveSnap = await db
    .collection("groups")
    .doc(groupId)
    .collection("live")
    .doc("current")
    .get();

  if (liveSnap.exists) {
    const live = liveSnap.data() || {};
    const lat = Number(live.latitude);
    const lng = Number(live.longitude);
    if (Number.isFinite(lat) && Number.isFinite(lng)) {
      return { lat, lng, source: "driver" };
    }
  }

  const pickupsSnap = await db
    .collection("groups")
    .doc(groupId)
    .collection("morningPickups")
    .limit(1)
    .get();

  if (!pickupsSnap.empty) {
    const pickup = pickupsSnap.docs[0].data() || {};
    const lat = Number(pickup.latitude);
    const lng = Number(pickup.longitude);
    if (Number.isFinite(lat) && Number.isFinite(lng)) {
      return { lat, lng, source: "pickup" };
    }
  }

  return null;
}

/**
 * @param {import("firebase-admin/firestore").Firestore} db
 * @param {string} groupId
 */
async function buildTripStartedMessageForGroup(db, groupId, driverName) {
  const coords = await resolveWeatherCoordinates(db, groupId);
  if (!coords) {
    console.log("[weather] no coordinates for group", groupId);
    return buildTripStartedNotification(driverName, null);
  }

  const weather = await fetchWeatherAt(coords.lat, coords.lng);
  const hint = weather ? weatherAccessoryHint(weather) : null;
  console.log(
    "[weather] group",
    groupId,
    coords.source,
    weather ? `${weather.tempC}°C wet=${weather.precipitation}` : "no data",
    hint || "normal"
  );
  return buildTripStartedNotification(driverName, hint);
}

const RETURNEE_BODY_LINES = [
  "Dün gelmedin, özledik seni. Bugün görüşürüz mü? ❤️",
  "Dün yoktun, seni özledik. Bugün gelir misin? ❤️",
  "Dün gelmedin lan, servis sensiz eksik kaldı. Bugün görüşelim mi? ❤️",
];

const RETURNEE_TITLE = "Servis yola çıktı";

/**
 * Takvim günü (yyyy-MM-dd) — bir gün geri (Europe/Istanbul).
 * @param {string} dateKey
 */
function previousDateKey(dateKey) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(dateKey)) {
    return null;
  }
  const noon = new Date(`${dateKey}T12:00:00+03:00`);
  noon.setTime(noon.getTime() - 86400000);
  return noon.toLocaleDateString("en-CA", { timeZone: "Europe/Istanbul" });
}

/**
 * @param {import("firebase-admin/firestore").Firestore} db
 * @param {string} groupId
 * @param {string} tripDateKey — servisin başladığı gün (event.date)
 */
async function fetchYesterdayNotComingMemberIds(db, groupId, tripDateKey) {
  const yesterdayKey = previousDateKey(tripDateKey);
  if (!yesterdayKey) {
    return new Set();
  }

  const snap = await db
    .collection("groups")
    .doc(groupId)
    .collection("attendance")
    .doc(yesterdayKey)
    .get();

  if (!snap.exists) {
    return new Set();
  }

  const responses = snap.data()?.responses || {};
  const ids = new Set();
  for (const [memberID, payload] of Object.entries(responses)) {
    if (payload?.status === "notComing") {
      ids.add(memberID);
    }
  }
  return ids;
}

/**
 * Dün "gelmiyorum" diyen yolcu — sıcak dönüş bildirimi.
 * @param {string} driverName
 */
function buildReturneeTripNotification(driverName) {
  const line = pickRandom(RETURNEE_BODY_LINES);
  const who = driverName?.trim() || "Şoför";
  return {
    title: RETURNEE_TITLE,
    body: `${line} ${who} servisi başlattı.`,
  };
}

module.exports = {
  buildTripStartedMessageForGroup,
  buildReturneeTripNotification,
  fetchYesterdayNotComingMemberIds,
  previousDateKey,
  fetchWeatherAt,
  weatherAccessoryHint,
  buildTripStartedNotification,
};
