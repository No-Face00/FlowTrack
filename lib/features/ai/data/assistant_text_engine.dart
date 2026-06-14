

import 'dart:math';

import 'package:intl/intl.dart';

import '../../../core/cubit/app_cubit.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/app_translations.dart';
import 'finance_assistant_prefs.dart';
import 'finance_snapshot.dart';
import 'insight_type.dart';

class AssistantTextEngine {
  AssistantTextEngine._();

  static Future<GeneratedInsight> generate(
      FinanceSnapshot s, {
        required String languageCode,
      }) async {
    final now         = s.now;
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysPassed  = now.day.clamp(1, daysInMonth);
    final daysLeft    = (daysInMonth - daysPassed).clamp(0, 31);

    final sym    = getIt<AppCubit>().state.symbol;
    final locale = _intlLocale(languageCode);

    String money(num v) => '$sym${NumberFormat('#,##0', locale).format(v)}';

    final recent = await FinanceAssistantPrefs.getRecentPatternKeys();

    // ── 1) Budget overflow (ratio ≥ 1.0) ──────────────────────────────────
    final overflows = s.budgetPressure.where((b) => b.ratio >= 1.0).toList();
    if (overflows.isNotEmpty) {
      final p      = overflows.first;
      final over   = (p.spent - p.limit).abs();
      final pct    = (p.ratio * 100).round();
      final allowedPerDay = daysLeft > 0 ? 0.0 : 0.0; // already over
      final key    = _pick(['fa_warn_2', 'fa_warn_1'], avoid: recent);
      final text   = _render(languageCode, key, {
        'cat':    p.label,
        'pct':    '$pct',
        'days':   '$daysLeft',
        'over':   money(over),
        'spent':  money(p.spent),
        'limit':  money(p.limit),
        'daily':  money(daysLeft > 0 ? allowedPerDay : 0),
      });
      await FinanceAssistantPrefs.pushRecentPatternKey(key);
      return GeneratedInsight(text: text, type: InsightType.warning);
    }

    // ── 2) High-risk budget pressure (80–99 %) with velocity projection ───
    final atRisk = s.budgetPressure.where((b) => b.ratio >= 0.80).toList();
    if (atRisk.isNotEmpty) {
      final p                = atRisk.first;
      final pct              = (p.ratio * 100).round();
      final remaining        = p.limit - p.spent;
      final dailyBurn        = daysPassed > 0 ? p.spent / daysPassed : 0.0;
      final projectedOverRaw = dailyBurn * daysInMonth - p.limit;
      final projectedOver    = projectedOverRaw > 0 ? projectedOverRaw : 0.0;
      final key              = _pick(['fa_warn_1', 'fa_warn_2'], avoid: recent);
      final text             = _render(languageCode, key, {
        'cat':        p.label,
        'pct':        '$pct',
        'days':       '$daysLeft',
        'over':       money(projectedOver > 0 ? projectedOver : remaining),
        'spent':      money(p.spent),
        'limit':      money(p.limit),
        'remaining':  money(remaining),
        'daily_burn': money(dailyBurn),
      });
      await FinanceAssistantPrefs.pushRecentPatternKey(key);
      return GeneratedInsight(text: text, type: InsightType.warning);
    }

    // ── 3) Spending velocity (early-month overpace, < 80 % but fast) ──────
    if (daysPassed >= 5) {
      for (final b in s.budgetPressure) {
        if (b.limit <= 0 || b.ratio >= 0.80) continue;
        final expectedByNow = b.limit * (daysPassed / daysInMonth);
        if (b.spent > expectedByNow * 1.30) {
          final aheadOf = b.spent - expectedByNow;
          final key     = _pick(['fa_spike_1', 'fa_warn_1'], avoid: recent);
          final text    = _render(languageCode, key, {
            'cat':  b.label,
            'chg':  '${((b.spent / expectedByNow - 1) * 100).round()}',
            'days': '$daysLeft',
            'over': money(aheadOf),
            'spent': money(b.spent),
            'limit': money(b.limit),
            'pct':  '${(b.ratio * 100).round()}',
          });
          await FinanceAssistantPrefs.pushRecentPatternKey(key);
          return GeneratedInsight(text: text, type: InsightType.spending);
        }
      }
    }

    // ── 4) Week-over-week category spike ───────────────────────────────────
    final wow = s.toGeminiJson()['weekOverWeek'] as List;
    Map<String, dynamic>? spike;
    for (final e in wow) {
      final change = (e['changePct'] as num).toDouble();
      final thisW  = (e['thisWeek'] as num).toDouble();
      if (thisW <= 0) continue;
      if (change >= 22) {
        spike = Map<String, dynamic>.from(e as Map);
        break;
      }
    }
    if (spike != null) {
      final cat  = (spike['category'] as String).trim();
      final chg  = (spike['changePct'] as num).abs().round();
      final thisW = (spike['thisWeek'] as num).toDouble();
      final prevW = (spike['prevWeek'] as num).toDouble();
      final key  = _pick(['fa_spike_1', 'fa_spike_2'], avoid: recent);
      final text = _render(languageCode, key, {
        'cat':   _cap(cat),
        'chg':   '$chg',
        'days':  '$daysLeft',
        'spent': money(thisW),
        'over':  money(thisW - prevW),
        'limit': money(prevW > 0 ? prevW : thisW),
        'pct':   '$chg',
      });
      await FinanceAssistantPrefs.pushRecentPatternKey(key);
      return GeneratedInsight(text: text, type: InsightType.spending);
    }

    // ── 5) Income vs expense health + savings ──────────────────────────────
    final mi = s.monthIncome;
    final me = s.monthExpense;
    if (mi > 0 && me > 0) {
      final ratio = me / mi;

      if (ratio >= 0.95) {
        final gap = me - mi;
        final key = _pick(['fa_warn_1', 'fa_spike_2'], avoid: recent);
        final text = _render(languageCode, key, {
          'cat':   _tr(languageCode, S.expenses),
          'pct':   '${(ratio * 100).round()}',
          'days':  '$daysLeft',
          'over':  money(gap > 0 ? gap : 0),
          'spent': money(me),
          'limit': money(mi),
          'chg':   '${(ratio * 100 - 80).clamp(0, 100).round()}',
          'ratio': '${(ratio * 100).round()}',
        });
        await FinanceAssistantPrefs.pushRecentPatternKey(key);
        return GeneratedInsight(text: text, type: InsightType.warning);
      }

      if (ratio <= 0.62) {
        final saveRate = ((1 - ratio) * 100).round();
        final key = _pick(['fa_save_1', 'fa_motiv_1'], avoid: recent);
        final text = _render(languageCode, key, {
          'ratio': '$saveRate',
          'days':  '$daysLeft',
          'spent': money(me),
          'limit': money(mi),
          'over':  money(mi - me),
        });
        await FinanceAssistantPrefs.pushRecentPatternKey(key);
        return GeneratedInsight(text: text, type: InsightType.saving);
      }
    }

    // ── 6) Month vs last month improvement ────────────────────────────────
    if (s.lastMonthExpense > 0 && s.monthExpense > 0) {
      final change = (s.monthExpense - s.lastMonthExpense) / s.lastMonthExpense * 100;
      if (change <= -10) {
        final key  = _pick(['fa_save_2', 'fa_motiv_2'], avoid: recent);
        final text = _render(languageCode, key, {
          'days':  '$daysLeft',
          'chg':   '${(-change).round()}',
          'over':  money((s.lastMonthExpense - s.monthExpense).abs()),
          'spent': money(s.monthExpense),
          'limit': money(s.lastMonthExpense),
          'pct':   '${(-change).round()}',
        });
        await FinanceAssistantPrefs.pushRecentPatternKey(key);
        return GeneratedInsight(text: text, type: InsightType.motivation);
      }
      if (change >= 15) {
        final key  = _pick(['fa_spike_1', 'fa_spike_2'], avoid: recent);
        final text = _render(languageCode, key, {
          'cat':   _tr(languageCode, S.expenses),
          'chg':   '${change.round()}',
          'days':  '$daysLeft',
          'spent': money(s.monthExpense),
          'over':  money((s.monthExpense - s.lastMonthExpense).abs()),
          'limit': money(s.lastMonthExpense),
          'pct':   '${change.round()}',
        });
        await FinanceAssistantPrefs.pushRecentPatternKey(key);
        return GeneratedInsight(text: text, type: InsightType.spending);
      }
    }

    // ── 7) Neutral / encouragement ────────────────────────────────────────
    final budgetsOnTrack = s.budgetPressure.where((b) => b.ratio < 0.80).length;
    final totalBudgets   = s.budgetPressure.length;
    final key = totalBudgets > 0
        ? _pick(['fa_neutral_1', 'fa_motiv_1'], avoid: recent)
        : _pick(['fa_neutral_1', 'fa_neutral_2', 'fa_motiv_2'], avoid: recent);
    final text = _render(languageCode, key, {
      'days':  '$daysLeft',
      'ratio': totalBudgets > 0 ? '$budgetsOnTrack/$totalBudgets' : '—',
      'spent': money(me > 0 ? me : 0),
      'limit': money(mi > 0 ? mi : 0),
      'over':  money(0),
      'pct':   mi > 0 && me > 0 ? '${(me / mi * 100).round()}' : '—',
      'chg':   '0',
      'cat':   '',
    });
    await FinanceAssistantPrefs.pushRecentPatternKey(key);
    return GeneratedInsight(text: text, type: InsightType.neutral);
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  static String _render(String languageCode, String key, Map<String, String> vars) {
    var t = AppTranslations.tr(languageCode, key);
    vars.forEach((k, v) => t = t.replaceAll('{$k}', v));
    // Clean up any unreplaced tokens so the UI never shows raw placeholders.
    t = t.replaceAll(RegExp(r'\{[a-z_]+\}'), '—');
    return t;
  }

  static String _pick(List<String> keys, {required List<String> avoid}) {
    final options  = keys.where((k) => !avoid.contains(k)).toList();
    final pickFrom = options.isNotEmpty ? options : keys;
    return pickFrom[Random().nextInt(pickFrom.length)];
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
    _    => 'en',
  };
}

class GeneratedInsight {
  const GeneratedInsight({required this.text, required this.type});
  final String      text;
  final InsightType type;
}