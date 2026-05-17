// lib/core/l10n/app_locale.dart
import 'package:flutter/material.dart';

class AppLocaleOption {
  const AppLocaleOption({
    required this.code,
    required this.name,
    required this.nativeName,
    this.rtl = false,
  });

  final String code;
  final String name;
  final String nativeName;
  final bool   rtl;

  Locale get locale => Locale(code);
}

class AppLocales {
  AppLocales._();

  static const options = <AppLocaleOption>[
    AppLocaleOption(code: 'en', name: 'English',  nativeName: 'English'),
    AppLocaleOption(code: 'bn', name: 'Bangla',   nativeName: 'বাংলা'),
    AppLocaleOption(code: 'ar', name: 'Arabic',   nativeName: 'العربية', rtl: true),
    AppLocaleOption(code: 'hi', name: 'Hindi',    nativeName: 'हिन्दी'),
    AppLocaleOption(code: 'ur', name: 'Urdu',     nativeName: 'اردو',    rtl: true),
    AppLocaleOption(code: 'es', name: 'Spanish',  nativeName: 'Español'),
    AppLocaleOption(code: 'fr', name: 'French',   nativeName: 'Français'),
    AppLocaleOption(code: 'de', name: 'German',   nativeName: 'Deutsch'),
    AppLocaleOption(code: 'zh', name: 'Chinese',  nativeName: '中文'),
    AppLocaleOption(code: 'ja', name: 'Japanese', nativeName: '日本語'),
  ];

  static AppLocaleOption? find(String code) {
    for (final o in options) {
      if (o.code == code) return o;
    }
    return null;
  }

  static bool isRtl(String code) => find(code)?.rtl ?? false;

  static List<Locale> get supported =>
      options.map((o) => o.locale).toList();

  /// Returns the correct [TextDirection] for [code].
  ///
  /// Defined HERE (in a file that only imports flutter/material.dart)
  /// so that app.dart never needs to reference TextDirection directly.
  /// This sidesteps the dart:ui transitive scope pollution that causes
  /// "Member not found: 'rtl'" when other files have bare `import 'dart:ui'`.
  static TextDirection textDirectionFor(String code) =>
      isRtl(code) ? TextDirection.rtl : TextDirection.ltr;

  /// Wraps [child] in a [Directionality] for [languageCode].
  /// Use this in app.dart instead of referencing TextDirection directly.
  static Widget wrapWithDirectionality({
    required String  languageCode,
    required Widget? child,
  }) {
    return Directionality(
      textDirection: textDirectionFor(languageCode),
      child: child ?? const SizedBox.shrink(),
    );
  }
}