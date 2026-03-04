// lib/core/router/app_router.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/home.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/auth_screen.dart';
// import '../../features/home/presentation/home_screen.dart';

// ══════════════════════════════════════════════════════════════
//  Route name constants — use these everywhere, never raw strings
// ══════════════════════════════════════════════════════════════
abstract class AppRoutes {
  static const onboarding = '/onboarding';
  static const login      = '/login';   // → AuthScreen (sign-in tab)
  static const register   = '/register'; // → AuthScreen (sign-up tab)
  static const home       = '/home';
// Add more as you build:
// static const addTransaction = '/add-transaction';
// static const analytics      = '/analytics';
// static const settings       = '/settings';
}

// ══════════════════════════════════════════════════════════════
//  AppRouter.create()
// ══════════════════════════════════════════════════════════════
class AppRouter {
  AppRouter._();

  static GoRouter create({required bool seenOnboarding}) {
    return GoRouter(
      initialLocation:     seenOnboarding ? AppRoutes.login : AppRoutes.onboarding,
      debugLogDiagnostics: true,

      // ── Auth guard (uncomment when auth is ready) ──────────
      redirect: (context, state) async {
        // final isLoggedIn = FirebaseAuth.instance.currentUser != null;
        // final goingToAuth = state.matchedLocation == AppRoutes.login ||
        //                     state.matchedLocation == AppRoutes.register;
        // if (!isLoggedIn && !goingToAuth &&
        //     state.matchedLocation != AppRoutes.onboarding) return AppRoutes.login;
        // if (isLoggedIn && goingToAuth) return AppRoutes.home;
        return null;
      },

      errorBuilder: (context, state) => _ErrorPage(error: state.error),

      routes: [

        // ── Onboarding ──────────────────────────────────────
        GoRoute(
          path: AppRoutes.onboarding,
          pageBuilder: (context, state) => _fadePage(
            state: state,
            child: const OnboardingScreen(),
          ),
        ),

        // ── Auth (sign-in tab) ───────────────────────────────
        GoRoute(
          path: AppRoutes.login,
          pageBuilder: (context, state) => _fadePage(
            state: state,
            child: const AuthScreen(),
          ),
        ),

        // ── Auth (sign-up tab — same screen, different initial tab)
        GoRoute(
          path: AppRoutes.register,
          pageBuilder: (context, state) => _fadePage(
            state: state,
            child: const AuthScreen(),
          ),
        ),

        // ── Home ─────────────────────────────────────────────
        GoRoute(
          path: AppRoutes.home,
          pageBuilder: (context, state) => _fadePage(
            state: state,
            // child: const HomeScreen(),
            child: const Home(),
          ),
        ),

      ],
    );
  }
}

// ── Transition helpers ──────────────────────────────────────────
CustomTransitionPage<void> _fadePage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    transitionsBuilder: (context, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
      child: child,
    ),
  );
}

// ── Error page ──────────────────────────────────────────────────
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
            const Text('404', style: TextStyle(fontSize: 64, fontWeight: FontWeight.bold)),
            Text('Page not found\n${error?.toString() ?? ''}', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.login),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Placeholder — delete when real screen is built ──────────────
class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title, required this.route});
  final String title;
  final String route;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00033D),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(
                color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('→ Continue'),
            ),
          ],
        ),
      ),
    );
  }
}