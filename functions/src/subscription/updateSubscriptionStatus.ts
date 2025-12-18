import * as admin from "firebase-admin";
import * as functions from "firebase-functions";

interface SubscriptionData {
  subscriptionTier: string;
  subscriptionStatus: string;
  subscriptionExpiresAt: string | null;
  subscriptionPurchaseDate: string;
  subscriptionPlatform: string;
  premiumHubTypes: string[];
  subscriptionPurchaseToken: string;
}

/**
 * Update user subscription status in Firestore
 * 
 * @param userId - User ID
 * @param subscriptionData - Subscription data to update
 */
export async function updateSubscriptionStatus(
  userId: string,
  subscriptionData: SubscriptionData
): Promise<void> {
  try {
    const db = admin.firestore();
    
    // Update user document with subscription data
    // Check both prefixed and unprefixed collections
    const prefixedPath = `users/${userId}`;
    const unprefixedPath = `users/${userId}`;
    
    const updateData = {
      subscriptionTier: subscriptionData.subscriptionTier,
      subscriptionStatus: subscriptionData.subscriptionStatus,
      subscriptionExpiresAt: subscriptionData.subscriptionExpiresAt
        ? admin.firestore.Timestamp.fromDate(
            new Date(subscriptionData.subscriptionExpiresAt)
          )
        : null,
      subscriptionPurchaseDate: admin.firestore.Timestamp.fromDate(
        new Date(subscriptionData.subscriptionPurchaseDate)
      ),
      subscriptionPlatform: subscriptionData.subscriptionPlatform,
      premiumHubTypes: subscriptionData.premiumHubTypes,
      subscriptionPurchaseToken: subscriptionData.subscriptionPurchaseToken,
      subscriptionUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    // Try to update prefixed collection first
    try {
      await db.doc(prefixedPath).update(updateData);
      functions.logger.info(
        `Updated subscription for user ${userId} (prefixed collection)`
      );
    } catch (error: any) {
      // If prefixed collection doesn't exist, try unprefixed
      if (error.code === 5) { // NOT_FOUND
        try {
          await db.doc(unprefixedPath).update(updateData);
          functions.logger.info(
            `Updated subscription for user ${userId} (unprefixed collection)`
          );
        } catch (unprefixedError: any) {
          functions.logger.error(
            `Error updating subscription in unprefixed collection`,
            unprefixedError
          );
          throw unprefixedError;
        }
      } else {
        throw error;
      }
    }

    // Also update subscription subcollection for history
    const subscriptionDoc = {
      ...subscriptionData,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await db
      .collection(`users/${userId}/subscriptions`)
      .add(subscriptionDoc);

    functions.logger.info(`Subscription updated for user ${userId}`);
  } catch (error: any) {
    functions.logger.error(
      `Error updating subscription status for user ${userId}`,
      error
    );
    throw error;
  }
}

