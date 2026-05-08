// lib/core/constants/app_themes.dart
//
// ── Light + Dark ThemeData ────────────────────────────────────────────────────
//
// Every token a screen needs is defined here. Screens use ONLY:
//   Theme.of(context).scaffoldBackgroundColor  → page background
//   Theme.of(context).cardColor                → rounded content card
//   Theme.of(context).colorScheme.surface      → sheets / dialogs
//   Theme.of(context).colorScheme.onSurface    → primary text
//   Theme.of(context).colorScheme.onSurface.withOpacity(0.55) → secondary text
//   Theme.of(context).colorScheme.onSurface.withOpacity(0.40) → muted text
//   Theme.of(context).dividerColor             → dividers/borders
//   Theme.of(context).iconTheme.color          → default icon color
//   inputDecorationTheme                       → all TextFields

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppThemes {

  // ══════════════════════════════════════════════════════════════════
  // LIGHT
  // ══════════════════════════════════════════════════════════════════
  static ThemeData get light {
    // Start from DM Sans base
    final base = ThemeData.light(useMaterial3: true);
    final tt   = GoogleFonts.dmSansTextTheme(base.textTheme);

    const onSurface = Color(0xFF0A0A2E);  // AppColors.textDark

    return base.copyWith(
      brightness:              Brightness.light,
      scaffoldBackgroundColor: AppColors.bgLavender,
      cardColor:               Colors.white,
      dividerColor:            const Color(0xFFE0DEEE),  // soft lavender divider

      colorScheme: ColorScheme.fromSeed(
        seedColor:  AppColors.royalBlue,
        brightness: Brightness.light,
      ).copyWith(
        surface:               Colors.white,
        onSurface:             onSurface,
        surfaceContainerLow:   const Color(0xFFF7F6FC),  // alternating row tint
        primary:               AppColors.royalBlue,
        onPrimary:             Colors.white,
        secondary:             AppColors.violet,
        primaryContainer:      AppColors.iconTile,
        onPrimaryContainer:    AppColors.royalBlue,
      ),

      textTheme: tt.copyWith(
        titleLarge:  tt.titleLarge?.copyWith(color: onSurface, fontWeight: FontWeight.w800),
        titleMedium: tt.titleMedium?.copyWith(color: onSurface, fontWeight: FontWeight.w700),
        titleSmall:  tt.titleSmall?.copyWith(color: AppColors.textMid),
        bodyLarge:   tt.bodyLarge?.copyWith(color: onSurface),
        bodyMedium:  tt.bodyMedium?.copyWith(color: AppColors.textMid),
        bodySmall:   tt.bodySmall?.copyWith(color: AppColors.textMuted),
        labelLarge:  tt.labelLarge?.copyWith(color: onSurface, fontWeight: FontWeight.w600),
        labelMedium: tt.labelMedium?.copyWith(color: AppColors.textMid),
        labelSmall:  tt.labelSmall?.copyWith(color: AppColors.textMuted),
      ),

      iconTheme:      const IconThemeData(color: AppColors.textMid),
      splashFactory:  NoSplash.splashFactory,
      highlightColor: Colors.transparent,

      inputDecorationTheme: InputDecorationTheme(
        filled:     true,
        fillColor:  AppColors.bgLavender,
        border:     OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:   BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:   BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:   const BorderSide(color: AppColors.royalBlue, width: 1.5)),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      cardTheme: CardThemeData(
        color:     Colors.white,
        elevation: 0,
        shape:     RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor:     Colors.white,
        selectedItemColor:   AppColors.royalBlue,
        unselectedItemColor: AppColors.textMuted,
        elevation:           0,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22)),
        titleTextStyle: const TextStyle(
            color: onSurface, fontSize: 18, fontWeight: FontWeight.w800),
        contentTextStyle: const TextStyle(
            color: AppColors.textMid, fontSize: 14),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor:      Colors.white,
        modalBackgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.selected) ? AppColors.royalBlue : Colors.white),
        trackColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.selected)
            ? AppColors.royalBlue.withOpacity(0.4)
            : const Color(0xFFE0DEEE)),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // DARK
  // ══════════════════════════════════════════════════════════════════
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    final tt   = GoogleFonts.dmSansTextTheme(base.textTheme);

    // Text color constants — explicitly white-leaning so they're
    // never mistaken for the dark background
    const textPrimary   = Color(0xFFF0EEF8);
    const textSecondary = Color(0xFFB8B5D4);
    const textMuted     = Color(0xFF7A789A);

    return base.copyWith(
      brightness:              Brightness.dark,
      scaffoldBackgroundColor: DarkColors.background,
      cardColor:               DarkColors.card,
      dividerColor:            DarkColors.divider,

      colorScheme: ColorScheme.fromSeed(
        seedColor:  AppColors.royalBlue,
        brightness: Brightness.dark,
      ).copyWith(
        surface:               DarkColors.surface,
        onSurface:             textPrimary,          // ← ALL surface text is near-white
        surfaceContainerLow:   DarkColors.cardElevated, // alternating row tint
        primary:               AppColors.royalBlue,
        onPrimary:             Colors.white,
        secondary:             AppColors.violet,
        primaryContainer:      const Color(0xFF1A1B3A), // icon bg tint
        onPrimaryContainer:    AppColors.violet,
      ),

      // textTheme: every slot has a concrete near-white color so NO
      // inherited default can bleed dark-on-dark text through
      textTheme: tt.copyWith(
        displayLarge:  tt.displayLarge?.copyWith(color: textPrimary),
        displayMedium: tt.displayMedium?.copyWith(color: textPrimary),
        displaySmall:  tt.displaySmall?.copyWith(color: textPrimary),
        headlineLarge: tt.headlineLarge?.copyWith(color: textPrimary),
        headlineMedium:tt.headlineMedium?.copyWith(color: textPrimary),
        headlineSmall: tt.headlineSmall?.copyWith(color: textPrimary),
        titleLarge:    tt.titleLarge?.copyWith(color: textPrimary,   fontWeight: FontWeight.w800),
        titleMedium:   tt.titleMedium?.copyWith(color: textPrimary,  fontWeight: FontWeight.w700),
        titleSmall:    tt.titleSmall?.copyWith(color: textSecondary),
        bodyLarge:     tt.bodyLarge?.copyWith(color: textPrimary),
        bodyMedium:    tt.bodyMedium?.copyWith(color: textSecondary),
        bodySmall:     tt.bodySmall?.copyWith(color: textMuted),
        labelLarge:    tt.labelLarge?.copyWith(color: textPrimary,   fontWeight: FontWeight.w600),
        labelMedium:   tt.labelMedium?.copyWith(color: textSecondary),
        labelSmall:    tt.labelSmall?.copyWith(color: textMuted),
      ),

      iconTheme: const IconThemeData(color: textSecondary),
      splashFactory:  NoSplash.splashFactory,
      highlightColor: Colors.transparent,

      inputDecorationTheme: InputDecorationTheme(
        filled:    true,
        fillColor: DarkColors.inputFill,
        // Typed text must be white — set explicitly
        labelStyle: const TextStyle(color: textSecondary),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:   BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:   BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:   const BorderSide(color: AppColors.royalBlue, width: 1.5)),
        hintStyle:    const TextStyle(color: textMuted, fontSize: 14),
        // ← This ensures text typed into any TextField is near-white
        prefixIconColor: textMuted,
        suffixIconColor: textMuted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      cardTheme: CardThemeData(
        color:     DarkColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: DarkColors.border.withOpacity(0.6), width: 0.8),
        ),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor:     DarkColors.navBar,
        selectedItemColor:   AppColors.royalBlue,
        unselectedItemColor: textMuted,
        elevation:           0,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: DarkColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22)),
        titleTextStyle: const TextStyle(
            color: textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
        contentTextStyle: const TextStyle(
            color: textSecondary, fontSize: 14),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor:      DarkColors.surface,
        modalBackgroundColor: DarkColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor:  DarkColors.cardElevated,
        contentTextStyle: const TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.selected) ? Colors.white : textMuted),
        trackColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.selected)
            ? AppColors.royalBlue.withOpacity(0.5)
            : DarkColors.border),
      ),

      popupMenuTheme: const PopupMenuThemeData(
        color:     DarkColors.surface,
        textStyle: TextStyle(color: textPrimary),
      ),
    );
  }
}

// ── Dark mode color tokens ────────────────────────────────────────────────────
class DarkColors {
  DarkColors._();

  // Backgrounds
  static const Color background   = Color(0xFF0B1220);
  static const Color surface      = Color(0xFF111827);
  static const Color card         = Color(0xFF111827);
  static const Color cardElevated = Color(0xFF1A2336);
  static const Color navBar       = Color(0xFF0F1929);

  // Inputs
  static const Color inputFill    = Color(0xFF1A2336);

  // Text — explicit near-white palette
  static const Color textPrimary   = Color(0xFFF0EEF8);
  static const Color textSecondary = Color(0xFFB8B5D4);
  static const Color textMuted     = Color(0xFF7A789A);

  // Borders / dividers
  static const Color divider = Color(0xFF1E2D45);
  static const Color border  = Color(0xFF253347);

  // Misc
  static const Color headerOverlay = Color(0x1A000000);
}