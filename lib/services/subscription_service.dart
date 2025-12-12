import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter/foundation.dart';
import '../core/services/logger_service.dart';
import '../core/errors/app_exceptions.dart';
import '../models/user_model.dart';
import '../models/subscription_tier.dart';
import '../utils/firestore_path_utils.dart';
import 'auth_service.dart';

/// Service for managing user subscriptions and in-app purchases
class SubscriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  final InAppPurchase _iap = InAppPurchase.instance;
  
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  bool _isAvailable = false;
  final List<String> _productIds = [
    'premium_monthly',  // Monthly subscription
    'premium_yearly',   // Yearly subscription
  ];
  
  /// Initialize the subscription service
  Future<void> initialize() async {
    try {
      _isAvailable = await _iap.isAvailable();
      
      if (!_isAvailable) {
        Logger.warning('In-app purchases not available on this device', tag: 'SubscriptionService');
        return;
      }
      
      // Listen to purchase updates
      _purchaseSubscription = _iap.purchaseStream.listen(
        _handlePurchaseUpdates,
        onDone: () {
          Logger.debug('Purchase stream closed', tag: 'SubscriptionService');
        },
        onError: (error) {
          Logger.error('Purchase stream error', error: error, tag: 'SubscriptionService');
        },
      );
      
      Logger.info('SubscriptionService initialized', tag: 'SubscriptionService');
    } catch (e) {
      Logger.error('Error initializing SubscriptionService', error: e, tag: 'SubscriptionService');
    }
  }
  
  /// Dispose of resources
  void dispose() {
    _purchaseSubscription?.cancel();
  }
  
  /// Grant premium access for testing purposes
  /// This bypasses IAP and directly grants premium subscription
  /// Should only be used in dev/test environments
  /// 
  /// [userId] - User ID to grant access to (optional if email provided)
  /// [email] - Email address to grant access to (optional if userId provided)
  /// [premiumHubTypes] - List of premium hub types to grant access to (defaults to all)
  /// [expiresAt] - When subscription expires (defaults to 1 year from now)
  Future<void> grantPremiumAccessForTesting({
    String? userId,
    String? email,
    List<String>? premiumHubTypes,
    DateTime? expiresAt,
  }) async {
    try {
      UserModel? user;
      
      if (userId != null) {
        user = await _authService.getUserModel(userId);
      } else if (email != null) {
        // Query by email
        final query = await _firestore
            .collection(FirestorePathUtils.getUsersCollection())
            .where('email', isEqualTo: email.trim().toLowerCase())
            .limit(1)
            .get();
        
        if (query.docs.isEmpty) {
          // Try unprefixed collection
          final unprefixedQuery = await _firestore
              .collection('users')
              .where('email', isEqualTo: email.trim().toLowerCase())
              .limit(1)
              .get();
          
          if (unprefixedQuery.docs.isNotEmpty) {
            final data = unprefixedQuery.docs.first.data();
            user = UserModel.fromJson({'id': unprefixedQuery.docs.first.id, ...data});
          }
        } else {
          final data = query.docs.first.data();
          user = UserModel.fromJson({'id': query.docs.first.id, ...data});
        }
      } else {
        // Use current user
        user = await _authService.getCurrentUserModel();
      }
      
      if (user == null) {
        throw AuthException('User not found. Provide userId or email, or ensure user is logged in.', code: 'user-not-found');
      }
      
      // Set expiration to 1 year from now if not specified
      final expiration = expiresAt ?? DateTime.now().add(const Duration(days: 365));
      
      // Grant access to all premium hub types if not specified
      final hubTypes = premiumHubTypes ?? [
        'extended_family',
        'homeschooling',
        'coparenting',
      ];
      
      // Update user document in Firestore (check both prefixed and unprefixed)
      final prefixedPath = FirestorePathUtils.getUsersCollection();
      final unprefixedPath = 'users';
      
      final updateData = {
        'subscriptionTier': SubscriptionTier.premium.name,
        'subscriptionStatus': SubscriptionStatus.active.name,
        'subscriptionExpiresAt': expiration.toIso8601String(),
        'subscriptionPurchaseDate': DateTime.now().toIso8601String(),
        'premiumHubTypes': hubTypes,
        // Don't set subscriptionPlatform for test grants
      };
      
      // Try prefixed collection first
      try {
        await _firestore
            .collection(prefixedPath)
            .doc(user.uid)
            .update(updateData);
        Logger.info('Granted premium access to ${user.email} (prefixed collection)', tag: 'SubscriptionService');
      } catch (e) {
        Logger.warning('Error updating prefixed collection, trying unprefixed', error: e, tag: 'SubscriptionService');
      }
      
      // Also update unprefixed collection if different
      if (prefixedPath != unprefixedPath) {
        try {
          await _firestore
              .collection(unprefixedPath)
              .doc(user.uid)
              .update(updateData);
          Logger.info('Granted premium access to ${user.email} (unprefixed collection)', tag: 'SubscriptionService');
        } catch (e) {
          Logger.warning('Error updating unprefixed collection', error: e, tag: 'SubscriptionService');
        }
      }
      
      // Clear the cached user model so it will be refreshed on next access
      AuthService.clearUserModelCache();
      
      Logger.info('✓ Premium access granted for testing: ${user.email} (${user.uid})', tag: 'SubscriptionService');
      Logger.info('  - Tier: Premium', tag: 'SubscriptionService');
      Logger.info('  - Status: Active', tag: 'SubscriptionService');
      Logger.info('  - Expires: ${expiration.toIso8601String()}', tag: 'SubscriptionService');
      Logger.info('  - Hub Types: ${hubTypes.join(", ")}', tag: 'SubscriptionService');
      Logger.info('  - User model cache cleared - changes will be visible on next access', tag: 'SubscriptionService');
    } catch (e) {
      Logger.error('Error granting premium access for testing', error: e, tag: 'SubscriptionService');
      rethrow;
    }
  }
  
  /// Check if user has an active premium subscription
  Future<bool> hasActiveSubscription() async {
    try {
      final userModel = await _authService.getCurrentUserModel();
      if (userModel == null) return false;
      
      return userModel.hasActivePremiumSubscription();
    } catch (e) {
      Logger.error('Error checking active subscription', error: e, tag: 'SubscriptionService');
      return false;
    }
  }
  
  /// Check if user has access to a specific premium hub type
  Future<bool> hasPremiumHubAccess(String hubType) async {
    try {
      final userModel = await _authService.getCurrentUserModel();
      if (userModel == null) return false;
      
      return userModel.hasPremiumHubAccess(hubType);
    } catch (e) {
      Logger.error('Error checking premium hub access', error: e, tag: 'SubscriptionService');
      return false;
    }
  }
  
  /// Get current subscription tier
  Future<SubscriptionTier> getCurrentTier() async {
    try {
      final userModel = await _authService.getCurrentUserModel();
      if (userModel == null) return SubscriptionTier.free;
      
      return userModel.subscriptionTier ?? SubscriptionTier.free;
    } catch (e) {
      Logger.error('Error getting current tier', error: e, tag: 'SubscriptionService');
      return SubscriptionTier.free;
    }
  }
  
  /// Get current subscription status
  Future<SubscriptionStatus?> getCurrentStatus() async {
    try {
      final userModel = await _authService.getCurrentUserModel();
      if (userModel == null) return null;
      
      return userModel.subscriptionStatus;
    } catch (e) {
      Logger.error('Error getting subscription status', error: e, tag: 'SubscriptionService');
      return null;
    }
  }
  
  /// Get available products for purchase
  Future<List<ProductDetails>> getAvailableProducts() async {
    if (!_isAvailable) {
      Logger.warning('IAP not available, returning empty list', tag: 'SubscriptionService');
      return [];
    }
    
    try {
      final productDetailsResponse = await _iap.queryProductDetails(_productIds.toSet());
      
      if (productDetailsResponse.error != null) {
        Logger.error('Error querying products', error: productDetailsResponse.error, tag: 'SubscriptionService');
        return [];
      }
      
      return productDetailsResponse.productDetails;
    } catch (e) {
      Logger.error('Error getting available products', error: e, tag: 'SubscriptionService');
      return [];
    }
  }
  
  /// Purchase a subscription product
  Future<bool> purchaseProduct(ProductDetails productDetails) async {
    if (!_isAvailable) {
      throw const SubscriptionException('In-app purchases not available', code: 'iap-not-available');
    }
    
    try {
      final purchaseParam = PurchaseParam(productDetails: productDetails);
      
      if (productDetails.id.contains('monthly') || productDetails.id.contains('yearly')) {
        // Subscription purchase
        await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      } else {
        // One-time purchase
        await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      }
      
      return true;
    } catch (e) {
      Logger.error('Error purchasing product', error: e, tag: 'SubscriptionService');
      throw SubscriptionException('Failed to purchase product: ${e.toString()}', code: 'purchase-failed', originalError: e);
    }
  }
  
  /// Restore previous purchases
  Future<void> restorePurchases() async {
    if (!_isAvailable) {
      throw const SubscriptionException('In-app purchases not available', code: 'iap-not-available');
    }
    
    try {
      await _iap.restorePurchases();
      Logger.info('Restore purchases initiated', tag: 'SubscriptionService');
    } catch (e) {
      Logger.error('Error restoring purchases', error: e, tag: 'SubscriptionService');
      throw SubscriptionException('Failed to restore purchases: ${e.toString()}', code: 'restore-failed', originalError: e);
    }
  }
  
  /// Verify purchase and update user subscription
  Future<void> verifyPurchase(String purchaseToken, String platform) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw AuthException('User not authenticated', code: 'not-authenticated');
      }
      
      // TODO: Implement server-side verification
      // For now, we'll verify client-side and update Firestore
      // In production, this should verify with Google Play/App Store servers
      
      // Determine subscription tier and expiration from product ID
      final isYearly = purchaseToken.contains('yearly') || platform.contains('yearly');
      final expiresAt = DateTime.now().add(Duration(days: isYearly ? 365 : 30));
      
      // Update user model in Firestore
      await _firestore
          .collection(FirestorePathUtils.getUsersCollection())
          .doc(user.uid)
          .update({
        'subscriptionTier': SubscriptionTier.premium.name,
        'subscriptionStatus': SubscriptionStatus.active.name,
        'subscriptionExpiresAt': expiresAt.toIso8601String(),
        'subscriptionPurchaseDate': DateTime.now().toIso8601String(),
        'subscriptionPlatform': platform,
        'subscriptionPurchaseToken': purchaseToken,
      });
      
      Logger.info('Purchase verified and subscription updated', tag: 'SubscriptionService');
    } catch (e) {
      Logger.error('Error verifying purchase', error: e, tag: 'SubscriptionService');
      rethrow;
    }
  }
  
  /// Update subscription from receipt (for server-side verification)
  Future<void> updateSubscriptionFromReceipt(String receipt) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw AuthException('User not authenticated', code: 'not-authenticated');
      }
      
      // TODO: Implement server-side receipt verification
      // This should call a backend API to verify the receipt with Google Play/App Store
      // For now, this is a placeholder
      
      Logger.warning('updateSubscriptionFromReceipt not fully implemented - requires backend API', tag: 'SubscriptionService');
    } catch (e) {
      Logger.error('Error updating subscription from receipt', error: e, tag: 'SubscriptionService');
      rethrow;
    }
  }
  
  /// Handle purchase updates from the IAP stream
  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (var purchase in purchases) {
      try {
        if (purchase.status == PurchaseStatus.pending) {
          Logger.info('Purchase pending: ${purchase.productID}', tag: 'SubscriptionService');
          // Show loading indicator to user
        } else if (purchase.status == PurchaseStatus.error) {
          Logger.error('Purchase error: ${purchase.error}', error: purchase.error, tag: 'SubscriptionService');
          // Show error to user
        } else if (purchase.status == PurchaseStatus.purchased || 
                   purchase.status == PurchaseStatus.restored) {
          // Verify and process the purchase
          await _processPurchase(purchase);
          
          // Complete the purchase
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
        }
      } catch (e) {
        Logger.error('Error handling purchase update', error: e, tag: 'SubscriptionService');
      }
    }
  }
  
  /// Process a completed purchase
  Future<void> _processPurchase(PurchaseDetails purchase) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        Logger.warning('User not authenticated, cannot process purchase', tag: 'SubscriptionService');
        return;
      }
      
      // Determine platform
      final platform = Platform.isAndroid ? 'google' : 'apple';
      
      // Get purchase token
      final purchaseToken = purchase.verificationData.serverVerificationData;
      
      // Verify and update subscription
      await verifyPurchase(purchaseToken, platform);
      
      Logger.info('Purchase processed successfully: ${purchase.productID}', tag: 'SubscriptionService');
    } catch (e) {
      Logger.error('Error processing purchase', error: e, tag: 'SubscriptionService');
      rethrow;
    }
  }
  
  /// Stream of subscription status changes
  Stream<SubscriptionStatus> subscriptionStatusStream() {
    return Stream.periodic(const Duration(seconds: 30), (_) async {
      return await getCurrentStatus();
    }).asyncMap((statusFuture) => statusFuture).where((status) => status != null).cast<SubscriptionStatus>();
  }
  
  /// Check and update subscription expiration
  Future<void> checkSubscriptionExpiration() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      final userModel = await _authService.getCurrentUserModel();
      if (userModel == null) return;
      
      // Check if subscription has expired
      if (userModel.subscriptionExpiresAt != null && 
          userModel.subscriptionExpiresAt!.isBefore(DateTime.now()) &&
          userModel.subscriptionStatus == SubscriptionStatus.active) {
        
        // Update status to expired
        await _firestore
            .collection(FirestorePathUtils.getUsersCollection())
            .doc(user.uid)
            .update({
          'subscriptionStatus': SubscriptionStatus.expired.name,
        });
        
        Logger.info('Subscription expired for user ${user.uid}', tag: 'SubscriptionService');
      }
    } catch (e) {
      Logger.error('Error checking subscription expiration', error: e, tag: 'SubscriptionService');
    }
  }
  
  /// Cancel subscription (marks as cancelled, but remains active until expiry)
  Future<void> cancelSubscription() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw AuthException('User not authenticated', code: 'not-authenticated');
      }
      
      await _firestore
          .collection(FirestorePathUtils.getUsersCollection())
          .doc(user.uid)
          .update({
        'subscriptionStatus': SubscriptionStatus.cancelled.name,
      });
      
      Logger.info('Subscription cancelled for user ${user.uid}', tag: 'SubscriptionService');
    } catch (e) {
      Logger.error('Error cancelling subscription', error: e, tag: 'SubscriptionService');
      rethrow;
    }
  }
}

