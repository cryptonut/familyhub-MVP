import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/logger_service.dart';
import '../../services/hub_service.dart';
import '../../services/widget_config_service.dart' show WidgetConfigService, WidgetConfig, WidgetSize, WidgetDisplayOption;
import '../../services/widget_method_channel_service.dart';
import '../../services/ios_widget_data_service.dart';
import '../../services/auth_service.dart';
import '../../models/hub.dart';
import '../../widgets/ui_components.dart';

/// Screen for configuring home screen widgets
class WidgetConfigurationScreen extends StatefulWidget {
  final String? existingWidgetId; // If provided, edit existing widget

  const WidgetConfigurationScreen({
    super.key,
    this.existingWidgetId,
  });

  @override
  State<WidgetConfigurationScreen> createState() => _WidgetConfigurationScreenState();
}

class _WidgetConfigurationScreenState extends State<WidgetConfigurationScreen> {
  final HubService _hubService = HubService();
  final AuthService _authService = AuthService();
  WidgetConfigService? _widgetConfigService;
  String? _currentUserId;

  List<Hub> _hubs = [];
  Hub? _selectedHub;
  WidgetSize _selectedSize = WidgetSize.medium;
  final Set<WidgetDisplayOption> _selectedDisplayOptions = {
    WidgetDisplayOption.events,
    WidgetDisplayOption.messages,
  };
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeService();
    _loadData();
  }

  Future<void> _initializeService() async {
    final prefs = await SharedPreferences.getInstance();
    _widgetConfigService = WidgetConfigService(prefs);
    final userModel = await _authService.getCurrentUserModel();
    _currentUserId = userModel?.uid;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Load user's hubs
      final hubs = await _hubService.getUserHubs();
      
      // If editing existing widget, load its config
      if (widget.existingWidgetId != null && _widgetConfigService != null) {
        final config = await _widgetConfigService!.getConfig(widget.existingWidgetId!);
        if (config != null) {
          _selectedHub = hubs.firstWhere(
            (h) => h.id == config.hubId,
            orElse: () => hubs.first,
          );
          _selectedSize = config.size;
          _selectedDisplayOptions.clear();
          _selectedDisplayOptions.addAll(config.displayOptions);
        }
      }

      setState(() {
        _hubs = hubs;
        if (_selectedHub == null && hubs.isNotEmpty) {
          _selectedHub = hubs.first;
        }
        _isLoading = false;
      });
    } catch (e) {
      Logger.error('Error loading widget configuration data', error: e, tag: 'WidgetConfigurationScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfiguration() async {
    if (_selectedHub == null || _widgetConfigService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a hub'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final widgetId = widget.existingWidgetId ?? const Uuid().v4();
      
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      final config = WidgetConfig(
        widgetId: widgetId,
        hubId: _selectedHub!.id,
        hubName: _selectedHub!.name,
        hubType: _selectedHub!.hubType,
        size: _selectedSize,
        displayOptions: _selectedDisplayOptions.toList(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save to Flutter config service (SharedPreferences)
      await _widgetConfigService!.saveConfig(config);

      // Sync to iOS App Group for iOS widgets
      await IOSWidgetDataService.writeAvailableHubsToAppGroup(
        _hubs.map((h) => {'id': h.id, 'name': h.name}).toList(),
      );

      // Trigger widget update via method channel
      await WidgetMethodChannelService.updateWidget(widgetId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingWidgetId != null
                ? 'Widget configuration updated!'
                : 'Widget configuration saved! Add the widget to your home screen.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      Logger.error('Error saving widget configuration', error: e, tag: 'WidgetConfigurationScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving configuration: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildHubSelection() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Hub',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          if (_hubs.isEmpty)
            const Text('No hubs available. Create a hub first.')
          else
            DropdownButtonFormField<Hub>(
              value: _selectedHub,
              decoration: const InputDecoration(
                labelText: 'Hub',
                border: OutlineInputBorder(),
              ),
              items: _hubs.map((hub) {
                return DropdownMenuItem<Hub>(
                  value: hub,
                  child: Text(hub.name),
                );
              }).toList(),
              onChanged: (hub) {
                setState(() {
                  _selectedHub = hub;
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSizeSelection() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Widget Size',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<WidgetSize>(
            segments: [
              ButtonSegment<WidgetSize>(
                value: WidgetSize.small,
                label: const Text('Small'),
                icon: const Icon(Icons.square, size: 16),
              ),
              ButtonSegment<WidgetSize>(
                value: WidgetSize.medium,
                label: const Text('Medium'),
                icon: const Icon(Icons.rectangle, size: 16),
              ),
              ButtonSegment<WidgetSize>(
                value: WidgetSize.large,
                label: const Text('Large'),
                icon: const Icon(Icons.aspect_ratio, size: 16),
              ),
            ],
            selected: {_selectedSize},
            onSelectionChanged: (Set<WidgetSize> selection) {
              setState(() {
                _selectedSize = selection.first;
              });
            },
          ),
          const SizedBox(height: 8),
          Text(
            _getSizeDescription(_selectedSize),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }

  String _getSizeDescription(WidgetSize size) {
    switch (size) {
      case WidgetSize.small:
        return 'Shows hub name and unread message count';
      case WidgetSize.medium:
        return 'Shows hub name, upcoming events, and unread messages';
      case WidgetSize.large:
        return 'Shows hub name, upcoming events, unread messages, and pending tasks';
    }
  }

  Widget _buildDisplayOptions() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Display Options',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          ...WidgetDisplayOption.values.map((option) {
            return CheckboxListTile(
              title: Text(_getDisplayOptionLabel(option)),
              subtitle: Text(_getDisplayOptionDescription(option)),
              value: _selectedDisplayOptions.contains(option),
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) {
                    _selectedDisplayOptions.add(option);
                  } else {
                    _selectedDisplayOptions.remove(option);
                  }
                });
              },
            );
          }),
        ],
      ),
    );
  }

  String _getDisplayOptionLabel(WidgetDisplayOption option) {
    switch (option) {
      case WidgetDisplayOption.events:
        return 'Upcoming Events';
      case WidgetDisplayOption.messages:
        return 'Unread Messages';
      case WidgetDisplayOption.tasks:
        return 'Pending Tasks';
      case WidgetDisplayOption.photos:
        return 'Recent Photos';
      case WidgetDisplayOption.location:
        return 'Family Locations';
    }
  }

  String _getDisplayOptionDescription(WidgetDisplayOption option) {
    switch (option) {
      case WidgetDisplayOption.events:
        return 'Show upcoming events in the widget';
      case WidgetDisplayOption.messages:
        return 'Show unread message count';
      case WidgetDisplayOption.tasks:
        return 'Show pending tasks count';
      case WidgetDisplayOption.photos:
        return 'Show recent family photos';
      case WidgetDisplayOption.location:
        return 'Show family member locations';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingWidgetId != null
            ? 'Edit Widget'
            : 'Configure Widget'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveConfiguration,
              tooltip: 'Save Configuration',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHubSelection(),
                  const SizedBox(height: 16),
                  _buildSizeSelection(),
                  const SizedBox(height: 16),
                  _buildDisplayOptions(),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveConfiguration,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(widget.existingWidgetId != null
                        ? 'Update Widget'
                        : 'Save Configuration'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'After saving, add the widget to your home screen:\n'
                    '• Android: Long-press home screen → Widgets → Family Hub\n'
                    '• iOS: Long-press home screen → + → Family Hub',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }
}

