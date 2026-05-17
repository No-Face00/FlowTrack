// lib/app.dart
//
// Root widget — theme, currency, and locale from AppCubit.
//
// FIX v2:
//   • Removed ValueKey from MaterialApp.router — it was forcing a full widget
//     tree rebuild (including router recreation) on every theme/language change,
//     which navigated back to the initial route. Without the key, Flutter
//     reuses the existing MaterialApp and only updates theme/locale in-place.
//   • RTL support: Directionality is set via MaterialApp.builder so the
//     entire subtree flips for Arabic/Urdu without a route change.
//   • Theme changes are instant — no flicker, no navigation.
//   • Language changes are instant — no navigation, no state loss.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';

import 'core/constants/app_themes.dart';
import 'core/cubit/app_cubit.dart';
import 'core/di/service_locator.dart';
import 'core/l10n/app_locale.dart';
import 'core/router/appRouter.dart';

class FlowTrack extends StatefulWidget {
  const FlowTrack({super.key, required this.seenOnboarding});

  final bool seenOnboarding;

  @override
  State<FlowTrack> createState() => _FlowTrackState();
}

class _FlowTrackState extends State<FlowTrack> {
  // Router is created ONCE and kept alive for the full app lifetime.
  // This is the critical fix — creating it inside build() or tying it to a
  // ValueKey caused it to be recreated every time theme/language changed,
  // which reset navigation back to the initial route.
  late final _router = AppRouter.create(seenOnboarding: widget.seenOnboarding);

  @override
  void initState() {
    super.initState();
    getIt<AppCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AppCubit>.value(
      value: getIt<AppCubit>(),
      child: BlocBuilder<AppCubit, AppSettings>(
        // Only rebuild when theme OR language actually changes.
        // Currency changes must NOT trigger a rebuild here — they only
        // affect individual money-display widgets lower in the tree.
        buildWhen: (prev, curr) =>
        prev.themeMode    != curr.themeMode ||
            prev.languageCode != curr.languageCode,
        builder: (_, settings) {
          final locale = Locale(settings.languageCode);
          final isRtl  = AppLocales.isRtl(settings.languageCode);

          // Sync Intl default locale so DateFormat / NumberFormat pick up
          // the right locale without needing explicit locale parameters.
          Intl.defaultLocale = settings.languageCode;

          return MaterialApp.router(
            // ── KEY REMOVED ──────────────────────────────────────────────────
            // DO NOT add a key here. A ValueKey tied to language/theme caused
            // Flutter to unmount and remount the entire widget tree (including
            // the GoRouter), which reset navigation to the initial route.
            // Without a key, Flutter reuses the existing MaterialApp and diffs
            // only the changed properties (themeMode, locale) — no navigation.
            // ─────────────────────────────────────────────────────────────────
            routerConfig: _router,
            debugShowCheckedModeBanner: false,
            title: 'FlowTrack',

            // Theme
            theme:     AppThemes.light,
            darkTheme: AppThemes.dark,
            themeMode: settings.themeMode,

            // Locale
            locale:            locale,
            supportedLocales:  AppLocales.supported,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],

            // ── RTL support ──────────────────────────────────────────────────
            // builder wraps the entire navigator in a Directionality widget.
            // This is the correct place — setting it here means every route,
            // dialog, bottom sheet, and overlay gets the right text direction
            // without needing individual Directionality widgets per screen.
            builder: (ctx, child) {
              return Directionality(
                textDirection: isRtl
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }
}