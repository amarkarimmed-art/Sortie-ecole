import 'package:flutter/material.dart';

class SortieColors {
  SortieColors._();

  static const Color primary = Color(0xFF0F766E); // Teal 700 - lisible au soleil
  static const Color primaryLight = Color(0xFF14B8A6); // Teal 500
  static const Color primaryDark = Color(0xFF115E59); // Teal 800
  static const Color secondary = Color(0xFF0284C7); // Sky 600

  static const Color background = Color(0xFFF8FAFC); // Slate 50
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF475569); // Slate 600
  static const Color border = Color(0xFFCBD5E1); // Slate 300

  static const Color success = Color(0xFF16A34A); // Green 600
  static const Color warning = Color(0xFFD97706); // Amber 600
  static const Color error = Color(0xFFDC2626); // Red 600
}

class SortieTheme {
  SortieTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: SortieColors.primary,
        primary: SortieColors.primary,
        secondary: SortieColors.secondary,
        surface: SortieColors.surface,
        error: SortieColors.error,
      ),
      scaffoldBackgroundColor: SortieColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: SortieColors.surface,
        foregroundColor: SortieColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: SortieColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 52), // ≥ 48dp obligatoire
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsetsDirectional.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: SortieColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: SortieColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: SortieColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: SortieColors.error),
        ),
      ),
    );
  }
}
