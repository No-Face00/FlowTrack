// lib/app.dart
//
// Root widget.
// • Provides AppCubit (theme + currency) to the entire widget tree
// • MaterialApp.router's themeMode is driven by AppCubit
// • AppCubit.load() is called once here — reads SharedPrefs then Firestore

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/constants/app_colors.dart';
import 'core/constants/app_themes.dart';
import 'core/cubit/app_cubit.dart';
import 'core/di/service_locator.dart';
import 'core/router/appRouter.dart';

class FlowTrack extends StatefulWidget {
  const FlowTrack({super.key, required this.seenOnboarding});

  final bool seenOnboarding;

  @override
  State<FlowTrack> createState() => _FlowTrackState();
}

class _FlowTrackState extends State<FlowTrack> {
  late final _router = AppRouter.create(seenOnboarding: widget.seenOnboarding);

  @override
  void initState() {
    super.initState();
    // Load persisted settings (SharedPrefs → Firestore).
    // AppCubit is a singleton registered in GetIt, so this fires once.
    getIt<AppCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AppCubit>.value(
      value: getIt<AppCubit>(),
      child: BlocBuilder<AppCubit, AppSettings>(
        buildWhen: (prev, curr) => prev.themeMode != curr.themeMode,
        builder: (_, settings) {
          return MaterialApp.router(
            routerConfig:              _router,
            debugShowCheckedModeBanner: false,
            title:                     'FlowTrack',

            // ── Themes ──────────────────────────────────────────
            theme:     AppThemes.light,
            darkTheme: AppThemes.dark,
            themeMode: settings.themeMode,   // ← driven by AppCubit
          );
        },
      ),
    );
  }
}