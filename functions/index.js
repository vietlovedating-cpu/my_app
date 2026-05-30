const admin = require("firebase-admin");
const sgMail = require("@sendgrid/mail");
const jwt = require("jsonwebtoken");
const axios = require("axios");

const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const APPLE_KEY_ID = "5Y96FGHGP6";
const APPLE_ISSUER_ID = "6cd61427-575e-490b-99c4-79302d8872f8";
const APPLE_BUNDLE_ID = "com.vietlovedating.app";

admin.initializeApp();

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

exports.checkMemberships = onSchedule(
  {
    schedule: "every 24 hours",
    timeZone: "Australia/Sydney",
    region: "us-central1",
    timeoutSeconds: 540,
    memory: "512MiB",
  },
  async () => {
    const now = new Date();

    const snapshot = await admin.firestore().collectionGroup("members").get();

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
// 👉 DÁN FUNCTION MỚI Ở ĐÂY
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
      vipPriceTextVi: "$14.99/tuần",
      vipPriceTextEn: "$14.99/week",
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
      vipPriceTextVi: "$24.99/tháng",
      vipPriceTextEn: "$24.99/month",
    };
  }

  return null;
}

function getGroupPlanFromProductId(productId) {
  if (productId === "group.weekend_coffee.monthly.v2") {
    return {
      groupId: "weekend_coffee",
      planType: "1_month",
      price: 24.99,
      currency: "AUD",
      groupTitleEn: "Weekend Coffee",
      groupTitleVi: "Cà phê cuối tuần",
    };
  }

  if (productId === "group.hiking_camping.monthly") {
    return {
      groupId: "hiking_camping",
      planType: "1_month",
      price: 24.99,
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
      price: 24.99,
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