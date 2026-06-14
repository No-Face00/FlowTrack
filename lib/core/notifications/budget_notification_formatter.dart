import 'package:intl/intl.dart';

import '../cubit/app_cubit.dart';
import '../l10n/app_strings.dart';
import '../l10n/app_translations.dart';

/// Budget alert severity derived from spent ÷ limit.
enum BudgetAlertLevel {
  none,
  warning,  // ≥ 70%
  critical, // ≥ 90%
  exceeded, // ≥ 100%
}

/// Stored on [BudgetAlertPayload.level] — persisted in notification JSON.
abstract class BudgetAlertLevelKey {
  static const warning  = 'warning';
  static const critical = 'critical';
  static const exceeded = 'exceeded';
}

/// Reusable, localized budget notification copy (token templates).
class BudgetNotificationFormatter {
  BudgetNotificationFormatter._();

  static BudgetAlertLevel levelForRatio(double ratio) {
    if (ratio >= 1.0) return BudgetAlertLevel.exceeded;
    if (ratio >= 0.90) return BudgetAlertLevel.critical;
    if (ratio >= 0.70) return BudgetAlertLevel.warning;
    return BudgetAlertLevel.none;
  }

  static String levelKey(BudgetAlertLevel level) => switch (level) {
        BudgetAlertLevel.warning  => BudgetAlertLevelKey.warning,
        BudgetAlertLevel.critical => BudgetAlertLevelKey.critical,
        BudgetAlertLevel.exceeded => BudgetAlertLevelKey.exceeded,
        BudgetAlertLevel.none     => BudgetAlertLevelKey.warning,
      };

  static BudgetAlertLevel levelFromKey(String key) => switch (key) {
        BudgetAlertLevelKey.critical => BudgetAlertLevel.critical,
        BudgetAlertLevelKey.exceeded => BudgetAlertLevel.exceeded,
        _                            => BudgetAlertLevel.warning,
      };

  /// Notification list row / banner body.
  static String formatBody({
    required String languageCode,
    required String currencyCode,
    required String categoryLabel,
    required double spent,
    required double limit,
    required String levelKey,
    required int daysLeftInMonth,
  }) {
    final ratio = limit > 0 ? spent / limit : 0.0;
    final pct   = (ratio * 100).clamp(0, 999).round();
    final sym   = CurrencyHelper.symbol(currencyCode);
    final locale = _intlLocale(languageCode);

    String money(double v) =>
        '$sym${NumberFormat('#,##0', locale).format(v.abs())}';

    final spentStr     = money(spent);
    final limitStr     = money(limit);
    final remainingStr = money((limit - spent).clamp(0, double.infinity));
    final overStr      = money(spent - limit);

    final templateKey = switch (levelKey) {
      BudgetAlertLevelKey.exceeded => S.budgetNotifBodyExceeded,
      BudgetAlertLevelKey.critical => S.budgetNotifBodyCritical,
      _                            => S.budgetNotifBodyWarning,
    };

    return _render(languageCode, templateKey, {
      'category':  categoryLabel,
      'pct':       '$pct',
      'spent':     spentStr,
      'limit':     limitStr,
      'remaining': remainingStr,
      'over':      overStr,
      'days':      '$daysLeftInMonth',
    });
  }

  /// Short title: emoji + category label + severity chip text.
  static String formatTitle({
    required String languageCode,
    required String categoryLabel,
    required String emoji,
    required String levelKey,
  }) {
    final severity = switch (levelKey) {
      BudgetAlertLevelKey.exceeded => tr(languageCode, S.budgetNotifTitleExceeded),
      BudgetAlertLevelKey.critical => tr(languageCode, S.budgetNotifTitleCritical),
      _                            => tr(languageCode, S.budgetNotifTitleWarning),
    };
    return '$emoji $categoryLabel · $severity';
  }

  static String chipLabel(String languageCode, String levelKey) =>
      switch (levelKey) {
        BudgetAlertLevelKey.exceeded =>
          tr(languageCode, S.notifChipExceeded),
        BudgetAlertLevelKey.critical =>
          tr(languageCode, S.notifChipCritical),
        _ => tr(languageCode, S.notifChipWarning),
      };

  static String tr(String languageCode, String key) =>
      AppTranslations.tr(languageCode, key);

  static String _render(
    String languageCode,
    String key,
    Map<String, String> vars,
  ) {
    var t = AppTranslations.tr(languageCode, key);
    vars.forEach((k, v) => t = t.replaceAll('{$k}', v));
    return t;
  }

  static String _intlLocale(String code) => switch (code) {
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
}
