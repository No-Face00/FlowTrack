import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../widgets/premium_snackbar.dart';

/// Centralized error mapping and logging for production builds.
class AppErrorHandler {
  AppErrorHandler._();

  static void install() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      _log(details.exception, details.stack);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      _log(error, stack);
      return true;
    };
  }

  static void _log(Object error, StackTrace? stack) {
    if (kDebugMode) {
      debugPrint('══ FlowTrack Error ══');
      debugPrint('$error');
      if (stack != null) debugPrint('$stack');
    }
  }

  /// Maps any thrown object to a safe user-facing message.
  static String messageFor(Object error) {
    if (error is FirebaseAuthException) {
      return _authMessage(error.code);
    }
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return 'You do not have permission for this action.';
      }
      if (error.code == 'unavailable') {
        return 'Service temporarily unavailable. Try again shortly.';
      }
    }
    final s = error.toString().toLowerCase();
    if (s.contains('socket') ||
        s.contains('network') ||
        s.contains('connection') ||
        s.contains('offline')) {
      return 'No internet connection. Changes are saved locally and will sync.';
    }
    if (s.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  static String _authMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'network-request-failed':
        return 'No internet connection. Check your network.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  /// Show a user-friendly snackbar for an error (optional global context).
  static void showError(BuildContext? context, Object error) {
    final msg = messageFor(error);
    if (context != null && context.mounted) {
      AppSnack.show(context, message: msg, type: SnackType.error);
    } else {
      AppSnack.showGlobal(message: msg, type: SnackType.error);
    }
  }
}

/// Runs [body] inside a guarded zone — catches async errors in release.
Future<void> runAppGuarded(Future<void> Function() body) async {
  runZonedGuarded(
    () async => body(),
    (error, stack) {
      AppErrorHandler._log(error, stack);
    },
  );
}
