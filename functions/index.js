const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

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

    const membersSnapshot = await db
      .collection("groups")
      .doc(groupId)
      .collection("members")
      .get();

    const tokens = membersSnapshot.docs
      .map((doc) => doc.data().fcmToken)
      .filter(Boolean);

    if (tokens.length === 0) {
      return;
    }

    await getMessaging().sendEachForMulticast({
      tokens,
      notification: {
        title: "Servis yola çıktı!",
        body: `${driverName} servisi başlattı. Gelecek misiniz?`,
      },
      data: {
        type: "trip_started",
        groupId,
      },
    });
  }
);
