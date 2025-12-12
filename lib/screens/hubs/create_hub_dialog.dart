import 'package:flutter/material.dart';
import '../../models/hub.dart';
import '../../screens/subscription/subscription_screen.dart';
import '../../services/hub_service.dart';
import '../../services/subscription_service.dart';
import '../../services/auth_service.dart';

class CreateHubDialog extends StatefulWidget {
  const CreateHubDialog({super.key});

  @override
  State<CreateHubDialog> createState() => _CreateHubDialogState();
}

class _CreateHubDialogState extends State<CreateHubDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _hubService = HubService();
  final SubscriptionService _subscriptionService = SubscriptionService();
  String? _selectedIcon;
  HubType _selectedHubType = HubType.family;
  bool _isCreating = false;
  bool _hasPremiumAccess = false;

  final List<Map<String, dynamic>> _icons = [
    {'value': 'people', 'icon': Icons.people, 'label': 'People'},
    {'value': 'sports', 'icon': Icons.sports_soccer, 'label': 'Sports'},
    {'value': 'work', 'icon': Icons.work, 'label': 'Work'},
    {'value': 'school', 'icon': Icons.school, 'label': 'School'},
    {'value': null, 'icon': Icons.group, 'label': 'Default'},
  ];

  @override
  void initState() {
    super.initState();
    _checkPremiumAccess();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh premium access check when dialog is opened (in case it was just granted)
    _checkPremiumAccess();
  }

  Future<void> _checkPremiumAccess({bool forceRefresh = false}) async {
    try {
      // If forcing refresh, clear cache first
      if (forceRefresh) {
        AuthService.clearUserModelCache();
      }
      final hasAccess = await _subscriptionService.hasActiveSubscription();
      if (mounted) {
        setState(() {
          _hasPremiumAccess = hasAccess;
        });
      }
    } catch (e) {
      // Ignore errors, default to false
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createHub() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreating = true);

    try {
      final hub = await _hubService.createHub(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        icon: _selectedIcon,
        hubType: _selectedHubType,
      );

      if (mounted) {
        Navigator.pop(context, hub);
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Error creating hub: $e';
        if (e.toString().contains('premium-required') || 
            e.toString().contains('Premium hub access required')) {
          errorMessage = 'Premium subscription required for Extended Family Hubs. Would you like to view subscription options?';
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'View Options',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SubscriptionScreen(),
                    ),
                  );
                },
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Hub'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Hub Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a hub name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              const Text(
                'Hub Type:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildHubTypeSelector(),
              const SizedBox(height: 16),
              const Text(
                'Icon:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _icons.map((iconData) {
                  final isSelected = _selectedIcon == iconData['value'];
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedIcon = iconData['value'] as String?;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).primaryColor.withOpacity(0.1)
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            iconData['icon'] as IconData,
                            color: isSelected
                                ? Theme.of(context).primaryColor
                                : Colors.grey[700],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            iconData['label'] as String,
                            style: TextStyle(
                              fontSize: 10,
                              color: isSelected
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isCreating ? null : _createHub,
          child: _isCreating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  Widget _buildHubTypeSelector() {
    return Column(
      children: [
        _buildHubTypeOption(
          HubType.family,
          'Family Hub',
          'Your core family hub (free)',
          Icons.family_restroom,
          Colors.blue,
          isFree: true,
        ),
        const SizedBox(height: 8),
        _buildHubTypeOption(
          HubType.extendedFamily,
          'Extended Family Hub',
          'Connect with grandparents, aunts, uncles, cousins (premium)',
          Icons.people_outline,
          Colors.purple,
          isPremium: true,
        ),
      ],
    );
  }

  Widget _buildHubTypeOption(
    HubType hubType,
    String title,
    String description,
    IconData icon,
    Color color, {
    bool isFree = false,
    bool isPremium = false,
  }) {
    final isSelected = _selectedHubType == hubType;
    final isDisabled = isPremium && !_hasPremiumAccess;

    return InkWell(
      onTap: isDisabled
          ? () {
              // Show upgrade prompt
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Premium Feature'),
                  content: Text(
                    '$title requires a premium subscription. Would you like to view subscription options?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SubscriptionScreen(),
                          ),
                        );
                      },
                      child: const Text('View Options'),
                    ),
                  ],
                ),
              );
            }
          : () {
              setState(() {
                _selectedHubType = hubType;
              });
            },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(icon, color: isDisabled ? Colors.grey : color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDisabled ? Colors.grey : null,
                        ),
                      ),
                      if (isFree) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'FREE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      if (isPremium) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.workspace_premium,
                          size: 16,
                          color: isDisabled ? Colors.grey : Colors.amber,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDisabled ? Colors.grey : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: color)
            else
              Icon(Icons.radio_button_unchecked, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

