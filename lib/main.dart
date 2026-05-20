import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/di/service_locator.dart';
import 'core/errors/app_error_handler.dart';
import 'core/services/hive_service.dart';
import 'core/widgets/premium_snackbar.dart';
import 'features/home/finance/finance_assistant_prefs.dart';
import 'core/notifications/notification_cubit.dart';
import 'core/l10n/l10n_extension.dart';
import 'core/l10n/app_strings.dart';
import 'features/transactions/presentation/cubit/transaction_cubit.dart';
import 'firebase_options.dart';

Future<void> main() async {
  await runAppGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    AppErrorHandler.install();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
    ));
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await HiveService.init();
    await setupLocator();
    await FinanceAssistantPrefs.syncFromDisk();

    final bool seenOnboarding = await _getSeenOnboarding();

    runApp(FlowTrack(seenOnboarding: seenOnboarding));

    _listenConnectivity();
  });
}

void _listenConnectivity() {
  Connectivity().onConnectivityChanged.listen((results) async {
    final isOnline = results.any((r) => r != ConnectivityResult.none);
    if (!isOnline) return;
    try {
      final synced = await getIt<TransactionCubit>().syncPending();
      if (synced > 0) {
        AppSnack.showGlobal(
          message: trGlobal(S.done),
          subtitle: '$synced ${trGlobal(S.transactions)}',
          type: SnackType.success,
          icon: Icons.cloud_done_rounded,
        );
        getIt<NotificationCubit>().pushSystem(
          title: trGlobal(S.done),
          body: '$synced ${trGlobal(S.transactions)} ☁️',
          emoji: '☁️',
          category: 'sync',
        );
      }
    } catch (_) {}
  });
}

Future<bool> _getSeenOnboarding() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('seen_onboarding') ?? false;
  } catch (e) {
    debugPrint('SharedPreferences error: $e');
    return false;
  }
}
