// lib/core/cubit/app_cubit.dart
//
// ── AppCubit ──────────────────────────────────────────────────────────────────
//
// SINGLE SOURCE OF TRUTH for two global settings:
//   • ThemeMode  (light / dark / system)
//   • Currency   (BDT / USD / EUR / …)
//
// WHY a dedicated cubit and not BalanceCubit?
//   BalanceCubit re-emits every time a transaction changes.
//   If ThemeMode lived there, the whole app would re-theme on every delete.
//   AppCubit only emits when the user explicitly changes a setting.
//
// PERSISTENCE STRATEGY:
//   SharedPreferences  → instant load on cold start, no network needed
//   Firestore          → syncs across devices for the same account
//   On startup:        SharedPrefs is read first (instant), then Firestore
//                      overwrites if different (background).
//
// HOW SCREENS USE IT:
//   Read:  context.watch<AppCubit>().state.currency
//          context.watch<AppCubit>().state.themeMode
//   Write: context.read<AppCubit>().setCurrency('USD')
//          context.read<AppCubit>().setTheme(ThemeMode.dark)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Lazy import — BalanceCubit is only accessed via getIt, which resolves
// lazily. This avoids a circular dependency (balance_cubit → app_cubit → balance_cubit).
import '../di/service_locator.dart';
import '../../features/transactions/presentation/cubit/balance_cubit.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class AppSettings {
  final String    currency;
  final ThemeMode themeMode;

  const AppSettings({
    this.currency  = 'BDT',
    this.themeMode = ThemeMode.light,
  });

  AppSettings copyWith({String? currency, ThemeMode? themeMode}) => AppSettings(
    currency:  currency  ?? this.currency,
    themeMode: themeMode ?? this.themeMode,
  );

  // Maps currency code → display symbol
  String get symbol => CurrencyHelper.symbol(currency);
}

// ── Cubit ─────────────────────────────────────────────────────────────────────

class AppCubit extends Cubit<AppSettings> {
  AppCubit() : super(const AppSettings());

  static const _kCurrency  = 'app_currency';
  static const _kTheme     = 'app_theme'; // 'light' | 'dark' | 'system'

  // ── Load settings (call once after login) ────────────────────────────────
  /// Reads from SharedPrefs (instant), then syncs from Firestore (background).
  Future<void> load() async {
    // 1. Load from local cache immediately — zero latency
    final prefs = await SharedPreferences.getInstance();
    final localCurrency = prefs.getString(_kCurrency) ?? 'BDT';
    final localTheme    = _themeFromString(prefs.getString(_kTheme) ?? 'light');
    emit(AppSettings(currency: localCurrency, themeMode: localTheme));

    // 2. Sync from Firestore in background
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(uid).get();
      final data = doc.data();
      if (data == null) return;

      final remoteCurrency = data['currency'] as String? ?? localCurrency;
      final remoteTheme    = _themeFromString(data['theme'] as String? ?? 'light');

      if (remoteCurrency != localCurrency || remoteTheme != localTheme) {
        await prefs.setString(_kCurrency, remoteCurrency);
        await prefs.setString(_kTheme, _themeToString(remoteTheme));
        emit(AppSettings(currency: remoteCurrency, themeMode: remoteTheme));
      }
    } catch (_) {}
  }

  // ── Currency change ───────────────────────────────────────────────────────
  Future<void> setCurrency(String code) async {
    if (state.currency == code) return;   // no-op if unchanged
    emit(state.copyWith(currency: code));
    _persist(currency: code);
    // Instantly propagate to BalanceCubit so every screen that reads
    // BalanceLoaded.symbol rebuilds without needing a Firestore round-trip.
    try {
      getIt<BalanceCubit>().refreshCurrency();
    } catch (_) {} // getIt may not have BalanceCubit registered yet during tests
  }

  // ── Theme change ──────────────────────────────────────────────────────────
  Future<void> setTheme(ThemeMode mode) async {
    emit(state.copyWith(themeMode: mode));
    _persist(theme: mode);
  }

  // ── Private: persist to both stores ──────────────────────────────────────
  Future<void> _persist({String? currency, ThemeMode? theme}) async {
    final prefs = await SharedPreferences.getInstance();
    if (currency != null) await prefs.setString(_kCurrency, currency);
    if (theme    != null) await prefs.setString(_kTheme, _themeToString(theme));

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final Map<String, dynamic> update = {};
      if (currency != null) update['currency'] = currency;
      if (theme    != null) update['theme']     = _themeToString(theme);
      if (update.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users').doc(uid)
            .update(update);
      }
    } catch (_) {}
  }

  static ThemeMode _themeFromString(String s) => switch (s) {
    'dark'   => ThemeMode.dark,
    'system' => ThemeMode.system,
    _        => ThemeMode.light,
  };

  static String _themeToString(ThemeMode m) => switch (m) {
    ThemeMode.dark   => 'dark',
    ThemeMode.system => 'system',
    _                => 'light',
  };
}

// ── CurrencyHelper ────────────────────────────────────────────────────────────

class CurrencyHelper {
  CurrencyHelper._();

  static const _symbols = <String, String>{
    'BDT': '৳',
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'INR': '₹',
    'JPY': '¥',
    'CAD': 'CA\$',
    'AUD': 'A\$',
    'SGD': 'S\$',
    'CHF': 'Fr',
    'MYR': 'RM',
    'AED': 'د.إ',
    'SAR': '﷼',
  };

  static const _names = <String, String>{
    'BDT': 'Bangladeshi Taka',
    'USD': 'US Dollar',
    'EUR': 'Euro',
    'GBP': 'British Pound',
    'INR': 'Indian Rupee',
    'JPY': 'Japanese Yen',
    'CAD': 'Canadian Dollar',
    'AUD': 'Australian Dollar',
    'SGD': 'Singapore Dollar',
    'CHF': 'Swiss Franc',
    'MYR': 'Malaysian Ringgit',
    'AED': 'UAE Dirham',
    'SAR': 'Saudi Riyal',
  };

  static String symbol(String code) => _symbols[code] ?? code;
  static String name(String code)   => _names[code]   ?? code;

  static List<String> get supported => _symbols.keys.toList();

  /// Compact numeric part for inline money text (no symbol). Used by
  /// notifications, snackbars, and other UI that should stay consistent.
  static String formatCompactAmount(double v) {
    if (v >= 1000000) {
      return '${(v / 1000000).toStringAsFixed(1)}M';
    }
    if (v >= 1000) {
      return '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}K';
    }
    return v.toStringAsFixed(v % 1 == 0 ? 0 : 1);
  }

  // ── Detect default currency from device locale/timezone ─────────────────
  /// Called during registration to set a sensible default.
  /// Uses the device's locale country code as the primary signal,
  /// falls back to timezone offset heuristics.
  static String detectDefault() {
    // Flutter's Locale uses IETF language tags: 'en_US', 'bn_BD', etc.
    // WidgetsBinding.instance.platformDispatcher.locale is always available.
    try {
      final locale = WidgetsBinding
          .instance.platformDispatcher.locale.countryCode?.toUpperCase() ?? '';
      if (locale.isNotEmpty) {
        final fromLocale = _countryToCurrency[locale];
        if (fromLocale != null) return fromLocale;
      }
    } catch (_) {}

    // Fallback: system timezone offset (very rough)
    final offset = DateTime.now().timeZoneOffset.inHours;
    if (offset == 6)  return 'BDT'; // Asia/Dhaka
    if (offset >= -5 && offset <= -4) return 'USD';
    if (offset >= 0  && offset <= 2)  return 'EUR';
    if (offset == 5 || offset == 5)   return 'INR';
    return 'USD';
  }

  static const _countryToCurrency = <String, String>{
    'BD': 'BDT', // Bangladesh
    'US': 'USD', // United States
    'CA': 'CAD', // Canada
    'AU': 'AUD', // Australia
    'GB': 'GBP', // UK
    'IE': 'EUR', // Ireland
    'DE': 'EUR', // Germany
    'FR': 'EUR', // France
    'IT': 'EUR', // Italy
    'ES': 'EUR', // Spain
    'NL': 'EUR', // Netherlands
    'BE': 'EUR', // Belgium
    'AT': 'EUR', // Austria
    'PT': 'EUR', // Portugal
    'FI': 'EUR', // Finland
    'IN': 'INR', // India
    'PK': 'PKR', // Pakistan — not in our list, fall through to USD
    'JP': 'JPY', // Japan
    'SG': 'SGD', // Singapore
    'MY': 'MYR', // Malaysia
    'CH': 'CHF', // Switzerland
    'AE': 'AED', // UAE
    'SA': 'SAR', // Saudi Arabia
    'CN': 'CNY', // China — not in our list
    'KR': 'KRW', // Korea — not in our list
  };
}