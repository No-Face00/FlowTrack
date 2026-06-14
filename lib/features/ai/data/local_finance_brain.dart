
import 'package:intl/intl.dart';

import '../../../core/l10n/app_translations.dart';
import 'finance_snapshot.dart';
import 'insight_type.dart';

class AssistantInsight {
  const AssistantInsight({
    required this.headline,
    required this.bullets,
    this.type = InsightType.neutral,
  });

  final String      headline;
  final List<String> bullets;
  final InsightType  type;

  AssistantInsight copyWith({
    String?      headline,
    List<String>? bullets,
    InsightType? type,
  }) =>
      AssistantInsight(
        headline: headline ?? this.headline,
        bullets:  bullets  ?? this.bullets,
        type:     type     ?? this.type,
      );
}

/// Rule-based multi-category finance coach — fully offline, always available.
///
/// Analysis priority order:
///  1) Critical budget overflows  — ALL categories ≥ 100%
///  2) High-risk budget pressure  — ALL categories 80–99%
///  3) Spending velocity          — ALL categories pacing over-limit
///  4) Week-over-week spike       — top spending jump
///  5) Income vs expense health
///  6) Month-over-month trend
///  7) Top-category concentration
///  8) All-time savings rate
///  9) Neutral / encouraging coach
class LocalFinanceBrain {
  LocalFinanceBrain._();

  /// [languageCode] must be the app's active language code so all text
  /// is rendered in the correct language.
  static AssistantInsight generate(
      FinanceSnapshot s, {
        String languageCode = 'en',
      }) {
    final now         = s.now;
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysPassed  = now.day.clamp(1, daysInMonth);
    final daysLeft    = (daysInMonth - daysPassed).clamp(0, 31);
    final sym         = _sym(s.currencyCode);

    String money(num v) =>
        '$sym${NumberFormat('#,##0', _intlLocale(languageCode)).format(v)}';

    // ── 1) Critical overflows — ALL categories ≥ 100% ─────────────────────
    final overBudget = s.budgetPressure.where((b) => b.ratio >= 1.0).toList();
    if (overBudget.isNotEmpty) {
      // Headline: count and worst category
      final worst   = overBudget.first; // sorted desc by ratio already
      final over    = worst.spent - worst.limit;
      final worstPct = (worst.ratio * 100).round();

      // Build a bullet for EVERY over-budget category
      final bullets = <String>[];
      for (final b in overBudget) {
        final bOver = b.spent - b.limit;
        final bPct  = (b.ratio * 100).round();
        bullets.add(
          _tr(languageCode, 'fa_budget_overflow_item', {
            'cat':   b.label,
            'spent': money(b.spent),
            'limit': money(b.limit),
            'over':  money(bOver),
            'pct':   '$bPct',
          }),
        );
      }

      // Add velocity / recovery advice for worst category
      if (daysLeft > 0) {
        final allowedPerDay = (worst.limit - worst.spent).abs() / daysLeft;
        bullets.add(
          _tr(languageCode, 'fa_recovery_tip', {
            'cat':   worst.label,
            'daily': money(allowedPerDay > 0 ? 0 : 0), // already over; show 0
            'days':  '$daysLeft',
          }),
        );
      }

      // Warn if total expenses exceed income
      if (s.monthExpense > s.monthIncome && s.monthIncome > 0) {
        bullets.add(_tr(languageCode, 'fa_income_exceeded', {}));
      }

      return AssistantInsight(
        type:     InsightType.warning,
        headline: _tr(languageCode, 'fa_overflow_headline', {
          'count': '${overBudget.length}',
          'cat':   worst.label,
          'over':  money(over),
          'pct':   '$worstPct',
        }),
        bullets: _trim(bullets),
      );
    }

    // ── 2) High-risk pressure — ALL categories 80–99% ─────────────────────
    final atRisk = s.budgetPressure
        .where((b) => b.ratio >= 0.80 && b.ratio < 1.0)
        .toList();
    if (atRisk.isNotEmpty) {
      final bullets = <String>[];
      for (final b in atRisk) {
        final pct       = (b.ratio * 100).round();
        final remaining = b.limit - b.spent;
        final dailyBurn = daysPassed > 0 ? b.spent / daysPassed : 0.0;
        final projected = dailyBurn * daysInMonth - b.limit;

        bullets.add(
          _tr(languageCode, 'fa_risk_item', {
            'cat':       b.label,
            'pct':       '$pct',
            'remaining': money(remaining),
            'days':      '$daysLeft',
          }),
        );

        if (projected > 0) {
          bullets.add(
            _tr(languageCode, 'fa_projection_tip', {
              'cat':  b.label,
              'over': money(projected),
            }),
          );
        }
      }

      final top    = atRisk.first;
      final topPct = (top.ratio * 100).round();

      return AssistantInsight(
        type:     InsightType.warning,
        headline: _tr(languageCode, 'fa_risk_headline', {
          'count': '${atRisk.length}',
          'cat':   top.label,
          'pct':   '$topPct',
          'days':  '$daysLeft',
        }),
        bullets: _trim(bullets),
      );
    }

    // ── 3) Spending velocity — ALL fast-burning categories ─────────────────
    if (daysPassed >= 5 && s.budgetPressure.isNotEmpty) {
      final fastBurners = <BudgetPressure>[];
      for (final b in s.budgetPressure) {
        if (b.limit <= 0 || b.ratio >= 0.80) continue;
        final expected = b.limit * (daysPassed / daysInMonth);
        if (b.spent > expected * 1.30) fastBurners.add(b);
      }

      if (fastBurners.isNotEmpty) {
        final bullets = fastBurners.map((b) {
          final ahead = b.spent - b.limit * (daysPassed / daysInMonth);
          return _tr(languageCode, 'fa_velocity_item', {
            'cat':   b.label,
            'ahead': money(ahead),
            'days':  '$daysLeft',
          });
        }).toList();

        bullets.add(_tr(languageCode, 'fa_velocity_footer', {
          'day':   '$daysPassed',
          'total': '$daysInMonth',
        }));

        return AssistantInsight(
          type:     InsightType.spending,
          headline: _tr(languageCode, 'fa_velocity_headline', {
            'count': '${fastBurners.length}',
          }),
          bullets: _trim(bullets),
        );
      }
    }

    // ── 4) Week-over-week spike ─────────────────────────────────────────────
    final wow = s.toGeminiJson()['weekOverWeek'] as List;
    for (final e in wow) {
      final cat   = (e['category'] as String).trim();
      final ch    = (e['changePct'] as num).toDouble();
      final thisW = (e['thisWeek']  as num).toDouble();
      final prevW = (e['prevWeek']  as num).toDouble();
      if (ch >= 25 && thisW > 0) {
        return AssistantInsight(
          type:     InsightType.spending,
          headline: _tr(languageCode, 'fa_spike_headline', {
            'cat': _cap(cat),
            'chg': '${ch.round()}',
          }),
          bullets: _trim([
            _tr(languageCode, 'fa_spike_item', {
              'cat':  _cap(cat),
              'chg':  '${ch.round()}',
              'this': money(thisW),
              'prev': money(prevW),
            }),
            _budgetContextForCategory(cat, s, languageCode, money),
            _tr(languageCode, 'fa_spike_warning', {}),
          ]),
        );
      }
    }

    // ── 5) Income vs expense health ─────────────────────────────────────────
    if (s.monthIncome > 0 && s.monthExpense > 0) {
      final ratio = s.monthExpense / s.monthIncome;

      if (ratio >= 0.95) {
        final gap = s.monthExpense - s.monthIncome;
        return AssistantInsight(
          type:     InsightType.warning,
          headline: _tr(languageCode, 'fa_income_warn_headline', {
            'pct': '${(ratio * 100).round()}',
          }),
          bullets: _trim([
            _tr(languageCode, 'fa_income_warn_item', {
              'pct':    '${(ratio * 100).round()}',
              'over':   money(gap > 0 ? gap : 0),
              'income': money(s.monthIncome),
              'spent':  money(s.monthExpense),
            }),
            if (s.budgetPressure.isNotEmpty)
              _tr(languageCode, 'fa_review_all_cats', {
                'count': '${s.budgetPressure.length}',
              }),
          ]),
        );
      }

      if (ratio <= 0.62) {
        final saveRate = ((1 - ratio) * 100).round();
        return AssistantInsight(
          type:     InsightType.saving,
          headline: _tr(languageCode, 'fa_save_headline', {
            'rate': '$saveRate',
          }),
          bullets: _trim([
            _tr(languageCode, 'fa_save_item', {
              'rate':  '$saveRate',
              'saved': money(s.monthIncome - s.monthExpense),
              'days':  '$daysLeft',
            }),
            if (s.budgetPressure.isNotEmpty)
              _tr(languageCode, 'fa_on_track_count', {
                'count': '${s.budgetPressure.where((b) => b.ratio < 0.80).length}',
                'total': '${s.budgetPressure.length}',
              }),
          ]),
        );
      }
    }

    // ── 6) Month-over-month trend ───────────────────────────────────────────
    if (s.lastMonthExpense > 0 && s.monthExpense > 0) {
      final pct = (s.monthExpense - s.lastMonthExpense) / s.lastMonthExpense * 100;

      if (pct >= 15) {
        return AssistantInsight(
          type:     InsightType.spending,
          headline: _tr(languageCode, 'fa_mom_up_headline', {
            'pct': '${pct.round()}',
          }),
          bullets: _trim([
            _tr(languageCode, 'fa_mom_up_item', {
              'pct':  '${pct.round()}',
              'this': money(s.monthExpense),
              'last': money(s.lastMonthExpense),
              'diff': money((s.monthExpense - s.lastMonthExpense).abs()),
              'days': '$daysLeft',
            }),
          ]),
        );
      }

      if (pct <= -12) {
        final saved = s.lastMonthExpense - s.monthExpense;
        return AssistantInsight(
          type:     InsightType.motivation,
          headline: _tr(languageCode, 'fa_mom_down_headline', {
            'pct': '${(-pct).round()}',
          }),
          bullets: _trim([
            _tr(languageCode, 'fa_mom_down_item', {
              'saved': money(saved),
              'pct':   '${(-pct).round()}',
              'days':  '$daysLeft',
            }),
            if (s.monthIncome > 0)
              _tr(languageCode, 'fa_savings_rate_note', {
                'rate': '${((1 - s.monthExpense / s.monthIncome).clamp(0, 1) * 100).round()}',
              }),
          ]),
        );
      }
    }

    // ── 7) Top-category concentration ──────────────────────────────────────
    if (s.categoryMonthSpend.isNotEmpty && s.monthExpense > 0) {
      final sorted = s.categoryMonthSpend.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top   = sorted.first;
      final share = top.value / s.monthExpense;
      if (share > 0.45) {
        return AssistantInsight(
          type:     InsightType.spending,
          headline: _tr(languageCode, 'fa_concentration_headline', {
            'cat': _cap(top.key),
            'pct': '${(share * 100).round()}',
          }),
          bullets: _trim([
            _tr(languageCode, 'fa_concentration_item', {
              'cat':    _cap(top.key),
              'pct':    '${(share * 100).round()}',
              'amount': money(top.value),
            }),
            _tr(languageCode, 'fa_concentration_tip', {}),
          ]),
        );
      }
    }

    // ── 8) Lifetime savings rate ────────────────────────────────────────────
    if (s.allTimeIncome > 0 && s.allTimeExpense > 0) {
      final rate = (s.allTimeIncome - s.allTimeExpense) / s.allTimeIncome;

      if (rate < 0.05) {
        return AssistantInsight(
          type:     InsightType.warning,
          headline: _tr(languageCode, 'fa_lifetime_low_headline', {}),
          bullets: _trim([
            _tr(languageCode, 'fa_lifetime_low_item', {
              'income':  money(s.allTimeIncome),
              'expense': money(s.allTimeExpense),
              'rate':    '${(rate.clamp(0, 1) * 100).round()}',
            }),
            _tr(languageCode, 'fa_set_budgets_tip', {}),
          ]),
        );
      }

      if (rate >= 0.30) {
        return AssistantInsight(
          type:     InsightType.motivation,
          headline: _tr(languageCode, 'fa_lifetime_high_headline', {
            'rate': '${(rate * 100).round()}',
          }),
          bullets: _trim([
            _tr(languageCode, 'fa_lifetime_high_item', {
              'saved': money(s.allTimeIncome - s.allTimeExpense),
            }),
            _tr(languageCode, 'fa_keep_budgets_tip', {}),
          ]),
        );
      }
    }

    // ── 9) Neutral / encouraging ────────────────────────────────────────────
    if (s.monthExpense == 0 && s.monthIncome == 0) {
      return AssistantInsight(
        type:     InsightType.neutral,
        headline: _tr(languageCode, 'fa_empty_headline', {}),
        bullets: _trim([
          _tr(languageCode, 'fa_empty_tip', {}),
        ]),
      );
    }

    final onTrack = s.budgetPressure.where((b) => b.ratio < 0.80).length;
    final total   = s.budgetPressure.length;

    if (total > 0) {
      return AssistantInsight(
        type:     InsightType.neutral,
        headline: _tr(languageCode, 'fa_neutral_headline', {
          'on_track': '$onTrack',
          'total':    '$total',
          'days':     '$daysLeft',
        }),
        bullets: _trim([
          if (s.monthIncome > 0 && s.monthExpense > 0)
            _tr(languageCode, 'fa_income_pct_note', {
              'pct': '${(s.monthExpense / s.monthIncome * 100).round()}',
            }),
          _tr(languageCode, 'fa_keep_logging', {}),
        ]),
      );
    }

    return AssistantInsight(
      type:     InsightType.neutral,
      headline: _tr(languageCode, 'fa_steady_headline', {}),
      bullets: _trim([
        if (s.monthIncome > 0 && s.monthExpense > 0)
          _tr(languageCode, 'fa_steady_item', {
            'income':  money(s.monthIncome),
            'expense': money(s.monthExpense),
            'left':    money(s.monthIncome - s.monthExpense),
          }),
        _tr(languageCode, 'fa_set_budgets_tip', {}),
      ]),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Translate a key with token substitution through AppTranslations so every
  /// string goes through the localization pipeline.
  static String _tr(
      String langCode,
      String key,
      Map<String, String> vars,
      ) {
    var t = AppTranslations.tr(langCode, key);
    vars.forEach((k, v) => t = t.replaceAll('{$k}', v));
    // Clean up any unreplaced tokens — never show raw placeholders in the UI.
    t = t.replaceAll(RegExp(r'\{[a-z_]+\}'), '—');
    return t;
  }

  static String? _budgetContextForCategory(
      String cat,
      FinanceSnapshot s,
      String langCode,
      String Function(num) money,
      ) {
    final match = s.budgetPressure.where(
          (b) => b.category.toLowerCase() == cat.toLowerCase(),
    );
    if (match.isEmpty) return null;
    final b = match.first;
    return _tr(langCode, 'fa_budget_context', {
      'cat':   b.label,
      'spent': money(b.spent),
      'limit': money(b.limit),
      'pct':   '${(b.ratio * 100).round()}',
    });
  }

  static String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  static String _sym(String currencyCode) {
    const map = {
      'BDT': '৳', 'USD': '\$', 'EUR': '€', 'GBP': '£',
      'INR': '₹', 'JPY': '¥', 'CNY': '¥', 'PKR': '₨',
      'SAR': '﷼', 'AED': 'د.إ',
    };
    return map[currencyCode.toUpperCase()] ?? currencyCode;
  }

  static String _intlLocale(String code) => switch (code) {
    'bn' => 'bn', 'ar' => 'ar', 'hi' => 'hi', 'ur' => 'ur',
    'ja' => 'ja', 'zh' => 'zh', 'de' => 'de', 'fr' => 'fr',
    'es' => 'es', _   => 'en',
  };

  static List<String> _trim(List<String?> raw) {
    final out = <String>[];
    for (final b in raw) {
      if (b == null) continue;
      final t = b.trim();
      if (t.isEmpty || t == '—') continue;
      out.add(t.length > 140 ? '${t.substring(0, 137)}…' : t);
      if (out.length >= 4) break; // allow 4 bullets for multi-cat summaries
    }
    return out;
  }
}