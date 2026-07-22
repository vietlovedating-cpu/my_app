const admin = require("firebase-admin");
const sgMail = require("@sendgrid/mail");
const jwt = require("jsonwebtoken");
const axios = require("axios");
const { google } = require("googleapis");
const crypto = require("crypto");

const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onMessagePublished } =
  require("firebase-functions/v2/pubsub");
const APPLE_KEY_ID = "5Y96FGHGP6";
const APPLE_ISSUER_ID = "6cd61427-575e-490b-99c4-79302d8872f8";
const APPLE_BUNDLE_ID = "com.vietlovedating.app";
const GOOGLE_PACKAGE_NAME = "com.vietlovedating.app";

admin.initializeApp();
function getSydneyDateKey(date = new Date()) {
  const parts = new Intl.DateTimeFormat("en-AU", {
    timeZone: "Australia/Sydney",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(date);

  const year = parts.find(
    (part) => part.type === "year"
  )?.value;

  const month = parts.find(
    (part) => part.type === "month"
  )?.value;

  const day = parts.find(
    (part) => part.type === "day"
  )?.value;

  if (!year || !month || !day) {
    throw new Error(
      "Could not create Sydney date key."
    );
  }

  return `${year}-${month}-${day}`;
}

function addDaysToDateKey(
  dateKey,
  numberOfDays
) {
  const [year, month, day] = dateKey
    .split("-")
    .map(Number);

  if (
    !year ||
    !month ||
    !day ||
    !Number.isInteger(numberOfDays)
  ) {
    throw new Error("Invalid date key.");
  }

  const date = new Date(
    Date.UTC(year, month - 1, day)
  );

  date.setUTCDate(
    date.getUTCDate() + numberOfDays
  );

  const newYear = String(
    date.getUTCFullYear()
  ).padStart(4, "0");

  const newMonth = String(
    date.getUTCMonth() + 1
  ).padStart(2, "0");

  const newDay = String(
    date.getUTCDate()
  ).padStart(2, "0");

  return `${newYear}-${newMonth}-${newDay}`;
}

function secureRandomInt(min, max) {
  return crypto.randomInt(
    min,
    max + 1
  );
}

function luckySpinSafeInt(value) {
  const parsed = Number(value);

  if (!Number.isFinite(parsed)) {
    return 0;
  }

  return Math.floor(parsed);
}

const SENDGRID_KEY = process.env.SENDGRID_KEY;
sgMail.setApiKey(SENDGRID_KEY);

async function sendEmail(to, subject, html) {
  try {
    await sgMail.send({
      to,
      from: "vietlovedating@gmail.com",
      subject,
      html,
    });
    console.log("Email sent to:", to);
  } catch (error) {
    console.error("Send email error:", error);
    throw error;
  }
}

async function sendPushNotification({
  token,
  title,
  body,
  data = {},
}) {
  if (!token) return;

  try {
    // FCM data payload keys/values should be strings.
    const stringData = {};
    for (const [key, value] of Object.entries(data)) {
      stringData[key] = value == null ? "" : String(value);
    }

    const message = {
      token,
      notification: {
        title,
        body,
      },
      data: stringData,
      android: {
        priority: "high",
        notification: {
          channelId: "vietlove_default",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    };

    const response = await admin.messaging().send(message);
    console.log("Push sent:", response);
    return response;
  } catch (error) {
    console.error("Push send error:", error);

    // Nếu token hỏng / hết hạn thì xóa khỏi users để tránh lỗi lặp lại
    const code = error?.code || "";
    if (
      code === "messaging/registration-token-not-registered" ||
      code === "messaging/invalid-registration-token"
    ) {
      console.log("Invalid FCM token, should remove token from Firestore.");
    }

    return null;
  }
}


exports.deleteMyAccount = onCall(
  {
    region: "us-central1",
    timeoutSeconds: 540,
    memory: "512MiB",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "You must be logged in.");
    }

    const uid = request.auth.uid;
    const email = request.auth.token.email || "";

    const { deleteReason = "", deleteReasonText = "" } = request.data || {};
console.log("DELETE REASON RECEIVED:", {
  uid,
  deleteReason,
  deleteReasonText,
  rawData: request.data || {},
});
    const db = admin.firestore();
    const userRef = db.collection("users").doc(uid);

    let logRef;

    try {
      const userSnap = await userRef.get();
      const userData = userSnap.data() || {};

      logRef = await db.collection("deletion_logs").add({
        uid,
        email,
        requestedByUser: true,
        deleteReason,
        deleteReasonText,
        status: "deleting",
deletedAt: admin.firestore.FieldValue.serverTimestamp(),
requestedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      await userRef.set(
        {
          isDeleted: true,
          isPaused: true,
          showOnDiscover: false,
          profileCompleted: false,
          deletedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      try {
        const matchesSnap = await db
          .collection("matches")
          .where("users", "array-contains", uid)
          .get();

        for (const doc of matchesSnap.docs) {
          await doc.ref.delete();
        }
      } catch (error) {
        console.error("DELETE MATCHES ERROR:", uid, error);
      }

      try {
        const chatsSnap = await db
          .collection("chats")
          .where("participants", "array-contains", uid)
          .get();

        for (const chatDoc of chatsSnap.docs) {
          const chatData = chatDoc.data() || {};

          const participants = (chatData.participants || []).filter(
            (id) => id !== uid
          );

          const participantNames = {
            ...(chatData.participantNames || {}),
          };

          const participantPhotos = {
            ...(chatData.participantPhotos || {}),
          };

          delete participantNames[uid];
          delete participantPhotos[uid];

          await chatDoc.ref.set(
            {
              participants,
              participantNames,
              participantPhotos,
              deletedUserIds: admin.firestore.FieldValue.arrayUnion(uid),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
        }
      } catch (error) {
        console.error("ANONYMIZE CHATS ERROR:", uid, error);
      }

      try {
        const bucket = admin.storage().bucket();

        const storagePaths = new Set();

        for (const field of ["mainPhotoUrl"]) {
          const value = userData[field];
          if (typeof value === "string" && value) {
            storagePaths.add(value);
          }
        }

        for (const field of ["photoUrls", "photos"]) {
          const values = userData[field];

          if (Array.isArray(values)) {
            for (const value of values) {
              if (typeof value === "string" && value) {
                storagePaths.add(value);
              }
            }
          }
        }

        for (const photoUrl of storagePaths) {
          try {
            const decodedUrl = decodeURIComponent(photoUrl);
            const match = decodedUrl.match(/\/o\/(.+?)\?/);

            if (!match || !match[1]) continue;

            await bucket.file(match[1]).delete({
              ignoreNotFound: true,
            });
          } catch (error) {
            console.error("DELETE PHOTO ERROR:", uid, photoUrl, error);
          }
        }

        await bucket.deleteFiles({ prefix: `users/${uid}/` });
        await bucket.deleteFiles({ prefix: `user_photos/${uid}/` });
      } catch (error) {
        console.error("DELETE STORAGE ERROR:", uid, error);
      }

      try {
        const subcollections = [
  "appleVipNotifications",
  "blockedUsers",
  "blocked_users",
  "hidden_users",
  "datePlans",
  "likedBy",
  "passedUsers",
  "processedVipPurchases",
  "settings",
  "top_picks_daily",
  "trustedContacts",
];
        for (const collectionName of subcollections) {
          const collectionRef = userRef.collection(collectionName);

          while (true) {
            const snap = await collectionRef.limit(400).get();

            if (snap.empty) break;

            const batch = db.batch();

            for (const doc of snap.docs) {
              batch.delete(doc.ref);
            }

            await batch.commit();
          }
        }
      } catch (error) {
        console.error("DELETE SUBCOLLECTIONS ERROR:", uid, error);
      }
try {
  const photoVerificationSnap = await db
    .collection("photo_verification_requests")
    .where("uid", "==", uid)
    .get();

  for (const doc of photoVerificationSnap.docs) {
    await doc.ref.delete();
  }
} catch (error) {
  console.error(
    "DELETE PHOTO VERIFICATION REQUEST ERROR:",
    uid,
    error
  );
}
try {
  const membershipRefs = new Map();

  const membershipsByUid = await db
    .collectionGroup("members")
    .where("uid", "==", uid)
    .get();

  for (const doc of membershipsByUid.docs) {
    membershipRefs.set(doc.ref.path, doc.ref);
  }

  const membershipsByUserId = await db
    .collectionGroup("members")
    .where("userId", "==", uid)
    .get();

  for (const doc of membershipsByUserId.docs) {
    membershipRefs.set(doc.ref.path, doc.ref);
  }

  const refs = [...membershipRefs.values()];

  for (let i = 0; i < refs.length; i += 400) {
    const batch = db.batch();
    const chunk = refs.slice(i, i + 400);

    for (const ref of chunk) {
      batch.delete(ref);
    }

    await batch.commit();
  }

  console.log(
    "GROUP MEMBERSHIPS DELETED:",
    uid,
    refs.length
  );
} catch (error) {
  console.error(
    "DELETE GROUP MEMBERSHIPS ERROR:",
    uid,
    error
  );
}
      await userRef.delete();

      try {
        await admin.auth().deleteUser(uid);
      } catch (error) {
        console.error("DELETE AUTH ERROR:", uid, error);
        throw error;
      }

      await logRef.set(
        {
          status: "completed",
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      console.log("ACCOUNT DELETED:", uid);

      return { success: true };
    } catch (error) {
      console.error("DELETE ACCOUNT FAILED:", uid, error);

      if (logRef) {
        await logRef.set(
          {
            status: "failed",
            errorMessage: error.message || String(error),
            failedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      }

      throw new HttpsError("internal", "Could not delete account.");
    }
  }
);
function buildEmailShell({
  titleVi,
  titleEn,
  bodyVi,
  bodyEn,
  buttonTextVi,
  buttonTextEn,
  renewUrl,
}) {
  return `
  <!DOCTYPE html>
  <html>
    <body style="margin:0; padding:0; background-color:#f7f8fc; font-family:Arial, sans-serif;">
      <div style="max-width:600px; margin:30px auto; background:#ffffff; border-radius:20px; overflow:hidden; box-shadow:0 8px 24px rgba(0,0,0,0.08);">
        <div style="background:linear-gradient(135deg,#ff8fb1,#7b8cff); padding:28px 24px; text-align:center;">
          <div style="font-size:28px; font-weight:700; color:#ffffff;">
            VietLove Dating
          </div>
          <div style="margin-top:8px; font-size:14px; color:#ffeef4;">
            Kết nối chân thành • Meaningful connections
          </div>
        </div>

        <div style="padding:30px 24px 20px 24px; color:#333333; line-height:1.7;">
          <div style="font-size:22px; font-weight:700; color:#222222; margin-bottom:14px;">
            ${titleVi}
          </div>

          <div style="font-size:15px; color:#444444; white-space:pre-line;">
            ${bodyVi}
          </div>

          <div style="height:1px; background:#ececf3; margin:26px 0;"></div>

          <div style="font-size:20px; font-weight:700; color:#222222; margin-bottom:14px;">
            ${titleEn}
          </div>

          <div style="font-size:15px; color:#444444; white-space:pre-line;">
            ${bodyEn}
          </div>

          <div style="text-align:center; margin:30px 0 18px;">
            <div style="display:inline-block; background:#5d74d3; color:#ffffff; padding:14px 28px; border-radius:14px; font-size:15px; font-weight:700;">
              ${buttonTextVi} / ${buttonTextEn}
            </div>
          </div>

          <div style="font-size:14px; color:#555555; line-height:1.7; text-align:center; margin-top:10px;">
            Vui lòng mở ứng dụng VietLove Dating và vào đúng nhóm đã hết hạn để gia hạn.<br/>
            Please open the VietLove Dating app and go to your expired group page to renew.
          </div>

          <div style="font-size:13px; color:#888888; text-align:center; margin-top:14px; word-break:break-all;">
            Deep link: ${renewUrl}
          </div>

          <div style="font-size:13px; color:#888888; text-align:center; margin-top:8px;">
            Nếu nút không hoạt động, vui lòng mở ứng dụng VietLove Dating để gia hạn.<br/>
            If the button does not work, please open the VietLove Dating app to renew.
          </div>
        </div>

        <div style="background:#fafafe; padding:18px 20px; text-align:center; font-size:12px; color:#999999;">
          VietLove Dating<br/>
          Sydney, Australia
        </div>
      </div>
    </body>
  </html>
  `;
}

function buildReminder7dEmail(renewUrl) {
  return buildEmailShell({
    titleVi: "Gói nhóm của bạn sắp hết hạn",
    titleEn: "Your group plan is expiring soon",
    bodyVi:
      "Gói nhóm của bạn sẽ hết hạn trong 7 ngày.\n\nVui lòng gia hạn để tiếp tục nhắn tin, kết nối và tham gia nhóm.",
    bodyEn:
      "Your group membership will expire in 7 days.\n\nPlease renew to continue chatting, connecting, and accessing the group.",
    buttonTextVi: "Gia hạn ngay",
    buttonTextEn: "Renew now",
    renewUrl,
  });
}

function buildReminder3dEmail(renewUrl) {
  return buildEmailShell({
    titleVi: "Gói nhóm của bạn sắp hết hạn",
    titleEn: "Your group plan is expiring soon",
    bodyVi:
      "Gói nhóm của bạn sẽ hết hạn trong 3 ngày.\n\nHãy gia hạn sớm để tránh bị gián đoạn trải nghiệm của bạn.",
    bodyEn:
      "Your group membership will expire in 3 days.\n\nPlease renew soon to avoid interruption to your experience.",
    buttonTextVi: "Gia hạn ngay",
    buttonTextEn: "Renew now",
    renewUrl,
  });
}
function buildReminder1dEmail(renewUrl) {
  return buildEmailShell({
    titleVi: "Gói nhóm của bạn sắp hết hạn",
    titleEn: "Your group plan is expiring soon",
    bodyVi:
      "Gói nhóm của bạn sẽ hết hạn trong 1 ngày.\n\nHãy gia hạn ngay để không bị gián đoạn việc nhắn tin và truy cập nhóm.",
    bodyEn:
      "Your group membership will expire in 1 day.\n\nPlease renew now to avoid interruption to your chats and group access.",
    buttonTextVi: "Gia hạn ngay",
    buttonTextEn: "Renew now",
    renewUrl,
  });
}

function buildExpiredEmail(renewUrl) {
  return buildEmailShell({
    titleVi: "Gói nhóm của bạn đã hết hạn",
    titleEn: "Your group plan has expired",
    bodyVi:
      "Gói nhóm của bạn đã hết hạn.\n\nVui lòng gia hạn để tiếp tục nhắn tin và truy cập nhóm.",
    bodyEn:
      "Your group membership has expired.\n\nPlease renew to continue chatting and accessing the group.",
    buttonTextVi: "Gia hạn lại",
    buttonTextEn: "Renew again",
    renewUrl,
  });
}

async function getUserMeta(userId) {
  if (!userId) {
    return {
      fcmToken: "",
      languageCode: "en",
    };
  }

  try {
    const userSnap = await admin.firestore().collection("users").doc(userId).get();

    if (!userSnap.exists) {
      return {
        fcmToken: "",
        languageCode: "en",
      };
    }

    const userData = userSnap.data() || {};
    return {
      fcmToken: userData.fcmToken || "",
      languageCode: userData.languageCode || "en",
    };
  } catch (error) {
    console.error("getUserMeta error:", error);
    return {
      fcmToken: "",
      languageCode: "en",
    };
  }
}

exports.testSendEmail = onRequest(async (req, res) => {
  try {
    const renewUrl = "vietlove://group-renew?groupId=gym_fitness";

    await sendEmail(
      "vietlovedating@gmail.com",
      "VietLove Dating | Email kiểm tra / Test email",
      buildReminder7dEmail(renewUrl)
    );

    res.status(200).send("Email sent!");
  } catch (error) {
    console.error("Send email error:", error);
    res.status(500).send("Send failed");
  }
});

exports.testSendPush = onRequest(async (req, res) => {
  try {
    const token = req.query.token || req.body?.token;

    if (!token) {
      res.status(400).send("Missing token");
      return;
    }

    await sendPushNotification({
      token,
      title: "VietLove Dating",
      body: "Đây là push notification test / This is a test push notification",
      data: {
        route: "group_renew",
        groupId: "gym_fitness",
      },
    });

    res.status(200).send("Push sent!");
  } catch (error) {
    console.error("Test push error:", error);
    res.status(500).send("Push failed");
  }
});

function startOfDayPlus(days) {
  const d = new Date();
  d.setDate(d.getDate() + days);
  d.setHours(0, 0, 0, 0);
  return d;
}

function endOfDayPlus(days) {
  const d = new Date();
  d.setDate(d.getDate() + days);
  d.setHours(23, 59, 59, 999);
  return d;
}

async function sendGroupReminderForDay(days, flagField) {
  const db = admin.firestore();

  const start = admin.firestore.Timestamp.fromDate(startOfDayPlus(days));
  const end = admin.firestore.Timestamp.fromDate(endOfDayPlus(days));

  const snap = await db
    .collectionGroup("members")
    .where("membershipActive", "==", true)
    .where(flagField, "==", false)
    .where("expiresAt", ">=", start)
    .where("expiresAt", "<=", end)
    .limit(200)
    .get();

  console.log(`GROUP REMINDER ${days}D COUNT:`, snap.size);

  for (const doc of snap.docs) {
    const data = doc.data() || {};

    const groupId = data.groupId || "";
    const renewUrl = `vietlove://group-renew?groupId=${groupId}`;
    const email = data.email || "";
    const userId = data.userId || data.uid || doc.id;

    const { fcmToken, languageCode } = await getUserMeta(userId);
    const isVi = languageCode === "vi";

    if (email) {
      let html = buildReminder7dEmail(renewUrl);

      if (days === 3) {
        html = buildReminder3dEmail(renewUrl);
      }

      if (days === 1) {
  html = buildReminder1dEmail(renewUrl);
}
      await sendEmail(
        email,
        "VietLove Dating | Gói nhóm sắp hết hạn / Your group plan is expiring soon",
        html
      );
    }

    await sendPushNotification({
      token: fcmToken,
      title: isVi ? "Gói nhóm sắp hết hạn" : "Your group plan is expiring soon",
      body: isVi
        ? `Gói nhóm của bạn sẽ hết hạn sau ${days} ngày.`
        : `Your group plan will expire in ${days} day${days > 1 ? "s" : ""}.`,
      data: {
        route: "group_renew",
        groupId,
        type: `group_expiry_${days}d`,
      },
    });

    await doc.ref.update({
      [flagField]: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
}
/*
exports.sendGroupReminder7d = onSchedule(
  {
    schedule: "every day 09:00",
    timeZone: "Australia/Sydney",
    region: "us-central1",
    timeoutSeconds: 540,
    memory: "512MiB",
  },
  async () => {
    await sendGroupReminderForDay(7, "reminder7dSent");
  }
);

exports.sendGroupReminder3d = onSchedule(
  {
    schedule: "every day 10:00",
    timeZone: "Australia/Sydney",
    region: "us-central1",
    timeoutSeconds: 540,
    memory: "512MiB",
  },
  async () => {
    await sendGroupReminderForDay(3, "reminder3dSent");
  }
);

exports.sendGroupReminder1d = onSchedule(
  {
    schedule: "every day 11:00",
    timeZone: "Australia/Sydney",
    region: "us-central1",
    timeoutSeconds: 540,
    memory: "512MiB",
  },
  async () => {
    await sendGroupReminderForDay(1, "reminder1dSent");
  }
);
*/
async function sendVipReminderForDay(days, flagField) {
  const db = admin.firestore();

  const start = admin.firestore.Timestamp.fromDate(startOfDayPlus(days));
  const end = admin.firestore.Timestamp.fromDate(endOfDayPlus(days));

  const snap = await db
    .collection("users")
    .where("isVip", "==", true)
    .where(flagField, "==", false)
    .where("vipExpiresAt", ">=", start)
    .where("vipExpiresAt", "<=", end)
    .limit(200)
    .get();

  console.log(`VIP REMINDER ${days}D COUNT:`, snap.size);

  for (const userDoc of snap.docs) {
    const userData = userDoc.data() || {};

    const fcmToken = userData.fcmToken || "";
    const isVi = userData.languageCode === "vi";

    await sendPushNotification({
      token: fcmToken,
      title: isVi ? "VIP sắp hết hạn" : "VIP expiring soon",
      body: isVi
        ? `VIP của bạn sẽ hết hạn sau ${days} ngày.`
        : `Your VIP will expire in ${days} day${days > 1 ? "s" : ""}.`,
      data: {
        type: `vip_${days}d`,
      },
    });

    await userDoc.ref.update({
      [flagField]: true,
      vipUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
}
exports.sendVipReminder7d = onSchedule(
  {
    schedule: "every day 12:00",
    timeZone: "Australia/Sydney",
    region: "us-central1",
    timeoutSeconds: 540,
    memory: "512MiB",
  },
  async () => {
    await sendVipReminderForDay(7, "vipReminder7dSent");
  }
);

exports.sendVipReminder3d = onSchedule(
  {
    schedule: "every day 13:00",
    timeZone: "Australia/Sydney",
    region: "us-central1",
    timeoutSeconds: 540,
    memory: "512MiB",
  },
  async () => {
    await sendVipReminderForDay(3, "vipReminder3dSent");
  }
);

exports.sendVipReminder1d = onSchedule(
  {
    schedule: "every day 14:00",
    timeZone: "Australia/Sydney",
    region: "us-central1",
    timeoutSeconds: 540,
    memory: "512MiB",
  },
  async () => {
    await sendVipReminderForDay(1, "vipReminder1dSent");
  }
);
exports.checkMemberships = onSchedule(
  {
    schedule: "every 24 hours",
    timeZone: "Australia/Sydney",
    region: "us-central1",
    timeoutSeconds: 540,
    memory: "512MiB",
  },
  async () => {
  console.log("CHECK MEMBERSHIPS START");
  console.log("Time:", new Date().toISOString());

  const now = new Date();

  const snapshot = await admin.firestore()
  .collectionGroup("members")
  .where("membershipActive", "==", true)
  .where("expiresAt", "<=", admin.firestore.Timestamp.fromDate(now))
  .get();

  console.log("Members count:", snapshot.size);

  for (const doc of snapshot.docs) {
      
      const data = doc.data();

      if (!data.membershipActive) continue;
      if (!data.expiresAt) continue;

      const groupId = data.groupId || "";
      const renewUrl = `vietlove://group-renew?groupId=${groupId}`;

      const expiresAt = data.expiresAt.toDate();
      const diffDays = Math.ceil((expiresAt - now) / (1000 * 60 * 60 * 24));

      const email = data.email || "";
      const userId = data.userId || data.uid || doc.id;

      const { fcmToken, languageCode } = await getUserMeta(userId);
      const isVi = languageCode === "vi";
      const userRef = admin.firestore().collection("users").doc(userId);
/*
      // 7 ngày
if (diffDays === 7 && !data.vipReminder7dSent) {
  await sendPushNotification({
    token: fcmToken,
    title: isVi ? "VIP sắp hết hạn" : "VIP expiring soon",
    body: isVi
      ? "VIP của bạn sẽ hết hạn sau 7 ngày."
      : "Your VIP will expire in 7 days.",
    data: { type: "vip_7d" },
  });

  await userRef.update({ vipReminder7dSent: true });
}

// 3 ngày
if (diffDays === 3 && !data.vipReminder3dSent) {
  await sendPushNotification({
    token: fcmToken,
    title: isVi ? "VIP sắp hết hạn" : "VIP expiring soon",
    body: isVi
      ? "VIP của bạn sẽ hết hạn sau 3 ngày."
      : "Your VIP will expire in 3 days.",
    data: { type: "vip_3d" },
  });

  await userRef.update({ vipReminder3dSent: true });
}

// 1 ngày
if (diffDays === 1 && !data.vipReminder1dSent) {
  await sendPushNotification({
    token: fcmToken,
    title: isVi ? "VIP sắp hết hạn" : "VIP expiring soon",
    body: isVi
      ? "VIP của bạn sẽ hết hạn sau 1 ngày."
      : "Your VIP will expire in 1 day.",
    data: { type: "vip_1d" },
  });

  await userRef.update({ vipReminder1dSent: true });
}

// hết hạn
if (diffDays <= 0 && !data.vipExpiredHandled) {
  await sendPushNotification({
    token: fcmToken,
    title: isVi ? "VIP đã hết hạn" : "VIP expired",
    body: isVi
      ? "VIP của bạn đã hết hạn."
      : "Your VIP has expired.",
    data: { type: "vip_expired" },
  });

  await userRef.update({
    isVip: false,
    vipUnlocked: false,
    vipStatus: "expired",
    vipExpiredHandled: true,
    vipExpiredAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}
  */
 /*
      if (diffDays === 7 && !data.reminder7dSent) {
        if (email) {
          await sendEmail(
            email,
            "VietLove Dating | Gói nhóm sắp hết hạn / Your group plan is expiring soon",
            buildReminder7dEmail(renewUrl)
          );
        }

        await sendPushNotification({
          token: fcmToken,
          title: isVi ? "Gói nhóm sắp hết hạn" : "Your group plan is expiring soon",
          body: isVi
            ? "Gói nhóm của bạn sẽ hết hạn sau 7 ngày."
            : "Your group plan will expire in 7 days.",
          data: {
  route: "group_renew",
  groupId,
  type: "group_expiry_7d",
},
        });

        await doc.ref.update({
          reminder7dSent: true,
        });
      }

      if (diffDays === 3 && !data.reminder3dSent) {
        if (email) {
          await sendEmail(
            email,
            "VietLove Dating | Gói nhóm sắp hết hạn / Your group plan is expiring soon",
            buildReminder3dEmail(renewUrl)
          );
        }

        await sendPushNotification({
          token: fcmToken,
          title: isVi ? "Gói nhóm sắp hết hạn" : "Your group plan is expiring soon",
          body: isVi
            ? "Gói nhóm của bạn sẽ hết hạn sau 3 ngày."
            : "Your group plan will expire in 3 days.",
          data: {
            route: "group_renew",
            groupId,
            type: "group_expiry_3d",
          },
        });

        await doc.ref.update({
          reminder3dSent: true,
        });
        
      }
if (diffDays === 1 && !data.reminder1dSent) {
  await sendPushNotification({
    token: fcmToken,
    title: isVi ? "Gói nhóm sắp hết hạn" : "Your group plan is expiring soon",
    body: isVi
      ? "Gói nhóm của bạn sẽ hết hạn sau 1 ngày."
      : "Your group plan will expire in 1 day.",
    data: {
      route: "group_renew",
      groupId,
      type: "group_expiry_1d",
    },
  });

  await doc.ref.update({
    reminder1dSent: true,
  });
}
  */
 
      if (diffDays <= 0 && !data.expiredHandled) {
        if (email) {
          await sendEmail(
            email,
            "VietLove Dating | Gói nhóm đã hết hạn / Your group plan has expired",
            buildExpiredEmail(renewUrl)
          );
        }

        await sendPushNotification({
          token: fcmToken,
          title: isVi ? "Gói nhóm đã hết hạn" : "Your group plan has expired",
          body: isVi
            ? "Gói nhóm của bạn đã hết hạn. Hãy gia hạn để tiếp tục sử dụng."
            : "Your group plan has expired. Renew to continue using it.",
          data: {
            route: "group_renew",
            groupId,
            type: "group_expired",
          },
        });

        await doc.ref.update({
          membershipActive: false,
          expiredHandled: true,
        });
      }
      
    }
    console.log("START VIP CHECK");
    /*
    // VIP 7 ngày
const vipSnap = await admin.firestore()
  .collection("users")
  .where("isVip", "==", true)
  .get();

for (const userDoc of vipSnap.docs) {
  const userData = userDoc.data() || {};

  if (!userData.vipExpiresAt) continue;
  if (userData.vipReminder7dSent) continue;

  const vipExpiresAt = userData.vipExpiresAt.toDate();

  const vipMsLeft = vipExpiresAt - now;
const sevenDaysMs = 7 * 24 * 60 * 60 * 1000;

if (vipMsLeft <= 0) continue;
if (vipMsLeft > sevenDaysMs) continue;

  const fcmToken = userData.fcmToken || "";
  const isVi = userData.languageCode === "vi";

  const freshSnap = await userDoc.ref.get();
const freshData = freshSnap.data() || {};

if (freshData.vipReminder7dSent) {
  continue;
}

await sendPushNotification({
  token: fcmToken,
  title: isVi ? "VIP sắp hết hạn" : "VIP expiring soon",
  body: isVi
    ? "VIP của bạn sẽ hết hạn sau 7 ngày."
    : "Your VIP will expire in 7 days.",
  data: {
    type: "vip_7d",
  },
});

await userDoc.ref.update({
  vipReminder7dSent: true,
});
}
*/
// VIP hết hạn - khóa quyền VIP
const expiredVipSnap = await admin.firestore()
  .collection("users")
  .where("isVip", "==", true)
  .get();

for (const userDoc of expiredVipSnap.docs) {
  const userData = userDoc.data() || {};

  if (!userData.vipExpiresAt) continue;

  const vipExpiresAt = userData.vipExpiresAt.toDate();

  if (vipExpiresAt > now) continue;

  await userDoc.ref.set(
  {
    isVip: false,
    vipUnlocked: false,
    membership: "",
    plan: "",
    vipStatus: "expired",
    vipExpiredHandled: true,
    vipExpiredAt: admin.firestore.FieldValue.serverTimestamp(),
    vipUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  { merge: true }
);

  console.log("VIP expired and disabled:", userDoc.id);
}
console.log("END VIP CHECK");
   }
);
exports.addPromoForNewCityGroups = onRequest(
  {
    region: "us-central1",
    timeoutSeconds: 540,
    memory: "512MiB",
  },
  async (req, res) => {
    try {
      const db = admin.firestore();

      const promoGroupIds = [
  "sydney_vietnamese",
  "melbourne_vietnamese",
  "queensland_vietnamese",
  "perth_vietnamese",
  "adelaide_vietnamese",
  "tasmania_vietnamese",
  "canberra_vietnamese",
  "darwin_vietnamese",
];

      const now = new Date();
      const promoExpiresAt = new Date(now);
      promoExpiresAt.setMonth(promoExpiresAt.getMonth() + 3);

      // tạo group doc cha để Firebase Console thấy rõ
      for (const groupId of promoGroupIds) {
        await db.collection("groups").doc(groupId).set(
          {
            active: true,
            groupId,
            source: "city_group",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      }

      const usersSnap = await db.collection("users").get();

      let added = 0;
      let skippedDeleted = 0;
      let skippedIncomplete = 0;

      let batch = db.batch();
      let batchCount = 0;

      for (const userDoc of usersSnap.docs) {
        const userId = userDoc.id;
        const userData = userDoc.data() || {};

        const isDeleted =
          userData.deleted === true ||
          userData.isDeleted === true ||
          userData.accountDeleted === true ||
          userData.status === "deleted";

        if (isDeleted) {
          skippedDeleted++;
          continue;
        }

        const profileComplete =
          userData.profileComplete === true ||
          userData.isProfileComplete === true ||
          userData.profileCompleted === true;

        if (!profileComplete) {
          skippedIncomplete++;
          continue;
        }

        for (const groupId of promoGroupIds) {
          const memberRef = db
            .collection("groups")
            .doc(groupId)
            .collection("members")
            .doc(userId);

          batch.set(
            memberRef,
            {
              uid: userId,
              userId,
              groupId,
              email: userData.email || "",

              membershipActive: true,
              groupStatus: "active",
              source: "promo_3_months",

              appleVerified: false,
              groupProductId: "",
              groupTransactionId: "",
              groupOriginalTransactionId: "",
              groupRenewCount: 0,

              expiresAt:
                admin.firestore.Timestamp.fromDate(promoExpiresAt),

              joinedAt:
                admin.firestore.FieldValue.serverTimestamp(),

              expiredHandled: false,
              reminder7dSent: false,
              reminder3dSent: false,
              reminder1dSent: false,

              updatedAt:
                admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );

          added++;
          batchCount++;

          if (batchCount >= 400) {
            await batch.commit();
            batch = db.batch();
            batchCount = 0;
          }
        }
      }

      if (batchCount > 0) {
        await batch.commit();
      }

      res.status(200).json({
        success: true,
        added,
        skippedDeleted,
        skippedIncomplete,
        groups: promoGroupIds,
      });
    } catch (error) {
      console.error("addPromoForNewCityGroups error:", error);
      res.status(500).send(error.message || "Server error");
    }
  }
);
exports.addPromoWhenProfileCompleted = onDocumentUpdated(
  {
    document: "users/{userId}",
    region: "us-central1",
    timeoutSeconds: 540,
    memory: "512MiB",
  },
  async (event) => {
    try {
      const userId = event.params.userId;

      const before = event.data.before.data() || {};
      const after = event.data.after.data() || {};

      if (
        before.profileCompleted === true ||
        after.profileCompleted !== true
      ) {
        return;
      }

      const isDeleted =
        after.deleted === true ||
        after.isDeleted === true ||
        after.accountDeleted === true ||
        after.status === "deleted";

      if (isDeleted) {
        return;
      }

      const db = admin.firestore();

      const promoGroupIds = [
  "sydney_vietnamese",
  "melbourne_vietnamese",
  "queensland_vietnamese",
  "perth_vietnamese",
  "adelaide_vietnamese",
  "tasmania_vietnamese",
  "canberra_vietnamese",
  "darwin_vietnamese",
];

      const expiresAt = new Date();
      expiresAt.setMonth(expiresAt.getMonth() + 3);

      for (const groupId of promoGroupIds) {
        const memberRef = db
          .collection("groups")
          .doc(groupId)
          .collection("members")
          .doc(userId);

        const memberSnap = await memberRef.get();

        if (memberSnap.exists) {
          continue;
        }

        await memberRef.set(
          {
            uid: userId,
            userId: userId,
            groupId: groupId,
            email: after.email || "",

            membershipActive: true,
            groupStatus: "active",
            source: "promo_3_months",

            appleVerified: false,
            groupProductId: "",
            groupTransactionId: "",
            groupOriginalTransactionId: "",
            groupRenewCount: 0,

            expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),

            joinedAt: admin.firestore.FieldValue.serverTimestamp(),

            expiredHandled: false,
            reminder7dSent: false,
            reminder3dSent: false,
            reminder1dSent: false,

            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      }

      console.log("Promo added after profileCompleted:", userId);
    } catch (error) {
      console.error("addPromoWhenProfileCompleted error:", error);
    }
  }
);
exports.addFemaleVipWhenProfileCompleted = onDocumentUpdated(
  {
    document: "users/{userId}",
    region: "us-central1",
    timeoutSeconds: 540,
    memory: "512MiB",
  },
  async (event) => {
    try {
      // Chương trình kết thúc sau ngày 30/06/2026
const promoEndDate = new Date("2026-06-15T23:59:59+10:00");

if (new Date() > promoEndDate) {
  return;
}
      const userId = event.params.userId;

      const before = event.data.before.data() || {};
      const after = event.data.after.data() || {};

      // Chỉ chạy khi user vừa hoàn thành profile
      if (
        before.profileCompleted === true ||
        after.profileCompleted !== true
      ) {
        return;
      }

      const isDeleted =
        after.deleted === true ||
        after.isDeleted === true ||
        after.accountDeleted === true ||
        after.status === "deleted";

      if (isDeleted) return;

      const genderText = String(
        after.genderLower ||
        after.gender ||
        after.sex ||
        ""
      ).toLowerCase();

      const isFemale =
        genderText === "female" ||
        genderText === "woman" ||
        genderText === "nu" ||
        genderText === "nữ";

      if (!isFemale) return;

      // Nếu đã từng nhận promo này rồi thì không cho nhận lại
      if (after.vipPromoSource === "female_1_month_promo") {
        return;
      }

      const now = new Date();
      const promoExpiresAt = new Date(now);
      promoExpiresAt.setMonth(promoExpiresAt.getMonth() + 1);

      await admin.firestore().collection("users").doc(userId).set(
        {
          isVip: true,
          vipUnlocked: true,
          membership: "vip",
          plan: "vip",

          vipStatus: "active",
          vipPlanId: "promo_1_month_female",
          subscriptionType: "promo_1_month_female",
          vipProductId: "promo_female_free_1_month",
          vipPlatform: "promo",

          vipExpiresAt: admin.firestore.Timestamp.fromDate(promoExpiresAt),

          vipPlanTitleVi: "VIP miễn phí 1 tháng",
          vipPlanTitleEn: "Free VIP 1 month",
          vipPriceTextVi: "Miễn phí",
          vipPriceTextEn: "Free",

          vipPromoSource: "female_1_month_promo",
          vipPromoStartedAt: admin.firestore.FieldValue.serverTimestamp(),
          vipUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),

          vipReminder7dSent: false,
          vipReminder3dSent: false,
          vipReminder1dSent: false,
          vipExpiredHandled: false,
        },
        { merge: true }
      );

      console.log("Female 1 month VIP promo added:", userId);
    } catch (error) {
      console.error("addFemaleVipWhenProfileCompleted error:", error);
    }
  }
);


exports.syncGoogleVipSubscriptions = onSchedule(
  {
    schedule: "every 24 hours",
    timeZone: "Australia/Sydney",
    region: "us-central1",
    timeoutSeconds: 540,
    memory: "512MiB",
    secrets: ["GOOGLE_PLAY_SERVICE_ACCOUNT_JSON"],
  },
  async () => {
    const db = admin.firestore();

    const snap = await db
      .collection("users")
      .where("vipPlatform", "==", "google_play")
      .where("googlePurchaseToken", "!=", "")
      .get();

    console.log("SYNC GOOGLE VIP COUNT:", snap.size);

    const now = new Date();

    for (const userDoc of snap.docs) {
      const data = userDoc.data() || {};

      const productId = data.vipProductId;
      const purchaseToken = data.googlePurchaseToken;

      if (!productId || !purchaseToken) continue;

      try {
        const googleInfo = await getGoogleSubscriptionInfo(
          productId,
          purchaseToken
        );

        const expiryTimeMillis = Number(
          googleInfo.expiryTimeMillis || 0
        );

        if (!expiryTimeMillis) continue;

        const expiresAt = new Date(expiryTimeMillis);
        const isActive = expiresAt > now;

        await userDoc.ref.set(
          {
            isVip: isActive,
            vipUnlocked: isActive,
            membership: isActive ? "vip" : "",
            plan: isActive ? "vip" : "",
            vipStatus: isActive ? "active" : "expired",
            vipExpiresAt:
              admin.firestore.Timestamp.fromDate(expiresAt),

            googleOrderId:
              googleInfo.orderId || data.googleOrderId || "",

            googleAutoRenewing:
              googleInfo.autoRenewing === true,

            googlePaymentState:
              googleInfo.paymentState ?? null,

            googleAcknowledgementState:
              googleInfo.acknowledgementState ?? null,

            vipGoogleSyncedAt:
              admin.firestore.FieldValue.serverTimestamp(),

            vipUpdatedAt:
              admin.firestore.FieldValue.serverTimestamp(),

            vipExpiredHandled: !isActive,
          },
          { merge: true }
        );

        console.log(
          "Google VIP synced:",
          userDoc.id,
          expiresAt
        );
      } catch (e) {
        console.error(
          "syncGoogleVipSubscriptions error:",
          userDoc.id,
          e.response?.data || e
        );
      }
    }
  }
);
exports.googlePlayVipNotification = onMessagePublished(
  {
    topic: "vietlove-google-billing",
    region: "us-central1",
    timeoutSeconds: 120,
    memory: "256MiB",
    secrets: ["GOOGLE_PLAY_SERVICE_ACCOUNT_JSON"],
  },
  async (event) => {
    const messageJson = event.data.message.json;

    console.log(
      "GOOGLE PLAY RTDN RECEIVED:",
      JSON.stringify(messageJson)
    );

    const subscriptionNotification =
      messageJson?.subscriptionNotification;

    if (!subscriptionNotification) {
      console.log(
        "RTDN does not contain subscriptionNotification."
      );
      return;
    }

    const purchaseToken =
      subscriptionNotification.purchaseToken || "";

    const productId =
      subscriptionNotification.subscriptionId || "";

    const notificationType =
      Number(subscriptionNotification.notificationType || 0);

    if (!purchaseToken || !productId) {
      console.log("Missing productId or purchaseToken.");
      return;
    }

    const db = admin.firestore();

    // Tìm đúng user sở hữu purchase token này
    const usersSnap = await db
      .collection("users")
      .where("googlePurchaseToken", "==", purchaseToken)
      .limit(2)
      .get();

    if (usersSnap.empty) {
      console.error(
        "No user found for Google purchase token:",
        purchaseToken
      );
      return;
    }

    if (usersSnap.size > 1) {
      console.error(
        "Multiple users found for the same purchase token:",
        purchaseToken
      );
      return;
    }

    const userDoc = usersSnap.docs[0];
    const userData = userDoc.data() || {};

    try {
      // Luôn hỏi lại Google để lấy trạng thái chính xác
      const googleInfo = await getGoogleSubscriptionInfo(
        productId,
        purchaseToken
      );

      const expiryTimeMillis = Number(
        googleInfo.expiryTimeMillis || 0
      );

      if (!expiryTimeMillis) {
        console.error(
          "Google response missing expiryTimeMillis:",
          googleInfo
        );
        return;
      }

      const expiresAt = new Date(expiryTimeMillis);
      const now = new Date();
      const isActive = expiresAt > now;

      const previousExpiry =
        userData.vipExpiresAt?.toDate?.() || null;

      const renewed =
        previousExpiry != null &&
        expiresAt.getTime() > previousExpiry.getTime();

      await userDoc.ref.set(
        {
          isVip: isActive,
          vipUnlocked: isActive,
          membership: isActive ? "vip" : "",
          plan: isActive ? "vip" : "",
          vipStatus: isActive ? "active" : "expired",

          vipPlatform: "google_play",
          vipProductId: productId,
          googlePurchaseToken: purchaseToken,

          vipExpiresAt:
            admin.firestore.Timestamp.fromDate(expiresAt),

          googleOrderId:
            googleInfo.orderId ||
            userData.googleOrderId ||
            "",

          googleAutoRenewing:
            googleInfo.autoRenewing === true,

          googlePaymentState:
            googleInfo.paymentState ?? null,

          googleAcknowledgementState:
            googleInfo.acknowledgementState ?? null,

          googleLastNotificationType: notificationType,

          googleRtdnReceivedAt:
            admin.firestore.FieldValue.serverTimestamp(),

          vipUpdatedAt:
            admin.firestore.FieldValue.serverTimestamp(),

          vipExpiredHandled: !isActive,

          ...(renewed
            ? {
                vipRenewCount:
                  admin.firestore.FieldValue.increment(1),

                vipLastRenewedAt:
                  admin.firestore.FieldValue.serverTimestamp(),

                vipReminder7dSent: false,
                vipReminder3dSent: false,
                vipReminder1dSent: false,
              }
            : {}),
        },
        { merge: true }
      );

      console.log(
        "GOOGLE VIP RTDN UPDATED:",
        userDoc.id,
        {
          productId,
          notificationType,
          isActive,
          renewed,
          expiresAt: expiresAt.toISOString(),
        }
      );
    } catch (error) {
      console.error(
        "GOOGLE VIP RTDN VERIFY ERROR:",
        userDoc.id,
        error.response?.data || error
      );

      // Throw để Pub/Sub retry lại thay vì mất notification
      throw error;
    }
  }
);

// 👉 DÁN 
// FUNCTION MỚI Ở ĐÂY
/*
exports.checkMemberships = onSchedule(
// 👉 DÁN 
// FUNCTION MỚI Ở ĐÂY
/*
exports.checkMemberships = onSchedule(
  {
    schedule: "every 24 hours",
    timeZone: "Australia/Sydney",
    region: "us-central1",
    secrets: ["SENDGRID_KEY"],
  },
  async () => {
    const usersSnap = await admin.firestore()
      .collection("users")
      .where("isVip", "==", true)
      .get();

    const now = new Date();

    for (const userDoc of usersSnap.docs) {
      ...
    }
  }
);
*/
async function getGoogleAccessToken() {
  const serviceAccountJson = process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON;

  if (!serviceAccountJson) {
    throw new Error("Missing GOOGLE_PLAY_SERVICE_ACCOUNT_JSON secret");
  }

  const credentials = JSON.parse(serviceAccountJson);

  const auth = new google.auth.GoogleAuth({
    credentials,
    scopes: [
      "https://www.googleapis.com/auth/androidpublisher",
    ],
  });

  const client = await auth.getClient();
  const token = await client.getAccessToken();

  return token.token;
}
async function getGoogleSubscriptionInfo(productId, purchaseToken) {
  const accessToken = await getGoogleAccessToken();

  const url =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${GOOGLE_PACKAGE_NAME}/purchases/subscriptions/${productId}/tokens/${purchaseToken}`;

  const response = await axios.get(url, {
    headers: {
      Authorization: `Bearer ${accessToken}`,
    },
  });

  return response.data;
}
function createAppleJwt() {
  const privateKey = process.env.APPLE_IAP_PRIVATE_KEY;

  if (!privateKey) {
    throw new Error("Missing APPLE_IAP_PRIVATE_KEY secret");
  }

  return jwt.sign(
    {
      iss: APPLE_ISSUER_ID,
      iat: Math.floor(Date.now() / 1000),
      exp: Math.floor(Date.now() / 1000) + 20 * 60,
      aud: "appstoreconnect-v1",
      bid: APPLE_BUNDLE_ID,
    },
    privateKey,
    {
      algorithm: "ES256",
      header: {
        alg: "ES256",
        kid: APPLE_KEY_ID,
        typ: "JWT",
      },
    }
  );
}

async function getAppleTransactionInfo(transactionId) {
  const token = createAppleJwt();

  const productionUrl =
    `https://api.storekit.itunes.apple.com/inApps/v1/transactions/${transactionId}`;

  try {
    const response = await axios.get(productionUrl, {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    });

    return response.data;
  } catch (error) {
    const status = error.response?.status;

    if (status === 404) {
      const sandboxUrl =
        `https://api.storekit-sandbox.itunes.apple.com/inApps/v1/transactions/${transactionId}`;

      const response = await axios.get(sandboxUrl, {
        headers: {
          Authorization: `Bearer ${token}`,
        },
      });

      return response.data;
    }

    throw error;
  }
}

function decodeAppleSignedTransaction(signedTransactionInfo) {
  const decoded = jwt.decode(signedTransactionInfo);

  if (!decoded) {
    throw new Error("Could not decode Apple signedTransactionInfo");
  }

  return decoded;
}

function getVipPlanFromProductId(productId) {
  if (productId === "com.vietlove.vip.weekly") {
    return {
      vipPlanId: "1_week",
      vipPlanTitleVi: "1 tuần",
      vipPlanTitleEn: "1 week",
      vipPriceTextVi: "$1/tuần",
      vipPriceTextEn: "$1/week",
    };
  }

  if (productId === "com.vietlove.vip.monthly") {
    return {
      vipPlanId: "1_month",
      vipPlanTitleVi: "1 tháng",
      vipPlanTitleEn: "1 month",
      vipPriceTextVi: "$29.99/tháng",
      vipPriceTextEn: "$29.99/month",
    };
  }

  if (productId === "com.vietlove.vip.3months") {
    return {
      vipPlanId: "3_months",
      vipPlanTitleVi: "3 tháng",
      vipPlanTitleEn: "3 months",
      vipPriceTextVi: "$26.66/tháng",
      vipPriceTextEn: "$26.66/month",
    };
  }

  if (productId === "com.vietlove.vip.6months") {
    return {
      vipPlanId: "6_months",
      vipPlanTitleVi: "6 tháng",
      vipPlanTitleEn: "6 months",
      vipPriceTextVi: "$2/tháng",
      vipPriceTextEn: "$2/month",
    };
  }

  return null;
}

function getGroupPlanFromProductId(productId) {
  if (productId === "group.weekend_coffee.monthly.v2") {
    return {
      groupId: "weekend_coffee",
      planType: "1_month",
      price: 2,
      currency: "AUD",
      groupTitleEn: "Weekend Coffee",
      groupTitleVi: "Cà phê cuối tuần",
    };
  }

  if (productId === "group.hiking_camping.monthly") {
    return {
      groupId: "hiking_camping",
      planType: "1_month",
      price: 2,
      currency: "AUD",
      groupTitleEn: "Hiking & Camping",
      groupTitleVi: "Leo núi & Cắm trại",
    };
  }

  if (productId === "group.speed_dating.monthly") {
    return {
      groupId: "speed_dating",
      planType: "1_month",
      price: 49.99,
      currency: "AUD",
      groupTitleEn: "Speed Dating",
      groupTitleVi: "Hẹn hò nhanh",
    };
  }

  if (productId === "group.gym_fitness.monthly") {
    return {
      groupId: "gym_fitness",
      planType: "1_month",
      price: 2,
      currency: "AUD",
      groupTitleEn: "Gym & Fitness",
      groupTitleVi: "Gym & Fitness",
    };
  }

  if (productId === "group.sydney_vietnamese.monthlyv3") {
    return {
      groupId: "sydney_vietnamese",
      planType: "1_month",
      price: 9.99,
      currency: "AUD",
      groupTitleEn: "Sydney Vietnamese Group",
      groupTitleVi: "Nhóm Người Việt Sydney",
    };
  }

  if (productId === "group.melbourne_vietnamese.monthly") {
    return {
      groupId: "melbourne_vietnamese",
      planType: "1_month",
      price: 9.99,
      currency: "AUD",
      groupTitleEn: "Melbourne Vietnamese Group",
      groupTitleVi: "Nhóm Người Việt Melbourne",
    };
  }

  if (productId === "group.queensland_vietnamese.monthly") {
    return {
      groupId: "queensland_vietnamese",
      planType: "1_month",
      price: 9.99,
      currency: "AUD",
      groupTitleEn: "Queensland Vietnamese Group",
      groupTitleVi: "Nhóm Người Việt Queensland",
    };
  }

  if (productId === "group.perth_vietnamese.monthly") {
    return {
      groupId: "perth_vietnamese",
      planType: "1_month",
      price: 9.99,
      currency: "AUD",
      groupTitleEn: "Perth Vietnamese Group",
      groupTitleVi: "Nhóm Người Việt Perth",
    };
  }



    if (productId === "group.adelaide_vietnamese.monthly") {
    return {
      groupId: "adelaide_vietnamese",
      planType: "1_month",
      price: 9.99,
      currency: "AUD",
      groupTitleEn: "Adelaide Vietnamese Group",
      groupTitleVi: "Nhóm Người Việt Adelaide",
    };
  }

  if (productId === "group.tasmania_vietnamese.monthly") {
    return {
      groupId: "tasmania_vietnamese",
      planType: "1_month",
      price: 9.99,
      currency: "AUD",
      groupTitleEn: "Tasmania Vietnamese Group",
      groupTitleVi: "Nhóm Người Việt Tasmania",
    };
  }

  if (productId === "group.canberra_vietnamese.monthly") {
    return {
      groupId: "canberra_vietnamese",
      planType: "1_month",
      price: 9.99,
      currency: "AUD",
      groupTitleEn: "Canberra Vietnamese Group",
      groupTitleVi: "Nhóm Người Việt Canberra",
    };
  }

  if (productId === "group.darwin_vietnamese.monthly") {
    return {
      groupId: "darwin_vietnamese",
      planType: "1_month",
      price: 9.99,
      currency: "AUD",
      groupTitleEn: "Darwin Vietnamese Group",
      groupTitleVi: "Nhóm Người Việt Darwin",
    };
  }
  return null;
}
exports.verifyAppleGroupPurchase = onCall(
  {
    region: "us-central1",
    secrets: ["APPLE_IAP_PRIVATE_KEY"],
  },
  async (request) => {
    try {
      const {
  userId,
  groupId,
  productId,
  transactionId,
  mode = "purchase",
} = request.data || {};

      if (!userId || !groupId || !productId || !transactionId) {
        throw new HttpsError(
          "invalid-argument",
          "Missing userId, groupId, productId, or transactionId"
        );
      }

      const plan = getGroupPlanFromProductId(productId);
      const transactionResponse =
  await getAppleTransactionInfo(transactionId);

const signedTransactionInfo =
  transactionResponse.signedTransactionInfo;

if (!signedTransactionInfo) {
  throw new HttpsError(
    "failed-precondition",
    "Missing signedTransactionInfo"
  );
}

const transactionInfo =
  decodeAppleSignedTransaction(
    signedTransactionInfo
  );

const appleProductId =
  transactionInfo.productId || "";
  console.log("GROUP VERIFY PRODUCT CHECK:", {
  appProductId: productId,
  appleProductId,
  groupId,
  transactionId,
});

const appleTransactionId =
  transactionInfo.transactionId || transactionId;

const appleOriginalTransactionId =
  transactionInfo.originalTransactionId || "";

if (!appleOriginalTransactionId) {
  throw new HttpsError(
    "failed-precondition",
    "Missing originalTransactionId from Apple"
  );
}
const existingGroupSnap = await admin.firestore()
  .collectionGroup("members")
  .where(
    "groupOriginalTransactionId",
    "==",
    appleOriginalTransactionId
  )
  .limit(1)
  .get();

if (!existingGroupSnap.empty) {
  const existingMember = existingGroupSnap.docs[0];
  const existingData = existingMember.data() || {};

  if (existingData.userId !== userId) {
    throw new HttpsError(
      "already-exists",
      "This Apple subscription is already linked to another account."
    );
  }
}

const expiresDateMs =
  Number(transactionInfo.expiresDate || 0);
  if (appleProductId !== productId) {
  throw new HttpsError(
    "failed-precondition",
    "Apple productId does not match app productId"
  );
}

if (!appleOriginalTransactionId) {
  throw new HttpsError(
    "failed-precondition",
    "Missing originalTransactionId from Apple"
  );
}

if (!expiresDateMs) {
  throw new HttpsError(
    "failed-precondition",
    "Missing expiresDate from Apple"
  );
}

const expiresAt = new Date(expiresDateMs);
const now = new Date();
const isActive = expiresAt > now;

const transactionReason =
  transactionInfo.transactionReason || "";

const shouldShowPopup =
  transactionReason !== "RENEWAL" &&
  transactionReason !== "AUTO_RENEWAL";

      if (!plan || plan.groupId !== groupId) {
        throw new HttpsError("invalid-argument", "Invalid group productId");
      }

      const memberRef = admin
  .firestore()
  .collection("groups")
  .doc(groupId)
  .collection("members")
  .doc(userId);

const memberSnapBefore = await memberRef.get();
const oldData = memberSnapBefore.data() || {};

const oldTransactionId = oldData.groupTransactionId || "";
const oldOriginalTransactionId =
  oldData.groupOriginalTransactionId || "";

const isRenew =
  oldOriginalTransactionId &&
  oldOriginalTransactionId === appleOriginalTransactionId &&
  oldTransactionId &&
  oldTransactionId !== appleTransactionId;

const oldRenewCount = Number(oldData.groupRenewCount || 0);

const processedRef = memberRef
  .collection("processedGroupPurchases")
  .doc(appleTransactionId);

const processedSnap = await processedRef.get();

if (processedSnap.exists) {
  return {
    success: isActive,
    alreadyProcessed: true,
    shouldShowPopup: false,
    groupId,
    groupStatus: isActive ? "active" : "expired",
    expiresAt: expiresAt.toISOString(),
    originalTransactionId: appleOriginalTransactionId,
  };
}
const userSnap = await admin
  .firestore()
  .collection("users")
  .doc(userId)
  .get();

const userData = userSnap.data() || {};

const userEmail = userData.email || "";
await memberRef.set(
  
  {
    uid: userId,
userId: userId,
groupId: groupId,
email: userEmail,

membershipActive: isActive,

source: "app_store",

groupRenewCount: isRenew
  ? oldRenewCount + 1
  : oldRenewCount,

groupLastRenewAt: isRenew
  ? admin.firestore.FieldValue.serverTimestamp()
  : oldData.groupLastRenewAt || null,

expiresAt:
  admin.firestore.Timestamp.fromDate(expiresAt),

    groupProductId: productId,

    groupTransactionId: appleTransactionId,

    groupOriginalTransactionId:
      appleOriginalTransactionId,

    groupStatus:
      isActive ? "active" : "expired",

    appleVerified: true,

    appleVerifiedAt:
      admin.firestore.FieldValue.serverTimestamp(),

      joinedAt:
  oldData.joinedAt || admin.firestore.FieldValue.serverTimestamp(),

expiredHandled: !isActive,
reminder7dSent: false,
reminder3dSent: false,
reminder1dSent: false,

planType: plan.planType,
price: plan.price,
currency: plan.currency,
groupTitleEn: plan.groupTitleEn,
groupTitleVi: plan.groupTitleVi,
    updatedAt:
      admin.firestore.FieldValue.serverTimestamp(),
  },
  { merge: true }
);
await processedRef.set(
  {
    transactionId: appleTransactionId,
    originalTransactionId: appleOriginalTransactionId,
    productId,
    groupId,
    planType: plan.planType,
    expiresAt:
      admin.firestore.Timestamp.fromDate(expiresAt),
    appleVerified: true,
    transactionReason,
    createdAt:
      admin.firestore.FieldValue.serverTimestamp(),
  },
  { merge: true }
);

return {
  success: isActive,
  alreadyProcessed: false,
  shouldShowPopup: isActive && shouldShowPopup,
  groupId,
  groupStatus: isActive ? "active" : "expired",
  expiresAt: expiresAt.toISOString(),
  originalTransactionId: appleOriginalTransactionId,
};
    } catch (error) {
      console.error("verifyAppleGroupPurchase error:", error);

      if (error instanceof HttpsError) {
        throw error;
      }

      throw new HttpsError("internal", "Server error");
    }
  }
);
exports.verifyGoogleVipPurchase = onCall(
  {
  region: "us-central1",
  secrets: ["GOOGLE_PLAY_SERVICE_ACCOUNT_JSON"],
},
  async (request) => {
    try {
      const {
        userId,
        productId,
        purchaseToken,
        mode = "purchase",
      } = request.data || {};

      if (!userId || !productId || !purchaseToken) {
        throw new HttpsError(
          "invalid-argument",
          "Missing userId, productId, or purchaseToken"
        );
      }

      const plan = getVipPlanFromProductId(productId);

      if (!plan) {
        throw new HttpsError("invalid-argument", "Invalid productId");
      }

      const googleInfo = await getGoogleSubscriptionInfo(
        productId,
        purchaseToken
      );

      console.log("Google subscription info:", googleInfo);

      const googleOrderId = googleInfo.orderId || "";
      const expiryTimeMillis = Number(googleInfo.expiryTimeMillis || 0);

      if (!expiryTimeMillis) {
        throw new HttpsError(
          "failed-precondition",
          "Missing expiryTimeMillis from Google"
        );
      }

      const expiresAt = new Date(expiryTimeMillis);
      const now = new Date();
      const isActive = expiresAt > now;

      const userRef = admin.firestore().collection("users").doc(userId);

      const processedRef = userRef
        .collection("processedVipPurchases")
        .doc(googleOrderId || purchaseToken);

      const processedSnap = await processedRef.get();

      if (processedSnap.exists) {
        return {
          success: isActive,
          alreadyProcessed: true,
          shouldShowPopup: false,
          vipPlanId: plan.vipPlanId,
          vipStatus: isActive ? "active" : "expired",
          vipExpiresAt: expiresAt.toISOString(),
          googleOrderId,
        };
      }

      const existingVipSnap = await admin.firestore()
        .collection("users")
        .where("googlePurchaseToken", "==", purchaseToken)
        .limit(1)
        .get();

      if (!existingVipSnap.empty) {
        const existingUser = existingVipSnap.docs[0];

        if (existingUser.id !== userId) {
          throw new HttpsError(
            "already-exists",
            "This Google subscription is already linked to another account."
          );
        }
      }

      const userSnap = await userRef.get();
      const oldData = userSnap.data() || {};

      const oldOrderId = oldData.googleOrderId || "";
      const oldRenewCount = Number(oldData.renewCount || 0);

      const isRenew =
        oldOrderId &&
        googleOrderId &&
        oldOrderId !== googleOrderId &&
        isActive;

      await userRef.set(
        {
          isVip: isActive,
          vipUnlocked: isActive,
          membership: isActive ? "vip" : "",
          plan: isActive ? "vip" : "",
          subscriptionType: plan.vipPlanId,
          vipPlanId: plan.vipPlanId,
          vipProductId: productId,
          vipPlatform: "google_play",
          vipStatus: isActive ? "active" : "expired",
          vipExpiresAt: admin.firestore.Timestamp.fromDate(expiresAt),

          googleOrderId,
          googlePurchaseToken: purchaseToken,
          googleAutoRenewing: googleInfo.autoRenewing === true,
          googlePaymentState: googleInfo.paymentState ?? null,
          googleAcknowledgementState:
            googleInfo.acknowledgementState ?? null,

          renewCount: isRenew
            ? oldRenewCount + 1
            : oldRenewCount,

          lastRenewAt: isRenew
            ? admin.firestore.FieldValue.serverTimestamp()
            : oldData.lastRenewAt || null,

          vipPlanTitleVi: plan.vipPlanTitleVi,
          vipPlanTitleEn: plan.vipPlanTitleEn,
          vipPriceTextVi: plan.vipPriceTextVi,
          vipPriceTextEn: plan.vipPriceTextEn,

          vipGoogleVerified: true,
          vipGoogleVerifiedAt:
            admin.firestore.FieldValue.serverTimestamp(),

          vipPurchasedAt:
            oldData.vipPurchasedAt ||
            admin.firestore.FieldValue.serverTimestamp(),

          vipUpdatedAt:
            admin.firestore.FieldValue.serverTimestamp(),

          vipReminder7dSent: false,
          vipReminder3dSent: false,
          vipReminder1dSent: false,
          vipExpiredHandled: !isActive,
        },
        { merge: true }
      );

      await processedRef.set(
        {
          transactionId: googleOrderId || purchaseToken,
          googleOrderId,
          googlePurchaseToken: purchaseToken,
          vipProductId: productId,
          vipPlanId: plan.vipPlanId,
          vipExpiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
          googleVerified: true,
          rawGoogleInfo: googleInfo,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      return {
        success: isActive,
        alreadyProcessed: false,
        shouldShowPopup: isActive,
        vipPlanId: plan.vipPlanId,
        vipStatus: isActive ? "active" : "expired",
        vipExpiresAt: expiresAt.toISOString(),
        googleOrderId,
      };
    } catch (error) {
      console.error(
        "verifyGoogleVipPurchase error:",
        error.response?.data || error
      );

      if (error instanceof HttpsError) {
        throw error;
      }

      throw new HttpsError("internal", "Server error");
    }
  }
);
exports.verifyGoogleGroupPurchase = onCall(
  {
    region: "us-central1",
    secrets: ["GOOGLE_PLAY_SERVICE_ACCOUNT_JSON"],
  },
  async (request) => {
    try {
      const {
        userId,
        groupId,
        productId,
        purchaseToken,
      } = request.data || {};

      if (!userId || !groupId || !productId || !purchaseToken) {
        throw new HttpsError(
          "invalid-argument",
          "Missing userId, groupId, productId, or purchaseToken"
        );
      }

      const plan = getGroupPlanFromProductId(productId);

      if (!plan || plan.groupId !== groupId) {
        throw new HttpsError(
          "invalid-argument",
          "Invalid group productId"
        );
      }

      const googleInfo = await getGoogleSubscriptionInfo(
        productId,
        purchaseToken
      );

      console.log("Google group subscription info:", googleInfo);

      const googleOrderId = googleInfo.orderId || "";
      const expiryTimeMillis = Number(googleInfo.expiryTimeMillis || 0);

      if (!expiryTimeMillis) {
        throw new HttpsError(
          "failed-precondition",
          "Missing expiryTimeMillis from Google"
        );
      }

      const expiresAt = new Date(expiryTimeMillis);
      const now = new Date();
      const isActive = expiresAt > now;

      const memberRef = admin
        .firestore()
        .collection("groups")
        .doc(groupId)
        .collection("members")
        .doc(userId);

      const processedRef = memberRef
        .collection("processedGroupPurchases")
        .doc(googleOrderId || purchaseToken);

      const processedSnap = await processedRef.get();

      if (processedSnap.exists) {
        return {
          success: isActive,
          alreadyProcessed: true,
          shouldShowPopup: false,
          groupId,
          groupStatus: isActive ? "active" : "expired",
          expiresAt: expiresAt.toISOString(),
          googleOrderId,
        };
      }

      const existingGroupSnap = await admin
        .firestore()
        .collectionGroup("members")
        .where("googleGroupPurchaseToken", "==", purchaseToken)
        .limit(1)
        .get();

      if (!existingGroupSnap.empty) {
        const existingMember = existingGroupSnap.docs[0];
        const existingData = existingMember.data() || {};

        if (existingData.userId !== userId) {
          throw new HttpsError(
            "already-exists",
            "This Google group subscription is already linked to another account."
          );
        }
      }

      const memberSnap = await memberRef.get();
      const oldData = memberSnap.data() || {};

      const oldOrderId = oldData.googleGroupOrderId || "";
      const oldRenewCount = Number(oldData.groupRenewCount || 0);

      const isRenew =
        oldOrderId &&
        googleOrderId &&
        oldOrderId !== googleOrderId &&
        isActive;

      const userSnap = await admin
        .firestore()
        .collection("users")
        .doc(userId)
        .get();

      const userData = userSnap.data() || {};
      const userEmail = userData.email || "";

      await memberRef.set(
        {
          uid: userId,
          userId,
          groupId,
          email: userEmail,

          membershipActive: isActive,
          groupStatus: isActive ? "active" : "expired",

          source: "google_play",

          groupProductId: productId,
          groupTransactionId: googleOrderId || purchaseToken,
          groupOriginalTransactionId: purchaseToken,

          googleGroupOrderId: googleOrderId,
          googleGroupPurchaseToken: purchaseToken,
          googleGroupAutoRenewing: googleInfo.autoRenewing === true,
          googleGroupPaymentState: googleInfo.paymentState ?? null,
          googleGroupAcknowledgementState:
            googleInfo.acknowledgementState ?? null,

          groupRenewCount: isRenew
            ? oldRenewCount + 1
            : oldRenewCount,

          groupLastRenewAt: isRenew
            ? admin.firestore.FieldValue.serverTimestamp()
            : oldData.groupLastRenewAt || null,

          expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),

          googleVerified: true,
          googleVerifiedAt:
            admin.firestore.FieldValue.serverTimestamp(),

          joinedAt:
            oldData.joinedAt ||
            admin.firestore.FieldValue.serverTimestamp(),

          expiredHandled: !isActive,
          reminder7dSent: false,
          reminder3dSent: false,
          reminder1dSent: false,

          planType: plan.planType,
          price: plan.price,
          currency: plan.currency,
          groupTitleEn: plan.groupTitleEn,
          groupTitleVi: plan.groupTitleVi,

          updatedAt:
            admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      await processedRef.set(
        {
          transactionId: googleOrderId || purchaseToken,
          googleOrderId,
          googlePurchaseToken: purchaseToken,
          productId,
          groupId,
          planType: plan.planType,
          expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
          googleVerified: true,
          rawGoogleInfo: googleInfo,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      return {
        success: isActive,
        alreadyProcessed: false,
        shouldShowPopup: isActive,
        groupId,
        groupStatus: isActive ? "active" : "expired",
        expiresAt: expiresAt.toISOString(),
        googleOrderId,
      };
    } catch (error) {
      console.error(
        "verifyGoogleGroupPurchase error:",
        error.response?.data || error
      );

      if (error instanceof HttpsError) {
        throw error;
      }

      throw new HttpsError("internal", "Server error");
    }
  }
);
// 👉 GIỮ NGUYÊN CÁI NÀY
exports.verifyAppleVipPurchase = onCall(
  {
    region: "us-central1",
    secrets: ["APPLE_IAP_PRIVATE_KEY"],
  },
  async (request) => {
    try {
      const {
  userId,
  productId,
  transactionId,
  mode = "purchase",
} = request.data || {};

      if (!userId || !productId || !transactionId) {
        throw new HttpsError(
          "invalid-argument",
          "Missing userId, productId, or transactionId"
        );
      }

      const plan = getVipPlanFromProductId(productId);

      if (!plan) {
        throw new HttpsError("invalid-argument", "Invalid productId");
      }

      const appleResponse = await getAppleTransactionInfo(transactionId);
      const signedTransactionInfo = appleResponse.signedTransactionInfo;

      if (!signedTransactionInfo) {
        throw new HttpsError(
          "failed-precondition",
          "Missing signedTransactionInfo from Apple"
        );
      }

     const transactionInfo =
  decodeAppleSignedTransaction(signedTransactionInfo);

console.log("Apple transactionInfo:", transactionInfo);

const appleProductId =
  transactionInfo.productId || "";

const appleTransactionId =
  transactionInfo.transactionId || transactionId;

const appleOriginalTransactionId =
  transactionInfo.originalTransactionId || "";

if (!appleOriginalTransactionId) {
  throw new HttpsError(
    "failed-precondition",
    "Missing originalTransactionId from Apple"
  );
}

const existingVipSnap = await admin.firestore()
  .collection("users")
  .where(
    "vipOriginalTransactionId",
    "==",
    appleOriginalTransactionId
  )
  .limit(1)
  .get();

if (!existingVipSnap.empty) {
  const existingUser = existingVipSnap.docs[0];

  if (existingUser.id !== userId) {
    throw new HttpsError(
      "already-exists",
      "This Apple subscription is already linked to another account."
    );
  }
}



const expiresDateMs =
  Number(transactionInfo.expiresDate || 0);

if (appleProductId !== productId) {
  console.log("VIP VERIFY PRODUCT CHECK:", {
  appProductId: productId,
  appleProductId,
  transactionId,
  appleTransactionId,
  originalTransactionId: appleOriginalTransactionId,
});

  throw new HttpsError(
    "failed-precondition",
    "Apple productId does not match app productId"
  );
}

if (!expiresDateMs) {
  throw new HttpsError(
    "failed-precondition",
    "Missing expiresDate from Apple"
  );
}

      const expiresAt = new Date(expiresDateMs);
const now = new Date();
const isActive = expiresAt > now;

const transactionReason = transactionInfo.transactionReason || "";
const shouldShowPopup =
  transactionReason !== "RENEWAL" &&
  transactionReason !== "AUTO_RENEWAL";

const userRef = admin.firestore().collection("users").doc(userId);

const processedRef = userRef
  .collection("processedVipPurchases")
  .doc(appleTransactionId);

const processedSnap = await processedRef.get();

if (processedSnap.exists) {
  return {
    success: isActive,
    alreadyProcessed: true,
    shouldShowPopup: false,
    transactionReason,
    vipPlanId: plan.vipPlanId,
    vipStatus: isActive ? "active" : "expired",
    vipExpiresAt: expiresAt.toISOString(),
    originalTransactionId: appleOriginalTransactionId,
  };
}

const userSnap = await userRef.get();
const oldData = userSnap.data() || {};

const oldTransactionId = oldData.vipTransactionId || "";
const oldOriginalTransactionId =
  oldData.vipOriginalTransactionId || "";

const isRenew =
  oldOriginalTransactionId &&
  oldOriginalTransactionId === appleOriginalTransactionId &&
  oldTransactionId &&
  oldTransactionId !== appleTransactionId;

const oldRenewCount = Number(oldData.renewCount || 0);

      await userRef.set(
        {
          isVip: isActive,
          vipUnlocked: isActive,
          membership: isActive ? "vip" : "",
          vipTransactionId: appleTransactionId,
vipOriginalTransactionId: appleOriginalTransactionId,

renewCount: isRenew
  ? oldRenewCount + 1
  : oldRenewCount,

lastRenewAt: isRenew
  ? admin.firestore.FieldValue.serverTimestamp()
  : oldData.lastRenewAt || null,

lastAppleTransactionId: appleTransactionId,
          plan: isActive ? "vip" : "",
          subscriptionType: plan.vipPlanId,
          vipPlanId: plan.vipPlanId,
          vipProductId: productId,
          vipPlatform: "app_store",
          vipStatus: isActive ? "active" : "expired",
          vipExpiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
          vipPlanTitleVi: plan.vipPlanTitleVi,
          vipPlanTitleEn: plan.vipPlanTitleEn,
          vipPriceTextVi: plan.vipPriceTextVi,
          vipPriceTextEn: plan.vipPriceTextEn,
          vipAppleVerified: true,
          vipAppleVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
          vipPurchasedAt: admin.firestore.FieldValue.serverTimestamp(),
          vipUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          vipReminder7dSent: false,
          vipReminder3dSent: false,
          vipReminder1dSent: false,
          vipExpiredHandled: !isActive,
        },
        { merge: true }
      );

      await admin
        .firestore()
        .collection("users")
        .doc(userId)
        .collection("processedVipPurchases")
        .doc(appleTransactionId)
        .set(
          {
            transactionId: appleTransactionId,
            originalTransactionId: appleOriginalTransactionId,
            vipProductId: productId,
            vipPlanId: plan.vipPlanId,
            vipExpiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
            appleVerified: true,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

      return {
  success: isActive,
  alreadyProcessed: false,
shouldShowPopup: isActive && shouldShowPopup,
  transactionReason,
  vipPlanId: plan.vipPlanId,
  vipStatus: isActive ? "active" : "expired",
  vipExpiresAt: expiresAt.toISOString(),
  originalTransactionId: appleOriginalTransactionId,
};
    } catch (error) {
      console.error(
        "verifyAppleVipPurchase error:",
        error.response?.data || error
      );

      if (error instanceof HttpsError) {
        throw error;
      }

      throw new HttpsError("internal", "Server error");
    }
  }
);
exports.appleGroupNotification = onRequest(
  {
    region: "us-central1",
  },
  async (req, res) => {
    try {
      if (req.method !== "POST") {
        res.status(405).send("Method Not Allowed");
        return;
      }

      const signedPayload = req.body?.signedPayload;

      if (!signedPayload) {
        res.status(400).send("Missing signedPayload");
        return;
      }

      const notification = jwt.decode(signedPayload);

      if (!notification) {
        res.status(400).send("Invalid signedPayload");
        return;
      }

      const notificationType = notification.notificationType || "";
      const subtype = notification.subtype || "";

      const signedTransactionInfo =
        notification.data?.signedTransactionInfo || "";

      if (!signedTransactionInfo) {
        res.status(200).send("No transaction info");
        return;
      }

      const transactionInfo = jwt.decode(signedTransactionInfo);

      if (!transactionInfo) {
        res.status(400).send("Invalid transaction info");
        return;
      }

      const productId = transactionInfo.productId || "";
      const transactionId = transactionInfo.transactionId || "";
      const originalTransactionId =
        transactionInfo.originalTransactionId || "";
      const expiresDateMs = Number(transactionInfo.expiresDate || 0);

      if (!productId || !originalTransactionId || !expiresDateMs) {
        res.status(200).send("Missing required transaction fields");
        return;
      }

      const plan = getGroupPlanFromProductId(productId);

      if (!plan) {
        res.status(200).send("Not a group product");
        return;
      }

      const membersSnap = await admin
        .firestore()
        .collectionGroup("members")
        .where("groupOriginalTransactionId", "==", originalTransactionId)
        .limit(1)
        .get();

      if (membersSnap.empty) {
        res.status(200).send("No matching group member");
        return;
      }

      const memberDoc = membersSnap.docs[0];
      const memberData = memberDoc.data() || {};
      const memberRef = memberDoc.ref;

      const expiresAt = new Date(expiresDateMs);
      const now = new Date();

      let isActive = expiresAt > now;

      if (
        notificationType === "EXPIRED" ||
        notificationType === "REFUND" ||
        notificationType === "REVOKE" ||
        notificationType === "DID_FAIL_TO_RENEW"
      ) {
        isActive = false;
      }

      const oldTransactionId = memberData.groupTransactionId || "";
      const oldRenewCount = Number(memberData.groupRenewCount || 0);

      const isRenew =
        oldTransactionId &&
        transactionId &&
        oldTransactionId !== transactionId &&
        isActive;

      await memberRef.set(
        {
          membershipActive: isActive,
          expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),

          groupProductId: productId,
          groupTransactionId: transactionId,
          groupOriginalTransactionId: originalTransactionId,
          groupStatus: isActive ? "active" : "expired",

          lastAppleNotificationType: notificationType,
          lastAppleNotificationSubtype: subtype,
          lastAppleTransactionId: transactionId,

          groupRenewCount: isRenew
            ? oldRenewCount + 1
            : oldRenewCount,

          groupLastRenewAt: isRenew
            ? admin.firestore.FieldValue.serverTimestamp()
            : memberData.groupLastRenewAt || null,

          appleWebhookReceivedAt:
            admin.firestore.FieldValue.serverTimestamp(),

          updatedAt:
            admin.firestore.FieldValue.serverTimestamp(),

          expiredHandled: !isActive,
        },
        { merge: true }
      );

      await memberRef
        .collection("appleGroupNotifications")
        .doc(transactionId || `${Date.now()}`)
        .set(
          {
            notificationType,
            subtype,
            productId,
            transactionId,
            originalTransactionId,
            expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
            isActive,
            rawNotification: notification,
            rawTransactionInfo: transactionInfo,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

      res.status(200).send("OK");
    } catch (error) {
      console.error("appleGroupNotification error:", error);
      res.status(500).send("Server error");
    }
  }
);
exports.appleVipNotification = onRequest(
  {
    region: "us-central1",
  },
  async (req, res) => {
    try {
      if (req.method !== "POST") {
        res.status(405).send("Method Not Allowed");
        return;
      }

      const signedPayload = req.body?.signedPayload;

      if (!signedPayload) {
        res.status(400).send("Missing signedPayload");
        return;
      }

      const notification = jwt.decode(signedPayload);

      if (!notification) {
        res.status(400).send("Invalid signedPayload");
        return;
      }

      console.log("Apple notification:", notification);

      const notificationType = notification.notificationType || "";
      const subtype = notification.subtype || "";

      const signedTransactionInfo =
        notification.data?.signedTransactionInfo || "";

      if (!signedTransactionInfo) {
        res.status(200).send("No transaction info");
        return;
      }

      const transactionInfo = jwt.decode(signedTransactionInfo);

      if (!transactionInfo) {
        res.status(400).send("Invalid transaction info");
        return;
      }

      console.log("Apple transaction from notification:", transactionInfo);

      const productId = transactionInfo.productId || "";
      const transactionId = transactionInfo.transactionId || "";
      const originalTransactionId =
        transactionInfo.originalTransactionId || "";
      const expiresDateMs = Number(transactionInfo.expiresDate || 0);

      if (!productId || !originalTransactionId || !expiresDateMs) {
        res.status(200).send("Missing required transaction fields");
        return;
      }

      const plan = getVipPlanFromProductId(productId);

      if (!plan) {
        res.status(200).send("Not a VIP product");
        return;
      }

      const usersSnap = await admin.firestore()
        .collection("users")
        .where("vipOriginalTransactionId", "==", originalTransactionId)
        .limit(1)
        .get();

      if (usersSnap.empty) {
        console.log(
          "No user found for originalTransactionId:",
          originalTransactionId
        );
        res.status(200).send("No matching user");
        return;
      }

      const userDoc = usersSnap.docs[0];
      const userData = userDoc.data() || {};
      const userRef = userDoc.ref;

      const expiresAt = new Date(expiresDateMs);
      const now = new Date();

      let isActive = expiresAt > now;

      if (
        notificationType === "EXPIRED" ||
        notificationType === "REFUND" ||
        notificationType === "REVOKE" ||
        notificationType === "DID_FAIL_TO_RENEW"
      ) {
        isActive = false;
      }

      const oldTransactionId = userData.vipTransactionId || "";
      const oldRenewCount = Number(userData.renewCount || 0);

      const isRenew =
        oldTransactionId &&
        transactionId &&
        oldTransactionId !== transactionId &&
        isActive;

      await userRef.set(
        {
          isVip: isActive,
          vipUnlocked: isActive,
          membership: isActive ? "vip" : "",
          plan: isActive ? "vip" : "",
          subscriptionType: plan.vipPlanId,
          vipPlanId: plan.vipPlanId,
          vipProductId: productId,
          vipPlatform: "app_store",
          vipStatus: isActive ? "active" : "expired",
          vipExpiresAt: admin.firestore.Timestamp.fromDate(expiresAt),

          vipTransactionId: transactionId,
          vipOriginalTransactionId: originalTransactionId,
          lastAppleNotificationType: notificationType,
          lastAppleNotificationSubtype: subtype,
          lastAppleTransactionId: transactionId,

          renewCount: isRenew ? oldRenewCount + 1 : oldRenewCount,
          lastRenewAt: isRenew
            ? admin.firestore.FieldValue.serverTimestamp()
            : userData.lastRenewAt || null,

          vipAppleWebhookReceivedAt:
            admin.firestore.FieldValue.serverTimestamp(),
          vipUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),

          vipExpiredHandled: !isActive,
        },
        { merge: true }
      );

      await userRef
        .collection("appleVipNotifications")
        .doc(transactionId || `${Date.now()}`)
        .set(
          {
            notificationType,
            subtype,
            productId,
            transactionId,
            originalTransactionId,
            expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
            isActive,
            rawNotification: notification,
            rawTransactionInfo: transactionInfo,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

      res.status(200).send("OK");
    } catch (error) {
      console.error("appleVipNotification error:", error);
      res.status(500).send("Server error");
    }
  }
);
exports.appleStoreNotification = onRequest(
  {
    region: "us-central1",
  },
  async (req, res) => {
    try {
      if (req.method !== "POST") {
        res.status(405).send("Method Not Allowed");
        return;
      }

      const signedPayload = req.body?.signedPayload;

      if (!signedPayload) {
        res.status(400).send("Missing signedPayload");
        return;
      }

      const notification = jwt.decode(signedPayload);

      if (!notification) {
        res.status(400).send("Invalid signedPayload");
        return;
      }

      console.log("Apple STORE notification:", notification);

      const notificationType = notification.notificationType || "";
      const subtype = notification.subtype || "";

      const signedTransactionInfo =
        notification.data?.signedTransactionInfo || "";

      if (!signedTransactionInfo) {
        res.status(200).send("No transaction info");
        return;
      }

      const transactionInfo = jwt.decode(signedTransactionInfo);

      if (!transactionInfo) {
        res.status(400).send("Invalid transaction info");
        return;
      }

      console.log("Apple STORE transaction:", transactionInfo);

      const productId = transactionInfo.productId || "";
      const transactionId = transactionInfo.transactionId || "";
      const originalTransactionId =
        transactionInfo.originalTransactionId || "";
      const expiresDateMs = Number(transactionInfo.expiresDate || 0);

      if (!productId || !originalTransactionId || !expiresDateMs) {
        res.status(200).send("Missing required transaction fields");
        return;
      }

      const expiresAt = new Date(expiresDateMs);
      const now = new Date();

      let isActive = expiresAt > now;

      if (
        notificationType === "EXPIRED" ||
        notificationType === "REFUND" ||
        notificationType === "REVOKE" ||
        notificationType === "DID_FAIL_TO_RENEW"
      ) {
        isActive = false;
      }

      const vipPlan = getVipPlanFromProductId(productId);

      if (vipPlan) {
        const usersSnap = await admin.firestore()
          .collection("users")
          .where("vipOriginalTransactionId", "==", originalTransactionId)
          .limit(1)
          .get();

        if (usersSnap.empty) {
          console.log("No VIP user found:", originalTransactionId);
          res.status(200).send("No matching VIP user");
          return;
        }

        const userDoc = usersSnap.docs[0];
        const userData = userDoc.data() || {};
        const userRef = userDoc.ref;

        const oldTransactionId = userData.vipTransactionId || "";
        const oldRenewCount = Number(userData.renewCount || 0);

        const isRenew =
          oldTransactionId &&
          transactionId &&
          oldTransactionId !== transactionId &&
          isActive;

        await userRef.set(
          {
            isVip: isActive,
            vipUnlocked: isActive,
            membership: isActive ? "vip" : "",
            plan: isActive ? "vip" : "",
            subscriptionType: vipPlan.vipPlanId,
            vipPlanId: vipPlan.vipPlanId,
            vipProductId: productId,
            vipPlatform: "app_store",
            vipStatus: isActive ? "active" : "expired",
            vipExpiresAt: admin.firestore.Timestamp.fromDate(expiresAt),

            vipTransactionId: transactionId,
            vipOriginalTransactionId: originalTransactionId,
            lastAppleNotificationType: notificationType,
            lastAppleNotificationSubtype: subtype,
            lastAppleTransactionId: transactionId,

            renewCount: isRenew ? oldRenewCount + 1 : oldRenewCount,
            lastRenewAt: isRenew
              ? admin.firestore.FieldValue.serverTimestamp()
              : userData.lastRenewAt || null,

            vipAppleWebhookReceivedAt:
              admin.firestore.FieldValue.serverTimestamp(),
            vipUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),

            vipExpiredHandled: !isActive,
          },
          { merge: true }
        );

        await userRef
          .collection("appleVipNotifications")
          .doc(transactionId || `${Date.now()}`)
          .set(
            {
              notificationType,
              subtype,
              productId,
              transactionId,
              originalTransactionId,
              expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
              isActive,
              rawNotification: notification,
              rawTransactionInfo: transactionInfo,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );

        res.status(200).send("VIP OK");
        return;
      }

      const groupPlan = getGroupPlanFromProductId(productId);

      if (groupPlan) {
        const membersSnap = await admin.firestore()
          .collectionGroup("members")
          .where("groupOriginalTransactionId", "==", originalTransactionId)
          .limit(1)
          .get();

        if (membersSnap.empty) {
          console.log("No group member found:", originalTransactionId);
          res.status(200).send("No matching group member");
          return;
        }

        const memberDoc = membersSnap.docs[0];
        const memberData = memberDoc.data() || {};
        const memberRef = memberDoc.ref;

        const oldTransactionId = memberData.groupTransactionId || "";
        const oldRenewCount = Number(memberData.groupRenewCount || 0);

        const isRenew =
          oldTransactionId &&
          transactionId &&
          oldTransactionId !== transactionId &&
          isActive;

        await memberRef.set(
          {
            membershipActive: isActive,
            expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),

            groupProductId: productId,
            groupTransactionId: transactionId,
            groupOriginalTransactionId: originalTransactionId,
            groupStatus: isActive ? "active" : "expired",

            lastAppleNotificationType: notificationType,
            lastAppleNotificationSubtype: subtype,
            lastAppleTransactionId: transactionId,

            groupRenewCount: isRenew
              ? oldRenewCount + 1
              : oldRenewCount,

            groupLastRenewAt: isRenew
              ? admin.firestore.FieldValue.serverTimestamp()
              : memberData.groupLastRenewAt || null,

            appleWebhookReceivedAt:
              admin.firestore.FieldValue.serverTimestamp(),

            updatedAt:
              admin.firestore.FieldValue.serverTimestamp(),

            expiredHandled: !isActive,
          },
          { merge: true }
        );

        await memberRef
          .collection("appleGroupNotifications")
          .doc(transactionId || `${Date.now()}`)
          .set(
            {
              notificationType,
              subtype,
              productId,
              transactionId,
              originalTransactionId,
              expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
              isActive,
              rawNotification: notification,
              rawTransactionInfo: transactionInfo,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );

        res.status(200).send("GROUP OK");
        return;
      }

      res.status(200).send("Not VIP or group product");
    } catch (error) {
      console.error("appleStoreNotification error:", error);
      res.status(500).send("Server error");
    }
  }
);
const { Translate } = require("@google-cloud/translate").v2;

const translate = new Translate();

// Auto translate prompts when user updates profile
exports.autoTranslatePrompts = onRequest(async (req, res) => {
  try {
    const { text, target } = req.body;

    if (!text || !target) {
      return res.status(400).send("Missing text or target");
    }

    const [translation] = await translate.translate(text, target);

    res.status(200).json({
      translatedText: translation,
    });
  } catch (error) {
    console.error("Translate error:", error);
    res.status(500).send("Translate failed");
  }
});

exports.syncPhotoVerificationStatus = onDocumentUpdated(
  {
    document: "photo_verification_requests/{userId}",
    region: "us-central1",
  },
  async (event) => {
    try {
      const userId = event.params.userId;

      const before = event.data.before.data() || {};
      const after = event.data.after.data() || {};

      const beforeStatus = String(
        before.photoVerificationStatus || ""
      ).toLowerCase();

      const afterStatus = String(
        after.photoVerificationStatus || ""
      ).toLowerCase();

      if (beforeStatus === afterStatus) {
        return;
      }

      if (
        afterStatus !== "approved" &&
        afterStatus !== "rejected"
      ) {
        return;
      }

      const isApproved = afterStatus === "approved";

      await admin
        .firestore()
        .collection("users")
        .doc(userId)
        .set(
          {
            photoVerified: isApproved,
            photoVerificationStatus: afterStatus,
            photoVerificationReviewedAt:
              admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

      console.log(
        "PHOTO VERIFICATION SYNCED:",
        userId,
        afterStatus
      );
    } catch (error) {
      console.error(
        "syncPhotoVerificationStatus error:",
        error
      );
    }
  }
);


exports.spinLuckyWheel = onCall(
  {
    region: "us-central1",
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "You must be logged in."
      );
    }

    const uid = request.auth.uid;

    const requestId = String(
      request.data?.requestId || ""
    ).trim();

    if (
      !requestId ||
      requestId.length < 10 ||
      requestId.length > 200
    ) {
      throw new HttpsError(
        "invalid-argument",
        "A valid requestId is required."
      );
    }

    const db = admin.firestore();

    const userRef = db
      .collection("users")
      .doc(uid);

    const now = new Date();
    const todayKey = getSydneyDateKey(now);

    /*
     * Tạo random bên ngoài transaction.
     *
     * Firestore có thể tự chạy lại transaction khi có xung đột.
     * Việc tạo random ở ngoài giúp cùng một request không bị đổi
     * kết quả giữa các lần transaction tự chạy lại.
     */
    const noRewardResult =
      secureRandomInt(0, 1) === 0
        ? "try_again"
        : "better_luck";

    const nextRewardAfterDays =
      secureRandomInt(7, 12);

    const nextWinningSpinNumber =
      secureRandomInt(1, 3);

    const newPendingRewardId =
      crypto.randomBytes(20).toString("hex");

    try {
      const result = await db.runTransaction(
        async (transaction) => {
          const userSnapshot =
            await transaction.get(userRef);

          if (!userSnapshot.exists) {
            throw new HttpsError(
              "not-found",
              "User profile was not found."
            );
          }

          const data =
            userSnapshot.data() || {};

          // ==========================================
          // CHỐNG GỬI TRÙNG CÙNG MỘT REQUEST
          // ==========================================

          const previousRequestId = String(
            data.luckySpinLastRequestId || ""
          ).trim();

          if (
            previousRequestId === requestId &&
            data.luckySpinLastResponse &&
            typeof data.luckySpinLastResponse ===
              "object"
          ) {
            return {
              ...data.luckySpinLastResponse,
              duplicateRequest: true,
            };
          }

          // ==========================================
          // KHÔNG CHO QUAY KHI CÒN THƯỞNG CHỜ XỬ LÝ
          // ==========================================

          const pendingStatus = String(
            data.luckySpinPendingRewardStatus ||
              ""
          ).trim();

          const pendingRewardId = String(
            data.luckySpinPendingRewardId || ""
          ).trim();

          const pendingFlowers =
            luckySpinSafeInt(
              data.luckySpinPendingFlowers
            );

          if (
            pendingStatus === "pending" &&
            pendingRewardId &&
            pendingFlowers > 0
          ) {
            throw new HttpsError(
              "failed-precondition",
              "PENDING_REWARD"
            );
          }

          // ==========================================
          // ĐỌC SỐ LƯỢT QUAY TRONG NGÀY
          // ==========================================

          const savedDateKey = String(
            data.luckySpinDateKey || ""
          ).trim();

          let spinsUsedToday =
            luckySpinSafeInt(
              data.luckySpinSpinsUsedToday
            );

          if (savedDateKey !== todayKey) {
            spinsUsedToday = 0;
          }

          if (spinsUsedToday >= 3) {
            throw new HttpsError(
              "resource-exhausted",
              "NO_SPINS_LEFT"
            );
          }

          const spinNumberToday =
            spinsUsedToday + 1;

          // ==========================================
          // ĐỌC TỔNG SỐ LƯỢT QUAY TRONG ĐỜI
          // ==========================================

          const firstRewardAlreadyOffered =
            data.luckySpinFirstRewardOffered ===
              true ||
            data.luckySpinFirstRewardClaimed ===
              true;

          let lifetimeSpinsUsed =
            luckySpinSafeInt(
              data.luckySpinLifetimeSpinsUsed
            );

          /*
           * Hỗ trợ dữ liệu cũ:
           *
           * Nếu từng được đề nghị 5 Flowers nhưng chưa có
           * lifetimeSpinsUsed, xem như đã hoàn tất 3 lượt đầu.
           */
          if (
            lifetimeSpinsUsed <= 0 &&
            firstRewardAlreadyOffered
          ) {
            lifetimeSpinsUsed = 3;
          } else if (
            lifetimeSpinsUsed <= 0 &&
            savedDateKey === todayKey
          ) {
            lifetimeSpinsUsed =
              spinsUsedToday;
          }

          const lifetimeSpinNumber =
            lifetimeSpinsUsed + 1;

          // ==========================================
          // ĐỌC NGÀY VÀ LƯỢT TRÚNG TIẾP THEO
          // ==========================================

          let nextRewardDateKey = String(
            data.luckySpinNextRewardDateKey ||
              ""
          ).trim();

          /*
           * Hỗ trợ field Timestamp cũ nếu có.
           */
          if (
            !nextRewardDateKey &&
            data.luckySpinNextRewardDate &&
            typeof data
              .luckySpinNextRewardDate
              .toDate === "function"
          ) {
            nextRewardDateKey =
              getSydneyDateKey(
                data.luckySpinNextRewardDate.toDate()
              );
          }

          let winningSpinNumber =
            luckySpinSafeInt(
              data.luckySpinWinningSpinNumber
            );

          if (
            winningSpinNumber < 1 ||
            winningSpinNumber > 3
          ) {
            winningSpinNumber =
              nextWinningSpinNumber;
          }

          let resultKey = noRewardResult;
          let flowersWon = 0;

          let newNextRewardDateKey = null;
          let newWinningSpinNumber = null;

          // ==========================================
          // BA LƯỢT ĐẦU TIÊN TRONG ĐỜI
          //
          // Lượt 1: không trúng
          // Lượt 2: 5 Flowers
          // Lượt 3: không trúng
          // ==========================================

          if (lifetimeSpinNumber <= 3) {
            if (lifetimeSpinNumber === 2) {
              resultKey = "five_flowers";
              flowersWon = 5;

              newNextRewardDateKey =
                addDaysToDateKey(
                  todayKey,
                  nextRewardAfterDays
                );

              newWinningSpinNumber =
                nextWinningSpinNumber;
            } else {
              resultKey = noRewardResult;
              flowersWon = 0;
            }
          } else {
            // ========================================
            // SAU BA LƯỢT ĐẦU
            //
            // Chỉ có thể trúng đúng 1 Flower.
            // Ngày trúng cách lần trước 7–12 ngày.
            // Lượt trúng trong ngày là lượt 1–3.
            // ========================================

         const isRewardDay =
  nextRewardDateKey.length > 0 &&
  todayKey >= nextRewardDateKey;

            if (
              isRewardDay &&
              spinNumberToday ===
                winningSpinNumber
            ) {
              resultKey = "one_flower";
              flowersWon = 1;

              newNextRewardDateKey =
                addDaysToDateKey(
                  todayKey,
                  nextRewardAfterDays
                );

              newWinningSpinNumber =
                nextWinningSpinNumber;
            } else {
              resultKey = noRewardResult;
              flowersWon = 0;
            }
          }

          // Backend không được trả hai phần thưởng này.
          if (
            resultKey === "ten_flowers" ||
            resultKey === "one_week_vip"
          ) {
            throw new HttpsError(
              "internal",
              "INVALID_LUCKY_SPIN_RESULT"
            );
          }

          const currentFlowerBalance =
            luckySpinSafeInt(
              data.flowerBalance
            );

          const responseData = {
            success: true,
            resultKey,
            spinNumber: spinNumberToday,
            spinsUsedToday: spinNumberToday,
            spinsRemaining:
              Math.max(
                0,
                3 - spinNumberToday
              ),
            lifetimeSpinNumber,
            flowersWon,
            pendingRewardId:
              flowersWon > 0
                ? newPendingRewardId
                : "",
            pendingRewardKey:
              flowersWon > 0
                ? resultKey
                : "",
            pendingFlowers: flowersWon,
            flowerBalance:
              currentFlowerBalance,
          };

          const updateData = {
            luckySpinDateKey: todayKey,

            luckySpinSpinsUsedToday:
              spinNumberToday,

            luckySpinLifetimeSpinsUsed:
              lifetimeSpinNumber,

            luckySpinLastResult:
              resultKey,

            luckySpinLastRequestId:
              requestId,

            luckySpinLastResponse:
              responseData,

            luckySpinLastSpinAt:
              admin.firestore.FieldValue
                .serverTimestamp(),

            luckySpinUpdatedAt:
              admin.firestore.FieldValue
                .serverTimestamp(),
          };

          /*
           * 5 Flowers chỉ được đề nghị đúng một lần.
           * Dù người dùng nhận hay từ chối cũng không hiện lại.
           */
          if (resultKey === "five_flowers") {
            updateData
              .luckySpinFirstRewardOffered =
              true;

            updateData
              .luckySpinFirstRewardOfferedAt =
              admin.firestore.FieldValue
                .serverTimestamp();
          }

          /*
           * Khi trúng chỉ tạo pending reward.
           * Chưa cộng vào flowerBalance.
           */
          if (flowersWon > 0) {
            updateData
              .luckySpinPendingRewardId =
              newPendingRewardId;

            updateData
              .luckySpinPendingRewardKey =
              resultKey;

            updateData
              .luckySpinPendingFlowers =
              flowersWon;

            updateData
              .luckySpinPendingRewardStatus =
              "pending";

            updateData
              .luckySpinPendingRewardCreatedAt =
              admin.firestore.FieldValue
                .serverTimestamp();
          }

          if (newNextRewardDateKey) {
            updateData
              .luckySpinNextRewardDateKey =
              newNextRewardDateKey;
          }

          if (newWinningSpinNumber) {
            updateData
              .luckySpinWinningSpinNumber =
              newWinningSpinNumber;
          }

          transaction.set(
            userRef,
            updateData,
            {
              merge: true,
            }
          );

          return responseData;
        }
      );

      console.log(
        "LUCKY SPIN SUCCESS:",
        {
          uid,
          requestId,
          resultKey: result.resultKey,
          spinNumber: result.spinNumber,
          lifetimeSpinNumber:
            result.lifetimeSpinNumber,
          flowersWon: result.flowersWon,
          duplicateRequest:
            result.duplicateRequest === true,
        }
      );

      return result;
    } catch (error) {
      console.error(
        "SPIN LUCKY WHEEL ERROR:",
        {
          uid,
          requestId,
          error,
        }
      );

      if (error instanceof HttpsError) {
        throw error;
      }

      throw new HttpsError(
        "internal",
        "Could not spin the lucky wheel."
      );
    }
  }
);



exports.claimLuckySpinReward = onCall(
  {
    region: "us-central1",
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "You must be logged in."
      );
    }

    const uid = request.auth.uid;

    const expectedRewardId = String(
      request.data?.rewardId || ""
    ).trim();

    if (!expectedRewardId) {
      throw new HttpsError(
        "invalid-argument",
        "rewardId is required."
      );
    }

    const db = admin.firestore();

    const userRef = db
      .collection("users")
      .doc(uid);

    try {
      const result = await db.runTransaction(
        async (transaction) => {
          const userSnapshot =
            await transaction.get(userRef);

          if (!userSnapshot.exists) {
            throw new HttpsError(
              "not-found",
              "User profile was not found."
            );
          }

          const data =
            userSnapshot.data() || {};

          const pendingRewardId = String(
            data.luckySpinPendingRewardId || ""
          ).trim();

          const pendingRewardStatus = String(
            data.luckySpinPendingRewardStatus ||
              ""
          ).trim();

          const pendingRewardKey = String(
            data.luckySpinPendingRewardKey || ""
          ).trim();

          const pendingFlowers =
            luckySpinSafeInt(
              data.luckySpinPendingFlowers
            );

          if (
            pendingRewardId !== expectedRewardId ||
            pendingRewardStatus !== "pending" ||
            pendingFlowers <= 0
          ) {
            throw new HttpsError(
              "failed-precondition",
              "REWARD_ALREADY_PROCESSED"
            );
          }

          if (
            pendingRewardKey !== "one_flower" &&
            pendingRewardKey !== "five_flowers"
          ) {
            throw new HttpsError(
              "failed-precondition",
              "INVALID_PENDING_REWARD"
            );
          }

          if (
            pendingRewardKey === "one_flower" &&
            pendingFlowers !== 1
          ) {
            throw new HttpsError(
              "failed-precondition",
              "INVALID_FLOWER_AMOUNT"
            );
          }

          if (
            pendingRewardKey === "five_flowers" &&
            pendingFlowers !== 5
          ) {
            throw new HttpsError(
              "failed-precondition",
              "INVALID_FLOWER_AMOUNT"
            );
          }

          const oldBalance =
            luckySpinSafeInt(
              data.flowerBalance
            );

          const totalBalance =
            oldBalance + pendingFlowers;

          const updateData = {
            flowerBalance:
              admin.firestore.FieldValue.increment(
                pendingFlowers
              ),

            luckySpinPendingRewardStatus:
              "claimed",

            luckySpinPendingRewardClaimedAt:
              admin.firestore.FieldValue
                .serverTimestamp(),

            luckySpinPendingFlowers: 0,
            luckySpinPendingRewardKey: "",
            luckySpinPendingRewardId: "",

            luckySpinLastClaimedFlowers:
              pendingFlowers,

            luckySpinLastClaimedRewardId:
              expectedRewardId,

            luckySpinLastClaimedAt:
              admin.firestore.FieldValue
                .serverTimestamp(),

            luckySpinUpdatedAt:
              admin.firestore.FieldValue
                .serverTimestamp(),
          };

          if (
            pendingRewardKey === "five_flowers"
          ) {
            updateData
              .luckySpinFirstRewardClaimed =
              true;

            updateData
              .luckySpinFirstRewardClaimedAt =
              admin.firestore.FieldValue
                .serverTimestamp();
          }

          transaction.set(
            userRef,
            updateData,
            {
              merge: true,
            }
          );

          return {
            success: true,
            rewardId: expectedRewardId,
            rewardKey: pendingRewardKey,
            oldBalance,
            flowersWon: pendingFlowers,
            totalBalance,
          };
        }
      );

      console.log(
        "LUCKY SPIN REWARD CLAIMED:",
        {
          uid,
          rewardId: result.rewardId,
          rewardKey: result.rewardKey,
          flowersWon: result.flowersWon,
          totalBalance: result.totalBalance,
        }
      );

      return result;
    } catch (error) {
      console.error(
        "CLAIM LUCKY SPIN REWARD ERROR:",
        {
          uid,
          rewardId: expectedRewardId,
          error,
        }
      );

      if (error instanceof HttpsError) {
        throw error;
      }

      throw new HttpsError(
        "internal",
        "Could not claim the lucky spin reward."
      );
    }
  }
);

exports.declineLuckySpinReward = onCall(
  {
    region: "us-central1",
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "You must be logged in."
      );
    }

    const uid = request.auth.uid;

    const rewardId = String(
      request.data?.rewardId || ""
    ).trim();

    if (!rewardId) {
      throw new HttpsError(
        "invalid-argument",
        "rewardId is required."
      );
    }

    const db = admin.firestore();

    const userRef = db.collection("users").doc(uid);

    try {
      await db.runTransaction(async (transaction) => {
        const snap = await transaction.get(userRef);

        if (!snap.exists) {
          throw new HttpsError(
            "not-found",
            "User not found."
          );
        }

        const data = snap.data() || {};

        if (
          String(data.luckySpinPendingRewardId || "") !== rewardId ||
          String(data.luckySpinPendingRewardStatus || "") !== "pending"
        ) {
          throw new HttpsError(
            "failed-precondition",
            "Reward already processed."
          );
        }

        transaction.set(
          userRef,
          {
            luckySpinPendingRewardStatus: "declined",

            luckySpinPendingRewardDeclinedAt:
              admin.firestore.FieldValue.serverTimestamp(),

            luckySpinPendingRewardId: "",
            luckySpinPendingRewardKey: "",
            luckySpinPendingFlowers: 0,

            luckySpinUpdatedAt:
              admin.firestore.FieldValue.serverTimestamp(),
          },
          {
            merge: true,
          }
        );
      });

      return {
        success: true,
      };
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }

      throw new HttpsError(
        "internal",
        "Could not decline reward."
      );
    }
  }
);