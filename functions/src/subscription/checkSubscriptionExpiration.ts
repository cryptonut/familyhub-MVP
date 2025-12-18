import * as admin from "firebase-admin";
import * as functions from "firebase-functions";

/**
 * Check and update expired subscriptions
 * 
 * @param userId - Optional: Check specific user, otherwise check all users
 */
export async function checkSubscriptionExpiration(
  userId?: string
): Promise<void> {
  try {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    if (userId) {
      // Check specific user
      await checkUserSubscription(db, userId, now);
    } else {
      // Check all users with active subscriptions
      const usersRef = db.collection("users");
      const activeSubscriptions = await usersRef
        .where("subscriptionStatus", "==", "active")
        .where("subscriptionExpiresAt", "!=", null)
        .get();

      functions.logger.info(
        `Checking ${activeSubscriptions.size} active subscriptions`
      );

      const batch = db.batch();
      let batchCount = 0;

      for (const doc of activeSubscriptions.docs) {
        const userData = doc.data();
        const expiresAt = userData.subscriptionExpiresAt as admin.firestore.Timestamp;

        if (expiresAt && expiresAt.toMillis() < now.toMillis()) {
          // Subscription has expired
          batch.update(doc.ref, {
            subscriptionStatus: "expired",
            subscriptionUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          batchCount++;

          functions.logger.info(
            `Marked subscription as expired for user ${doc.id}`
          );
        }

        // Commit batch every 500 updates (Firestore limit)
        if (batchCount >= 500) {
          await batch.commit();
          batchCount = 0;
        }
      }

      if (batchCount > 0) {
        await batch.commit();
      }

      functions.logger.info(
        `Completed subscription expiration check. Updated ${batchCount} subscriptions.`
      );
    }
  } catch (error: any) {
    functions.logger.error("Error checking subscription expiration", error);
    throw error;
  }
}

/**
 * Check subscription for a specific user
 */
async function checkUserSubscription(
  db: admin.firestore.Firestore,
  userId: string,
  now: admin.firestore.Timestamp
): Promise<void> {
  try {
    // Try prefixed collection first
    let userDoc = await db.doc(`users/${userId}`).get();

    if (!userDoc.exists) {
      // Try unprefixed collection
      userDoc = await db.doc(`users/${userId}`).get();
    }

    if (!userDoc.exists) {
      functions.logger.warn(`User ${userId} not found`);
      return;
    }

    const userData = userDoc.data();
    if (!userData) return;

    const subscriptionStatus = userData.subscriptionStatus;
    const expiresAt = userData.subscriptionExpiresAt as admin.firestore.Timestamp | null;

    // Only check if subscription is active and has expiration
    if (subscriptionStatus === "active" && expiresAt) {
      if (expiresAt.toMillis() < now.toMillis()) {
        // Subscription has expired
        await userDoc.ref.update({
          subscriptionStatus: "expired",
          subscriptionUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        functions.logger.info(`Marked subscription as expired for user ${userId}`);
      }
    }
  } catch (error: any) {
    functions.logger.error(
      `Error checking subscription for user ${userId}`,
      error
    );
    throw error;
  }
}

