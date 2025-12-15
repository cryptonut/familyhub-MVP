import 'package:flutter/material.dart';
import '../../services/extended_family_privacy_service.dart';
import '../../utils/app_theme.dart';

/// Screen for managing privacy settings in extended family hub
class PrivacySettingsScreen extends StatefulWidget {
  final String hubId;

  const PrivacySettingsScreen({
    super.key,
    required this.hubId,
  });

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  final ExtendedFamilyPrivacyService _service = ExtendedFamilyPrivacyService();
  ExtendedFamilyPrivacySettings? _settings;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final settings = await _service.getPrivacySettings(hubId: widget.hubId);
      if (mounted) {
        setState(() {
          _settings = settings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateSettings(ExtendedFamilyPrivacySettings newSettings) async {
    try {
      await _service.updatePrivacySettings(newSettings);
      if (mounted) {
        setState(() {
          _settings = newSettings;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Privacy settings updated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _settings == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Privacy Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        children: [
          _buildPrivacyLevelSelector(
            'Calendar Visibility',
            _settings!.calendarVisibility,
            (level) => _updateSettings(_settings!.copyWith(calendarVisibility: level)),
          ),
          const SizedBox(height: AppTheme.spacingMD),
          _buildPrivacyLevelSelector(
            'Photo Visibility',
            _settings!.photoVisibility,
            (level) => _updateSettings(_settings!.copyWith(photoVisibility: level)),
          ),
          const SizedBox(height: AppTheme.spacingMD),
          _buildPrivacyLevelSelector(
            'Message Visibility',
            _settings!.messageVisibility,
            (level) => _updateSettings(_settings!.copyWith(messageVisibility: level)),
          ),
          const SizedBox(height: AppTheme.spacingMD),
          _buildPrivacyLevelSelector(
            'Location Visibility',
            _settings!.locationVisibility,
            (level) => _updateSettings(_settings!.copyWith(locationVisibility: level)),
          ),
          const SizedBox(height: AppTheme.spacingLG),
          _buildToggleSetting(
            'Show Birthday',
            _settings!.showBirthday,
            (value) => _updateSettings(_settings!.copyWith(showBirthday: value)),
          ),
          _buildToggleSetting(
            'Show Phone Number',
            _settings!.showPhoneNumber,
            (value) => _updateSettings(_settings!.copyWith(showPhoneNumber: value)),
          ),
          _buildToggleSetting(
            'Show Email',
            _settings!.showEmail,
            (value) => _updateSettings(_settings!.copyWith(showEmail: value)),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyLevelSelector(
    String title,
    PrivacyLevel currentLevel,
    Function(PrivacyLevel) onChanged,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppTheme.spacingSM),
            ...PrivacyLevel.values.map((level) => RadioListTile<PrivacyLevel>(
                  title: Text(level.displayName),
                  value: level,
                  groupValue: currentLevel,
                  onChanged: (value) {
                    if (value != null) onChanged(value);
                  },
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleSetting(
    String title,
    bool value,
    Function(bool) onChanged,
  ) {
    return Card(
      child: SwitchListTile(
        title: Text(title),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

extension ExtendedFamilyPrivacySettingsCopyWith on ExtendedFamilyPrivacySettings {
  ExtendedFamilyPrivacySettings copyWith({
    String? hubId,
    String? userId,
    PrivacyLevel? calendarVisibility,
    PrivacyLevel? photoVisibility,
    PrivacyLevel? messageVisibility,
    PrivacyLevel? locationVisibility,
    bool? showBirthday,
    bool? showPhoneNumber,
    bool? showEmail,
    DateTime? updatedAt,
  }) =>
      ExtendedFamilyPrivacySettings(
        hubId: hubId ?? this.hubId,
        userId: userId ?? this.userId,
        calendarVisibility: calendarVisibility ?? this.calendarVisibility,
        photoVisibility: photoVisibility ?? this.photoVisibility,
        messageVisibility: messageVisibility ?? this.messageVisibility,
        locationVisibility: locationVisibility ?? this.locationVisibility,
        showBirthday: showBirthday ?? this.showBirthday,
        showPhoneNumber: showPhoneNumber ?? this.showPhoneNumber,
        showEmail: showEmail ?? this.showEmail,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}


