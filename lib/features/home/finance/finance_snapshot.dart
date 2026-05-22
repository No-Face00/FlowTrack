import '../../budget/domain/entities/budget_entity.dart';
import '../../budget/presentation/cubit/budget_state.dart';
import '../../transactions/domain/entities/transaction_entity.dart';
import '../../transactions/presentation/cubit/balance_state.dart';
import '../../transactions/presentation/cubit/transaction_state.dart';

/// Aggregated metrics for the finance assistant (local + optional Gemini).
class FinanceSnapshot {
  const FinanceSnapshot({
    required this.currencyCode,
    required this.monthKey,
    required this.now,
    required this.monthIncome,
    required this.monthExpense,
    required this.lastMonthIncome,
    required this.lastMonthExpense,
    required this.allTimeIncome,
    required this.allTimeExpense,
    required this.categoryMonthSpend,
    required this.categoryLastMonthSpend,
    required this.categoryThisWeekSpend,
    required this.categoryPrevWeekSpend,
    required this.budgetPressure,
  });

  final String currencyCode;
  final String monthKey;
  final DateTime now;

  final double monthIncome;
  final double monthExpense;
  final double lastMonthIncome;
  final double lastMonthExpense;
  final double allTimeIncome;
  final double allTimeExpense;

  final Map<String, double> categoryMonthSpend;
  final Map<String, double> categoryLastMonthSpend;
  final Map<String, double> categoryThisWeekSpend;
  final Map<String, double> categoryPrevWeekSpend;

  /// category → spent/limit (only limits > 0)
  final List<BudgetPressure> budgetPressure;

  static FinanceSnapshot build({
    required String currencyCode,
    required TransactionState txState,
    required BalanceState balState,
    required BudgetState budState,
  }) {
    final now = DateTime.now();
    final monthKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final lastMonth = DateTime(now.year, now.month - 1);
    final lastMonthKey =
        '${lastMonth.year}-${lastMonth.month.toString().padLeft(2, '0')}';

    final txs = txState is TransactionLoaded
        ? txState.transactions.where((t) => !t.isDeleted).toList()
        : <TransactionEntity>[];

    double mi = 0, me = 0, lmi = 0, lme = 0;
    final catM = <String, double>{};
    final catL = <String, double>{};
    final catW = <String, double>{};
    final catP = <String, double>{};

    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final week0 = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final prevWeekEnd = week0.subtract(const Duration(days: 1));
    final prevWeekStart = prevWeekEnd.subtract(const Duration(days: 6));

    for (final t in txs) {
      if (t.type == 'income') {
        if (t.month == monthKey) mi += t.amount;
        if (t.month == lastMonthKey) lmi += t.amount;
      } else if (t.type == 'expense') {
        if (t.month == monthKey) {
          me += t.amount;
          final c = t.category.toLowerCase().trim();
          catM[c] = (catM[c] ?? 0) + t.amount;
        }
        if (t.month == lastMonthKey) {
          lme += t.amount;
          final c = t.category.toLowerCase().trim();
          catL[c] = (catL[c] ?? 0) + t.amount;
        }
        final d = t.date;
        if (!d.isBefore(week0) && !d.isAfter(now)) {
          final c = t.category.toLowerCase().trim();
          catW[c] = (catW[c] ?? 0) + t.amount;
        }
        if (!d.isBefore(prevWeekStart) && !d.isAfter(prevWeekEnd)) {
          final c = t.category.toLowerCase().trim();
          catP[c] = (catP[c] ?? 0) + t.amount;
        }
      }
    }

    final ai = balState is BalanceLoaded ? balState.income : 0.0;
    final ae = balState is BalanceLoaded ? balState.expense : 0.0;

    final pressure = <BudgetPressure>[];
    if (budState is BudgetLoaded) {
      for (final b in budState.budgets) {
        if (b.limitAmount <= 0) continue;
        final cat = b.category.toLowerCase().trim();
        final spent = catM[cat] ?? 0;
        pressure.add(BudgetPressure(
          category: b.category,
          label: b.label,
          spent: spent,
          limit: b.limitAmount,
          ratio: spent / b.limitAmount,
        ));
      }
      pressure.sort((a, b) => b.ratio.compareTo(a.ratio));
    }

    return FinanceSnapshot(
      currencyCode: currencyCode,
      monthKey: monthKey,
      now: now,
      monthIncome: mi,
      monthExpense: me,
      lastMonthIncome: lmi,
      lastMonthExpense: lme,
      allTimeIncome: ai,
      allTimeExpense: ae,
      categoryMonthSpend: catM,
      categoryLastMonthSpend: catL,
      categoryThisWeekSpend: catW,
      categoryPrevWeekSpend: catP,
      budgetPressure: pressure,
    );
  }

  Map<String, dynamic> toGeminiJson() => {
        'currency': currencyCode,
        'month': monthKey,
        'monthIncome': monthIncome,
        'monthExpense': monthExpense,
        'lastMonthExpense': lastMonthExpense,
        'lastMonthIncome': lastMonthIncome,
        'allTimeIncome': allTimeIncome,
        'allTimeExpense': allTimeExpense,
        'topCategoriesThisMonth': _topN(categoryMonthSpend, 6),
        'weekOverWeek': _wow(),
        'budgetPressure': budgetPressure
            .take(5)
            .map((e) => {
                  'category': e.category,
                  'spent': e.spent,
                  'limit': e.limit,
                  'pct': (e.ratio * 100).round(),
                })
            .toList(),
      };

  List<Map<String, dynamic>> _topN(Map<String, double> m, int n) {
    final s = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return s
        .take(n)
        .map((e) => {'category': e.key, 'amount': e.value})
        .toList();
  }

  List<Map<String, dynamic>> _wow() {
    final keys = {...categoryThisWeekSpend.keys, ...categoryPrevWeekSpend.keys};
    final out = <Map<String, dynamic>>[];
    for (final k in keys) {
      final w = categoryThisWeekSpend[k] ?? 0;
      final p = categoryPrevWeekSpend[k] ?? 0;
      if (p <= 0 && w <= 0) continue;
      final pct = p > 0 ? ((w - p) / p * 100) : (w > 0 ? 100.0 : 0.0);
      out.add({'category': k, 'thisWeek': w, 'prevWeek': p, 'changePct': pct});
    }
    out.sort((a, b) => (b['changePct'] as num).abs().compareTo((a['changePct'] as num).abs()));
    return out.take(6).toList();
  }
}

class BudgetPressure {
  const BudgetPressure({
    required this.category,
    required this.label,
    required this.spent,
    required this.limit,
    required this.ratio,
  });

  final String category;
  final String label;
  final double spent;
  final double limit;
  final double ratio;
}
