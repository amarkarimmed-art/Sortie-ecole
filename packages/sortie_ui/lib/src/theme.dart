import 'package:flutter/material.dart';

class SortieColors {
  SortieColors._();

  static const Color primary = Color(0xFF0F766E); // Teal 700 - haute lisibilité plein soleil
  static const Color primaryLight = Color(0xFF14B8A6); // Teal 500
  static const Color primaryDark = Color(0xFF115E59); // Teal 800
  static const Color secondary = Color(0xFF0284C7); // Sky 600

  static const Color background = Color(0xFFF0F4F9); // Google Material You authentique
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF1F1F1F); // Google Grey 900
  static const Color textSecondary = Color(0xFF444746); // Google Grey 700
  static const Color border = Color(0xFFE0E3E7); // Filet subtil Google

  static const Color success = Color(0xFF146C2E); // Google Green
  static const Color warning = Color(0xFFB06000); // Google Amber / Brown
  static const Color error = Color(0xFFB3261E); // Google Red M3
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
        backgroundColor: SortieColors.background,
        foregroundColor: SortieColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: SortieColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: SortieColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: SortieColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 54), // ≥ 48dp obligatoire, largeur finie
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28), // Pilule Google
          ),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 24,
            vertical: 14,
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFD),
        contentPadding: const EdgeInsetsDirectional.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: SortieColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: SortieColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: SortieColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: SortieColors.error),
        ),
      ),
    );
  }
}
