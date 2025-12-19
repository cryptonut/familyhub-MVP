import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/logger_service.dart';
import '../../services/auth_service.dart';
import '../../providers/user_data_provider.dart';
import '../../models/user_model.dart';
import '../../config/config.dart';
import '../../services/subscription_service.dart';
import 'chat_screen.dart';
import 'private_chat_screen.dart';
import '../feed/feed_screen.dart';
import '../sms/sms_conversations_screen.dart';
import '../../utils/app_theme.dart';

class ChatTabsScreen extends StatefulWidget {
  const ChatTabsScreen({super.key});

  @override
  State<ChatTabsScreen> createState() => _ChatTabsScreenState();
}

class _ChatTabsScreenState extends State<ChatTabsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<UserModel> _familyMembers = [];
  UserModel? _currentUser;
  int _selectedIndex = 0;
  bool _hasPremiumAccess = false;
  bool _isCheckingPremium = true;

  @override
  void initState() {
    super.initState();
    _loadFamilyMembers();
  }

  Future<void> _loadFamilyMembers() async {
    final userProvider = Provider.of<UserDataProvider>(context, listen: false);
    await userProvider.loadUserData(forceRefresh: false);
    
    // Check premium access for SMS feature
    bool hasPremium = false;
    if (Platform.isAndroid && Config.current.enableSmsFeature) {
      try {
        final subscriptionService = SubscriptionService();
        hasPremium = await subscriptionService.hasActiveSubscription();
      } catch (e) {
        Logger.warning('Error checking premium access', error: e, tag: 'ChatTabsScreen');
        hasPremium = false;
      }
    }
    
    if (mounted) {
      setState(() {
        _currentUser = userProvider.currentUser;
        // Filter out current user from tabs - they can use "All" for group chat
        _familyMembers = userProvider.familyMembers
            .where((member) => member.uid != _currentUser?.uid)
            .toList();
        
        _hasPremiumAccess = hasPremium;
        _isCheckingPremium = false;
        
        // Calculate tab length: "All" + family members + SMS (if Android, enabled, and premium)
        int tabLength = 1 + _familyMembers.length;
        if (Platform.isAndroid && Config.current.enableSmsFeature && hasPremium) {
          tabLength += 1; // Add SMS tab
        }
        
        // Initialize tab controller
        _tabController = TabController(
          length: tabLength,
          vsync: this,
          initialIndex: 0,
        );
        
        _tabController.addListener(() {
          if (_tabController.indexIsChanging) {
            setState(() {
              _selectedIndex = _tabController.index;
            });
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildAvatar(UserModel? member, {bool isAll = false}) {
    if (isAll) {
      // "All" tab - show group icon
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.purple.shade700,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.group,
          color: Colors.white,
          size: 14,
        ),
      );
    }
    
    if (member == null) return const SizedBox.shrink();
    
    // Show photo if available, otherwise initials
    if (member.photoUrl != null && member.photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 12,
        backgroundImage: NetworkImage(member.photoUrl!),
        onBackgroundImageError: (_, __) {
          // Fallback handled by child widget
        },
        child: member.photoUrl == null || member.photoUrl!.isEmpty
            ? Text(
                member.displayName.isNotEmpty
                    ? member.displayName[0].toUpperCase()
                    : member.email.isNotEmpty
                        ? member.email[0].toUpperCase()
                        : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      );
    }
    
    // Fallback to initials
    return CircleAvatar(
      radius: 12,
      backgroundColor: Colors.purple.shade700,
      child: Text(
        member.displayName.isNotEmpty
            ? member.displayName[0].toUpperCase()
            : member.email.isNotEmpty
                ? member.email[0].toUpperCase()
                : '?',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_familyMembers.isEmpty || _isCheckingPremium) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Family Chat'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Chat'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            // "All" tab
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAvatar(null, isAll: true),
                  const SizedBox(width: 8),
                  const Text('All'),
                ],
              ),
            ),
            // Family member tabs (current user excluded - they use "All")
            ..._familyMembers.map((member) {
              return Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildAvatar(member),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        member.displayName.isNotEmpty
                            ? member.displayName
                            : member.email.split('@')[0],
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }),
            // SMS tab (Android only, if enabled, and user has premium)
            if (Platform.isAndroid && Config.current.enableSmsFeature && _hasPremiumAccess)
              const Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sms, size: 20),
                    SizedBox(width: 8),
                    Text('SMS'),
                  ],
                ),
              ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // "All" tab - shows FEED (not bubbles)
          const FeedScreen(),
          // Individual member tabs - shows private chat (bubble style)
          ..._familyMembers.map((member) {
            return PrivateChatScreen(
              recipientId: member.uid,
              recipientName: member.displayName.isNotEmpty
                  ? member.displayName
                  : member.email.split('@')[0],
            );
          }),
          // SMS tab (Android only, if enabled, and user has premium)
          if (Platform.isAndroid && Config.current.enableSmsFeature && _hasPremiumAccess)
            const SmsConversationsScreen(),
        ],
      ),
    );
  }
}

