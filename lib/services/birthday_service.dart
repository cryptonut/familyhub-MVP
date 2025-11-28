import '../core/services/logger_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

/// Service for managing birthday-related operations
class BirthdayService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  /// Get upcoming birthdays for the next N days
  /// Returns a list of users with birthdays in the specified range
  Future<List<BirthdayInfo>> getUpcomingBirthdays({int days = 30}) async {
    try {
      final currentUser = await _authService.getCurrentUserModel();
      if (currentUser?.familyId == null) return [];

      final now = DateTime.now();
      final endDate = now.add(Duration(days: days));

      // Get all family members
      final familyMembers = await _authService.getFamilyMembers();
      
      final upcomingBirthdays = <BirthdayInfo>[];

      for (var member in familyMembers) {
        if (member.birthday == null) continue;
        if (!member.birthdayNotificationsEnabled) continue;

        // Calculate this year's birthday
        final thisYearBirthday = DateTime(
          now.year,
          member.birthday!.month,
          member.birthday!.day,
        );

        // Calculate next year's birthday (in case we're past this year's date)
        final nextYearBirthday = DateTime(
          now.year + 1,
          member.birthday!.month,
          member.birthday!.day,
        );

        DateTime? upcomingBirthday;
        if (thisYearBirthday.isAfter(now) && thisYearBirthday.isBefore(endDate)) {
          upcomingBirthday = thisYearBirthday;
        } else if (nextYearBirthday.isAfter(now) && nextYearBirthday.isBefore(endDate)) {
          upcomingBirthday = nextYearBirthday;
        }

        if (upcomingBirthday != null) {
          final age = upcomingBirthday.year - member.birthday!.year;
          upcomingBirthdays.add(BirthdayInfo(
            user: member,
            upcomingDate: upcomingBirthday,
            ageTurning: age,
          ));
        }
      }

      // Sort by upcoming date
      upcomingBirthdays.sort((a, b) => a.upcomingDate.compareTo(b.upcomingDate));

      return upcomingBirthdays;
    } catch (e) {
      Logger.error('Error getting upcoming birthdays', error: e, tag: 'BirthdayService');
      return [];
    }
  }

  /// Get birthdays happening today
  Future<List<UserModel>> getTodayBirthdays() async {
    try {
      final familyMembers = await _authService.getFamilyMembers();
      final today = DateTime.now();
      
      return familyMembers.where((member) {
        if (member.birthday == null) return false;
        return member.birthday!.month == today.month && 
               member.birthday!.day == today.day;
      }).toList();
    } catch (e) {
      Logger.error('Error getting today birthdays', error: e, tag: 'BirthdayService');
      return [];
    }
  }

  /// Calculate age from birthday
  static int calculateAge(DateTime birthday) {
    final now = DateTime.now();
    int age = now.year - birthday.year;
    if (now.month < birthday.month || 
        (now.month == birthday.month && now.day < birthday.day)) {
      age--;
    }
    return age;
  }
}

/// Information about an upcoming birthday
class BirthdayInfo {
  final UserModel user;
  final DateTime upcomingDate;
  final int ageTurning;

  BirthdayInfo({
    required this.user,
    required this.upcomingDate,
    required this.ageTurning,
  });
}

