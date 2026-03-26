// lib/core/router/app_router.dart
//
// UPDATED FOR PHASE 2:
//   - Added AppRoutes.addTransaction = '/add-transaction'
//   - HomeScreen() replaces placeholder Home()
//   - AddTransactionScreen uses _slidePage (slides up like a modal)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/cubit/pin_cubit.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/auth/presentation/pin_reset_screen.dart';
import '../../features/auth/presentation/pin_setup_screen.dart';
import '../../features/auth/presentation/pinlock_screen.dart';
import '../../features/auth/presentation/wellcome_screen.dart';
import '../../core/di/service_locator.dart';
import '../../features/main_navigation.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/transactions/presentation/add_transaction_screen.dart';
import '../../features/transactions/presentation/cubit/balance_cubit.dart';
import '../../features/transactions/presentation/cubit/transaction_cubit.dart';


// ══════════════════════════════════════════════════════════════
//  Route constants
// ══════════════════════════════════════════════════════════════
abstract class AppRoutes {
  static const onboarding     = '/onboarding';
  static const login          = '/login';
  static const register       = '/register';
  static const pinSetup       = '/pin-setup';
  static const pinLock        = '/pin-lock';
  static const pinReset       = '/pin-reset';
  static const welcome        = '/welcome';
  static const home           = '/home';
  static const addTransaction = '/add-transaction';
  static const transactions   = '/transactions';
  static const analytics      = '/analytics';
  static const account        = '/account';
}

// ══════════════════════════════════════════════════════════════
//  AppRouter
// ══════════════════════════════════════════════════════════════
class AppRouter {
  AppRouter._();

  static bool _pinJustSet = false;
  static void markPinJustSet()  => _pinJustSet = true;
  static void clearPinJustSet() => _pinJustSet = false;

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<bool> _isPinSet() async {
    // 1. Check local storage first (fast, no network)
    final val = await _storage.read(key: 'flowtrack_pin_hash');
    if (val != null) return true;

    // 2. Check Firestore (handles reinstall / cleared app data)
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      return doc.data()?['pinHash'] != null;
    } catch (_) {
      return false;
    }
  }

  static GoRouter create({required bool seenOnboarding}) {
    final user = FirebaseAuth.instance.currentUser;
    final String startLocation;
    if (!seenOnboarding) {
      startLocation = AppRoutes.onboarding;
    } else if (user != null) {
      startLocation = AppRoutes.home;
    } else {
      startLocation = AppRoutes.login;
    }

    return GoRouter(
      initialLocation: startLocation,
      debugLogDiagnostics: true,

      redirect: (context, state) async {
        final loc        = state.matchedLocation;
        final user       = FirebaseAuth.instance.currentUser;
        final isLoggedIn = user != null;

        const noRedirectRoutes = {
          AppRoutes.onboarding,
          AppRoutes.login,
          AppRoutes.register,
          AppRoutes.pinSetup,
          AppRoutes.pinReset,
          AppRoutes.welcome,
          AppRoutes.addTransaction,
          AppRoutes.transactions,
          AppRoutes.analytics,
          AppRoutes.account,
        };

        if (noRedirectRoutes.contains(loc)) return null;
        if (!isLoggedIn) return AppRoutes.login;

        if (_pinJustSet) {
          if (loc == AppRoutes.home) _pinJustSet = false;
          return null;
        }

        if (loc == AppRoutes.pinLock) return null;

        if (loc == AppRoutes.home) {
          final pinSet = await _isPinSet();
          if (pinSet) return AppRoutes.pinLock;
        }

        return null;
      },

      errorBuilder: (context, state) => _ErrorPage(error: state.error),

      routes: [
        GoRoute(
          path: AppRoutes.onboarding,
          pageBuilder: (_, state) =>
              _fadePage(state: state, child: const OnboardingScreen()),
        ),
        GoRoute(
          path: AppRoutes.login,
          pageBuilder: (_, state) =>
              _fadePage(state: state, child: const AuthScreen()),
        ),
        GoRoute(
          path: AppRoutes.register,
          pageBuilder: (_, state) =>
              _fadePage(state: state, child: const AuthScreen()),
        ),
        GoRoute(
          path: AppRoutes.pinSetup,
          pageBuilder: (_, state) => _slidePage(
            state: state,
            child: BlocProvider(
              create: (_) => PinCubit(),
              child: const PinSetupScreen(),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.pinLock,
          pageBuilder: (_, state) => _fadePage(
            state: state,
            child: BlocProvider(
              create: (_) => PinCubit(),
              child: const PinLockScreen(),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.pinReset,
          pageBuilder: (_, state) => _slidePage(
            state: state,
            child: const PinResetScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.welcome,
          pageBuilder: (_, state) =>
              _fadePage(state: state, child: const WelcomeScreen()),
        ),
        GoRoute(
          path: AppRoutes.home,
          pageBuilder: (_, state) =>
              _fadePage(state: state, child: const MainNavigation()),
        ),

        // ── Phase 2: Add Transaction ───────────────────────────
        // MultiBlocProvider injects the lazySingleton cubits here so
        // AddTransactionScreen shares the exact same TransactionCubit
        // instance as HomeScreen — real-time updates work across routes.
        GoRoute(
          path: AppRoutes.addTransaction,
          pageBuilder: (_, state) => _slidePage(
            state: state,
            child: MultiBlocProvider(
              providers: [
                BlocProvider.value(value: getIt<TransactionCubit>()),
                BlocProvider.value(value: getIt<BalanceCubit>()),
              ],
              child: AddTransactionScreen(
                initialType: state.extra as String?,
              ),
            ),
          ),
        ),




      ],
    );
  }
}

// ── Transitions ────────────────────────────────────────────────
CustomTransitionPage<void> _fadePage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (_, anim, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn),
      child: child,
    ),
  );
}

CustomTransitionPage<void> _slidePage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 340),
    transitionsBuilder: (_, anim, __, child) => SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end:   Offset.zero,
      ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
}

class _ErrorPage extends StatelessWidget {
  const _ErrorPage({this.error});
  final Exception? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('404',
                style: TextStyle(fontSize: 64, fontWeight: FontWeight.bold)),
            Text('Page not found\n${error?.toString() ?? ''}',
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.login),
              child: const Text('Go to Login'),
            ),
          ],
        ),
      ),
    );
  }
}