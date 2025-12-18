import { google } from "googleapis";
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

interface ValidationResult {
  valid: boolean;
  subscriptionData?: SubscriptionData;
  error?: string;
}

/**
 * Validate Google Play purchase receipt
 * 
 * @param purchaseToken - Purchase token from Google Play
 * @param productId - Product ID (e.g., 'premium_monthly', 'premium_yearly')
 * @returns Validation result with subscription data
 */
export async function validateGooglePlayPurchase(
  purchaseToken: string,
  productId: string
): Promise<ValidationResult> {
  try {
    // Get service account credentials from environment
    // These should be set in Firebase Functions config
    const serviceAccountEmail = functions.config().googleplay?.service_account_email;
    const privateKey = functions.config().googleplay?.private_key?.replace(/\\n/g, "\n");

    if (!serviceAccountEmail || !privateKey) {
      functions.logger.warn(
        "Google Play service account credentials not configured. " +
        "Using mock validation for development."
      );
      
      // For development: return mock validation
      return getMockValidationResult(productId, purchaseToken);
    }

    // Initialize Google Play Developer API client
    const auth = new google.auth.JWT({
      email: serviceAccountEmail,
      key: privateKey,
      scopes: ["https://www.googleapis.com/auth/androidpublisher"],
    });

    const androidpublisher = google.androidpublisher({
      version: "v3",
      auth,
    });

    // Extract package name from environment or config
    const packageName = functions.config().app?.package_name || "com.example.familyhub_mvp";

    // Verify the purchase
    const response = await androidpublisher.purchases.subscriptions.get({
      packageName,
      subscriptionId: productId,
      token: purchaseToken,
    });

    const purchase = response.data;

    if (!purchase) {
      return {
        valid: false,
        error: "Purchase not found",
      };
    }

    // Check purchase state
    // 0 = Purchased, 1 = Canceled, 2 = Pending
    if (purchase.paymentState !== 1) {
      // Payment state: 0 = Payment pending, 1 = Payment received, 2 = Free trial, 3 = Pending deferred upgrade/downgrade
      return {
        valid: false,
        error: `Purchase not active. Payment state: ${purchase.paymentState}`,
      };
    }

    // Determine subscription tier and expiration
    const isYearly = productId.includes("yearly");
    const expiresAt = purchase.expiryTimeMillis
      ? new Date(parseInt(purchase.expiryTimeMillis))
      : null;

    // Calculate purchase date (expiry - duration)
    const purchaseDate = expiresAt
      ? new Date(expiresAt.getTime() - (isYearly ? 365 : 30) * 24 * 60 * 60 * 1000)
      : new Date();

    // Determine premium hub types based on subscription
    // Premium subscription grants access to all premium hub types
    const premiumHubTypes = [
      "extended_family",
      "homeschooling",
      "coparenting",
    ];

    const subscriptionData: SubscriptionData = {
      subscriptionTier: "premium",
      subscriptionStatus: "active",
      subscriptionExpiresAt: expiresAt?.toISOString() || null,
      subscriptionPurchaseDate: purchaseDate.toISOString(),
      subscriptionPlatform: "google",
      premiumHubTypes,
      subscriptionPurchaseToken: purchaseToken,
    };

    return {
      valid: true,
      subscriptionData,
    };
  } catch (error: any) {
    functions.logger.error("Error validating Google Play purchase", error);
    
    // For development: return mock validation on error
    if (process.env.FUNCTIONS_EMULATOR) {
      functions.logger.warn("Using mock validation due to error in emulator");
      return getMockValidationResult(productId, purchaseToken);
    }

    return {
      valid: false,
      error: error.message || "Failed to validate purchase",
    };
  }
}

/**
 * Mock validation result for development/testing
 */
function getMockValidationResult(
  productId: string,
  purchaseToken: string
): ValidationResult {
  const isYearly = productId.includes("yearly");
  const expiresAt = new Date();
  expiresAt.setDate(expiresAt.getDate() + (isYearly ? 365 : 30));

  return {
    valid: true,
    subscriptionData: {
      subscriptionTier: "premium",
      subscriptionStatus: "active",
      subscriptionExpiresAt: expiresAt.toISOString(),
      subscriptionPurchaseDate: new Date().toISOString(),
      subscriptionPlatform: "google",
      premiumHubTypes: ["extended_family", "homeschooling", "coparenting"],
      subscriptionPurchaseToken: purchaseToken,
    },
  };
}

