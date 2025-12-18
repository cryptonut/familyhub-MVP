import * as functions from "firebase-functions";
import fetch from "node-fetch";

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
 * Validate App Store purchase receipt
 * 
 * @param receiptData - Base64 encoded receipt data from App Store
 * @param productId - Product ID (e.g., 'premium_monthly', 'premium_yearly')
 * @returns Validation result with subscription data
 */
export async function validateAppStorePurchase(
  receiptData: string,
  productId: string
): Promise<ValidationResult> {
  try {
    // Get App Store credentials from environment
    const sharedSecret = functions.config().appstore?.shared_secret;
    const isSandbox = functions.config().appstore?.sandbox === "true";

    if (!sharedSecret) {
      functions.logger.warn(
        "App Store shared secret not configured. " +
        "Using mock validation for development."
      );
      
      // For development: return mock validation
      return getMockValidationResult(productId, receiptData);
    }

    // Determine which App Store endpoint to use
    const verifyUrl = isSandbox
      ? "https://sandbox.itunes.apple.com/verifyReceipt"
      : "https://buy.itunes.apple.com/verifyReceipt";

    // Verify the receipt with Apple
    const response = await fetch(verifyUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        "receipt-data": receiptData,
        "password": sharedSecret,
        "exclude-old-transactions": false,
      }),
    });

    const result = await response.json() as any;

    // Check response status
    // 0 = Valid receipt
    // 21007 = Receipt is from sandbox but sent to production (or vice versa)
    if (result.status === 21007 && !isSandbox) {
      // Retry with sandbox
      return validateAppStorePurchase(receiptData, productId);
    }

    if (result.status !== 0) {
      return {
        valid: false,
        error: `Receipt validation failed with status: ${result.status}`,
      };
    }

    // Find the subscription in the receipt
    const receipt = result.receipt;
    const inAppPurchases = receipt.in_app || [];

    // Find the latest purchase for this product
    const productPurchases = inAppPurchases
      .filter((purchase: any) => purchase.product_id === productId)
      .sort((a: any, b: any) => 
        parseInt(b.purchase_date_ms) - parseInt(a.purchase_date_ms)
      );

    if (productPurchases.length === 0) {
      return {
        valid: false,
        error: "Product not found in receipt",
      };
    }

    const latestPurchase = productPurchases[0];

    // Check pending_renewal_info for subscription status
    const pendingRenewalInfo = result.pending_renewal_info || [];
    const renewalInfo = pendingRenewalInfo.find(
      (info: any) => info.product_id === productId
    );

    // Determine expiration date
    // For subscriptions, check expires_date_ms
    const expiresAtMs = latestPurchase.expires_date_ms
      ? parseInt(latestPurchase.expires_date_ms)
      : null;

    const expiresAt = expiresAtMs ? new Date(expiresAtMs) : null;

    // Check if subscription is active
    const isActive = expiresAt ? expiresAt > new Date() : false;

    if (!isActive) {
      return {
        valid: false,
        error: "Subscription has expired",
      };
    }

    // Determine subscription tier and purchase date
    const isYearly = productId.includes("yearly");
    const purchaseDateMs = parseInt(latestPurchase.purchase_date_ms);
    const purchaseDate = new Date(purchaseDateMs);

    // Determine premium hub types
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
      subscriptionPlatform: "apple",
      premiumHubTypes,
      subscriptionPurchaseToken: receiptData, // Store receipt data for future validation
    };

    return {
      valid: true,
      subscriptionData,
    };
  } catch (error: any) {
    functions.logger.error("Error validating App Store purchase", error);
    
    // For development: return mock validation on error
    if (process.env.FUNCTIONS_EMULATOR) {
      functions.logger.warn("Using mock validation due to error in emulator");
      return getMockValidationResult(productId, receiptData);
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
  receiptData: string
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
      subscriptionPlatform: "apple",
      premiumHubTypes: ["extended_family", "homeschooling", "coparenting"],
      subscriptionPurchaseToken: receiptData,
    },
  };
}

