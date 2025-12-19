import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../models/subscription_tier.dart';
import '../../models/user_model.dart';
import '../../services/subscription_service.dart';
import '../../services/auth_service.dart';
import '../../core/services/logger_service.dart';
import '../../widgets/premium_feature_gate.dart';

/// Screen for managing subscriptions and viewing premium features
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  final AuthService _authService = AuthService();
  
  bool _isLoading = true;
  UserModel? _userModel;
  SubscriptionTier _currentTier = SubscriptionTier.free;
  SubscriptionStatus? _currentStatus;
  DateTime? _expiresAt;
  List<ProductDetails> _products = [];
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionData();
  }

  Future<void> _loadSubscriptionData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userModel = await _authService.getCurrentUserModel();
      final tier = await _subscriptionService.getCurrentTier();
      final status = await _subscriptionService.getCurrentStatus();
      final products = await _subscriptionService.getAvailableProducts();
      
      // Get expiration date from user model
      DateTime? expiresAt;
      if (userModel != null) {
        expiresAt = userModel.subscriptionExpiresAt;
      }

      setState(() {
        _userModel = userModel;
        _currentTier = tier;
        _currentStatus = status;
        _expiresAt = expiresAt;
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      Logger.error('Error loading subscription data', error: e, tag: 'SubscriptionScreen');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _purchaseProduct(ProductDetails product) async {
    setState(() {
      _isPurchasing = true;
    });

    try {
      final success = await _subscriptionService.purchaseProduct(product);
      if (success) {
        // Wait a moment for purchase to process
        await Future.delayed(const Duration(seconds: 2));
        await _loadSubscriptionData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Purchase successful! Your subscription is now active.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      Logger.error('Error purchasing product', error: e, tag: 'SubscriptionScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Purchase failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
        });
      }
    }
  }

  Future<void> _restorePurchases() async {
    setState(() {
      _isPurchasing = true;
    });

    try {
      await _subscriptionService.restorePurchases();
      await Future.delayed(const Duration(seconds: 2));
      await _loadSubscriptionData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchases restored successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      Logger.error('Error restoring purchases', error: e, tag: 'SubscriptionScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restore purchases: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription'),
        actions: [
          if (_currentTier == SubscriptionTier.premium)
            TextButton.icon(
              onPressed: _restorePurchases,
              icon: const Icon(Icons.restore),
              label: const Text('Restore'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSubscriptionData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildCurrentSubscriptionCard(),
                    const SizedBox(height: 24),
                    _buildPremiumFeaturesList(),
                    const SizedBox(height: 24),
                    if (_currentTier == SubscriptionTier.free) _buildUpgradeOptions(),
                    if (_currentTier == SubscriptionTier.premium) _buildManageSubscription(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCurrentSubscriptionCard() {
    final isPremium = _currentTier == SubscriptionTier.premium;
    final isActive = _currentStatus?.isActive ?? false;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isPremium ? Icons.star : Icons.star_border,
                  color: isPremium ? Colors.amber : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentTier.displayName,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isPremium && _currentStatus != null)
                        Text(
                          _currentStatus!.displayName,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isActive ? Colors.green : Colors.orange,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (isPremium && _expiresAt != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Expires:'),
                  Text(
                    _formatDate(_expiresAt!),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (_expiresAt!.isAfter(DateTime.now())) ...[
                const SizedBox(height: 8),
                Text(
                  '${_expiresAt!.difference(DateTime.now()).inDays} days remaining',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumFeaturesList() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Premium Features',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildFeatureItem('Extended Family Hubs', 'Connect with extended family members'),
            _buildFeatureItem('Home Schooling Hubs', 'Manage homeschooling activities and schedules'),
            _buildFeatureItem('Co-Parenting Hubs', 'Coordinate with co-parents effectively'),
            _buildFeatureItem('Encrypted Chat', 'End-to-end encrypted messaging with auto-destruct'),
            _buildFeatureItem('Priority Support', 'Get help when you need it most'),
            _buildFeatureItem('Advanced Analytics', 'Deeper insights into family activities'),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String title, String description) {
    final hasAccess = _currentTier == SubscriptionTier.premium;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            hasAccess ? Icons.check_circle : Icons.lock_outline,
            color: hasAccess ? Colors.green : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: hasAccess ? null : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeOptions() {
    if (_products.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(Icons.info_outline, size: 48, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              Text(
                'No subscription products available',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Subscription products need to be configured in Google Play Console or App Store Connect.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Upgrade to Premium',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ..._products.map((product) => _buildProductCard(product)),
      ],
    );
  }

  Widget _buildProductCard(ProductDetails product) {
    final isYearly = product.id.contains('yearly');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: _isPurchasing ? null : () => _purchaseProduct(product),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isYearly ? 'Yearly' : 'Monthly',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isYearly) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Best Value',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.price,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    if (isYearly)
                      Text(
                        'Save 20% vs monthly',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.green,
                        ),
                      ),
                  ],
                ),
              ),
              if (_isPurchasing)
                const CircularProgressIndicator()
              else
                ElevatedButton.icon(
                  onPressed: () => _purchaseProduct(product),
                  icon: const Icon(Icons.star),
                  label: const Text('Subscribe'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManageSubscription() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Manage Subscription',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _restorePurchases,
              icon: const Icon(Icons.restore),
              label: const Text('Restore Purchases'),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                // TODO: Open platform-specific subscription management
                // For Android: Open Google Play subscription management
                // For iOS: Open App Store subscription management
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Open your device\'s app store to manage your subscription'),
                  ),
                );
              },
              icon: const Icon(Icons.settings),
              label: const Text('Manage in Store'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

