import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/sms_service.dart';
import '../../services/contact_sync_service.dart';
import '../../models/sms_contact.dart';
import '../../utils/phone_number_utils.dart';
import '../../utils/app_theme.dart';
import 'sms_conversation_screen.dart';

/// Compose new SMS screen (Android only)
class ComposeSmsScreen extends StatefulWidget {
  final String? initialPhoneNumber;
  final String? initialMessage;

  const ComposeSmsScreen({
    super.key,
    this.initialPhoneNumber,
    this.initialMessage,
  });

  @override
  State<ComposeSmsScreen> createState() => _ComposeSmsScreenState();
}

class _ComposeSmsScreenState extends State<ComposeSmsScreen> {
  final SmsService _smsService = SmsService();
  final ContactSyncService _contactService = ContactSyncService();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _messageFocus = FocusNode();
  
  List<SmsContact> _contacts = [];
  List<SmsContact> _filteredContacts = [];
  bool _isLoadingContacts = false;
  bool _isSending = false;
  String? _selectedContactName;

  @override
  void initState() {
    super.initState();
    if (widget.initialPhoneNumber != null) {
      _phoneController.text = widget.initialPhoneNumber!;
    }
    if (widget.initialMessage != null) {
      _messageController.text = widget.initialMessage!;
    }
    
    if (Platform.isAndroid) {
      _loadContacts();
    }
    
    _phoneController.addListener(_onPhoneChanged);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _messageController.dispose();
    _phoneFocus.dispose();
    _messageFocus.dispose();
    super.dispose();
  }

  void _onPhoneChanged() {
    final phone = _phoneController.text;
    if (phone.isNotEmpty) {
      // Format phone number as user types
      final formatted = PhoneNumberUtils.formatPhoneNumber(phone);
      if (formatted != phone && formatted.isNotEmpty) {
        // Don't update if it would cause cursor issues
        // Just validate
      }
      
      // Search contacts
      _filterContacts(phone);
    } else {
      setState(() {
        _filteredContacts = _contacts;
        _selectedContactName = null;
      });
    }
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoadingContacts = true;
    });

    try {
      final contacts = await _contactService.syncDeviceContacts();
      setState(() {
        _contacts = contacts;
        _filteredContacts = contacts;
        _isLoadingContacts = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingContacts = false;
      });
    }
  }

  void _filterContacts(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredContacts = _contacts;
      });
      return;
    }

    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredContacts = _contacts.where((contact) {
        final name = contact.displayName.toLowerCase();
        final phone = contact.phoneNumber.toLowerCase();
        return name.contains(lowerQuery) || phone.contains(lowerQuery);
      }).toList();
    });
  }

  void _selectContact(SmsContact contact) {
    setState(() {
      _phoneController.text = contact.phoneNumber;
      _selectedContactName = contact.displayName;
      _filteredContacts = [];
    });
    _messageFocus.requestFocus();
  }

  Future<void> _sendSms() async {
    final phoneNumber = _phoneController.text.trim();
    final message = _messageController.text.trim();

    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a phone number')),
      );
      return;
    }

    if (!PhoneNumberUtils.validatePhoneNumber(phoneNumber)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid phone number')),
      );
      return;
    }

    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message')),
      );
      return;
    }

    if (_isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      final normalizedPhone = PhoneNumberUtils.normalizePhoneNumber(phoneNumber);
      if (normalizedPhone == null) {
        throw Exception('Invalid phone number');
      }

      final success = await _smsService.sendSms(normalizedPhone, message);
      if (success && mounted) {
        // Navigate to conversation screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => SmsConversationScreen(
              phoneNumber: normalizedPhone,
              contactName: _selectedContactName,
            ),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) {
      return Scaffold(
        appBar: AppBar(title: const Text('Compose SMS')),
        body: const Center(
          child: Text('SMS feature is only available on Android devices'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Message'),
      ),
      body: Column(
        children: [
          // Phone number input
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'To',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _phoneController,
                  focusNode: _phoneFocus,
                  decoration: InputDecoration(
                    hintText: 'Phone number',
                    prefixIcon: const Icon(Icons.phone),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    ),
                  ),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _messageFocus.requestFocus(),
                ),
                if (_selectedContactName != null) ...[
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(_selectedContactName!),
                    onDeleted: () {
                      setState(() {
                        _selectedContactName = null;
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
          
          // Contact suggestions
          if (_filteredContacts.isNotEmpty && _phoneController.text.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _filteredContacts.length,
                itemBuilder: (context, index) {
                  final contact = _filteredContacts[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(contact.displayName[0].toUpperCase()),
                    ),
                    title: Text(contact.displayName),
                    subtitle: Text(contact.phoneNumber),
                    onTap: () => _selectContact(contact),
                  );
                },
              ),
            ),
          
          // Message input
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Message',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _messageController,
                  focusNode: _messageFocus,
                  decoration: InputDecoration(
                    hintText: 'Type your message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    ),
                  ),
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSending ? null : _sendSms,
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(_isSending ? 'Sending...' : 'Send'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

