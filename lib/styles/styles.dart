// lib/styles/styles.dart

import 'package:flutter/material.dart';

class AppTheme {
  // HKMU Primary Colors
  static const Color hkmuGreen = Color(0xFF00A859); // Vibrant green
  static const Color hkmuBlue = Color(0xFF0066B3);  // Deep blue
  static const Color hkmuLightGreen = Color(0xFF8DC63F);

  // Neutral colors
  static const Color white = Colors.white;
  static const Color lightGrey = Color(0xFFF5F5F5);
  static const Color darkGrey = Color(0xFF333333);

  // Light Theme
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: hkmuGreen,
      brightness: Brightness.light,
      primary: hkmuGreen,
      secondary: hkmuBlue,
      surface: white,
    ),
    scaffoldBackgroundColor: white,
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
      color: white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontWeight: FontWeight.bold, color: darkGrey),
      bodyLarge: TextStyle(color: darkGrey),
    ),
  );

  // Dark Theme
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