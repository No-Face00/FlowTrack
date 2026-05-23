// lib/features/ai/data/local_finance_brain.dart
//
// Upgraded Flow Advisor — deep budget-aware financial analysis engine.
// Analyses every category budget vs actual spend, spending velocity,
// week-over-week patterns, income health, and savings trajectory.
// Produces rich, actionable multi-line insights instead of simple alerts.

import 'finance_snapshot.dart';
import 'insight_type.dart';

class AssistantInsight {
  const AssistantInsight({
    required this.headline,
    required this.bullets,
    this.type = InsightType.neutral,
  });

  final String headline;
  final List<String> bullets;
  final InsightType type;

  AssistantInsight copyWith({
    String? headline,
    List<String>? bullets,
    InsightType? type,
  }) =>
      AssistantInsight(
        headline: headline ?? this.headline,
        bullets: bullets ?? this.bullets,
        type: type ?? this.type,
      );
}

/// Rule-based finance coach — fully offline, always available.
///
/// Analysis priority order:
///  1) Critical budget overflows (any category ≥ 100 % used)
///  2) High-risk budget pressure (80–99 %, days-remaining aware)
///  3) Spending velocity — will the user blow the budget before month-end?
///  4) Week-over-week category spikes / drops
///  5) Monthly income-vs-expense health
///  6) Month-over-month improvement or regression
///  7) Top-category concentration risk
///  8) All-time savings rate
///  9) Encouraging / neutral coach voice when nothing critical found
class LocalFinanceBrain {
  LocalFinanceBrain._();

  static AssistantInsight generate(FinanceSnapshot s) {
    final now        = s.now;
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysPassed  = now.day;
    final daysLeft    = (daysInMonth - daysPassed).clamp(0, 31);

    // ── 1) Critical overflows ─────────────────────────────────────────────
    final overBudget = s.budgetPressure.where((b) => b.ratio >= 1.0).toList();
    if (overBudget.isNotEmpty) {
      final worst = overBudget.first; // already sorted desc by ratio
      final over  = worst.spent - worst.limit;
      final pct   = (worst.ratio * 100).round();

      final otherOverflow = overBudget.length > 1
          ? '${overBudget.length - 1} other categor${overBudget.length > 2 ? "ies" : "y"} also over budget.'
          : null;

      final bullets = _trim([
        '${worst.label} budget: spent ${_fmt(worst.spent)} of ${_fmt(worst.limit)} limit — ${_fmt(over)} over (${pct}%).',
        if (otherOverflow != null) otherOverflow,
        _velocityAdvice(worst.spent, worst.limit, daysLeft, worst.label),
        if (s.monthExpense > s.monthIncome && s.monthIncome > 0)
          'Total expenses are now exceeding income this month — review all discretionary categories.',
      ]);

      return AssistantInsight(
        type:     InsightType.warning,
        headline: '⚠ ${worst.label} is ${_fmt(over)} over its monthly budget — immediate action recommended.',
        bullets:  bullets,
      );
    }

    // ── 2) High-risk budget pressure (80–99 %) ────────────────────────────
    final atRisk = s.budgetPressure
        .where((b) => b.ratio >= 0.80 && b.ratio < 1.0)
        .toList();
    if (atRisk.isNotEmpty) {
      final top     = atRisk.first;
      final pct     = (top.ratio * 100).round();
      final budgetRemaining = top.limit - top.spent;

      // Daily burn rate vs remaining daily budget
      final dailyBurn         = daysPassed > 0 ? top.spent / daysPassed : 0.0;
      final projectedMonthEnd = dailyBurn * daysInMonth;
      final projectedOver     = projectedMonthEnd - top.limit;
      final projectedMsg      = projectedOver > 0
          ? 'At this pace you will overshoot the ${top.label} limit by ${_fmt(projectedOver)} before month-end.'
          : 'If spending holds steady, you should stay within the ${top.label} limit.';

      final otherAtRisk = atRisk.length > 1
          ? '${atRisk.length - 1} more categor${atRisk.length > 2 ? "ies are" : "y is"} also above 80 % — check Analytics.'
          : null;

      final bullets = _trim([
        '${top.label}: ${_fmt(top.spent)} used of ${_fmt(top.limit)} (${pct}%) — only ${_fmt(budgetRemaining)} left for $daysLeft days.',
        projectedMsg,
        if (otherAtRisk != null) otherAtRisk,
        _savingTip(top.label),
      ]);

      return AssistantInsight(
        type:     InsightType.warning,
        headline: '${top.label} is ${pct}% used with $daysLeft days left — budget is at risk.',
        bullets:  bullets,
      );
    }

    // ── 3) Spending velocity — on-track check for healthy budgets ─────────
    // Flag if any category is spending faster than the month allows.
    if (daysPassed >= 5 && s.budgetPressure.isNotEmpty) {
      final velocityWarnings = <String>[];
      for (final b in s.budgetPressure) {
        if (b.limit <= 0) continue;
        final expectedByNow = b.limit * (daysPassed / daysInMonth);
        // Overspending at >130 % of expected pace
        if (b.spent > expectedByNow * 1.30 && b.ratio < 0.80) {
          final ahead = b.spent - expectedByNow;
          velocityWarnings.add(
            '${b.label} is ${_fmt(ahead)} ahead of the expected daily pace — slow down to protect the budget.',
          );
        }
      }
      if (velocityWarnings.isNotEmpty) {
        final bullets = _trim([
          ...velocityWarnings,
          'You are on day $daysPassed of $daysInMonth — budgets flagged above are burning faster than planned.',
        ]);
        return AssistantInsight(
          type:     InsightType.spending,
          headline: 'Spending velocity is running high in ${velocityWarnings.length} categor${velocityWarnings.length > 1 ? "ies" : "y"} — you could hit limits before month-end.',
          bullets:  bullets,
        );
      }
    }

    // ── 4) Week-over-week category spike ──────────────────────────────────
    final wow = s.toGeminiJson()['weekOverWeek'] as List;
    String? spikeMsg;
    String? dropMsg;
    for (final e in wow) {
      final cat  = (e['category'] as String).trim();
      final ch   = (e['changePct'] as num).toDouble();
      final thisW = (e['thisWeek'] as num).toDouble();
      final prevW = (e['prevWeek'] as num).toDouble();
      if (ch >= 25 && thisW > 0 && spikeMsg == null) {
        spikeMsg = '${_cap(cat)} spending jumped ${ch.round()}% this week (${_fmt(thisW)} vs ${_fmt(prevW)} last week).';
      }
      if (ch <= -20 && prevW > 0 && dropMsg == null) {
        dropMsg = '${_cap(cat)} spending dropped ${(-ch).round()}% vs last week — great self-control.';
      }
    }
    if (spikeMsg != null) {
      final bullets = _trim([
        spikeMsg,
        if (dropMsg != null) dropMsg,
        'Check if this spike is a one-off or a new habit — consistent spikes erode monthly budgets quickly.',
        _budgetContextForCategory(_spikeCategory(wow), s),
      ]);
      return AssistantInsight(
        type:     InsightType.spending,
        headline: 'Unusual weekly spending detected — one category is up 25%+ this week.',
        bullets:  bullets,
      );
    }

    // ── 5) Income vs expense health ───────────────────────────────────────
    if (s.monthIncome > 0 && s.monthExpense > 0) {
      final ratio = s.monthExpense / s.monthIncome;

      if (ratio >= 0.95) {
        final gap = s.monthExpense - s.monthIncome;
        final bullets = _trim([
          'Expenses are ${(ratio * 100).round()}% of income — you have ${gap > 0 ? "exceeded" : "almost no"} buffer left this month.',
          if (gap > 0) 'You are ${_fmt(gap)} in the red for ${now.month}/${now.year} — reduce non-essential spending immediately.',
          _topCategoryAdvice(s),
          'With $daysLeft days remaining, aim to cut at least ${_fmt((gap / daysLeft).clamp(0, 9999999))} per day to recover.',
        ]);
        return AssistantInsight(
          type:     InsightType.warning,
          headline: 'Expenses are nearly equal to income this month — financial buffer is critically thin.',
          bullets:  bullets,
        );
      }

      if (ratio <= 0.60) {
        final saved    = s.monthIncome - s.monthExpense;
        final saveRate = ((1 - ratio) * 100).round();
        final bullets  = _trim([
          'You are saving ${saveRate}% of income this month — ${_fmt(saved)} already set aside.',
          if (dropMsg != null) dropMsg,
          'Consider channeling surplus into an emergency fund or investment before month-end.',
          if (s.allTimeIncome > 0) _lifetimeSavingsMsg(s),
        ]);
        return AssistantInsight(
          type:     InsightType.saving,
          headline: 'Excellent! You are on track to save ${saveRate}% of your income this month.',
          bullets:  bullets,
        );
      }
    }

    // ── 6) Month-over-month trend ─────────────────────────────────────────
    if (s.lastMonthExpense > 0 && s.monthExpense > 0) {
      final change = (s.monthExpense - s.lastMonthExpense) / s.lastMonthExpense * 100;
      if (change >= 15) {
        final extra = s.monthExpense - s.lastMonthExpense;
        final bullets = _trim([
          'This month you have spent ${_fmt(extra)} more than the same period last month (+${change.round()}%).',
          _topCategoryAdvice(s),
          'If this pace continues, you will exceed last month\'s total by ${_fmt(extra * (daysInMonth / daysPassed.clamp(1, 31)))}.',
        ]);
        return AssistantInsight(
          type:     InsightType.spending,
          headline: 'Spending is up ${change.round()}% vs last month — the gap is widening.',
          bullets:  bullets,
        );
      }
      if (change <= -12) {
        final saved = s.lastMonthExpense - s.monthExpense;
        final bullets = _trim([
          'You are ${_fmt(saved)} under last month\'s pace (${(-change).round()}% less) — great discipline.',
          if (s.monthIncome > 0)
            'Your savings rate this month is ${((1 - s.monthExpense / s.monthIncome).clamp(0, 1) * 100).round()}% of income.',
          if (dropMsg != null) dropMsg,
          'Keep the momentum — $daysLeft days left to lock in this improvement.',
        ]);
        return AssistantInsight(
          type:     InsightType.motivation,
          headline: 'Spending is down ${(-change).round()}% vs last month — your habits are clearly improving.',
          bullets:  bullets,
        );
      }
    }

    // ── 7) Top-category concentration ────────────────────────────────────
    if (s.categoryMonthSpend.isNotEmpty && s.monthExpense > 0) {
      final sorted = s.categoryMonthSpend.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top   = sorted.first;
      final share = top.value / s.monthExpense;
      if (share > 0.45) {
        final bullets = _trim([
          '${_cap(top.key)} alone accounts for ${_pct(share)} of all expenses this month (${_fmt(top.value)}).',
          'Diversifying or capping this category could meaningfully improve your monthly balance.',
          if (s.budgetPressure.any((b) => b.category.toLowerCase() == top.key))
            'A budget limit for ${_cap(top.key)} is already set — check how close you are in Analytics.',
        ]);
        return AssistantInsight(
          type:     InsightType.spending,
          headline: '${_cap(top.key)} dominates your spending at ${_pct(share)} of this month\'s total.',
          bullets:  bullets,
        );
      }
    }

    // ── 8) Lifetime savings rate ──────────────────────────────────────────
    if (s.allTimeIncome > 0 && s.allTimeExpense > 0) {
      final lifetimeRate = (s.allTimeIncome - s.allTimeExpense) / s.allTimeIncome;
      if (lifetimeRate < 0.05) {
        return AssistantInsight(
          type:     InsightType.warning,
          headline: 'Your all-time savings rate is very low — expenses are consuming almost all recorded income.',
          bullets:  _trim([
            'All-time: earned ${_fmt(s.allTimeIncome)}, spent ${_fmt(s.allTimeExpense)} — only ${_pct(lifetimeRate.clamp(0, 1))} saved overall.',
            'Setting monthly budget limits in Analytics is the fastest way to build a financial buffer.',
          ]),
        );
      }
      if (lifetimeRate >= 0.30) {
        return AssistantInsight(
          type:     InsightType.motivation,
          headline: 'Strong all-time savings rate of ${_pct(lifetimeRate)} — you are building real financial resilience.',
          bullets:  _trim([
            'Total saved to date: ${_fmt(s.allTimeIncome - s.allTimeExpense)} across all recorded transactions.',
            'Keep setting category budgets to protect this streak from lifestyle inflation.',
          ]),
        );
      }
    }

    // ── 9) Neutral / encouraging coach voice ──────────────────────────────
    if (s.monthExpense == 0 && s.monthIncome == 0) {
      return AssistantInsight(
        type:     InsightType.neutral,
        headline: 'Add a few transactions and Flow Advisor will start spotting patterns immediately.',
        bullets:  _trim([
          'Log income and expenses to unlock budget analysis, category insights, and trend tracking.',
        ]),
      );
    }

    final onTrackBudgets = s.budgetPressure.where((b) => b.ratio < 0.80).length;
    final totalBudgets   = s.budgetPressure.length;
    if (totalBudgets > 0) {
      return AssistantInsight(
        type:     InsightType.neutral,
        headline: 'Finances look healthy — $onTrackBudgets of $totalBudgets budgets are on track with $daysLeft days to go.',
        bullets:  _trim([
          if (s.monthIncome > 0 && s.monthExpense > 0)
            'You have used ${_pct(s.monthExpense / s.monthIncome)} of this month\'s income — well within range.',
          'Keep logging transactions daily so Flow Advisor can alert you before issues arise.',
        ]),
      );
    }

    return AssistantInsight(
      type:     InsightType.neutral,
      headline: 'Cash flow looks steady — keep logging transactions so I can catch shifts early.',
      bullets:  _trim([
        if (s.monthIncome > 0 && s.monthExpense > 0)
          'This month: earned ${_fmt(s.monthIncome)}, spent ${_fmt(s.monthExpense)} — ${_fmt(s.monthIncome - s.monthExpense)} remaining.',
        'Set category budgets in Analytics for real-time budget pressure alerts.',
      ]),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static String _fmt(num v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.round().toString();
  }

  static String _pct(double v) => '${(v * 100).round()}%';

  static String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  static String _velocityAdvice(double spent, double limit, int daysLeft, String label) {
    if (daysLeft <= 0) return 'Month is ending — review $label spending in Analytics.';
    final allowedPerDay = (limit - spent) / daysLeft;
    if (allowedPerDay <= 0) return 'No $label budget remaining — avoid further spending in this category.';
    return 'You can spend at most ${_fmt(allowedPerDay)}/day on $label for the remaining $daysLeft days to recover.';
  }

  static String _savingTip(String label) {
    final tips = {
      'food':      'Meal prepping and reducing takeout orders can significantly cut food costs.',
      'transport': 'Carpooling or combining errands into fewer trips can reduce transport spend.',
      'shopping':  'Try a 48-hour rule before non-essential purchases to curb impulse buys.',
      'health':    'Check if any upcoming health appointments can be deferred to next month.',
      'bills':     'Review subscriptions — cancelling unused ones is the easiest budget win.',
    };
    return tips[label.toLowerCase()] ??
        'Review recent $label transactions — cutting 2–3 non-essentials often restores budget headroom.';
  }

  static String _topCategoryAdvice(FinanceSnapshot s) {
    if (s.categoryMonthSpend.isEmpty) return '';
    final top = (s.categoryMonthSpend.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)))
        .first;
    return '${_cap(top.key)} is your biggest expense at ${_fmt(top.value)} — a small reduction here has the most impact.';
  }

  static String _lifetimeSavingsMsg(FinanceSnapshot s) {
    final rate = s.allTimeIncome > 0
        ? ((s.allTimeIncome - s.allTimeExpense) / s.allTimeIncome).clamp(0.0, 1.0)
        : 0.0;
    return 'All-time savings rate: ${_pct(rate)} — this month is well above your historical average.';
  }

  static String? _budgetContextForCategory(String? cat, FinanceSnapshot s) {
    if (cat == null) return null;
    final match = s.budgetPressure.where(
          (b) => b.category.toLowerCase() == cat.toLowerCase(),
    );
    if (match.isEmpty) return null;
    final b = match.first;
    return '${b.label} budget: ${_fmt(b.spent)} of ${_fmt(b.limit)} used this month (${(b.ratio * 100).round()}%).';
  }

  static String? _spikeCategory(List wow) {
    for (final e in wow) {
      final ch    = (e['changePct'] as num).toDouble();
      final thisW = (e['thisWeek'] as num).toDouble();
      if (ch >= 25 && thisW > 0) return (e['category'] as String).trim();
    }
    return null;
  }

  static List<String> _trim(List<String?> raw) {
    final out = <String>[];
    for (final b in raw) {
      if (b == null) continue;
      final t = b.trim();
      if (t.isEmpty) continue;
      out.add(t.length > 130 ? '${t.substring(0, 127)}…' : t);
      if (out.length >= 3) break;
    }
    return out;
  }
}