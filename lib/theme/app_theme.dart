import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors
  static const Color emeraldPrimary = Color(0xFF0F3E33);
  static const Color emeraldDark = Color(0xFF0A2B23);
  static const Color emeraldLight = Color(0xFF1E5B4D);
  static const Color amberGold = Color(0xFFE6B042);
  static const Color amberGoldLight = Color(0xFFF3CB77);
  static const Color jadeAccent = Color(0xFF2D8A70);

  // Financial Semantics
  static const Color creditGreen = Color(0xFF10B981);
  static const Color debitRed = Color(0xFFEF4444);
  static const Color transferBlue = Color(0xFF3B82F6);
  static const Color warningOrange = Color(0xFFF59E0B);

  // Backgrounds & Surfaces
  static const Color lightBg = Color(0xFFF9F8F5);
  static const Color lightSurface = Colors.white;
  static const Color darkBg = Color(0xFF0B1412);
  static const Color darkSurface = Color(0xFF13201D);
  static const Color darkCard = Color(0xFF192A26);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: emeraldPrimary,
      primary: emeraldPrimary,
      secondary: amberGold,
      tertiary: jadeAccent,
      surface: lightSurface,
      error: debitRed,
    ),
    scaffoldBackgroundColor: lightBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: emeraldPrimary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        letterSpacing: 0.5,
      ),
    ),
    cardTheme: CardTheme(
      color: lightSurface,
      elevation: 2,
      shadowColor: Colors.black.withAlpha(20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: amberGold,
      foregroundColor: emeraldDark,
      elevation: 4,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: emeraldPrimary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: emeraldPrimary,
      brightness: Brightness.dark,
      primary: amberGold,
      secondary: jadeAccent,
      surface: darkSurface,
      error: debitRed,
    ),
    scaffoldBackgroundColor: darkBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: darkSurface,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        letterSpacing: 0.5,
      ),
    ),
    cardTheme: CardTheme(
      color: darkCard,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: amberGold,
      foregroundColor: emeraldDark,
      elevation: 4,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1E302B),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2C433D)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2C433D)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: amberGold, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}
