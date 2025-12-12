/// Subscription tier levels for premium features
enum SubscriptionTier {
  free,      // Free tier - core family hub only
  premium,   // Premium tier - access to premium hubs and features
}

/// Subscription status
enum SubscriptionStatus {
  active,           // Subscription is active and paid
  expired,          // Subscription has expired
  cancelled,        // Subscription was cancelled (may still be active until expiry)
  pending,          // Purchase is pending verification
  gracePeriod,      // Subscription expired but in grace period
  trial,            // Free trial period
}

/// Platform where subscription was purchased
enum SubscriptionPlatform {
  google,   // Google Play Store
  apple,    // Apple App Store
}

/// Extension methods for SubscriptionTier
extension SubscriptionTierExtension on SubscriptionTier {
  /// Get display name for the tier
  String get displayName {
    switch (this) {
      case SubscriptionTier.free:
        return 'Free';
      case SubscriptionTier.premium:
        return 'Premium';
    }
  }
  
  /// Check if tier has access to premium hubs
  bool get hasPremiumHubAccess => this == SubscriptionTier.premium;
  
  /// Check if tier has access to encrypted chat
  bool get hasEncryptedChatAccess => this == SubscriptionTier.premium;
}

/// Extension methods for SubscriptionStatus
extension SubscriptionStatusExtension on SubscriptionStatus {
  /// Check if subscription is currently active (user has access)
  bool get isActive {
    switch (this) {
      case SubscriptionStatus.active:
      case SubscriptionStatus.trial:
      case SubscriptionStatus.gracePeriod:
        return true;
      case SubscriptionStatus.expired:
      case SubscriptionStatus.cancelled:
      case SubscriptionStatus.pending:
        return false;
    }
  }
  
  /// Get display name for the status
  String get displayName {
    switch (this) {
      case SubscriptionStatus.active:
        return 'Active';
      case SubscriptionStatus.expired:
        return 'Expired';
      case SubscriptionStatus.cancelled:
        return 'Cancelled';
      case SubscriptionStatus.pending:
        return 'Pending';
      case SubscriptionStatus.gracePeriod:
        return 'Grace Period';
      case SubscriptionStatus.trial:
        return 'Trial';
    }
  }
}

