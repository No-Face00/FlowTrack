// lib/app.dart
//
// Root widget — theme, currency, and locale from AppCubit.

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
        buildWhen: (prev, curr) =>
            prev.themeMode != curr.themeMode ||
            prev.languageCode != curr.languageCode,
        builder: (_, settings) {
          final locale = Locale(settings.languageCode);
          final rtl = AppLocales.isRtl(settings.languageCode);
          Intl.defaultLocale = settings.languageCode;

          return MaterialApp.router(
            key: ValueKey('app_${settings.languageCode}_${settings.themeMode.name}'),
            routerConfig: _router,
            debugShowCheckedModeBanner: false,
            title: 'FlowTrack',
            theme: AppThemes.light,
            darkTheme: AppThemes.dark,
            themeMode: settings.themeMode,
            locale: locale,
            supportedLocales: AppLocales.supported,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) {
              return Directionality(
                textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }
}
