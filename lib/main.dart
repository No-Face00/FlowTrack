// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'firebase_options.dart';

void main() async {
  // ── MUST be the very first line ─────────────────────────────
  // This initialises the Flutter engine binding so plugins
  // (SharedPreferences, Firebase, etc.) can talk to native code.
  WidgetsFlutterBinding.ensureInitialized();

  // ── UI chrome ────────────────────────────────────────────────
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:           Colors.transparent,
    statusBarIconBrightness:  Brightness.light,
    systemNavigationBarColor: Colors.transparent,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // ── Read first-launch flag ───────────────────────────────────
  // Safe call: if the plugin channel isn't ready for any reason
  // we fall back to false (show onboarding) instead of crashing.
  final bool seenOnboarding = await _getSeenOnboarding();

  // ── Firebase (uncomment when configured) ─────────────────────
   await Firebase.initializeApp(
   options: DefaultFirebaseOptions.currentPlatform,
   );

  runApp(FlowTrack(seenOnboarding: seenOnboarding));
}

/// Reads the onboarding flag safely.
/// Returns false on any error so the app always starts correctly.
Future<bool> _getSeenOnboarding() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('seen_onboarding') ?? false;
  } catch (e) {
    debugPrint('⚠️ SharedPreferences error: $e');
    return false; // safe default — show onboarding
  }
}