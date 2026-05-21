const admin = require("firebase-admin");
const sgMail = require("@sendgrid/mail");

const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");

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
    schedule: "every 5 minutes",
    timeZone: "Australia/Sydney",
    region: "us-central1",
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

  const vipDiffDays = Math.ceil(
    (vipExpiresAt - now) / (1000 * 60 * 60 * 24)
  );

  if (vipDiffDays !== 7) continue;

  const fcmToken = userData.fcmToken || "";
  const isVi = userData.languageCode === "vi";

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

// 👉 GIỮ NGUYÊN CÁI NÀY
exports.verifyAppleVipPurchase = onRequest(
  { region: "us-central1" },
  async (req, res) => {
    try {
      if (req.method !== "POST") {
        res.status(405).send("Method Not Allowed");
        return;
      }

      const { userId, productId, transactionId, originalTransactionId } =
        req.body || {};

      if (!userId || !productId) {
        res.status(400).json({
          success: false,
          message: "Missing userId or productId",
        });
        return;
      }

      const allowedProductIds = new Set([
        "com.vietlove.vip.weekly",
        "com.vietlove.vip.monthly",
        "com.vietlove.vip.3months",
        "com.vietlove.vip.6months",
      ]);

      if (!allowedProductIds.has(productId)) {
        res.status(400).json({
          success: false,
          message: "Invalid productId",
        });
        return;
      }

      let vipPlanId = "unknown";
      let vipPlanTitleVi = "";
      let vipPlanTitleEn = "";
      let vipPriceTextVi = "";
      let vipPriceTextEn = "";

      if (productId === "com.vietlove.vip.weekly") {
        vipPlanId = "1_week";
        vipPlanTitleVi = "1 tuần";
        vipPlanTitleEn = "1 week";
        vipPriceTextVi = "\$14.99/tuần";
        vipPriceTextEn = "\$14.99/week";
      } else if (productId === "com.vietlove.vip.monthly") {
        vipPlanId = "1_month";
        vipPlanTitleVi = "1 tháng";
        vipPlanTitleEn = "1 month";
        vipPriceTextVi = "\$29.99/tháng";
        vipPriceTextEn = "\$29.99/month";
      } else if (productId === "com.vietlove.vip.3months") {
        vipPlanId = "3_months";
        vipPlanTitleVi = "3 tháng";
        vipPlanTitleEn = "3 mths";
        vipPriceTextVi = "\$26.66/tháng";
        vipPriceTextEn = "\$26.66/month";
      } else if (productId === "com.vietlove.vip.6months") {
        vipPlanId = "6_months";
        vipPlanTitleVi = "6 tháng";
        vipPlanTitleEn = "6 months";
        vipPriceTextVi = "\$24.99/tháng";
        vipPriceTextEn = "\$24.99/month";
      }

      await admin.firestore().collection("users").doc(userId).set(
        {
          isVip: true,
          vipUnlocked: true,
          membership: "vip",
          plan: "vip",
          subscriptionType: vipPlanId,
          vipPlanId,
          vipProductId: productId,
          vipPlatform: "app_store",
          vipStatus: "active",
          vipPlanTitleVi,
          vipPlanTitleEn,
          vipPriceTextVi,
          vipPriceTextEn,
          vipTransactionId: transactionId || "",
          vipOriginalTransactionId: originalTransactionId || "",
          vipPurchasedAt: admin.firestore.FieldValue.serverTimestamp(),
          vipUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      res.status(200).json({
        success: true,
        vipPlanId,
      });
    } catch (error) {
      console.error("verifyAppleVipPurchase error:", error);
      res.status(500).json({
        success: false,
        message: "Server error",
      });
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