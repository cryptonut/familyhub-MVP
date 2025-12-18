import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

// Import subscription validation functions
import { validateGooglePlayPurchase } from "./subscription/validateGooglePlay";
import { validateAppStorePurchase } from "./subscription/validateAppStore";
import { updateSubscriptionStatus } from "./subscription/updateSubscriptionStatus";
import { checkSubscriptionExpiration } from "./subscription/checkSubscriptionExpiration";

/**
 * Validate Google Play purchase receipt
 * 
 * Expected request body:
 * {
 *   purchaseToken: string,
 *   productId: string,
 *   userId: string
 * }
 */
export const validateGooglePlayReceipt = functions.https.onCall(
  async (data, context) => {
    // Verify user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const { purchaseToken, productId, userId } = data;

    if (!purchaseToken || !productId || !userId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing required fields: purchaseToken, productId, userId"
      );
    }

    // Verify userId matches authenticated user
    if (userId !== context.auth.uid) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "User ID does not match authenticated user"
      );
    }

    try {
      const validationResult = await validateGooglePlayPurchase(
        purchaseToken,
        productId
      );

      if (validationResult.valid) {
        // Update user subscription in Firestore
        await updateSubscriptionStatus(
          userId,
          validationResult.subscriptionData
        );
      }

      return {
        valid: validationResult.valid,
        subscriptionData: validationResult.subscriptionData,
        error: validationResult.error,
      };
    } catch (error: any) {
      functions.logger.error("Error validating Google Play receipt", error);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to validate purchase",
        error.message
      );
    }
  }
);

/**
 * Validate App Store purchase receipt
 * 
 * Expected request body:
 * {
 *   receiptData: string (base64 encoded),
 *   productId: string,
 *   userId: string
 * }
 */
export const validateAppStoreReceipt = functions.https.onCall(
  async (data, context) => {
    // Verify user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const { receiptData, productId, userId } = data;

    if (!receiptData || !productId || !userId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing required fields: receiptData, productId, userId"
      );
    }

    // Verify userId matches authenticated user
    if (userId !== context.auth.uid) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "User ID does not match authenticated user"
      );
    }

    try {
      const validationResult = await validateAppStorePurchase(
        receiptData,
        productId
      );

      if (validationResult.valid) {
        // Update user subscription in Firestore
        await updateSubscriptionStatus(
          userId,
          validationResult.subscriptionData
        );
      }

      return {
        valid: validationResult.valid,
        subscriptionData: validationResult.subscriptionData,
        error: validationResult.error,
      };
    } catch (error: any) {
      functions.logger.error("Error validating App Store receipt", error);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to validate purchase",
        error.message
      );
    }
  }
);

/**
 * Periodic function to check subscription expiration
 * Runs every 6 hours
 */
export const checkSubscriptionsExpiration = functions.pubsub
  .schedule("every 6 hours")
  .onRun(async (context) => {
    try {
      await checkSubscriptionExpiration();
      return null;
    } catch (error: any) {
      functions.logger.error(
        "Error checking subscription expiration",
        error
      );
      throw error;
    }
  });

/**
 * Manual trigger to check a specific user's subscription
 * 
 * Expected request body:
 * {
 *   userId: string
 * }
 */
export const checkUserSubscription = functions.https.onCall(
  async (data, context) => {
    // Verify user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const { userId } = data;

    if (!userId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing required field: userId"
      );
    }

    // Verify userId matches authenticated user or user is admin
    if (userId !== context.auth.uid) {
      // TODO: Add admin check if needed
      throw new functions.https.HttpsError(
        "permission-denied",
        "User can only check their own subscription"
      );
    }

    try {
      await checkSubscriptionExpiration(userId);
      return { success: true };
    } catch (error: any) {
      functions.logger.error("Error checking user subscription", error);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to check subscription",
        error.message
      );
    }
  }
);

