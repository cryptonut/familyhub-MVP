import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'auth_service.dart';
import '../models/hub.dart';

class SubscriptionService {
  final AuthService _authService = AuthService();
  
  // Singleton pattern
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  /// Check if the current user has an active premium subscription
  Future<bool> hasActiveSubscription() async {
    final user = await _authService.getCurrentUserModel();
    return user?.isPremium ?? false;
  }

  /// Check if the current user has access to a specific hub type
  Future<bool> hasPremiumHubAccess(HubType hubType) async {
    // Core family hub is free for everyone
    if (hubType == HubType.family) return true;
    
    final user = await _authService.getCurrentUserModel();
    if (user == null) return false;
    
    // Check global premium status
    if (user.subscriptionTier == SubscriptionTier.familyPremium && 
        user.subscriptionStatus == SubscriptionStatus.active) {
      return true;
    }
    
    // Check specific hub access
    final hubTypeString = hubType.toString().split('.').last;
    return user.premiumHubTypes.contains(hubTypeString);
  }

  /// Get the current user's subscription tier
  Future<SubscriptionTier> getCurrentTier() async {
    final user = await _authService.getCurrentUserModel();
    return user?.subscriptionTier ?? SubscriptionTier.free;
  }
  
  /// Stream of subscription status (for real-time updates)
  /// Currently just maps auth state changes to user model updates
  Stream<SubscriptionStatus> get subscriptionStatusStream {
    return _authService.authStateChanges.asyncMap((user) async {
      if (user == null) return SubscriptionStatus.none;
      final userModel = await _authService.getCurrentUserModel();
      return userModel?.subscriptionStatus ?? SubscriptionStatus.none;
    });
  }

  // TODO: Implement IAP verification and purchase flows
  Future<void> verifyPurchase(String purchaseToken, String platform) async {
    debugPrint('verifyPurchase: Not implemented yet');
  }

  Future<void> restorePurchases() async {
    debugPrint('restorePurchases: Not implemented yet');
  }
}
