/// App-wide constants
class AppConstants {
  // API Configuration
  static const String apiBaseUrl = 'https://api.example.com';
  static const Duration apiTimeout = Duration(seconds: 30);

  // App Configuration
  static const String appName = 'Family Hub';
  static const String appVersion = '1.0.0';

  // Storage Keys
  static const String userTokenKey = 'user_token';
  static const String userIdKey = 'user_id';
  static const String themeModeKey = 'theme_mode';

  // Private constructor to prevent instantiation
  AppConstants._();
}

