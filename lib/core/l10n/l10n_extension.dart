// lib/core/l10n/l10n_extension.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../cubit/app_cubit.dart';
import '../di/service_locator.dart';
import 'app_translations.dart';

extension L10nContext on BuildContext {
  /// Current language code — safe to call anywhere (read, not select).
  /// For reactive rebuilds on language change, use [tr] or [watch] directly.
  String get langCode => read<AppCubit>().state.languageCode;

  /// Current currency symbol — safe to call anywhere.
  String get currencySymbol => read<AppCubit>().state.symbol;

  /// Translate [key] for the active locale.
  /// Uses [watch] so the widget rebuilds when language changes.
  /// Must only be called inside a build() method.
  String tr(String key) {
    final code = watch<AppCubit>().state.languageCode;
    return AppTranslations.tr(code, key);
  }

  /// Locale-aware compact amount string, e.g. £12.5K or ৳১২K
  /// Uses [watch] so the widget rebuilds when language changes.
  /// Must only be called inside a build() method.
  String fmtAmount(double value) {
    final code = watch<AppCubit>().state.languageCode;
    return _fmtCompact(value, code);
  }

  /// Full precision locale-aware amount, e.g. ৳১২,৫০০.৫০ or $12,500.50
  /// Uses [watch] so the widget rebuilds when language/currency changes.
  String fmtFull(double value) {
    final state = watch<AppCubit>().state;
    return _fmtFull(value, state.languageCode);
  }

  /// Currency symbol + locale-aware full amount.
  String fmtMoney(double value) {
    final state = watch<AppCubit>().state;
    final n = value.abs();
    return '${state.symbol}${_fmtFull(n, state.languageCode)}';
  }
}

/// Translate without a [BuildContext] — safe in cubits, services, callbacks.
String trGlobal(String key) =>
    AppTranslations.tr(getIt<AppCubit>().state.languageCode, key);

/// Format amount without a [BuildContext].
String fmtAmountGlobal(double value) =>
    _fmtCompact(value, getIt<AppCubit>().state.languageCode);

/// Full precision format without a [BuildContext].
String fmtFullGlobal(double value) =>
    _fmtFull(value, getIt<AppCubit>().state.languageCode);

String fmtMoneyGlobal(double value) {
  final state = getIt<AppCubit>().state;
  return '${state.symbol}${_fmtFull(value.abs(), state.languageCode)}';
}

// ── Internal formatters ──────────────────────────────────────────────────────
/// Full precision: 12,500.50 in locale-appropriate number system.
String _fmtFull(double value, String langCode) {
  final locale = _intlLocale(langCode);
  return NumberFormat('#,##0.##', locale).format(value);
}

String _fmtCompact(double value, String langCode) {
  final locale = _intlLocale(langCode);
  if (value.abs() >= 1000000) {
    return '${NumberFormat.compact(locale: locale).format(value / 1000000)}M';
  }
  if (value.abs() >= 1000) {
    return '${NumberFormat('#,##0.#', locale).format(value / 1000)}K';
  }
  return NumberFormat('#,##0.##', locale).format(value);
}

String _intlLocale(String code) => switch (code) {
  'bn' => 'bn',
  'ar' => 'ar',
  'hi' => 'hi',
  'ur' => 'ur',
  'ja' => 'ja',
  'zh' => 'zh',
  'de' => 'de',
  'fr' => 'fr',
  'es' => 'es',
  _    => 'en',
};