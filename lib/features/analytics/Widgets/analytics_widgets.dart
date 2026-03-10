// lib/features/analytics/widgets/analytics_widgets.dart
//
// Beautiful analytics widgets using Rs + AppColors
// Currency symbol always from BalanceCubit

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive_helper.dart';

// ── Data models ───────────────────────────────────────────────
class BarData {
  final String label;
  final double income, expense;
  const BarData({required this.label, required this.income, required this.expense});
}

class BudgetItem {
  final String label, category;
  final double limit;
  const BudgetItem(this.label, this.category, this.limit);
}

// ══════════════════════════════════════════════════════════════
// PERIOD CHIP
// ══════════════════════════════════════════════════════════════
class AnalyticsPeriodChip extends StatelessWidget {
  const AnalyticsPeriodChip({super.key});

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: rs.sp(14), vertical: rs.sp(8)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [AppColors.royalBlue, AppColors.violet]),
        borderRadius: BorderRadius.circular(rs.sp(22)),
        boxShadow: [
          BoxShadow(
              color: AppColors.royalBlue.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('Monthly',
            style: TextStyle(
                fontSize: rs.sp(12),
                fontWeight: FontWeight.w700,
                color: Colors.white)),
        SizedBox(width: rs.sp(5)),
        Icon(Icons.keyboard_arrow_down_rounded,
            size: rs.sp(15), color: Colors.white70),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SUMMARY ROW
// ══════════════════════════════════════════════════════════════
class AnalyticsSummaryRow extends StatelessWidget {
  const AnalyticsSummaryRow({
    super.key,
    required this.income,
    required this.expense,
    required this.symbol,
  });
  final double income, expense;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      AnalyticsSummaryCard(
        icon: Icons.arrow_upward_rounded,
        label: 'Total Income',
        value: income,
        symbol: symbol,
        color: AppColors.income,
        bgColor: const Color(0xFFE8FBF5),
      ),
      SizedBox(width: Rs.of(context).sp(12)),
      AnalyticsSummaryCard(
        icon: Icons.arrow_downward_rounded,
        label: 'Total Expenses',
        value: expense,
        symbol: symbol,
        color: AppColors.expense,
        bgColor: const Color(0xFFFFEEF1),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════
// SUMMARY CARD
// ══════════════════════════════════════════════════════════════
class AnalyticsSummaryCard extends StatelessWidget {
  const AnalyticsSummaryCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.symbol,
    required this.color,
    required this.bgColor,
  });
  final IconData icon;
  final String label, symbol;
  final double value;
  final Color color, bgColor;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    final fmt = NumberFormat.currency(symbol: symbol, decimalDigits: 0)
        .format(value);
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(rs.sp(18)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(rs.sp(22)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: rs.sp(40),
              height: rs.sp(40),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(rs.sp(12)),
              ),
              child: Icon(icon, color: color, size: rs.sp(20)),
            ),
            SizedBox(height: rs.sp(12)),
            Text(label,
                style: TextStyle(
                    fontSize: rs.sp(11),
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500)),
            SizedBox(height: rs.sp(4)),
            Text(fmt,
                style: TextStyle(
                  fontSize: rs.sp(20),
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                  fontFamily: 'Sora',
                ),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// BAR CHART CARD
// ══════════════════════════════════════════════════════════════
class AnalyticsBarChart extends StatelessWidget {
  const AnalyticsBarChart({super.key, required this.bars, required this.maxVal});
  final List<BarData> bars;
  final double maxVal;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(rs.sp(18), rs.sp(20), rs.sp(18), rs.sp(16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(rs.sp(22)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Cash Flow',
                style: TextStyle(
                    fontSize: rs.sp(16),
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                    fontFamily: 'Sora')),
            const Spacer(),
            _legendDot(rs, 'Income', AppColors.income),
            SizedBox(width: rs.sp(14)),
            _legendDot(rs, 'Expense', AppColors.expense),
          ]),
          SizedBox(height: rs.sp(20)),
          SizedBox(
            height: rs.sp(160),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: bars.map((d) => _BarCol(d: d, maxVal: maxVal, rs: rs)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Rs rs, String label, Color color) => Row(children: [
    Container(
        width: rs.sp(8),
        height: rs.sp(8),
        decoration:
        BoxDecoration(shape: BoxShape.circle, color: color)),
    SizedBox(width: rs.sp(5)),
    Text(label,
        style: TextStyle(
            fontSize: rs.sp(11),
            color: AppColors.textMuted,
            fontWeight: FontWeight.w500)),
  ]);
}

class _BarCol extends StatelessWidget {
  const _BarCol({required this.d, required this.maxVal, required this.rs});
  final BarData d;
  final double maxVal;
  final Rs rs;

  @override
  Widget build(BuildContext context) {
    const maxH = 130.0;
    final mx    = maxVal == 0 ? 1.0 : maxVal;
    final incH  = (d.income / mx * maxH).clamp(4.0, maxH);
    final expH  = (d.expense / mx * maxH).clamp(4.0, maxH);

    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                width: rs.sp(14),
                height: incH,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.income, Color(0xFF00A876)],
                  ),
                  borderRadius:
                  BorderRadius.vertical(top: Radius.circular(rs.sp(5))),
                ),
              ),
              SizedBox(width: rs.sp(3)),
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                width: rs.sp(14),
                height: expH,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.expense,
                      AppColors.expense.withOpacity(0.5),
                    ],
                  ),
                  borderRadius:
                  BorderRadius.vertical(top: Radius.circular(rs.sp(5))),
                ),
              ),
            ],
          ),
          SizedBox(height: rs.sp(7)),
          Text(d.label,
              style: TextStyle(
                  fontSize: rs.sp(10),
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// BUDGET LIST CARD
// ══════════════════════════════════════════════════════════════
class AnalyticsBudgetList extends StatelessWidget {
  const AnalyticsBudgetList({
    super.key,
    required this.budgets,
    required this.catTotals,
  });
  final List<BudgetItem> budgets;
  final Map<String, double> catTotals;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(rs.sp(22)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: budgets.asMap().entries.map((e) {
          return AnalyticsBudgetRow(
            budget: e.value,
            spent: catTotals[e.value.category] ?? 0.0,
            isLast: e.key == budgets.length - 1,
          );
        }).toList(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// BUDGET ROW
// ══════════════════════════════════════════════════════════════
class AnalyticsBudgetRow extends StatelessWidget {
  const AnalyticsBudgetRow({
    super.key,
    required this.budget,
    required this.spent,
    required this.isLast,
  });
  final BudgetItem budget;
  final double spent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final rs  = Rs.of(context);
    final pct = budget.limit > 0
        ? (spent / budget.limit * 100).clamp(0.0, 100.0)
        : 0.0;
    final over = spent > budget.limit;

    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Color(0x08000000))),
      ),
      padding: EdgeInsets.all(rs.sp(18)),
      child: Column(children: [
        Row(children: [
          Expanded(
              child: Text(budget.label,
                  style: TextStyle(
                      fontSize: rs.sp(13),
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark))),
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: rs.sp(8), vertical: rs.sp(3)),
            decoration: BoxDecoration(
              color: over
                  ? AppColors.expense.withOpacity(0.1)
                  : AppColors.income.withOpacity(0.1),
              borderRadius: BorderRadius.circular(rs.sp(8)),
            ),
            child: Text(
              '${pct.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: rs.sp(11),
                fontWeight: FontWeight.w700,
                color: over ? AppColors.expense : AppColors.income,
              ),
            ),
          ),
        ]),
        SizedBox(height: rs.sp(10)),
        ClipRRect(
          borderRadius: BorderRadius.circular(rs.sp(6)),
          child: LinearProgressIndicator(
            value: pct / 100,
            minHeight: rs.sp(7),
            backgroundColor: AppColors.bgLavender,
            valueColor: AlwaysStoppedAnimation(
                over ? AppColors.expense : AppColors.royalBlue),
          ),
        ),
        SizedBox(height: rs.sp(6)),
        Row(children: [
          Text('\$${spent.toStringAsFixed(0)}',
              style: TextStyle(
                  fontSize: rs.sp(11),
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500)),
          const Spacer(),
          Text('of \$${budget.limit.toStringAsFixed(0)}',
              style: TextStyle(
                  fontSize: rs.sp(11),
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500)),
        ]),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// HISTORY LIST CARD
// ══════════════════════════════════════════════════════════════
class AnalyticsHistoryList extends StatelessWidget {
  const AnalyticsHistoryList({super.key, required this.bars});
  final List<BarData> bars;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    final reversed = bars.reversed.toList();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(rs.sp(22)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: reversed.asMap().entries.map((e) => AnalyticsHistoryRow(
          bar: e.value,
          isLast: e.key == reversed.length - 1,
        )).toList(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// HISTORY ROW
// ══════════════════════════════════════════════════════════════
class AnalyticsHistoryRow extends StatelessWidget {
  const AnalyticsHistoryRow({super.key, required this.bar, required this.isLast});
  final BarData bar;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Color(0x08000000))),
      ),
      padding: EdgeInsets.symmetric(
          horizontal: rs.sp(18), vertical: rs.sp(15)),
      child: Row(children: [
        Container(
          width: rs.sp(8),
          height: rs.sp(8),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.royalBlue,
          ),
        ),
        SizedBox(width: rs.sp(10)),
        Text(bar.label,
            style: TextStyle(
                fontSize: rs.sp(13),
                fontWeight: FontWeight.w600,
                color: AppColors.textMid)),
        const Spacer(),
        Text('+\$${bar.income.toStringAsFixed(0)}',
            style: TextStyle(
                fontSize: rs.sp(13),
                fontWeight: FontWeight.w700,
                color: AppColors.income)),
        SizedBox(width: rs.sp(16)),
        Text('-\$${bar.expense.toStringAsFixed(0)}',
            style: TextStyle(
                fontSize: rs.sp(13),
                fontWeight: FontWeight.w700,
                color: AppColors.expense)),
      ]),
    );
  }
}