/** FCM — servis başladı + servis çağrısı (özel ses: approach_tink). */

const CHANNEL_TRIP = "bustracker_trip_v2";
const CHANNEL_APPROACHING = "bustracker_approaching";

const SOUND_TRIP_IOS = "approach_tink.caf";
const SOUND_TRIP_ANDROID = "approach_tink";
const SOUND_APPROACH_IOS = SOUND_TRIP_IOS;
const SOUND_APPROACH_ANDROID = SOUND_TRIP_ANDROID;

const APPROACH_TITLE = "Servis seni çağırıyor";
const APPROACH_SUBTITLE = "Korna = senin vanın, dışarı çık";
const APPROACH_BODIES = [
  "Biniş noktandayız — şimdi in, seni bekliyoruz.",
  "Bu ses senin servis çağrın — kapıya gel, kaçırma.",
  "Van hazır, seni almaya geldik — dışarı çık.",
  "Sürücü seni çağırıyor — 1 dakikada orada ol.",
];

function pickRandom(items) {
  return items[Math.floor(Math.random() * items.length)];
}

/**
 * Sürücü servisi başlattı — tüm yolculara (tatil/coming kuralları index.js'te).
 */
function buildTripStartedMessage({
  token,
  groupId,
  memberID,
  notification,
  returnee = false,
}) {
  const { title, body } = notification;
  return {
    token,
    notification: { title, body },
    data: {
      type: "trip_started",
      groupId,
      memberID,
      returnee: returnee ? "1" : "0",
    },
    android: {
      priority: "high",
      notification: {
        channelId: CHANNEL_TRIP,
        sound: SOUND_TRIP_ANDROID,
        priority: "high",
        tag: `trip_started_${groupId}_${memberID}`,
        ticker: title,
        visibility: "public",
      },
    },
    apns: {
      headers: { "apns-priority": "10" },
      payload: {
        aps: {
          alert: { title, body },
          sound: SOUND_TRIP_IOS,
          "thread-id": `trip_${groupId}`,
        },
      },
    },
  };
}

/**
 * Sürücü biniş noktasına yaklaşınca — servis çağrısı (korna sesi).
 */
function buildDriverApproachingMessage({ token, groupId, memberID }) {
  const body = pickRandom(APPROACH_BODIES);
  const tag = `shuttle_call_${groupId}_${memberID}`;
  return {
    token,
    notification: {
      title: APPROACH_TITLE,
      body,
    },
    data: {
      type: "driver_approaching",
      action: "shuttle_call",
      groupId,
      memberID,
    },
    android: {
      priority: "high",
      notification: {
        channelId: CHANNEL_APPROACHING,
        sound: SOUND_APPROACH_ANDROID,
        priority: "high",
        tag,
        ticker: APPROACH_TITLE,
        visibility: "public",
        defaultVibrateTimings: false,
        vibrateTimingsMillis: [0, 140, 90, 140, 90, 220],
      },
    },
    apns: {
      headers: {
        "apns-priority": "10",
      },
      payload: {
        aps: {
          alert: {
            title: APPROACH_TITLE,
            subtitle: APPROACH_SUBTITLE,
            body,
          },
          sound: SOUND_APPROACH_IOS,
          "thread-id": `shuttle_call_${groupId}`,
        },
      },
    },
  };
}

/**
 * Bir yolcu servise bindi — tüm servise (gelmeyenler hariç).
 */
function buildPassengerBoardedMessage({ token, groupId, boardedMemberID, boardedName }) {
  const title = "Servis";
  const body = `${boardedName} servise bindi`;
  return {
    token,
    notification: { title, body },
    data: {
      type: "passenger_boarded",
      groupId,
      boardedMemberID,
      boardedName,
    },
    android: {
      priority: "high",
      notification: {
        channelId: CHANNEL_APPROACHING,
        sound: SOUND_APPROACH_ANDROID,
        priority: "high",
        tag: `passenger_boarded_${groupId}_${boardedMemberID}`,
        ticker: body,
        visibility: "public",
        defaultVibrateTimings: false,
        vibrateTimingsMillis: [0, 140, 90, 140, 90, 220],
      },
    },
    apns: {
      headers: { "apns-priority": "10" },
      payload: {
        aps: {
          alert: { title, body },
          sound: SOUND_APPROACH_IOS,
          "thread-id": `trip_${groupId}`,
        },
      },
    },
  };
}

module.exports = {
  CHANNEL_TRIP,
  CHANNEL_APPROACHING,
  buildTripStartedMessage,
  buildDriverApproachingMessage,
  buildPassengerBoardedMessage,
};
