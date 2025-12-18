import 'package:flutter/material.dart';
import '../../services/sms_service.dart';

class SmsSettingsScreen extends StatefulWidget {
  const SmsSettingsScreen({super.key});

  @override
  State<SmsSettingsScreen> createState() => _SmsSettingsScreenState();
}

class _SmsSettingsScreenState extends State<SmsSettingsScreen> {
  final SmsService _smsService = SmsService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SMS Sync Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Sync SMS Messages'),
            subtitle: const Text('View and send device SMS messages in Family Chat'),
            value: _smsService.isSmsEnabled,
            onChanged: _isLoading ? null : (value) async {
              setState(() => _isLoading = true);
              try {
                await _smsService.setSmsEnabled(value);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              } finally {
                if (mounted) {
                  setState(() => _isLoading = false);
                }
              }
            },
          ),
          if (_smsService.isSmsEnabled)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'SMS messages will appear in your main chat feed. They are visible only to you unless you share them.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          
          // Debug info or other settings
          if (_smsService.isSmsEnabled)
            ListTile(
              title: const Text('Refresh Messages'),
              trailing: const Icon(Icons.refresh),
              onTap: () {
                // Trigger refresh if possible, or just show info
                 ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Messages will refresh automatically')),
                );
              },
            ),
        ],
      ),
    );
  }
}
