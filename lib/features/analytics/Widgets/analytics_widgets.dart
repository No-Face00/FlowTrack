// lib/features/analytics/Widgets/analytics_widgets.dart
// Premium redesign — glassmorphism, gradient cards, animated bars
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../budget/domain/entities/budget_entity.dart';

class BarData {
  final String label;
  final double income, expense;
  const BarData({required this.label, required this.income, required this.expense});
}

String _fmt(double v) => NumberFormat('#,##0', 'en_US').format(v);

// ════════════════════════════════════════════════════════════════
// SUMMARY ROW  — two glass + gradient tiles
// ════════════════════════════════════════════════════════════════
class AnalyticsSummaryRow extends StatelessWidget {
  const AnalyticsSummaryRow({super.key,
    required this.income, required this.expense, required this.symbol});
  final double income, expense;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Row(children: [
      Expanded(child: _SummaryCard(
        label:    'Total Income',
        value:    income,
        symbol:   symbol,
        icon:     Icons.arrow_upward_rounded,
        topColor: const Color(0xFF00E5A0),
        botColor: const Color(0xFF00875F),
        glow:     AppColors.income,
        tag:      'income',
      )),
      SizedBox(width: rs.sp(14)),
      Expanded(child: _SummaryCard(
        label:    'Total Expenses',
        value:    expense,
        symbol:   symbol,
        icon:     Icons.arrow_downward_rounded,
        topColor: const Color(0xFFFF6B8A),
        botColor: const Color(0xFFCC2050),
        glow:     AppColors.expense,
        tag:      'expense',
      )),
    ]);
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label, required this.value, required this.symbol,
    required this.icon,  required this.topColor, required this.botColor,
    required this.glow,  required this.tag,
  });
  final String label, symbol, tag;
  final double value;
  final IconData icon;
  final Color topColor, botColor, glow;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [topColor, botColor],
        ),
        borderRadius: BorderRadius.circular(rs.sp(24)),
        boxShadow: [
          BoxShadow(color: glow.withOpacity(0.40), blurRadius: 22, offset: const Offset(0, 10)),
          BoxShadow(color: glow.withOpacity(0.15), blurRadius: 6,  offset: const Offset(0, 2)),
        ],
      ),
      child: Stack(children: [
        // Decorative orb top-right
        Positioned(
          top: -rs.sp(12), right: -rs.sp(12),
          child: Container(
            width: rs.sp(70), height: rs.sp(70),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.10),
            ),
          ),
        ),
        Positioned(
          bottom: -rs.sp(16), left: rs.sp(30),
          child: Container(
            width: rs.sp(50), height: rs.sp(50),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.06),
            ),
          ),
        ),
        // Content
        Padding(
          padding: EdgeInsets.all(rs.sp(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(
                width: rs.sp(40), height: rs.sp(40),
                decoration: BoxDecoration(
                  color:        Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(rs.sp(13)),
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                ),
                child: Icon(icon, color: Colors.white, size: rs.sp(20)),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: rs.sp(8), vertical: rs.sp(4)),
                decoration: BoxDecoration(
                  color:        Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(rs.sp(20)),
                ),
                child: Text(tag == 'income' ? '↑' : '↓',
                    style: TextStyle(color: Colors.white, fontSize: rs.sp(12), fontWeight: FontWeight.w800)),
              ),
            ]),
            SizedBox(height: rs.sp(16)),
            Text(label, style: TextStyle(
                fontSize: rs.sp(11), color: Colors.white.withOpacity(0.75),
                fontWeight: FontWeight.w500, letterSpacing: 0.3)),
            SizedBox(height: rs.sp(5)),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text('$symbol${_fmt(value)}',
                  style: TextStyle(fontSize: rs.sp(22), fontWeight: FontWeight.w800,
                      color: Colors.white, fontFamily: 'Sora')),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// BAR CHART  — dark premium card
// ════════════════════════════════════════════════════════════════
class AnalyticsBarChart extends StatelessWidget {
  const AnalyticsBarChart({super.key, required this.bars, required this.maxVal});
  final List<BarData> bars;
  final double maxVal;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF00022A), Color(0xFF0D08A0), Color(0xFF1E1FD8)],
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(rs.sp(26)),
        boxShadow: [
          BoxShadow(color: AppColors.midnight.withOpacity(0.50),
              blurRadius: 28, offset: const Offset(0, 12)),
          BoxShadow(color: AppColors.royalBlue.withOpacity(0.20),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Stack(children: [
        // Orbs inside card
        Positioned(top: -20, right: -20,
            child: Container(width: 100, height: 100,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: AppColors.violet.withOpacity(0.08)))),
        Positioned(bottom: 10, left: -10,
            child: Container(width: 70, height: 70,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: AppColors.royalBlue.withOpacity(0.10)))),
        Padding(
          padding: EdgeInsets.fromLTRB(rs.sp(20), rs.sp(22), rs.sp(20), rs.sp(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Cash Flow', style: TextStyle(
                    fontSize: rs.sp(18), fontWeight: FontWeight.w800,
                    color: Colors.white, fontFamily: 'Sora')),
                SizedBox(height: rs.sp(3)),
                Text('Income vs Expenses', style: TextStyle(
                    fontSize: rs.sp(11), color: Colors.white38, fontWeight: FontWeight.w400)),
              ]),
              const Spacer(),
              _legend(rs, 'Income',  const Color(0xFF00E5A0)),
              SizedBox(width: rs.sp(16)),
              _legend(rs, 'Expense', const Color(0xFFFF6B8A)),
            ]),
            SizedBox(height: rs.sp(24)),
            SizedBox(
              height: rs.sp(130),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end,
                  children: bars.map((d) => _Bar(d: d, maxVal: maxVal, rs: rs)).toList()),
            ),
            SizedBox(height: rs.sp(14)),
            // Gradient divider
            Container(height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.transparent,
                    Colors.white.withOpacity(0.15),
                    Colors.transparent,
                  ]),
                )),
            SizedBox(height: rs.sp(12)),
            Row(children: [
              Icon(Icons.info_outline_rounded, size: rs.sp(11), color: Colors.white24),
              SizedBox(width: rs.sp(5)),
              Text('Showing ${bars.length} periods',
                  style: TextStyle(fontSize: rs.sp(10), color: Colors.white24)),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _legend(Rs rs, String label, Color color) => Row(children: [
    Container(
      width: rs.sp(7), height: rs.sp(7),
      decoration: BoxDecoration(
        shape: BoxShape.circle, color: color,
        boxShadow: [BoxShadow(color: color.withOpacity(0.8), blurRadius: 5)],
      ),
    ),
    SizedBox(width: rs.sp(5)),
    Text(label, style: TextStyle(fontSize: rs.sp(11), color: Colors.white54,
        fontWeight: FontWeight.w500)),
  ]);
}

class _Bar extends StatelessWidget {
  const _Bar({required this.d, required this.maxVal, required this.rs});
  final BarData d; final double maxVal; final Rs rs;

  @override
  Widget build(BuildContext context) {
    const maxH = 110.0;
    final mx   = maxVal == 0 ? 1.0 : maxVal;
    final incH = (d.income  / mx * maxH).clamp(4.0, maxH);
    final expH = (d.expense / mx * maxH).clamp(4.0, maxH);

    return Expanded(
      child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end, children: [
              Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 700), curve: Curves.easeOutQuart,
                  width: rs.sp(11), height: incH,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Color(0xFF00FFB3), Color(0xFF00C48C)],
                    ),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(rs.sp(5))),
                    boxShadow: [BoxShadow(color: const Color(0xFF00C48C).withOpacity(0.6),
                        blurRadius: 8, offset: const Offset(0, -3))],
                  ),
                ),
              ]),
              SizedBox(width: rs.sp(4)),
              Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 700), curve: Curves.easeOutQuart,
                  width: rs.sp(11), height: expH,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Color(0xFFFF8FA8), Color(0xFFFF647C)],
                    ),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(rs.sp(5))),
                    boxShadow: [BoxShadow(color: const Color(0xFFFF647C).withOpacity(0.5),
                        blurRadius: 8, offset: const Offset(0, -3))],
                  ),
                ),
              ]),
            ]),
        SizedBox(height: rs.sp(9)),
        Text(d.label, style: TextStyle(fontSize: rs.sp(9), color: Colors.white38,
            fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// BUDGET LIST
// ════════════════════════════════════════════════════════════════
class AnalyticsBudgetList extends StatelessWidget {
  const AnalyticsBudgetList({super.key,
    required this.budgets, required this.catTotals,
    required this.symbol,  required this.onEdit});
  final List<BudgetEntity> budgets;
  final Map<String, double> catTotals;
  final String symbol;
  final void Function(BudgetEntity) onEdit;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Container(
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(rs.sp(24)),
        boxShadow: [BoxShadow(color: AppColors.royalBlue.withOpacity(0.08),
            blurRadius: 28, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: budgets.asMap().entries.map((e) => AnalyticsBudgetRow(
          budget: e.value, spent: catTotals[e.value.category] ?? 0.0,
          symbol: symbol,  isLast: e.key == budgets.length - 1,
          index:  e.key,   onEdit: () => onEdit(e.value),
        )).toList(),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// BUDGET ROW
// ════════════════════════════════════════════════════════════════
class AnalyticsBudgetRow extends StatelessWidget {
  const AnalyticsBudgetRow({super.key,
    required this.budget, required this.spent,
    required this.symbol, required this.isLast,
    required this.index,  required this.onEdit});
  final BudgetEntity budget;
  final double spent; final String symbol;
  final bool isLast;  final int  index;
  final VoidCallback onEdit;

  static const _palettes = [
    [Color(0xFF0033FF), Color(0xFF977DFF)],
    [Color(0xFF00BFA5), Color(0xFF00897B)],
    [Color(0xFF7C4DFF), Color(0xFFB39DDB)],
    [Color(0xFFFF6D00), Color(0xFFFFAB40)],
    [Color(0xFFE91E63), Color(0xFFF48FB1)],
  ];

  @override
  Widget build(BuildContext context) {
    final rs     = Rs.of(context);
    final pct    = budget.limitAmount > 0
        ? (spent / budget.limitAmount * 100).clamp(0.0, 100.0) : 0.0;
    final over   = spent > budget.limitAmount && budget.limitAmount > 0;
    final colors = over
        ? [AppColors.expense, const Color(0xFFFF8A9B)]
        : _palettes[index % _palettes.length];
    final accent = colors[0];

    return GestureDetector(
      onTap: onEdit,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          border: isLast ? null : Border(
            bottom: BorderSide(color: AppColors.bgLavender, width: 1.5),
          ),
        ),
        padding: EdgeInsets.fromLTRB(rs.sp(16), rs.sp(16), rs.sp(16), rs.sp(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Emoji badge with gradient bg
          Container(
            width: rs.sp(48), height: rs.sp(48),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [colors[0].withOpacity(0.18), colors[1].withOpacity(0.08)],
              ),
              borderRadius: BorderRadius.circular(rs.sp(15)),
              border: Border.all(color: colors[0].withOpacity(0.25), width: 1.2),
            ),
            child: Center(child: Text(budget.emoji,
                style: TextStyle(fontSize: rs.sp(22)))),
          ),
          SizedBox(width: rs.sp(13)),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(budget.label,
                  style: TextStyle(fontSize: rs.sp(13), fontWeight: FontWeight.w700,
                      color: AppColors.textDark, letterSpacing: -0.2))),
              Container(
                padding: EdgeInsets.symmetric(horizontal: rs.sp(9), vertical: rs.sp(4)),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    accent.withOpacity(0.12), accent.withOpacity(0.06)]),
                  borderRadius: BorderRadius.circular(rs.sp(20)),
                  border: Border.all(color: accent.withOpacity(0.25), width: 1),
                ),
                child: Text(
                  budget.limitAmount > 0 ? '${pct.toStringAsFixed(0)}%' : 'Set',
                  style: TextStyle(fontSize: rs.sp(10), fontWeight: FontWeight.w800, color: accent),
                ),
              ),
            ]),
            SizedBox(height: rs.sp(9)),
            // Gradient progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(rs.sp(10)),
              child: Stack(children: [
                Container(height: rs.sp(7),
                    decoration: BoxDecoration(
                      color: AppColors.bgLavender,
                      borderRadius: BorderRadius.circular(rs.sp(10)),
                    )),
                FractionallySizedBox(
                  widthFactor: (pct / 100).clamp(0.0, 1.0),
                  child: Container(
                    height: rs.sp(7),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: colors),
                      borderRadius: BorderRadius.circular(rs.sp(10)),
                      boxShadow: [BoxShadow(color: accent.withOpacity(0.5), blurRadius: 6)],
                    ),
                  ),
                ),
              ]),
            ),
            SizedBox(height: rs.sp(7)),
            Row(children: [
              Text('$symbol${_fmt(spent)}',
                  style: TextStyle(fontSize: rs.sp(11), color: AppColors.textMid,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                budget.limitAmount > 0
                    ? 'of $symbol${_fmt(budget.limitAmount)}'
                    : 'Tap to set limit',
                style: TextStyle(fontSize: rs.sp(11), color: AppColors.textMuted,
                    fontWeight: FontWeight.w500),
              ),
            ]),
          ])),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// HISTORY LIST
// ════════════════════════════════════════════════════════════════
class AnalyticsHistoryList extends StatelessWidget {
  const AnalyticsHistoryList({super.key, required this.bars, required this.symbol});
  final List<BarData> bars; final String symbol;

  @override
  Widget build(BuildContext context) {
    final rs       = Rs.of(context);
    final reversed = bars.reversed.toList();

    return Container(
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(rs.sp(24)),
        boxShadow: [BoxShadow(color: AppColors.royalBlue.withOpacity(0.08),
            blurRadius: 24, offset: const Offset(0, 8))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: reversed.asMap().entries.map((e) => _HistoryRow(
          bar:    e.value,
          symbol: symbol,
          index:  e.key,
          isLast: e.key == reversed.length - 1,
        )).toList(),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({super.key,
    required this.bar, required this.symbol,
    required this.index, required this.isLast});
  final BarData bar; final String symbol;
  final int index;   final bool isLast;

  static const _monthColors = [
    [Color(0xFF0033FF), Color(0xFF977DFF)],
    [Color(0xFF00BFA5), Color(0xFF00E5A0)],
    [Color(0xFF7C4DFF), Color(0xFFB39DDB)],
    [Color(0xFFFF6D00), Color(0xFFFFAB40)],
    [Color(0xFFE91E63), Color(0xFFF48FB1)],
    [Color(0xFF0288D1), Color(0xFF4FC3F7)],
  ];

  @override
  Widget build(BuildContext context) {
    final rs     = Rs.of(context);
    final net    = bar.income - bar.expense;
    final fmt    = NumberFormat('#,##0', 'en_US');
    final colors = _monthColors[index % _monthColors.length];
    final isPos  = net >= 0;

    return Container(
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : const Color(0xFFF8F7FF),
        border: isLast ? null
            : const Border(bottom: BorderSide(color: Color(0x07000000), width: 1)),
      ),
      padding: EdgeInsets.symmetric(horizontal: rs.sp(16), vertical: rs.sp(14)),
      child: Row(children: [
        // Month gradient badge
        Container(
          width: rs.sp(44), height: rs.sp(44),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: colors,
            ),
            borderRadius: BorderRadius.circular(rs.sp(14)),
            boxShadow: [BoxShadow(color: colors[0].withOpacity(0.35),
                blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Center(child: Text(bar.label.substring(0, 1),
              style: TextStyle(fontSize: rs.sp(16), fontWeight: FontWeight.w900,
                  color: Colors.white, fontFamily: 'Sora'))),
        ),
        SizedBox(width: rs.sp(13)),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(bar.label, style: TextStyle(fontSize: rs.sp(14), fontWeight: FontWeight.w700,
              color: AppColors.textDark, letterSpacing: -0.2)),
          SizedBox(height: rs.sp(3)),
          Container(
            padding: EdgeInsets.symmetric(horizontal: rs.sp(7), vertical: rs.sp(2)),
            decoration: BoxDecoration(
              color: isPos
                  ? AppColors.income.withOpacity(0.10)
                  : AppColors.expense.withOpacity(0.10),
              borderRadius: BorderRadius.circular(rs.sp(20)),
            ),
            child: Text(
              isPos
                  ? 'Saved $symbol${fmt.format(net)}'
                  : 'Over $symbol${fmt.format(net.abs())}',
              style: TextStyle(
                fontSize: rs.sp(10),
                color: isPos ? AppColors.income : AppColors.expense,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Row(children: [
            Container(
              width: rs.sp(6), height: rs.sp(6),
              margin: EdgeInsets.only(right: rs.sp(4)),
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: AppColors.income),
            ),
            Text('+$symbol${fmt.format(bar.income)}',
                style: TextStyle(fontSize: rs.sp(12), fontWeight: FontWeight.w700,
                    color: AppColors.income)),
          ]),
          SizedBox(height: rs.sp(4)),
          Row(children: [
            Container(
              width: rs.sp(6), height: rs.sp(6),
              margin: EdgeInsets.only(right: rs.sp(4)),
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: AppColors.expense),
            ),
            Text('-$symbol${fmt.format(bar.expense)}',
                style: TextStyle(fontSize: rs.sp(12), fontWeight: FontWeight.w700,
                    color: AppColors.expense)),
          ]),
        ]),
      ]),
    );
  }
}