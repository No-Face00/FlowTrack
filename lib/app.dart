// lib/app.dart
//
// CRITICAL FIX — TextDirection isolation
// ───────────────────────────────────────
// This file does NOT reference TextDirection at all.
// The enum is resolved inside AppLocales.wrapWithDirectionality()
// which lives in app_locale.dart — a file that only imports
// flutter/material.dart. This avoids the "Member not found: rtl/ltr"
// error caused by bare `import 'dart:ui'` in other project files
// polluting the transitive scope of this file.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
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
  // Created once — never recreated. Preserves navigation stack on
  // theme/language changes. DO NOT move into build().
  late final GoRouter _router =
  AppRouter.create(seenOnboarding: widget.seenOnboarding);

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
        buildWhen: (prev, curr) =>
        prev.themeMode    != curr.themeMode ||
            prev.languageCode != curr.languageCode,
        builder: (_, settings) {
          Intl.defaultLocale = settings.languageCode;

          return MaterialApp.router(
            // NO KEY — a key here destroys and recreates the router on
            // every change, resetting navigation to the initial route.
            routerConfig:           _router,
            debugShowCheckedModeBanner: false,
            title:     'FlowTrack',
            theme:     AppThemes.light,
            darkTheme: AppThemes.dark,
            themeMode: settings.themeMode,
            locale:              Locale(settings.languageCode),
            supportedLocales:    AppLocales.supported,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (ctx, child) {
              // TextDirection is resolved inside AppLocales — not here.
              // This file never touches the TextDirection enum directly.
              return AppLocales.wrapWithDirectionality(
                languageCode: settings.languageCode,
                child:        child,
              );
            },
          );
        },
      ),
    );
  }
}