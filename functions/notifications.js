/** FCM — servis çağrısı (korna sesi) vs genel servis bildirimleri. */

const CHANNEL_TRIP = "bustracker_trip";
const CHANNEL_APPROACHING = "bustracker_approaching";

const SOUND_APPROACH_IOS = "approach_tink.caf";
const SOUND_APPROACH_ANDROID = "approach_tink";

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

module.exports = {
  CHANNEL_TRIP,
  CHANNEL_APPROACHING,
  buildDriverApproachingMessage,
};
