// ============================================================
// PokéGrading — Design System / Theme (Core)
// Defines colors, typography, and component styles.
// ============================================================
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// PokéGrading Color Palette
abstract class AppColors {
  // --- Primary Colors ---
  static const primary = Color(0xFF6C63FF); // Electric violet
  static const primaryDark = Color(0xFF4A42E8);
  static const primaryLight = Color(0xFF9D97FF);

  // --- Accent Colors / Pokémon Yellow ---
  static const accent = Color(0xFFFFCC00);
  static const accentDark = Color(0xFFE6B800);

  // --- Backgrounds (Dark Mode) ---
  static const backgroundDark = Color(0xFF0D0D1A);
  static const surfaceDark = Color(0xFF1A1A2E);
  static const surfaceDark2 = Color(0xFF16213E);
  static const cardDark = Color(0xFF1E1E35);

  // --- Backgrounds (Light Mode) ---
  static const backgroundLight = Color(0xFFF5F5FF);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const cardLight = Color(0xFFF0F0FF);

  // --- Typography / Text ---
  static const textPrimary = Color(0xFFE8E8FF);
  static const textSecondary = Color(0xFF9E9EC4);
  static const textOnDark = Color(0xFF0D0D1A);

  // --- System / State ---
  static const success = Color(0xFF4CAF82);
  static const warning = Color(0xFFFFB74D);
  static const error = Color(0xFFEF5350);
  static const info = Color(0xFF42A5F5);

  // --- Borders / Dividers ---
  static const borderDark = Color(0xFF2D2D4E);
  static const borderLight = Color(0xFFD0D0F0);
}

/// Centralizes all application themes.
class AppTheme {
  AppTheme._();

  // --- Dark Theme (Primary) ---
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surfaceDark,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: AppColors.textOnDark,
        onSurface: AppColors.textPrimary,
      ),
      scaffoldBackgroundColor: AppColors.backgroundDark,
      textTheme: _buildTextTheme(AppColors.textPrimary),
      cardTheme: const CardThemeData(
        color: AppColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: AppColors.borderDark),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfaceDark,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderDark,
        thickness: 1,
      ),
    );
  }

  // --- Light Theme ---
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surfaceLight,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: AppColors.textOnDark,
        onSurface: Color(0xFF1A1A2E),
      ),
      scaffoldBackgroundColor: AppColors.backgroundLight,
      textTheme: _buildTextTheme(const Color(0xFF1A1A2E)),
    );
  }

  /// Builds [TextTheme] using Google Fonts (Space Grotesk).
  static TextTheme _buildTextTheme(Color baseColor) {
    return TextTheme(
      displayLarge: GoogleFonts.spaceGrotesk(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        color: baseColor,
      ),
      displayMedium: GoogleFonts.spaceGrotesk(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        color: baseColor,
      ),
      headlineLarge: GoogleFonts.spaceGrotesk(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: baseColor,
      ),
      headlineMedium: GoogleFonts.spaceGrotesk(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      titleLarge: GoogleFonts.spaceGrotesk(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      bodyLarge: GoogleFonts.spaceGrotesk(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: baseColor,
      ),
      bodyMedium: GoogleFonts.spaceGrotesk(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: baseColor,
      ),
      labelLarge: GoogleFonts.spaceGrotesk(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: baseColor,
        letterSpacing: 0.5,
      ),
    );
  }
}
