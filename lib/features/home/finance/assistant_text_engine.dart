import 'dart:math';

import 'package:intl/intl.dart';

import '../../../core/cubit/app_cubit.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/app_translations.dart';
import 'finance_assistant_prefs.dart';
import 'finance_snapshot.dart';
import 'insight_type.dart';

/// Offline-first "real-time coach" text engine.
///
/// - Uses tokenized localized templates from [AppTranslations]
/// - Rotates patterns to avoid repetitive insights
/// - Produces human-like, practical guidance using live [FinanceSnapshot]
class AssistantTextEngine {
  AssistantTextEngine._();

  static Future<GeneratedInsight> generate(FinanceSnapshot s, {required String languageCode}) async {
    final now = s.now;
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysLeft = max(0, daysInMonth - now.day);

    final sym = getIt<AppCubit>().state.symbol;
    final locale = _intlLocale(languageCode);

    String money(num v) => '$sym${NumberFormat('#,##0', locale).format(v)}';

    final recent = await FinanceAssistantPrefs.getRecentPatternKeys();

    // ── 1) Budget pressure (most urgent) ──────────────────────────────────
    final p = s.budgetPressure.isNotEmpty ? s.budgetPressure.first : null;
    if (p != null && p.limit > 0) {
      final pctUsed = (p.ratio * 100).round();
      if (p.ratio >= 1.0) {
        final over = money((p.spent - p.limit).abs());
        final key = _pick(['fa_warn_2', 'fa_warn_1'], avoid: recent);
        final text = _render(languageCode, key, {
          'cat': p.label,
          'pct': '$pctUsed',
          'days': '$daysLeft',
          'over': over,
          'spent': money(p.spent),
          'limit': money(p.limit),
        });
        await FinanceAssistantPrefs.pushRecentPatternKey(key);
        return GeneratedInsight(text: text, type: InsightType.warning);
      }
      if (p.ratio >= 0.80 && daysLeft >= 3) {
        final key = _pick(['fa_warn_1', 'fa_warn_2'], avoid: recent);
        final over = money((p.spent - p.limit).abs());
        final text = _render(languageCode, key, {
          'cat': p.label,
          'pct': '$pctUsed',
          'days': '$daysLeft',
          'over': over,
          'spent': money(p.spent),
          'limit': money(p.limit),
        });
        await FinanceAssistantPrefs.pushRecentPatternKey(key);
        return GeneratedInsight(text: text, type: InsightType.warning);
      }
    }

    // ── 2) Week-over-week category spike ───────────────────────────────────
    final wow = s.toGeminiJson()['weekOverWeek'] as List;
    Map<String, dynamic>? spike;
    for (final e in wow) {
      final change = (e['changePct'] as num).toDouble();
      final thisW = (e['thisWeek'] as num).toDouble();
      if (thisW <= 0) continue;
      if (change >= 22) {
        spike = Map<String, dynamic>.from(e as Map);
        break;
      }
    }
    if (spike != null) {
      final cat = (spike['category'] as String).trim();
      final chg = (spike['changePct'] as num).abs().round();
      final key = _pick(['fa_spike_1', 'fa_spike_2'], avoid: recent);
      final text = _render(languageCode, key, {
        'cat': _cap(cat),
        'chg': '$chg',
        'days': '$daysLeft',
      });
      await FinanceAssistantPrefs.pushRecentPatternKey(key);
      return GeneratedInsight(text: text, type: InsightType.spending);
    }

    // ── 3) Income vs expense health + savings trend ─────────────────────────
    final mi = s.monthIncome;
    final me = s.monthExpense;
    if (mi > 0 && me > 0) {
      final ratio = (me / mi * 100).round().clamp(0, 999);
      if (ratio >= 95) {
        final key = _pick(['fa_warn_1', 'fa_spike_2'], avoid: recent);
        final text = _render(languageCode, key, {
          'cat': _tr(languageCode, S.expenses),
          'pct': '$ratio',
          'days': '$daysLeft',
          'over': money((me - mi).abs()),
          'spent': money(me),
          'limit': money(mi),
          'chg': '${min(100, max(10, ratio - 80))}',
          'ratio': '$ratio',
        });
        await FinanceAssistantPrefs.pushRecentPatternKey(key);
        return GeneratedInsight(text: text, type: InsightType.warning);
      }
      if (ratio <= 65) {
        final key = _pick(['fa_save_1', 'fa_motiv_1'], avoid: recent);
        final text = _render(languageCode, key, {
          'ratio': '$ratio',
          'days': '$daysLeft',
        });
        await FinanceAssistantPrefs.pushRecentPatternKey(key);
        return GeneratedInsight(text: text, type: InsightType.saving);
      }
    }

    // ── 4) Month vs last month improvement (gentle) ─────────────────────────
    if (s.lastMonthExpense > 0 && s.monthExpense > 0) {
      final change = ((s.monthExpense - s.lastMonthExpense) / s.lastMonthExpense * 100);
      if (change <= -10) {
        final key = _pick(['fa_save_2', 'fa_motiv_2'], avoid: recent);
        final text = _render(languageCode, key, {'days': '$daysLeft'});
        await FinanceAssistantPrefs.pushRecentPatternKey(key);
        return GeneratedInsight(text: text, type: InsightType.motivation);
      }
    }

    // ── 5) Neutral coach voice ──────────────────────────────────────────────
    final key = _pick(['fa_neutral_1', 'fa_neutral_2', 'fa_motiv_2'], avoid: recent);
    final text = _render(languageCode, key, {'days': '$daysLeft'});
    await FinanceAssistantPrefs.pushRecentPatternKey(key);
    return GeneratedInsight(text: text, type: InsightType.neutral);
  }

  static String _render(String languageCode, String key, Map<String, String> vars) {
    var t = AppTranslations.tr(languageCode, key);
    vars.forEach((k, v) => t = t.replaceAll('{$k}', v));
    return t;
  }

  static String _pick(List<String> keys, {required List<String> avoid}) {
    final options = keys.where((k) => !avoid.contains(k)).toList();
    final pickFrom = options.isNotEmpty ? options : keys;
    final rnd = Random();
    return pickFrom[rnd.nextInt(pickFrom.length)];
  }

  static String _tr(String languageCode, String key) =>
      AppTranslations.tr(languageCode, key);

  static String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

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
        _ => 'en',
      };
}

class GeneratedInsight {
  const GeneratedInsight({required this.text, required this.type});
  final String text;
  final InsightType type;
}

