import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/logger_service.dart';
import '../../services/auth_service.dart';

class FamilyInvitationScreen extends StatefulWidget {
  const FamilyInvitationScreen({super.key});

  @override
  State<FamilyInvitationScreen> createState() => _FamilyInvitationScreenState();
}

class _FamilyInvitationScreenState extends State<FamilyInvitationScreen> {
  String? _invitationCode;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvitationCode();
  }

  Future<void> _loadInvitationCode() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    try {
      // First try to get existing code
      String? code = await authService.getFamilyInvitationCode();
      
      if (code == null || code.isEmpty) {
        // If null, try to initialize it
        try {
          await authService.initializeFamilyId();
          code = await authService.getFamilyInvitationCode();
        } catch (e) {
          // If initialize fails, try force initialize
          Logger.warning('Initialize failed, trying force initialize', error: e, tag: 'FamilyInvitationScreen');
          code = await authService.forceInitializeFamilyId();
        }
      }
      
      setState(() {
        _invitationCode = code;
        _isLoading = false;
      });
      
      if (_invitationCode != null && _invitationCode!.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Family invitation code ready!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else if (mounted) {
        // If still null after retry, show error with option to force fix
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Unable to generate invitation code.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Fix Now',
              textColor: Colors.white,
              onPressed: () async {
                try {
                  final fixedCode = await authService.forceInitializeFamilyId();
                  setState(() {
                    _invitationCode = fixedCode;
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Family ID created successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      Logger.error('Error in _loadInvitationCode', error: e, tag: 'FamilyInvitationScreen');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading invitation code: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                _loadInvitationCode();
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _copyToClipboard() async {
    if (_invitationCode != null) {
      await Clipboard.setData(ClipboardData(text: _invitationCode!));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invitation code copied to clipboard!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _shareInvitation() async {
    if (_invitationCode == null) return;
    
    // For web, we'll show a dialog with the code
    // For mobile, you could use the share package
    if (mounted) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Share Invitation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Share this invitation code with family members:'),
              const SizedBox(height: 16),
              SelectableText(
                _invitationCode!,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'They can join your family by entering this code in the "Join Family" screen.',
                style: TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                _copyToClipboard();
                Navigator.pop(context);
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy Code'),
            ),
          ],
        ),
      );
    }
  }
  
  Future<void> _sendEmailInvitation() async {
    if (_invitationCode == null) return;
    
    // Get the current URL (for web) or construct invitation link
    String invitationLink;
    if (kIsWeb) {
      // For web, use the current origin + invitation parameter
      final uri = Uri.base;
      invitationLink = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}/?invite=${_invitationCode!}';
    } else {
      // For mobile, use a custom URL scheme or web link
      // You can configure this based on your app's deep linking setup
      invitationLink = 'https://familyhub.app/join?code=${_invitationCode!}';
    }
    
    final subject = 'Join my Family Hub!';
    final body = '''Hi!

I'd like to invite you to join my Family Hub. Family Hub helps us organize our family activities, share tasks, chat, and more!

To join my family, click the link below:
$invitationLink

Or enter this invitation code manually: $_invitationCode

Looking forward to having you in our family hub!

Best regards''';

    final emailUri = Uri(
      scheme: 'mailto',
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email client opened'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Fallback: show dialog with email content
        if (mounted) {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Email Invitation'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Copy this email content:'),
                    const SizedBox(height: 16),
                    SelectableText(
                      'Subject: $subject\n\n$body',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: body));
                    Navigator.pop(context);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Email content copied to clipboard'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy Email'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening email: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Invitation'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _invitationCode == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        const Text(
                          'No family invitation code available',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Unable to load or create a family invitation code.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: () async {
                            setState(() {
                              _isLoading = true;
                            });
                            try {
                              final authService = Provider.of<AuthService>(context, listen: false);
                              final fixedCode = await authService.forceInitializeFamilyId();
                              setState(() {
                                _invitationCode = fixedCode;
                                _isLoading = false;
                              });
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Family ID created successfully!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              setState(() {
                                _isLoading = false;
                              });
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: $e'),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 5),
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.build),
                          label: const Text('Create Family ID'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _loadInvitationCode,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.group_add,
                        size: 80,
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Invite Family Members',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Share this invitation code with your family members so they can join your family hub.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.blue, width: 2),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Your Family Invitation Code',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SelectableText(
                              _invitationCode!,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 4,
                                fontFamily: 'monospace',
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: _sendEmailInvitation,
                        icon: const Icon(Icons.email),
                        label: const Text('Send Email Invitation'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 16),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _copyToClipboard,
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy Code'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _shareInvitation,
                        icon: const Icon(Icons.share),
                        label: const Text('Share Invitation'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.info_outline, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text(
                                    'How to invite',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                '1. Share the invitation code above with your family members\n'
                                '2. They should open the app and go to "Join Family"\n'
                                '3. They enter the code to join your family\n'
                                '4. Once joined, they\'ll have access to all family features',
                                style: TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

