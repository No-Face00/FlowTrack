// lib/core/router/app_router.dart
//
// ─────────────────────────────────────────────────────────────
// FLOW SUMMARY:
//
//  First time (new user):
//    /onboarding → /login → sign up → /pin-setup → /welcome → /home
//
//  Returning user (cold start, PIN set):
//    app open → Firebase session found → /home → redirect → /pin-lock → verify → /home
//
//  Returning user (cold start, no PIN):
//    app open → Firebase session found → /home  (no redirect)
//
//  Returning user (session expired / signed out):
//    app open → /login
//
// FIXES:
//   1. initialLocation now checks FirebaseAuth.currentUser so users
//      are never forced back to /login on every cold start.
//   2. After /pin-setup, AppRouter._pinJustSet = true prevents
//      redirect() from looping back to /pin-lock.
//      The flag is cleared once /home is reached.
// ─────────────────────────────────────────────────────────────

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/cubit/pin_cubit.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/auth/presentation/pin_setup_screen.dart';
import '../../features/auth/presentation/pinlock_screen.dart';
import '../../features/auth/presentation/wellcome_screen.dart';
import '../../features/home.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
// ══════════════════════════════════════════════════════════════
//  Route constants
// ══════════════════════════════════════════════════════════════
abstract class AppRoutes {
  static const onboarding = '/onboarding';
  static const login      = '/login';
  static const register   = '/register';
  static const pinSetup   = '/pin-setup';
  static const pinLock    = '/pin-lock';
  static const welcome    = '/welcome';
  static const home       = '/home';

// Phase 2+:
// static const addTransaction = '/add-transaction';
// static const analytics      = '/analytics';
// static const settings       = '/settings';
}

// ══════════════════════════════════════════════════════════════
//  AppRouter
// ══════════════════════════════════════════════════════════════
class AppRouter {
  AppRouter._();

  // ── Flag: PIN was just created this session ────────────────
  // Set to true in PinSetupScreen BEFORE going to /welcome.
  // Prevents redirect() from sending the user to /pin-lock
  // right after they finished setting up their PIN.
  static bool _pinJustSet = false;

  static void markPinJustSet()  => _pinJustSet = true;
  static void clearPinJustSet() => _pinJustSet = false;

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<bool> _isPinSet() async {
    final val = await _storage.read(key: 'flowtrack_pin_hash');
    return val != null;
  }

  // ── Build router ───────────────────────────────────────────
  static GoRouter create({required bool seenOnboarding}) {
    // If user is already logged in (Firebase persisted the session),
    // send them straight to /home — redirect() will then check for
    // PIN and bounce to /pin-lock if needed.
    final user = FirebaseAuth.instance.currentUser;
    final String startLocation;
    if (!seenOnboarding) {
      startLocation = AppRoutes.onboarding;
    } else if (user != null) {
      startLocation = AppRoutes.home; // already logged in → redirect handles PIN
    } else {
      startLocation = AppRoutes.login;
    }

    return GoRouter(
      initialLocation:     startLocation,
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
          AppRoutes.welcome,   // ← welcome must NEVER be redirected away
        };

        // Always allow these routes through
        if (noRedirectRoutes.contains(loc)) return null;

        // Not logged in → go to login
        if (!isLoggedIn) return AppRoutes.login;

        // PIN was just set this session → skip the pin-lock check
        // This allows /welcome → /home to work without being
        // intercepted and sent back to /pin-lock.
        if (_pinJustSet) {
          // Once we reach /home, clear the flag
          if (loc == AppRoutes.home) _pinJustSet = false;
          return null;
        }

        // /pin-lock → always allow (user is entering PIN)
        if (loc == AppRoutes.pinLock) return null;

        // /home → check if they should be showing pin-lock first
        if (loc == AppRoutes.home) {
          final pinSet = await _isPinSet();
          if (pinSet) return AppRoutes.pinLock;
        }

        return null;
      },

      errorBuilder: (context, state) => _ErrorPage(error: state.error),

      routes: [

        // ── Onboarding ────────────────────────────────────────
        GoRoute(
          path: AppRoutes.onboarding,
          pageBuilder: (_, state) => _fadePage(
              state: state, child: const OnboardingScreen()),
        ),

        // ── Auth: sign-in ─────────────────────────────────────
        GoRoute(
          path: AppRoutes.login,
          pageBuilder: (_, state) => _fadePage(
              state: state, child: const AuthScreen()),
        ),

        // ── Auth: sign-up (same screen) ───────────────────────
        GoRoute(
          path: AppRoutes.register,
          pageBuilder: (_, state) => _fadePage(
              state: state, child: const AuthScreen()),
        ),

        // ── PIN Setup (first-time, after login/signup) ────────
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

        // ── PIN Lock (cold start, returning user) ─────────────
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

        // ── Welcome (after PIN saved) ─────────────────────────
        GoRoute(
          path: AppRoutes.welcome,
          pageBuilder: (_, state) => _fadePage(
              state: state, child: const WelcomeScreen()),
        ),

        // ── Home ──────────────────────────────────────────────
        GoRoute(
          path: AppRoutes.home,
          pageBuilder: (_, state) => _fadePage(
            state: state,
            // Replace with HomeScreen() when Phase 2 is built:
            child: const Home(),
          ),
        ),

      ],
    );
  }
}

// ── Fade transition ────────────────────────────────────────────
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

// ── Slide-up transition (for modal screens) ────────────────────
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

// ── Error page ─────────────────────────────────────────────────
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