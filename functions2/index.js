const admin = require("firebase-admin");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");

admin.initializeApp();
async function isNotificationEnabled(userId, type) {
  try {
    const snap = await admin
      .firestore()
      .collection("users")
      .doc(userId)
      .collection("settings")
      .doc("notifications")
      .get();

    const data = snap.data() || {};

    // nếu chưa có setting → mặc định bật
    return data[type] !== false;
  } catch (e) {
    console.error("Notification setting error:", e);
    return true;
  }
}
// 🔥 function gửi push đơn giản
async function sendPushNotification({ token, title, body, data = {} }) {
  if (!token) return;

  try {
    const message = {
      token,
      notification: {
        title,
        body,
      },
      data: Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, String(v ?? "")])
      ),
    };

    await admin.messaging().send(message);
    console.log("Push sent");
  } catch (e) {
    console.error("Push error:", e);
  }
}

// 🔥 MATCH TRIGGER
exports.sendMatchNotification = onDocumentCreated(
  {
    document: "matches/{matchId}",
    region: "us-central1",
  },
  async (event) => {
    try {
      const data = event.data.data();
      const users = data.userIds || [];

      if (users.length !== 2) return;

      const userA = users[0];
      const userB = users[1];

      const userASnap = await admin.firestore().collection("users").doc(userA).get();
      const userBSnap = await admin.firestore().collection("users").doc(userB).get();

      const userAData = userASnap.data() || {};
      const userBData = userBSnap.data() || {};

      const tokenA = userAData.fcmToken;
      const tokenB = userBData.fcmToken;

      const nameA = userAData.firstName || "Someone";
      const nameB = userBData.firstName || "Someone";

      const matchEnabledA = await isNotificationEnabled(userA, "match");

if (matchEnabledA) {
  await sendPushNotification({
    token: tokenA,
    title: "🎉 It's a Match!",
    body: `You matched with ${nameB}`,
    data: {
      route: "chat",
      userId: userB,
    },
  });
}

      const matchEnabledB = await isNotificationEnabled(userB, "match");

if (matchEnabledB) {
  await sendPushNotification({
    token: tokenB,
    title: "🎉 It's a Match!",
    body: `You matched with ${nameA}`,
    data: {
      route: "chat",
      userId: userA,
    },
  });
}

      console.log("MATCH NOTIFICATION SENT");
    } catch (e) {
      console.error("sendMatchNotification error:", e);
    }
  }
);

exports.sendMessageNotification = onDocumentCreated(
  {
    document: "chats/{chatId}/messages/{messageId}",
    region: "us-central1",
  },
  async (event) => {
    try {
      const message = event.data.data();

      const senderId = message.senderId;
const receiverId = message.receiverId;
const text = message.text || "New message";
const messageType = message.type || "text";

if (!receiverId || !senderId) return;

// Không gửi notification nếu sender và receiver là cùng 1 người
if (senderId === receiverId) {
  console.log("Skip - sender and receiver are the same user");
  return;
}

      // 👉 lấy thông tin receiver
      const receiverSnap = await admin
        .firestore()
        .collection("users")
        .doc(receiverId)
        .get();

      const receiverData = receiverSnap.data() || {};
      const token = receiverData.fcmToken;

      // 👉 lấy tên sender
      const senderSnap = await admin
        .firestore()
        .collection("users")
        .doc(senderId)
        .get();

      const senderData = senderSnap.data() || {};
      const senderName = senderData.firstName || "Someone";

      // ⏳ delay 10 giây để gom message
await new Promise((resolve) => setTimeout(resolve, 10000));

// 🔍 check lại message mới nhất
const latestMessages = await admin
  .firestore()
  .collection("chats")
  .doc(event.params.chatId)
  .collection("messages")
  .orderBy("createdAt", "desc")
  .limit(1)
  .get();

const latest = latestMessages.docs[0]?.data();

if (!latest || latest.senderId !== senderId) {
  console.log("Skip - newer message exists");
  return;
}

const messageEnabled = await isNotificationEnabled(receiverId, "message");

if (!messageEnabled) {
  console.log("Message notification turned off");
  return;
}

let notificationTitle = "💬 New message";
let notificationBody = `${senderName} sent you a message.`;

if (messageType === "flower") {
  notificationTitle = "🌹 New flower";
  notificationBody = `${senderName} sent you a flower. Tap to view their message.`;
}

if (messageType === "image") {
  notificationBody = `${senderName} sent you a photo.`;
}

await sendPushNotification({
  token,
  title: notificationTitle,
  body: notificationBody,
  data: {
    route: "chat",
    chatId: event.params.chatId,
    userId: senderId,
    type: messageType,
  },
});

      console.log("MESSAGE NOTIFICATION SENT");
    } catch (e) {
      console.error("sendMessageNotification error:", e);
    }
  }
);
const { onSchedule } = require("firebase-functions/v2/scheduler");

exports.remindUnreadMessages = onSchedule(
  {
    schedule: "every 3 hours",
    region: "us-central1",
    timeZone: "Australia/Sydney",
  },
  async () => {
    try {
      const snapshot = await admin
        .firestore()
        .collectionGroup("messages")
        .where("isRead", "==", false)
        .get();

      for (const doc of snapshot.docs) {
        const data = doc.data();

        const receiverId = data.receiverId;
        if (!receiverId) continue;

        // check setting
        const enabled = await isNotificationEnabled(receiverId, "message");
        if (!enabled) continue;

        const userSnap = await admin
          .firestore()
          .collection("users")
          .doc(receiverId)
          .get();

       const userData = userSnap.data() || {};
const token = userData.fcmToken;

// chống spam reminder: chỉ gửi tối đa 1 lần mỗi 60 phút
const lastNotifiedAt = userData.lastNotifiedAt?.toDate?.();
const now = new Date();

if (lastNotifiedAt) {
  const diffMinutes = (now - lastNotifiedAt) / (1000 * 60);

  if (diffMinutes < 180) {
    console.log("Skip unread reminder - recently notified");
    continue;
  }
}

await sendPushNotification({
  token,
  title: "💬 You have unread messages",
  body: "Open the app to reply now",
});

await admin.firestore().collection("users").doc(receiverId).set(
  {
    lastNotifiedAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  { merge: true }
);
      }

      console.log("REMINDER SENT");
    } catch (e) {
      console.error("remindUnreadMessages error:", e);
    }
  }
);