// lib/app.dart
//
//  Root widget. Receives seenOnboarding from main() so the
//  router picks the correct initial route with zero flicker.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/constants/app_colors.dart';
import 'core/router/appRouter.dart';


class FlowTrack extends StatefulWidget {
  const FlowTrack({super.key, required this.seenOnboarding});

  /// Passed from main() after reading SharedPreferences.
  /// true  → start at /login
  /// false → start at /onboarding
  final bool seenOnboarding;

  @override
  State<FlowTrack> createState() => _FlowTrackState();
}

class _FlowTrackState extends State<FlowTrack> {
  // Router is created once and stored — recreating it on every
  // rebuild would reset navigation state.
  late final _router = AppRouter.create(
    seenOnboarding: widget.seenOnboarding,
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      // ── Router config ──────────────────────────────────────
      routerConfig: _router,

      // ── App meta ───────────────────────────────────────────
      debugShowCheckedModeBanner: false,
      title: 'FlowTrack',

      // ── Theme ──────────────────────────────────────────────
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor:  AppColors.royalBlue,
          brightness: Brightness.light,
        ),
        // Apply DM Sans globally — screens can override with Sora
        textTheme: GoogleFonts.dmSansTextTheme(
          ThemeData.light().textTheme,
        ),
        // Remove ugly splash ink on buttons
        splashFactory:    NoSplash.splashFactory,
        highlightColor:   Colors.transparent,
      ),
    );
  }
}