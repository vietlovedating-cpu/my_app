const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();

async function addPromoOldUsers() {
  const usersSnapshot = await db.collection("users").get();

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

    const batch = db.batch();

    for (const groupId of groups) {
      const ref = db
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
    console.log("Added promo for user:", uid);
  }

  console.log("DONE. Total users updated:", count);
}

addPromoOldUsers().catch((e) => {
  console.error(e);
  process.exit(1);
});