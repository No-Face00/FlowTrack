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

/// Rule-based finance coach — always available without network.
class LocalFinanceBrain {
  LocalFinanceBrain._();

  static AssistantInsight generate(FinanceSnapshot s) {
    final bullets = <String>[];

    // 1) Budget pressure
    for (final b in s.budgetPressure) {
      if (b.ratio >= 1.0) {
        return AssistantInsight(
          type: InsightType.warning,
          headline:
              '${b.label} is over budget this month — re-balance before month-end.',
          bullets: _trimBullets([
            'You are at ${(b.ratio * 100).round()}% of the ${b.label} limit.',
            if (s.monthExpense > s.monthIncome && s.monthIncome > 0)
              'Overall spending is outpacing income this month.',
            'Trim discretionary categories or move limits in Analytics.',
          ]),
        );
      }
      if (b.ratio >= 0.85) {
        bullets.add(
            '${b.label} is at ${(b.ratio * 100).round()}% of its budget — easy to overshoot.');
        break;
      }
    }

    // 2) Week-over-week category swing
    for (final e in s.toGeminiJson()['weekOverWeek'] as List) {
      final cat = e['category'] as String;
      final ch = (e['changePct'] as num).toDouble();
      if (ch >= 22 && (e['thisWeek'] as num).toDouble() > 0) {
        bullets.add(
            '${_cap(cat)} spending is up ${ch.round()}% vs last week — worth a quick review.');
        break;
      }
      if (ch <= -18 && (e['prevWeek'] as num).toDouble() > 0) {
        bullets.add(
            '${_cap(cat)} cooled off (${ch.round()}% vs last week). Nice discipline.');
        break;
      }
    }

    // 3) Month vs last month expense
    if (s.lastMonthExpense > 0 && s.monthExpense > 0) {
      final m = ((s.monthExpense - s.lastMonthExpense) / s.lastMonthExpense * 100);
      if (m >= 12) {
        bullets.add(
            'This month’s spending is ${m.round()}% higher than last month at this pace.');
      } else if (m <= -10) {
        bullets.add(
            'You are spending about ${(-m).round()}% less than last month — trend is improving.');
      }
    }

    // 4) Income vs expense this month
    InsightType tone = InsightType.neutral;
    if (s.monthIncome > 0 && s.monthExpense > s.monthIncome * 1.05) {
      bullets.add(
          'Expenses are running above income this month — tighten discretionary buys.');
      tone = InsightType.warning;
    } else if (s.monthIncome > 0 && s.monthExpense < s.monthIncome * 0.65) {
      bullets.add(
          'You are spending well below income this month — good room to save or invest.');
      tone = InsightType.saving;
    }

    // 5) Savings from all-time balance
    if (s.allTimeIncome > 0) {
      final rate = ((s.allTimeIncome - s.allTimeExpense) / s.allTimeIncome * 100);
      if (rate >= 25 && bullets.length < 3) {
        bullets.add(
            'All-time you have kept roughly ${rate.round()}% of income — strong savings habit.');
        if (tone == InsightType.neutral) tone = InsightType.motivation;
      } else if (rate < 0 && bullets.isEmpty) {
        bullets.add(
            'Lifetime expenses exceed recorded income — capture every income source.');
      }
    }

    // 6) Top category concentration
    if (s.categoryMonthSpend.isNotEmpty) {
      final top = s.categoryMonthSpend.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final t = top.first;
      final share = s.monthExpense > 0 ? t.value / s.monthExpense : 0.0;
      if (share > 0.42 && bullets.length < 3) {
        bullets.add(
            '${_cap(t.key)} is ${_pct(share)} of this month’s spend — diversification could reduce risk.');
        if (tone == InsightType.neutral) tone = InsightType.spending;
      }
    }

    // Headline synthesis
    String headline;
    if (bullets.isEmpty) {
      if (s.monthExpense == 0 && s.monthIncome == 0) {
        headline =
            'Add a few transactions — Flow Advisor will start spotting patterns immediately.';
      } else if (s.monthExpense == 0) {
        headline =
            'No expenses logged this month yet — when you spend, I will benchmark it instantly.';
      } else {
        headline =
            'Cash flow looks steady — keep logging transactions so I can catch shifts early.';
      }
    } else {
      headline = bullets.first;
      bullets.removeAt(0);
    }

    return AssistantInsight(
      headline: headline,
      bullets: _trimBullets(bullets),
      type: tone,
    );
  }

  static String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  static String _pct(double v) => '${(v * 100).round()}%';

  static List<String> _trimBullets(List<String> raw) {
    final out = <String>[];
    for (final b in raw) {
      final t = b.trim();
      if (t.isEmpty) continue;
      out.add(t.length > 118 ? '${t.substring(0, 115)}…' : t);
      if (out.length >= 3) break;
    }
    return out;
  }
}
