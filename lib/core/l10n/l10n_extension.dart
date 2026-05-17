// lib/core/l10n/l10n_extension.dart
//
// ── L10n helpers ──────────────────────────────────────────────────────────────
//
// context.tr('key')     — translates using live language; rebuilds when language changes
// context.langCode      — current language code (reactive)
// context.fmtAmount(v)  — locale-aware compact amount (e.g. ৳১২K / $12K)
// trGlobal('key')       — translate without BuildContext (cubits, services)
// fmtAmountGlobal(v)    — format without BuildContext

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../cubit/app_cubit.dart';
import '../di/service_locator.dart';
import 'app_translations.dart';

extension L10nContext on BuildContext {
  /// Current language code — reactive (triggers rebuild on change).
  String get langCode =>
      select<AppCubit, String>((c) => c.state.languageCode);

  /// Current currency symbol — reactive.
  String get currencySymbol =>
      select<AppCubit, String>((c) => c.state.symbol);

  /// Translate [key] for the active locale.
  /// Rebuilds the widget whenever the language changes.
  String tr(String key) =>
      AppTranslations.tr(langCode, key);

  /// Locale-aware compact amount string, e.g.  ৳১২.৫K  or  $12.5K
  String fmtAmount(double value) =>
      _fmtCompact(value, langCode);
}

/// Translate without a [BuildContext] — use in cubits, services, trGlobal().
String trGlobal(String key) =>
    AppTranslations.tr(getIt<AppCubit>().state.languageCode, key);

/// Format without a [BuildContext].
String fmtAmountGlobal(double value) =>
    _fmtCompact(value, getIt<AppCubit>().state.languageCode);

// ── Internal formatter ────────────────────────────────────────────────────────
String _fmtCompact(double value, String langCode) {
  // Use the locale-aware intl number format so digit shapes localise properly.
  // e.g. Bengali: ১২,৫০০  Arabic: ١٢٬٥٠٠
  final locale = _intlLocale(langCode);
  if (value.abs() >= 1_000_000) {
    final n = (value / 1_000_000);
    return NumberFormat.compact(locale: locale).format(n) + 'M';
  }
  if (value.abs() >= 1_000) {
    final n = (value / 1_000);
    final fmt = NumberFormat('#,##0.#', locale);
    return '${fmt.format(n)}K';
  }
  return NumberFormat('#,##0.##', locale).format(value);
}

/// Maps app language codes to intl locale identifiers.
String _intlLocale(String code) => switch (code) {
  'bn' => 'bn',   // Bengali — uses Bengali digits
  'ar' => 'ar',   // Arabic — uses Arabic-Indic digits
  'hi' => 'hi',   // Hindi
  'ur' => 'ur',   // Urdu
  'ja' => 'ja',   // Japanese
  'zh' => 'zh',   // Chinese
  'de' => 'de',   // German — uses . as thousands, , as decimal
  'fr' => 'fr',   // French
  'es' => 'es',   // Spanish
  _    => 'en',   // Default English
};