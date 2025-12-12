import 'package:flutter/material.dart';
import '../models/subscription_tier.dart';
import '../services/subscription_service.dart';
import '../services/auth_service.dart';
import '../config/config.dart';

/// Widget that gates premium features based on subscription status
/// 
/// Shows [child] if user has access, otherwise shows [fallback] or upgrade prompt
class PremiumFeatureGate extends StatefulWidget {
  /// The widget to show if user has premium access
  final Widget child;
  
  /// The widget to show if user doesn't have premium access
  /// If null, shows default upgrade prompt
  final Widget? fallback;
  
  /// Optional: Specific premium hub type required (e.g., 'extended_family')
  /// If null, checks for any premium subscription
  final String? requiredHubType;
  
  /// Optional: Feature name to display in upgrade prompt
  final String? featureName;
  
  /// Optional: Custom message to show in upgrade prompt
  final String? customMessage;
  
  /// Show loading indicator while checking subscription
  final bool showLoading;
  
  const PremiumFeatureGate({
    super.key,
    required this.child,
    this.fallback,
    this.requiredHubType,
    this.featureName,
    this.customMessage,
    this.showLoading = true,
  });

  @override
  State<PremiumFeatureGate> createState() => _PremiumFeatureGateState();
}

class _PremiumFeatureGateState extends State<PremiumFeatureGate> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  bool _hasAccess = false;
  SubscriptionTier _currentTier = SubscriptionTier.free;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    try {
      final userModel = await _authService.getCurrentUserModel();
      if (userModel == null) {
        setState(() {
          _hasAccess = false;
          _isLoading = false;
        });
        return;
      }

      // Check if premium features are enabled in config
      if (!Config.current.enablePremiumHubs) {
        setState(() {
          _hasAccess = false;
          _isLoading = false;
        });
        return;
      }

      // Check subscription access
      bool hasAccess;
      if (widget.requiredHubType != null) {
        hasAccess = await _subscriptionService.hasPremiumHubAccess(widget.requiredHubType!);
      } else {
        hasAccess = await _subscriptionService.hasActiveSubscription();
      }

      final tier = await _subscriptionService.getCurrentTier();

      setState(() {
        _hasAccess = hasAccess;
        _currentTier = tier;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasAccess = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && widget.showLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_hasAccess) {
      return widget.child;
    }

    // Show custom fallback if provided
    if (widget.fallback != null) {
      return widget.fallback!;
    }

    // Show default upgrade prompt
    return _buildUpgradePrompt(context);
  }

  Widget _buildUpgradePrompt(BuildContext context) {
    final featureName = widget.featureName ?? 'this premium feature';
    final message = widget.customMessage ?? 
        'Upgrade to Premium to access $featureName and unlock all premium hubs and features.';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_outline,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Premium Feature',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to subscription screen
              // TODO: Navigate to subscription screen when implemented
              Navigator.of(context).pushNamed('/subscription');
            },
            icon: const Icon(Icons.star),
            label: const Text('Upgrade to Premium'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Maybe Later'),
          ),
        ],
      ),
    );
  }
}

/// Widget that conditionally shows content based on subscription tier
class SubscriptionTierGate extends StatelessWidget {
  /// Minimum tier required to see [child]
  final SubscriptionTier requiredTier;
  
  /// Widget to show if tier requirement is met
  final Widget child;
  
  /// Widget to show if tier requirement is not met
  final Widget? fallback;
  
  const SubscriptionTierGate({
    super.key,
    required this.requiredTier,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    // This would need to check subscription tier
    // For now, return child (can be enhanced with SubscriptionService)
    return child;
  }
}

