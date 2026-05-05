// lib/core/constants/app_themes.dart
//
// ── Light + Dark ThemeData ────────────────────────────────────────────────────
//
// DESIGN GOALS FOR DARK MODE:
//   • Same blue/violet brand gradient — feels like the same app
//   • Surface colors: near-black with slight blue tint (not pure #000)
//   • Cards elevated with subtle borders, not heavy shadows
//   • Text contrast ≥ 4.5:1 (WCAG AA) at all levels
//   • Income green / Expense red stay the same (semantic colors don't change)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppThemes {

  // ── LIGHT ─────────────────────────────────────────────────────────────────
  static ThemeData get light => ThemeData(
    useMaterial3:    true,
    brightness:      Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor:  AppColors.royalBlue,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: AppColors.bgLavender,
    textTheme: GoogleFonts.dmSansTextTheme(ThemeData.light().textTheme),
    splashFactory:  NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );

  // ── DARK ──────────────────────────────────────────────────────────────────
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness:   Brightness.dark,
    colorScheme:  ColorScheme.fromSeed(
      seedColor:  AppColors.royalBlue,
      brightness: Brightness.dark,
    ).copyWith(
      surface:          DarkColors.surface,
      onSurface:        DarkColors.textPrimary,
      primary:          AppColors.royalBlue,
      primaryContainer: DarkColors.card,
    ),
    scaffoldBackgroundColor: DarkColors.background,
    cardColor:               DarkColors.card,
    textTheme: GoogleFonts.dmSansTextTheme(ThemeData.dark().textTheme).apply(
      bodyColor:        DarkColors.textPrimary,
      displayColor:     DarkColors.textPrimary,
    ),
    splashFactory:  NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    dividerColor:   DarkColors.divider,
    iconTheme:      const IconThemeData(color: DarkColors.textSecondary),
    inputDecorationTheme: InputDecorationTheme(
      filled:           true,
      fillColor:        DarkColors.inputFill,
      border:           OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:   BorderSide.none,
      ),
      hintStyle: const TextStyle(color: DarkColors.textMuted),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: DarkColors.navBar,
      selectedItemColor:   AppColors.royalBlue,
      unselectedItemColor: DarkColors.textMuted,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: DarkColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
  );
}

// ── Dark mode color tokens ─────────────────────────────────────────────────────
//
// Why a separate class and not just AppColors?
//   AppColors is used with `const` everywhere — adding dark tokens there
//   would require every call site to change. DarkColors is a separate
//   namespace that dark-aware widgets can use explicitly.

class DarkColors {
  DarkColors._();

  // ── Backgrounds ────────────────────────────────────────────────────
  static const Color background = Color(0xFF0D0E1A); // near-black, blue tint
  static const Color surface    = Color(0xFF141527); // slightly lighter
  static const Color card       = Color(0xFF1C1D31); // card/sheet background
  static const Color cardElevated = Color(0xFF222440); // raised cards
  static const Color navBar     = Color(0xFF141527); // bottom nav

  // ── Inputs / fields ────────────────────────────────────────────────
  static const Color inputFill  = Color(0xFF1C1D31);

  // ── Text ───────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFF0EEF8); // near-white
  static const Color textSecondary = Color(0xFFB8B5D4); // secondary
  static const Color textMuted     = Color(0xFF6E6B92); // disabled/hints

  // ── Borders / dividers ─────────────────────────────────────────────
  static const Color divider    = Color(0xFF252640);
  static const Color border     = Color(0xFF2A2B45);

  // ── Overlay on gradient header (dark mode tints it slightly) ───────
  static const Color headerOverlay = Color(0x1A000000);
}