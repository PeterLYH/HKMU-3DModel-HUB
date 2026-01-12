// lib/styles/styles.dart

import 'package:flutter/material.dart';

class AppTheme {
  // HKMU Primary Colors
  static const Color hkmuGreen = Color(0xFF00A859);
  static const Color hkmuBlue = Color(0xFF0066B3);
  static const Color hkmuLightGreen = Color(0xFF8DC63F);

  // Neutral colors
  static const Color white = Colors.white;
  static const Color beige = Color(0xFFF5F5DC);       // ← 米色 (recommended starting point)
  // Alternative warmer 米色 options:
  // static const Color beigeWarm = Color(0xFFF9E9CD);     // traditional Chinese 米色
  // static const Color beigeCream = Color(0xFFF7EED6);

  static const Color lightGrey = Color(0xFFF5F5F5);
  static const Color darkGrey = Color(0xFF333333);

  // Light Theme – now with 米色 background
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: hkmuGreen,
      brightness: Brightness.light,
      primary: hkmuGreen,
      secondary: hkmuBlue,
      surface: beige,                    // main card/surface color
      // ignore: deprecated_member_use
      background: beige,                 // scaffold background ← changed to 米色
      surfaceContainerLowest: white,     // pure white for deepest layers
      surfaceContainerLow: Color(0xFFFAF8F0),   // very light warm tint
      surfaceContainer: Color(0xFFF5F0E0),      // subtle step up
      surfaceContainerHigh: Color(0xFFEAE4D5),
      surfaceContainerHighest: Color(0xFFE0D9C5),
    ),
    scaffoldBackgroundColor: beige,      // ← main change: 米色 background
    appBarTheme: const AppBarTheme(
      backgroundColor: hkmuGreen,
      foregroundColor: white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: white,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: hkmuGreen,
        foregroundColor: white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    cardTheme: CardThemeData(
      color: white,                      // keep cards white for contrast
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontWeight: FontWeight.bold, color: darkGrey),
      bodyLarge: TextStyle(color: darkGrey),
    ),
  );

  // Dark Theme (unchanged)
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: hkmuGreen,
      brightness: Brightness.dark,
      primary: hkmuGreen,
      secondary: hkmuBlue,
      surface: Color(0xFF121212),
    ),
    scaffoldBackgroundColor: Color(0xFF0A0A0A),
    appBarTheme: const AppBarTheme(
      backgroundColor: hkmuGreen,
      foregroundColor: white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: white,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: hkmuGreen,
        foregroundColor: white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    cardTheme: CardThemeData(
      color: Color(0xFF1E1E1E),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}