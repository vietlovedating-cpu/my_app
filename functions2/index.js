const sgMail = require("@sendgrid/mail");
require("dotenv").config();

const admin = require("firebase-admin");
const functions = require("firebase-functions/v1");

const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError, onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");


admin.initializeApp();

/*
exports.deleteUnverifiedUserByEmail = onCall(async (request) => {
  const email = String(request.data.email || "").trim().toLowerCase();

  if (!email) {
    throw new HttpsError("invalid-argument", "Missing email");
  }

  const user = await admin.auth().getUserByEmail(email);

  if (user.emailVerified) {
    throw new HttpsError(
      "failed-precondition",
      "Email already verified"
    );
  }

  await admin.auth().deleteUser(user.uid);

  await admin.firestore().collection("users").doc(user.uid).delete().catch(() => {});
  

  return {
    ok: true,
    deletedUid: user.uid,
  };
});
*/
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
  apns: {
    payload: {
      aps: {
        sound: "default",
      },
    },
  },
};

console.log("ABOUT TO SEND PUSH");
console.log("TOKEN =", token);
    const response = await admin.messaging().send(message);
console.log("Push sent:", response);
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

const latestDoc = latestMessages.docs[0];
const latest = latestDoc?.data();

if (
  !latestDoc ||
  latestDoc.id !== event.params.messageId ||
  latest.senderId !== senderId
) {
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
exports.sendMessageReactionNotification = onDocumentUpdated(
  {
    document: "chats/{chatId}/messages/{messageId}",
    region: "us-central1",
  },
  async (event) => {
    try {
      const before = event.data.before.data() || {};
      const after = event.data.after.data() || {};

      const beforeReactions = before.reactions || {};
      const afterReactions = after.reactions || {};

      const reactionUserIds = Object.keys(afterReactions);

      for (const reactionUserId of reactionUserIds) {
        const oldReaction = beforeReactions[reactionUserId];
        const newReaction = afterReactions[reactionUserId];

        if (!newReaction || oldReaction === newReaction) {
          continue;
        }

        const messageSenderId = after.senderId;

        if (!messageSenderId || reactionUserId === messageSenderId) {
          continue;
        }

        const receiverSnap = await admin
          .firestore()
          .collection("users")
          .doc(messageSenderId)
          .get();

        const receiverData = receiverSnap.data() || {};
        const token = receiverData.fcmToken;

        if (!token) {
          continue;
        }

        const reactionUserSnap = await admin
          .firestore()
          .collection("users")
          .doc(reactionUserId)
          .get();

        const reactionUserData = reactionUserSnap.data() || {};
        const reactionUserName =
          reactionUserData.firstName || "Someone";

        await sendPushNotification({
          token,
          title: "VietLove Dating",
          body: `${reactionUserName} reacted ${newReaction} to your message.`,
          data: {
            route: "chat",
            chatId: event.params.chatId,
            userId: reactionUserId,
            type: "message_reaction",
          },
        });

        console.log(
          "MESSAGE REACTION NOTIFICATION SENT:",
          event.params.chatId,
          event.params.messageId
        );
      }
    } catch (e) {
      console.error(
        "sendMessageReactionNotification error:",
        e
      );
    }
  }
);
exports.sendGroupMessageNotification = onDocumentCreated(
  {
    document: "groups/{groupId}/messages/{messageId}",
    region: "us-central1",
  },
  async (event) => {
    try {
      const message = event.data.data();
      const groupId = event.params.groupId;
      const messageId = event.params.messageId;
      const db = admin.firestore();

      const senderId = (message.senderId || "").toString();
      const senderName = (message.senderName || "Someone").toString();
      const text = (message.text || "").toString();
      const messageType = (message.type || "text").toString();

      if (!groupId || !senderId) return;
      const senderMemberRef = db
  .collection("groups")
  .doc(groupId)
  .collection("members")
  .doc(senderId);

const senderMemberSnap = await senderMemberRef.get();
const now = new Date();

if (senderMemberSnap.exists) {
  const lastSentAt =
    senderMemberSnap.data()?.lastGroupNotificationAt?.toDate?.();

  if (lastSentAt) {
    const diffSeconds = (now - lastSentAt) / 1000;

    if (diffSeconds < 60) {
      console.log("Skip group notification spam:", groupId, senderId);
      return;
    }
  }
}
      
      await new Promise((resolve) => setTimeout(resolve, 10000));

const latestMessages = await admin
  .firestore()
  .collection("groups")
  .doc(groupId)
  .collection("messages")
  .orderBy("createdAt", "desc")
  .limit(1)
  .get();

const latestDoc = latestMessages.docs[0];
const latest = latestDoc?.data();

if (
  !latestDoc ||
  latestDoc.id !== messageId ||
  latest.senderId !== senderId
) {
  console.log("Skip group notification - newer message exists");
  return;
}
await senderMemberRef.set(
  {
    lastGroupNotificationAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  { merge: true }
);

      const groupTitles = {
        weekend_coffee: "Weekend Coffee",
        hiking_camping: "Hiking & Camping",
        speed_dating: "Speed Dating",
        gym_fitness: "Gym & Fitness",
      };

            const groupTitle = groupTitles[groupId] || "Group Chat";

      const membersSnap = await admin
        .firestore()
        .collection("groups")
        .doc(groupId)
        .collection("members")
        .where("membershipActive", "==", true)
        .get();

      for (const memberDoc of membersSnap.docs) {
        const memberData = memberDoc.data() || {};
        const receiverId = memberData.uid || memberData.userId || memberDoc.id;

        if (!receiverId || receiverId === senderId) continue;

        const expiresAt = memberData.expiresAt?.toDate?.();
        if (!expiresAt || expiresAt < new Date()) continue;

        const userSnap = await admin
          .firestore()
          .collection("users")
          .doc(receiverId)
          .get();

        const userData = userSnap.data() || {};
        const token = userData.fcmToken;

        if (!token) continue;

        const groupMessageEnabled = await isNotificationEnabled(
  receiverId,
  "groupMessage"
);

if (!groupMessageEnabled) {
  continue;
}

        let body = `${senderName}: ${text}`;

        if (messageType === "image") {
          body = `${senderName} sent a photo.`;
        }

        if (!text && messageType !== "image") {
          body = `${senderName} sent a message.`;
        }

        await sendPushNotification({
          token,
          title: `👥 ${groupTitle}`,
          body,
          data: {
            route: "group_chat",
            groupId,
            type: "group_message",
            senderId,
          },
        });
      }

      console.log("GROUP MESSAGE NOTIFICATIONS SENT:", groupId);
    } catch (e) {
      console.error("sendGroupMessageNotification error:", e);
    }
  }
);
exports.remindUnreadMessages = onSchedule(
  {
    schedule: "every 24 hours",
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







exports.addFreeGroupsForNewUser = functions.auth.user().onCreate(
  async (user) => {
    try {

      if (!user) return;

      const uid = user.uid;
      const email = user.email || "";

      // lấy thêm info user
      const userSnap = await admin
        .firestore()
        .collection("users")
        .doc(uid)
        .get();

      const userData = userSnap.data() || {};

      const firstName = userData.firstName || "";
      const mainPhotoUrl = userData.mainPhotoUrl || "";

      const groups = [
  "weekend_coffee",
  "hiking_camping",
  "gym_fitness",
  "speed_dating",
];

      // hết free sau 2 tháng
      const expiresAt = admin.firestore.Timestamp.fromDate(
        new Date("2026-07-07T23:59:59+10:00")
      );

      const batch = admin.firestore().batch();

      for (const groupId of groups) {
        const ref = admin
          .firestore()
          .collection("groups")
          .doc(groupId)
          .collection("members")
          .doc(uid);

        batch.set(
          ref,
          {
            userId: uid,
            uid: uid,
            email: email,
            firstName: firstName,
            mainPhotoUrl: mainPhotoUrl,

            membershipActive: true,

            expiresAt: expiresAt,

            joinedAt: admin.firestore.FieldValue.serverTimestamp(),

            updatedAt: admin.firestore.FieldValue.serverTimestamp(),

            expiredHandled: false,
            reminder7dSent: false,
            reminder3dSent: false,

            source: "promo",

            planType: "promo_2_months",

            price: 0,

            currency: "AUD",

            groupId: groupId,
          },
          { merge: true }
        );
      }

      await batch.commit();

      console.log("FREE GROUPS ADDED FOR:", uid);
    } catch (e) {
      console.error("addFreeGroupsForNewUser error:", e);
    }
  }
);






exports.addPromoForAllExistingUsers = onRequest(
  {
    region: "us-central1",
  },
  async (req, res) => {
    try {
      const secret = req.query.secret;

      if (secret !== "vietlove_free_2026") {
        res.status(403).send("Forbidden");
        return;
      }

      const usersSnapshot = await admin.firestore().collection("users").get();

      const groups = [
        "weekend_coffee",
        "hiking_camping",
        "gym_fitness",
        "speed_dating",
      ];

      const expiresAt = admin.firestore.Timestamp.fromDate(
        new Date("2026-07-07T23:59:59+10:00")
      );

      let count = 0;

      for (const userDoc of usersSnapshot.docs) {
        const uid = userDoc.id;
        const userData = userDoc.data() || {};

        const batch = admin.firestore().batch();

        for (const groupId of groups) {
          const ref = admin
            .firestore()
            .collection("groups")
            .doc(groupId)
            .collection("members")
            .doc(uid);

          batch.set(
            ref,
            {
              userId: uid,
              uid: uid,
              email: userData.email || "",
              firstName: userData.firstName || "",
              mainPhotoUrl: userData.mainPhotoUrl || "",
              membershipActive: true,
              expiresAt: expiresAt,
              joinedAt: admin.firestore.FieldValue.serverTimestamp(),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              expiredHandled: false,
              reminder7dSent: false,
              reminder3dSent: false,
              source: "promo",
              planType: "promo_2_months",
              price: 0,
              currency: "AUD",
              groupId: groupId,
            },
            { merge: true }
          );
        }

        await batch.commit();
        count++;
      }

      res.status(200).send(`DONE. Total users updated: ${count}`);
    } catch (e) {
      console.error("addPromoForAllExistingUsers error:", e);
      res.status(500).send(e.toString());
    }
  }
);
/*
exports.sendIncompleteProfileReminderEmails = onSchedule(
  {
    schedule: "every day 09:00",
    region: "us-central1",
    timeZone: "Australia/Sydney",
    secrets: ["SENDGRID_KEY"]
  },
  async () => {
    try {

      sgMail.setApiKey(process.env.SENDGRID_KEY);

      const db = admin.firestore();

      const now = new Date();

      // 3 ngày trước
      const sixWeeksAgo = new Date(
  now.getTime() - 42 * 24 * 60 * 60 * 1000
);

      const snapshot = await db
        .collection("users")
        .where("profileCompleted", "==", false)
        .get();

      if (snapshot.empty) {
        console.log("No incomplete users");
        return;
      }

      for (const doc of snapshot.docs) {
        const data = doc.data();

        const email = data.email || "";
        const firstName = data.firstName || "there";

        if (!email) continue;

        const lastReminderEmailAt =
          data.lastReminderEmailAt?.toDate?.();

        // nếu chưa đủ 3 ngày thì skip
       if (
  lastReminderEmailAt &&
  lastReminderEmailAt > sixWeeksAgo
) {
  continue;
}

        const appLink =
          "https://thunderous-malabi-3689ef.netlify.app/";

        await sgMail.send({
          to: email,
          from: "vietlovedating@gmail.com",

          subject:
            "Complete your VietLove profile 💕 | Hoàn tất hồ sơ VietLove 💕",

          html: `
            <div style="font-family: Arial; line-height:1.7; padding:20px;">

              <h2>Hi ${firstName},</h2>

              <p>
                Your VietLove profile is waiting for you 💕
              </p>

              <p>
                Complete your registration to start matching and chatting with Vietnamese singles nearby.
              </p>

              <p>
                <span
  style="
    background:#e91e63;
    color:white;
    padding:12px 20px;
    border-radius:8px;
    display:inline-block;
    font-weight:bold;
  ">
  Continue Registration
</span>
              </p>

              <hr style="margin:30px 0;" />

              <h2>Xin chào ${firstName},</h2>

              <p>
                Hồ sơ VietLove của bạn vẫn đang chờ hoàn tất 💕
              </p>

              <p>
                Hoàn tất đăng ký để bắt đầu ghép đôi và trò chuyện với người Việt độc thân gần bạn.
              </p>

              <p>
                <span
  style="
    background:#e91e63;
    color:white;
    padding:12px 20px;
    border-radius:8px;
    display:inline-block;
    font-weight:bold;
  ">
  Tiếp tục đăng ký
</span>
              </p>

            </div>
          `,
        });

        // update thời gian gửi email gần nhất
        await doc.ref.set(
          {
            lastReminderEmailAt:
              admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

        console.log("Reminder email sent to:", email);
      }

      console.log("DONE sending incomplete profile reminders");
    } catch (e) {
      console.error(
        "sendIncompleteProfileReminderEmails error:",
        e
      );
    }
  }
);
*/



exports.sendSupportRequestEmail = onDocumentCreated(
  {
    document: "support_requests/{requestId}",
    region: "us-central1",
    secrets: ["SENDGRID_KEY"],
  },
  async (event) => {
    try {
      const data = event.data.data();

      const contactEmail = data.contactEmail || "";
      const message = data.message || "";
      const userId = data.userId || "";
      const userEmail = data.userEmail || "";

      await sgMail.send({
        to: "info@vietlovedating.com",
        from: "vietlovedating@gmail.com",
        replyTo: contactEmail,
        subject: "New Support Request - VietLove Dating",
        html: `
          <div style="font-family: Arial; padding:20px;">
            <h2>New Support Request</h2>

            <p><strong>User Email:</strong> ${contactEmail}</p>

            <p><strong>Firebase Email:</strong> ${userEmail}</p>

            <p><strong>User ID:</strong> ${userId}</p>

            <hr/>

            <p><strong>Message:</strong></p>

            <div style="white-space: pre-line;">
              ${message}
            </div>
          </div>
        `,
      });

      console.log("Support email sent");
    } catch (e) {
      console.error("sendSupportRequestEmail error:", e);
    }
  }
);


/*
const { onUserDeleted } = require("firebase-functions/v2/identity");

exports.cleanupDeletedUser = onUserDeleted(async (event) => {
  ...
});
*/