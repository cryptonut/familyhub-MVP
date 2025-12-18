import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/sms_conversation.dart';
import '../../services/sms_service.dart';
import '../../services/sms_permission_service.dart';
import '../../services/contact_sync_service.dart';
import '../../widgets/premium_feature_gate.dart';
import '../../widgets/sms_conversation_tile.dart';
import '../../widgets/sms_permission_request_dialog.dart';
import '../../widgets/ui_components.dart';
import '../../utils/app_theme.dart';
import '../../config/config.dart';
import 'sms_conversation_screen.dart';
import 'compose_sms_screen.dart';

/// Main SMS conversations list screen (Android only, Premium feature)
class SmsConversationsScreen extends StatefulWidget {
  const SmsConversationsScreen({super.key});

  @override
  State<SmsConversationsScreen> createState() => _SmsConversationsScreenState();
}

class _SmsConversationsScreenState extends State<SmsConversationsScreen> {
  final SmsService _smsService = SmsService();
  final SmsPermissionService _permissionService = SmsPermissionService();
  final ContactSyncService _contactService = ContactSyncService();
  
  List<SmsConversation> _conversations = [];
  bool _isLoading = true;
  bool _hasPermissions = false;
  String? _searchQuery;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid && Config.current.enableSmsFeature) {
      _initialize();
    }
  }

  Future<void> _initialize() async {
    // Check permissions
    final hasPermissions = await _permissionService.hasAllPermissions();
    setState(() {
      _hasPermissions = hasPermissions;
    });

    if (!hasPermissions) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Initialize SMS service
    await _smsService.initialize();
    
    // Load conversations
    await _loadConversations();
  }

  Future<void> _loadConversations() async {
    if (!Platform.isAndroid) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final conversations = await _smsService.getSmsConversations();
      setState(() {
        _conversations = conversations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading conversations: $e')),
        );
      }
    }
  }

  Future<void> _requestPermissions() async {
    final granted = await _permissionService.requestSmsPermissions();
    if (granted) {
      final contactGranted = await _permissionService.requestContactPermissions();
      if (contactGranted) {
        setState(() {
          _hasPermissions = true;
        });
        await _initialize();
      }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => SmsPermissionRequestDialog(
        onRequest: () async {
          await _requestPermissions();
        },
      ),
    );
  }

  List<SmsConversation> get _filteredConversations {
    if (_searchQuery == null || _searchQuery!.isEmpty) {
      return _conversations;
    }
    
    final query = _searchQuery!.toLowerCase();
    return _conversations.where((conv) {
      final name = (conv.contactName ?? conv.phoneNumber).toLowerCase();
      final phone = conv.phoneNumber.toLowerCase();
      return name.contains(query) || phone.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Platform check - hide on iOS
    if (!Platform.isAndroid) {
      return Scaffold(
        appBar: AppBar(title: const Text('SMS')),
        body: const Center(
          child: Text('SMS feature is only available on Android devices'),
        ),
      );
    }

    // Feature flag check
    if (!Config.current.enableSmsFeature) {
      return Scaffold(
        appBar: AppBar(title: const Text('SMS')),
        body: const Center(
          child: Text('SMS feature is not enabled'),
        ),
      );
    }

    return PremiumFeatureGate(
      featureName: 'SMS Messaging',
      customMessage: 'Upgrade to Premium to send and receive SMS messages from within the app.',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('SMS'),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                // TODO: Implement search
              },
            ),
          ],
        ),
        body: _buildBody(),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const ComposeSmsScreen(),
              ),
            );
          },
          child: const Icon(Icons.message),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (!_hasPermissions) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingXL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sms, size: 64, color: Colors.grey),
              const SizedBox(height: AppTheme.spacingLG),
              const Text(
                'SMS Permissions Required',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppTheme.spacingMD),
              const Text(
                'To use SMS messaging, we need permission to send and receive SMS messages.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacingXL),
              ElevatedButton.icon(
                onPressed: _showPermissionDialog,
                icon: const Icon(Icons.lock_open),
                label: const Text('Grant Permissions'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredConversations.isEmpty) {
      return EmptyState(
        icon: Icons.sms_outlined,
        title: 'No SMS conversations',
        message: 'Start a new conversation to begin messaging',
        action: ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const ComposeSmsScreen(),
              ),
            );
          },
          icon: const Icon(Icons.message),
          label: const Text('New Message'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadConversations,
      child: ListView.builder(
        itemCount: _filteredConversations.length,
        itemBuilder: (context, index) {
          final conversation = _filteredConversations[index];
          return SmsConversationTile(
            conversation: conversation,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SmsConversationScreen(
                    phoneNumber: conversation.phoneNumber,
                    contactName: conversation.contactName,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

