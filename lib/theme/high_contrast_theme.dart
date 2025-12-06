import 'package:flutter/material.dart';

class HighContrastTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF000000),
        onPrimary: Color(0xFFFFFFFF),
        secondary: Color(0xFF000000),
        onSecondary: Color(0xFFFFFFFF),
        error: Color(0xFF000000),
        onError: Color(0xFFFFFFFF),
        surface: Color(0xFFFFFFFF),
        onSurface: Color(0xFF000000),
        outline: Color(0xFF000000),
      ),
      scaffoldBackgroundColor: Colors.white,
      cardColor: Colors.white,
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: Colors.black, fontSize: 32, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(color: Colors.black, fontSize: 28, fontWeight: FontWeight.bold),
        displaySmall: TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold),
        headlineLarge: TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
        headlineSmall: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: Colors.black, fontSize: 16),
        bodyMedium: TextStyle(color: Colors.black, fontSize: 14),
        bodySmall: TextStyle(color: Colors.black, fontSize: 12),
        labelLarge: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w500),
        labelMedium: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w500),
        labelSmall: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w500),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFFFFFFF),
        onPrimary: Color(0xFF000000),
        secondary: Color(0xFFFFFFFF),
        onSecondary: Color(0xFF000000),
        error: Color(0xFFFFFFFF),
        onError: Color(0xFF000000),
        surface: Color(0xFF000000),
        onSurface: Color(0xFFFFFFFF),
        outline: Color(0xFFFFFFFF),
      ),
      scaffoldBackgroundColor: Colors.black,
      cardColor: Colors.black,
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
        displaySmall: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        headlineLarge: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        headlineSmall: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: Colors.white, fontSize: 16),
        bodyMedium: TextStyle(color: Colors.white, fontSize: 14),
        bodySmall: TextStyle(color: Colors.white, fontSize: 12),
        labelLarge: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
        labelMedium: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
        labelSmall: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
      ),
    );
  }
}

