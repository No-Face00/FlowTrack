// lib/main.dart
//
// UPDATED FOR PHASE 2:
//   Added HiveService.init() and setupLocator() before runApp().
//   Also adds connectivity listener to auto-sync when internet returns.
//
// INIT ORDER (critical — do NOT change this order):
//   1. WidgetsFlutterBinding.ensureInitialized()
//   2. SystemChrome
//   3. Firebase.initializeApp()
//   4. HiveService.init()       ← NEW: local DB ready before any widget
//   5. setupLocator()           ← NEW: GetIt wires services + cubits
//   6. _getSeenOnboarding()
//   7. runApp()

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/di/service_locator.dart';
import 'core/services/hive_service.dart';
import 'features/transactions/presentation/cubit/transaction_cubit.dart';
import 'firebase_options.dart';

void main() async {
  // 1. Always first
  WidgetsFlutterBinding.ensureInitialized();

  // 2. UI chrome
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:           Colors.transparent,
    statusBarIconBrightness:  Brightness.light,
    systemNavigationBarColor: Colors.transparent,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // 3. Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 4. Hive — must be before any widget or cubit accesses transactions
  await HiveService.init();

  // 5. GetIt — must be after Hive (TransactionLocalDS needs Hive open)
  await setupLocator();

  // 6. Read onboarding flag
  final bool seenOnboarding = await _getSeenOnboarding();

  // 7. Start app
  runApp(FlowTrack(seenOnboarding: seenOnboarding));

  // ── Auto-sync when internet returns ─────────────────────────
  // This listens for connectivity changes AFTER the app is running.
  // When the device goes offline → online, syncPending() pushes all
  // Hive transactions with isSynced=false to Firestore.
  Connectivity().onConnectivityChanged.listen((results) {
    final isOnline = results.any((r) => r != ConnectivityResult.none);
    if (isOnline) {
      try {
        getIt<TransactionCubit>().syncPending();
      } catch (_) {
        // Cubit may not be active yet on first launch — safe to ignore
      }
    }
  });
}

Future<bool> _getSeenOnboarding() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('seen_onboarding') ?? false;
  } catch (e) {
    debugPrint('⚠️ SharedPreferences error: $e');
    return false;
  }
}