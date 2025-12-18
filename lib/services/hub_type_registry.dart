import '../models/hub.dart';
import '../config/config.dart';

/// Registry for hub type-specific features and configurations
class HubTypeRegistry {
  /// Get available hub types for the current user
  static List<HubType> getAvailableHubTypes() {
    final config = Config.current;
    final availableTypes = <HubType>[HubType.family]; // Family is always available

    if (config.enablePremiumHubs) {
      if (config.enableExtendedFamilyHub) {
        availableTypes.add(HubType.extendedFamily);
      }
      if (config.enableHomeschoolingHub) {
        availableTypes.add(HubType.homeschooling);
      }
      if (config.enableCoparentingHub) {
        availableTypes.add(HubType.coparenting);
      }
    }

    return availableTypes;
  }

  /// Get display name for hub type
  static String getDisplayName(HubType hubType) {
    switch (hubType) {
      case HubType.family:
        return 'Family Hub';
      case HubType.extendedFamily:
        return 'Extended Family Hub';
      case HubType.homeschooling:
        return 'Home Schooling Hub';
      case HubType.coparenting:
        return 'Co-Parenting Hub';
      case HubType.library:
        return 'Library Hub';
    }
  }

  /// Get description for hub type
  static String getDescription(HubType hubType) {
    switch (hubType) {
      case HubType.family:
        return 'Your core family hub for immediate family members';
      case HubType.extendedFamily:
        return 'Connect with extended family members (grandparents, aunts, uncles, cousins)';
      case HubType.homeschooling:
        return 'Manage homeschooling activities, curriculum, and student progress';
      case HubType.coparenting:
        return 'Coordinate with co-parents for custody schedules and expenses';
      case HubType.library:
        return 'Shared family library for books, reading challenges, and book discussions';
    }
  }

  /// Get icon for hub type
  static String getIcon(HubType hubType) {
    switch (hubType) {
      case HubType.family:
        return 'home';
      case HubType.extendedFamily:
        return 'people';
      case HubType.homeschooling:
        return 'school';
      case HubType.coparenting:
        return 'handshake';
      case HubType.library:
        return 'menu_book';
    }
  }

  /// Check if hub type is premium
  static bool isPremium(HubType hubType) {
    return hubType != HubType.family;
  }

  /// Get hub type-specific features
  static List<String> getFeatures(HubType hubType) {
    switch (hubType) {
      case HubType.family:
        return [
          'Family chat',
          'Shared calendar',
          'Task management',
          'Photo albums',
          'Location sharing',
        ];
      case HubType.extendedFamily:
        return [
          'Extended family chat',
          'Family tree visualization',
          'Event coordination',
          'Photo sharing',
          'Privacy controls',
        ];
      case HubType.homeschooling:
        return [
          'Curriculum planning',
          'Student progress tracking',
          'Assignment management',
          'Resource library',
          'Parent collaboration',
        ];
      case HubType.coparenting:
        return [
          'Custody schedule management',
          'Expense tracking & splitting',
          'Communication logging',
          'Child information sharing',
          'Document storage',
        ];
      case HubType.library:
        return [
          'Book collection',
          'Reading challenges',
          'Book ratings & reviews',
          'Reading progress tracking',
          'Family reading goals',
        ];
    }
  }

  /// Get default type-specific data for a hub type
  static Map<String, dynamic>? getDefaultTypeSpecificData(HubType hubType) {
    switch (hubType) {
      case HubType.family:
        return null;
      case HubType.extendedFamily:
        return {
          'privacyLevel': 'moderate', // moderate, strict, open
          'showFamilyTree': true,
        };
      case HubType.homeschooling:
        return {
          'schoolYearStart': DateTime.now().month >= 8 
              ? DateTime(DateTime.now().year, 8, 1).toIso8601String()
              : DateTime(DateTime.now().year - 1, 8, 1).toIso8601String(),
          'curriculumStandards': [], // e.g., ['common_core', 'state_standards']
        };
      case HubType.coparenting:
        return {
          'custodySchedule': null, // Will be set up later
          'expenseSplitRatio': 50, // 50/50 default
          'communicationStyle': 'neutral', // neutral, formal, casual
        };
      case HubType.library:
        return {
          'readingGoals': [],
          'defaultPrivacy': 'family', // family, members, public
        };
    }
  }

  /// Validate type-specific data for a hub type
  static bool validateTypeSpecificData(HubType hubType, Map<String, dynamic>? data) {
    if (data == null) return true;

    switch (hubType) {
      case HubType.family:
        return true; // No specific data required
      case HubType.extendedFamily:
        // Validate privacy level
        if (data.containsKey('privacyLevel')) {
          final level = data['privacyLevel'] as String?;
          if (level != null && !['moderate', 'strict', 'open'].contains(level)) {
            return false;
          }
        }
        return true;
      case HubType.homeschooling:
        // Validate school year start date
        if (data.containsKey('schoolYearStart')) {
          try {
            DateTime.parse(data['schoolYearStart'] as String);
          } catch (e) {
            return false;
          }
        }
        return true;
      case HubType.coparenting:
        // Validate expense split ratio (0-100)
        if (data.containsKey('expenseSplitRatio')) {
          final ratio = data['expenseSplitRatio'];
          if (ratio is! int || ratio < 0 || ratio > 100) {
            return false;
          }
        }
        // Validate communication style
        if (data.containsKey('communicationStyle')) {
          final style = data['communicationStyle'] as String?;
          if (style != null && !['neutral', 'formal', 'casual'].contains(style)) {
            return false;
          }
        }
        return true;
      case HubType.library:
        // Validate default privacy
        if (data.containsKey('defaultPrivacy')) {
          final privacy = data['defaultPrivacy'] as String?;
          if (privacy != null && !['family', 'members', 'public'].contains(privacy)) {
            return false;
          }
        }
        return true;
    }
  }
}


