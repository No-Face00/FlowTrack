// lib/features/analytics/Widgets/analytics_widgets.dart
// ── All visual widgets for the Analytics screen live here ─────
// Screen file only manages state and BLoC wiring.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_categories.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/cubit/app_cubit.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../budget/domain/entities/budget_entity.dart';
import '../../budget/presentation/cubit/budget_cubit.dart';
import '../../budget/presentation/cubit/budget_state.dart';
import '../../transactions/presentation/cubit/balance_cubit.dart';
import '../../transactions/presentation/cubit/balance_state.dart';
import '../../transactions/presentation/cubit/transaction_cubit.dart';
import '../../transactions/presentation/cubit/transaction_state.dart';

// ════════════════════════════════════════════════════════════════
// MODEL
// ════════════════════════════════════════════════════════════════
class BarData {
  final String label;
  final double income, expense;
  const BarData({required this.label, required this.income, required this.expense});
}

// ── Compact number formatter ──────────────────────────────────
String _compact(double v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000)    return '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}K';
  return v.toStringAsFixed(0);
}

// ════════════════════════════════════════════════════════════════
// SHIMMER — animated loading placeholder
// ════════════════════════════════════════════════════════════════
class AnalyticsShimmer extends StatefulWidget {
  const AnalyticsShimmer({
    super.key,
    required this.width,
    required this.height,
    this.radius = 8,
    this.dark = false,
  });
  final double width, height, radius;
  final bool   dark;
  @override
  State<AnalyticsShimmer> createState() => _AnalyticsShimmerState();
}

class _AnalyticsShimmerState extends State<AnalyticsShimmer>
    with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) => Container(
      width: widget.width, height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        gradient: LinearGradient(
          begin: Alignment(-1.5 + _ctrl.value * 3, 0),
          end:   Alignment( 0.5 + _ctrl.value * 3, 0),
          colors: widget.dark
              ? const [Color(0x25FFFFFF), Color(0x60FFFFFF), Color(0x25FFFFFF)]
              : const [Color(0x18000000), Color(0x40000000), Color(0x18000000)],
        ),
      ),
    ),
  );
}

// Dark-variant shimmer used inside the gradient header
class _DarkShimmer extends StatefulWidget {
  const _DarkShimmer({required this.width, required this.height, this.radius = 8});
  final double width, height, radius;
  @override State<_DarkShimmer> createState() => _DarkShimmerState();
}

class _DarkShimmerState extends State<_DarkShimmer>
    with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) => Container(
      width: widget.width, height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        gradient: LinearGradient(
          begin: Alignment(-1.5 + _ctrl.value * 3, 0),
          end:   Alignment( 0.5 + _ctrl.value * 3, 0),
          colors: const [Color(0x20FFFFFF), Color(0x55FFFFFF), Color(0x20FFFFFF)],
        ),
      ),
    ),
  );
}

// ════════════════════════════════════════════════════════════════
// ANALYTICS HEADER
// Gradient background + orbs + net balance + stat chips.
// The period chip is rendered separately in Layer 3 of the screen
// but fades at the same rate via shared bgOpacity.
// ════════════════════════════════════════════════════════════════
class AnalyticsHeader extends StatelessWidget {
  const AnalyticsHeader({super.key, this.bgOpacity = 1.0});
  final double bgOpacity;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Stack(clipBehavior: Clip.none, children: [
      // Gradient background
      Positioned.fill(child: Opacity(
        opacity: bgOpacity,
        child: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [AppColors.midnight, AppColors.deepBlue,
                AppColors.royalBlue, AppColors.violet],
              stops: [0.0, 0.35, 0.70, 1.0],
            ),
          ),
        ),
      )),

      // Decorative orbs
      Positioned(top: -50, left: -50,  child: Opacity(opacity: bgOpacity, child: _Orb(180, 0.06))),
      Positioned(top:   8, right: -60, child: Opacity(opacity: bgOpacity, child: _Orb(200, 0.05))),
      Positioned(top: 200, right:  20, child: Opacity(opacity: bgOpacity, child: _Orb(100, 0.07))),
      Positioned(top: 230, left:   60, child: Opacity(opacity: bgOpacity, child: _Orb(70,  0.04))),

      // Content (fades with background)
      Opacity(
        opacity: bgOpacity,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(rs.sp(20), rs.sp(14), rs.sp(20), 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Title row — chip is in Layer 3 of screen, occupies the right side
              Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Analytics', style: TextStyle(
                      fontSize: rs.sp(28), fontWeight: FontWeight.w800,
                      color: Colors.white, fontFamily: 'Sora', letterSpacing: -0.5)),
                  Text('Financial Overview', style: TextStyle(
                      fontSize: rs.sp(14), color: Colors.white60)),
                ]),
              ]),
              SizedBox(height: rs.sp(16)),

              // Net balance card
              BlocBuilder<BalanceCubit, BalanceState>(
                builder: (_, s) => _NetBalanceCard(
                  balance: s is BalanceLoaded ? s.balance : 0.0,
                  symbol:  s is BalanceLoaded ? s.symbol  : '৳',
                  loading: s is BalanceLoading || s is BalanceInitial,
                ),
              ),
              SizedBox(height: rs.sp(12)),

              // Stat chips row
              BlocBuilder<BalanceCubit, BalanceState>(
                builder: (_, s) {
                  final loading = s is BalanceLoading || s is BalanceInitial;
                  final sym = s is BalanceLoaded ? s.symbol  : '৳';
                  final inc = s is BalanceLoaded ? s.income  : 0.0;
                  final exp = s is BalanceLoaded ? s.expense : 0.0;
                  final net = inc - exp;
                  return Row(children: [
                    _StatChip(icon: Icons.arrow_upward_rounded,
                        label: 'Income', sym: sym, amount: inc,
                        color: AppColors.income, loading: loading),
                    SizedBox(width: rs.sp(8)),
                    _StatChip(icon: Icons.arrow_downward_rounded,
                        label: 'Spent', sym: sym, amount: exp,
                        color: AppColors.expense, loading: loading),
                    SizedBox(width: rs.sp(8)),
                    _StatChip(icon: Icons.savings_rounded,
                        label: 'Saved', sym: sym, amount: net,
                        color: net >= 0 ? AppColors.income : AppColors.expense,
                        loading: loading),
                  ]);
                },
              ),
            ]),
          ),
        ),
      ),
    ]);
  }
}

// ── Decorative orb ────────────────────────────────────────────
class _Orb extends StatelessWidget {
  const _Orb(this.size, this.opacity);
  final double size, opacity;
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacity)),
  );
}

// ── Net balance glass card ────────────────────────────────────
class _NetBalanceCard extends StatelessWidget {
  const _NetBalanceCard({
    required this.balance,
    required this.symbol,
    required this.loading,
  });
  final double balance;
  final String symbol;
  final bool   loading;

  @override
  Widget build(BuildContext context) {
    final rs    = Rs.of(context);
    final isPos = balance >= 0;
    final fmt   = NumberFormat('#,##0', 'en_US');

    return ClipRRect(
      borderRadius: BorderRadius.circular(rs.sp(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.all(rs.sp(16)),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(rs.sp(20)),
            border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
          ),
          child: Row(children: [
            Container(
              width: rs.sp(42), height: rs.sp(42),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(rs.sp(13)),
                border: Border.all(color: Colors.white.withOpacity(0.22), width: 1),
              ),
              child: Icon(Icons.account_balance_wallet_rounded,
                  color: Colors.white, size: rs.sp(21)),
            ),
            SizedBox(width: rs.sp(12)),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Net Balance', style: TextStyle(
                  color: Colors.white70, fontSize: rs.sp(13),
                  fontWeight: FontWeight.w500)),
              SizedBox(height: rs.sp(3)),
              if (loading)
                _DarkShimmer(width: rs.sp(140), height: rs.sp(20), radius: 6)
              else
                Text('${isPos ? "+" : "-"}$symbol${fmt.format(balance.abs())}',
                    style: TextStyle(color: Colors.white,
                        fontSize: rs.sp(18), fontWeight: FontWeight.w800,
                        fontFamily: 'Sora'),
                    overflow: TextOverflow.ellipsis),
            ])),
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: rs.sp(10), vertical: rs.sp(6)),
              decoration: BoxDecoration(
                color: isPos
                    ? AppColors.income.withOpacity(0.18)
                    : AppColors.expense.withOpacity(0.18),
                borderRadius: BorderRadius.circular(rs.sp(12)),
                border: Border.all(
                    color: isPos
                        ? AppColors.income.withOpacity(0.30)
                        : AppColors.expense.withOpacity(0.30),
                    width: 1),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(isPos ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                    color: isPos ? AppColors.income : AppColors.expense,
                    size: rs.sp(13)),
                SizedBox(width: rs.sp(4)),
                Text(isPos ? 'Surplus' : 'Deficit',
                    style: TextStyle(
                        color: isPos ? AppColors.income : AppColors.expense,
                        fontSize: rs.sp(13), fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Stat chip (Income / Spent / Saved) ───────────────────────
class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon, required this.label, required this.sym,
    required this.amount, required this.color, required this.loading,
  });
  final IconData icon;
  final String   label, sym;
  final double   amount;
  final Color    color;
  final bool     loading;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    final display = amount < 0
        ? '-$sym${_compact(amount.abs())}'
        : '$sym${_compact(amount)}';

    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(rs.sp(14)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: rs.sp(10), vertical: rs.sp(9)),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(rs.sp(14)),
              border: Border.all(color: Colors.white.withOpacity(0.16), width: 1),
            ),
            child: Row(children: [
              Container(
                width: rs.sp(26), height: rs.sp(26),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.20),
                    borderRadius: BorderRadius.circular(rs.sp(8))),
                child: Icon(icon, color: color, size: rs.sp(13)),
              ),
              SizedBox(width: rs.sp(6)),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: TextStyle(
                    fontSize: rs.sp(13), color: Colors.white70,
                    fontWeight: FontWeight.w500)),
                if (loading)
                  _DarkShimmer(width: rs.sp(52), height: rs.sp(10), radius: 4)
                else
                  Text(display, style: TextStyle(
                      fontSize: rs.sp(13), color: Colors.white,
                      fontWeight: FontWeight.w700, fontFamily: 'Sora'),
                      overflow: TextOverflow.ellipsis),
              ])),
            ]),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// PERIOD CHIP — glass morphism, opens bottom sheet
// ════════════════════════════════════════════════════════════════
class AnalyticsPeriodChip extends StatelessWidget {
  const AnalyticsPeriodChip({
    super.key,
    required this.selected,
    required this.onChanged,
  });
  final String               selected;
  final ValueChanged<String> onChanged;

  static const _opts   = ['daily',       'monthly',        'yearly'];
  static const _labels = ['Daily',       'Monthly',        'Yearly'];

  void _show(BuildContext context) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (sheetCtx) => _PeriodSheet(
        selected:  selected,
        onChanged: (val) {
          Navigator.pop(sheetCtx);
          HapticFeedback.selectionClick();
          onChanged(val);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rs  = Rs.of(context);
    final idx = _opts.indexOf(selected).clamp(0, 2);

    return GestureDetector(
      onTap: () => _show(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(rs.sp(22)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: rs.sp(14), vertical: rs.sp(9)),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(rs.sp(22)),
              border: Border.all(
                  color: Colors.white.withOpacity(0.25), width: 1),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_labels[idx], style: TextStyle(
                  fontSize: rs.sp(12), fontWeight: FontWeight.w700,
                  color: Colors.white)),
              SizedBox(width: rs.sp(5)),
              Icon(Icons.keyboard_arrow_down_rounded,
                  size: rs.sp(15), color: Colors.white70),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Period selection bottom sheet ─────────────────────────────
class _PeriodSheet extends StatelessWidget {
  const _PeriodSheet({required this.selected, required this.onChanged});
  final String               selected;
  final ValueChanged<String> onChanged;

  static const _opts   = ['daily',       'monthly',        'yearly'];
  static const _labels = ['Daily',       'Monthly',        'Yearly'];
  static const _descs  = ['Last 7 days', 'Last 6 months',  'Last 5 years'];
  static const _icons  = [
    Icons.today_rounded,
    Icons.date_range_rounded,
    Icons.calendar_today_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Container(
      margin: EdgeInsets.fromLTRB(
          rs.sp(12), 0, rs.sp(12),
          rs.sp(12) + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(rs.sp(28)),
        boxShadow: [BoxShadow(
            color: AppColors.midnight.withOpacity(0.18),
            blurRadius: 40, offset: const Offset(0, -4))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _SheetHandle(),
        Padding(
          padding: EdgeInsets.fromLTRB(rs.sp(20), 0, rs.sp(20), rs.sp(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('View Period', style: TextStyle(
                fontSize: rs.sp(17), fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface, fontFamily: 'Sora')),
            SizedBox(height: rs.sp(4)),
            Text('Select the time range for your analytics',
                style: TextStyle(fontSize: rs.sp(12), color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
            SizedBox(height: rs.sp(16)),
            ..._opts.asMap().entries.map((e) {
              final isSel = e.value == selected;
              return GestureDetector(
                onTap: () => onChanged(e.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: EdgeInsets.only(bottom: rs.sp(10)),
                  padding: EdgeInsets.symmetric(
                      horizontal: rs.sp(16), vertical: rs.sp(12)),
                  decoration: BoxDecoration(
                    gradient: isSel ? AppColors.buttonGradient : null,
                    color: isSel ? null : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(rs.sp(16)),
                    boxShadow: isSel ? [BoxShadow(
                        color: AppColors.royalBlue.withOpacity(0.30),
                        blurRadius: 12, offset: const Offset(0, 4))] : null,
                  ),
                  child: Row(children: [
                    Container(
                      width: rs.sp(38), height: rs.sp(38),
                      decoration: BoxDecoration(
                        color: isSel
                            ? Colors.white.withOpacity(0.22)
                            : AppColors.royalBlue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(rs.sp(12)),
                      ),
                      child: Icon(_icons[e.key],
                          color: isSel ? Colors.white : AppColors.royalBlue,
                          size: rs.sp(18)),
                    ),
                    SizedBox(width: rs.sp(14)),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_labels[e.key], style: TextStyle(
                          fontSize: rs.sp(14), fontWeight: FontWeight.w700,
                          color: isSel ? Colors.white : Theme.of(context).colorScheme.onSurface)),
                      Text(_descs[e.key], style: TextStyle(
                          fontSize: rs.sp(13),
                          color: isSel
                              ? Colors.white.withOpacity(0.75)
                              : Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
                    ])),
                    if (isSel)
                      Container(
                        width: rs.sp(22), height: rs.sp(22),
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle),
                        child: Icon(Icons.check_rounded,
                            color: AppColors.royalBlue, size: rs.sp(13)),
                      ),
                  ]),
                ),
              );
            }),
          ]),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ANALYTICS BODY — all scrollable content sections
// ════════════════════════════════════════════════════════════════
class AnalyticsBody extends StatelessWidget {
  const AnalyticsBody({
    super.key,
    required this.bars,
    required this.maxVal,
    required this.catTotals,
    required this.symbol,
    required this.period,
    required this.resolveBudgets,
    required this.onEditBudget,
    required this.onAddBudget,
    required this.onDeleteBudget,
    this.budgetSectionKey,
  });
  final List<BarData>                          bars;
  final double                                 maxVal;
  final Map<String, double>                    catTotals;
  final String                                 symbol;
  final String                                 period;
  final List<BudgetEntity> Function(BudgetState) resolveBudgets;
  final void Function(BudgetEntity)            onEditBudget;
  final VoidCallback                           onAddBudget;
  final void Function(BudgetEntity)            onDeleteBudget;
  final GlobalKey?                             budgetSectionKey;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ── Total income / expense cards ──────────────────────
      AnalyticsSummaryRow(symbol: symbol),
      SizedBox(height: rs.sp(18)),

      // ── Cash flow bar chart ───────────────────────────────
      AnalyticsBarChart(bars: bars, maxVal: maxVal, period: period),
      SizedBox(height: rs.sp(24)),

      // ── Budget overview ───────────────────────────────────
      // budgetSectionKey lets scrollToBudget() find exact position
      KeyedSubtree(
        key: budgetSectionKey,
        child: _SectionHeader(
          title:    'Budget Overview',
          subtitle: 'This month • tap to edit',
          action:   _AddBtn(onTap: onAddBudget),
        ),
      ),
      SizedBox(height: rs.sp(12)),
      BlocBuilder<BudgetCubit, BudgetState>(
        buildWhen: (prev, curr) {
          if (curr is BudgetLoading && prev is BudgetLoaded) return false;
          return true;
        },
        builder: (_, bs) {
          if (bs is BudgetLoading || bs is BudgetInitial) {
            return AnalyticsBudgetShimmer(symbol: symbol);
          }
          return AnalyticsBudgetList(
            budgets:   resolveBudgets(bs),
            catTotals: catTotals,
            symbol:    symbol,
            onEdit:    onEditBudget,
            onDelete:  onDeleteBudget,
          );
        },
      ),
      SizedBox(height: rs.sp(24)),

      // ── Monthly history ───────────────────────────────────
      const _SectionHeader(
        title:    'Monthly History',
        subtitle: 'Income & expenses per period',
      ),
      SizedBox(height: rs.sp(12)),
      AnalyticsHistoryList(bars: bars, symbol: symbol),
    ]);
  }
}

// ── Section header ────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.action,
  });
  final String  title, subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Container(
        width: rs.sp(4), height: rs.sp(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [AppColors.royalBlue, AppColors.violet]),
          borderRadius: BorderRadius.circular(rs.sp(3)),
        ),
      ),
      SizedBox(width: rs.sp(10)),
      Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(
            fontSize: rs.sp(16), fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface, fontFamily: 'Sora', letterSpacing: -0.3)),
        SizedBox(height: rs.sp(1)),
        Text(subtitle, style: TextStyle(
            fontSize: rs.sp(13), color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
      ])),
      if (action != null) action!,
    ]);
  }
}

// ── Add budget button ─────────────────────────────────────────
class _AddBtn extends StatelessWidget {
  const _AddBtn({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: rs.sp(13), vertical: rs.sp(8)),
        decoration: BoxDecoration(
          gradient: AppColors.buttonGradient,
          borderRadius: BorderRadius.circular(rs.sp(22)),
          boxShadow: [BoxShadow(
              color: AppColors.royalBlue.withOpacity(0.35),
              blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.add_rounded, color: Colors.white, size: rs.sp(14)),
          SizedBox(width: rs.sp(4)),
          Text('Add', style: TextStyle(
              color: Colors.white, fontSize: rs.sp(12),
              fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SUMMARY ROW — Total Income / Total Expenses cards
// ════════════════════════════════════════════════════════════════
class AnalyticsSummaryRow extends StatelessWidget {
  const AnalyticsSummaryRow({super.key, required this.symbol});
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return BlocBuilder<BalanceCubit, BalanceState>(
      builder: (_, state) {
        final loading = state is BalanceLoading || state is BalanceInitial;
        final income  = state is BalanceLoaded ? state.income  : 0.0;
        final expense = state is BalanceLoaded ? state.expense : 0.0;
        final sym     = state is BalanceLoaded ? state.symbol  : symbol;
        return Row(children: [
          Expanded(child: _SummaryCard(
              label: 'Total Income',   value: income,
              symbol: sym,            icon: Icons.arrow_upward_rounded,
              gradStart: const Color(0xFF00C48C),
              gradEnd:   const Color(0xFF007A57),
              isLoading: loading,     isIncome: true)),
          SizedBox(width: rs.sp(12)),
          Expanded(child: _SummaryCard(
              label: 'Total Expenses', value: expense,
              symbol: sym,            icon: Icons.arrow_downward_rounded,
              gradStart: const Color(0xFFFF647C),
              gradEnd:   const Color(0xFFCC1A40),
              isLoading: loading,     isIncome: false)),
        ]);
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label, required this.value,   required this.symbol,
    required this.icon,  required this.gradStart, required this.gradEnd,
    required this.isLoading, required this.isIncome,
  });
  final String   label, symbol;
  final double   value;
  final IconData icon;
  final Color    gradStart, gradEnd;
  final bool     isLoading, isIncome;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Container(
      height: rs.sp(130),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [gradStart, gradEnd]),
        borderRadius: BorderRadius.circular(rs.sp(22)),
        boxShadow: [
          BoxShadow(color: gradStart.withOpacity(0.40),
              blurRadius: 20, offset: const Offset(0, 8)),
          BoxShadow(color: gradStart.withOpacity(0.15),
              blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Stack(children: [
        Positioned.fill(child: ClipRRect(
          borderRadius: BorderRadius.circular(rs.sp(22)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.18),
                      Colors.white.withOpacity(0.04),
                    ]),
              ),
            ),
          ),
        )),
        Positioned(top: -rs.sp(16), right: -rs.sp(16),
            child: Container(width: rs.sp(80), height: rs.sp(80),
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.12)))),
        Positioned(bottom: -rs.sp(12), left: rs.sp(20),
            child: Container(width: rs.sp(56), height: rs.sp(56),
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08)))),
        Padding(
          padding: EdgeInsets.all(rs.sp(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment:  MainAxisAlignment.spaceBetween,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Container(
                  width: rs.sp(38), height: rs.sp(38),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(rs.sp(12)),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.30), width: 1)),
                  child: Icon(icon, color: Colors.white, size: rs.sp(19)),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: rs.sp(8), vertical: rs.sp(4)),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.20),
                      borderRadius: BorderRadius.circular(rs.sp(20))),
                  child: Text(isIncome ? '↑' : '↓',
                      style: TextStyle(color: Colors.white,
                          fontSize: rs.sp(12), fontWeight: FontWeight.w800)),
                ),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: TextStyle(
                    fontSize: rs.sp(13), color: Colors.white.withOpacity(0.75),
                    fontWeight: FontWeight.w500, letterSpacing: 0.2)),
                SizedBox(height: rs.sp(4)),
                if (isLoading)
                  AnalyticsShimmer(width: rs.sp(100), height: rs.sp(24),
                      radius: 6, dark: true)
                else
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(symbol, style: TextStyle(
                        fontSize: rs.sp(14), color: Colors.white.withOpacity(0.85),
                        fontWeight: FontWeight.w700, fontFamily: 'Sora')),
                    SizedBox(width: rs.sp(2)),
                    Flexible(child: Text(_compact(value),
                        style: TextStyle(
                            fontSize: rs.sp(24), fontWeight: FontWeight.w800,
                            color: Colors.white, fontFamily: 'Sora',
                            letterSpacing: -0.5),
                        overflow: TextOverflow.ellipsis, maxLines: 1)),
                  ]),
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// BAR CHART — dark gradient cash flow card
// ════════════════════════════════════════════════════════════════
class AnalyticsBarChart extends StatelessWidget {
  const AnalyticsBarChart({super.key, required this.bars, required this.maxVal, required this.period});
  final List<BarData> bars;
  final double        maxVal;
  final String        period;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return BlocBuilder<TransactionCubit, TransactionState>(
      buildWhen: (p, c) => c is TransactionLoading || c is TransactionLoaded,
      builder: (_, txState) {
        final loading = txState is TransactionLoading;
        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF00022A), Color(0xFF0A07A8), Color(0xFF1A1BD4)],
                stops: [0.0, 0.5, 1.0]),
            borderRadius: BorderRadius.circular(rs.sp(24)),
            boxShadow: [BoxShadow(
                color: AppColors.midnight.withOpacity(0.45),
                blurRadius: 24, offset: const Offset(0, 10))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(rs.sp(24)),
            child: Stack(children: [
              Positioned(top: -30, right: -30, child: Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                      color: AppColors.violet.withOpacity(0.07)))),
              Positioned(bottom: 0, left: -20, child: Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                      color: AppColors.royalBlue.withOpacity(0.06)))),
              Padding(
                padding: EdgeInsets.fromLTRB(
                    rs.sp(18), rs.sp(18), rs.sp(18), rs.sp(14)),
                child: Column(children: [
                  // Header row
                  Row(children: [
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Cash Flow', style: TextStyle(
                          fontSize: rs.sp(15), fontWeight: FontWeight.w800,
                          color: Colors.white, fontFamily: 'Sora')),
                      Text('Income vs Expenses', style: TextStyle(
                          fontSize: rs.sp(12), color: Colors.white60)),
                    ])),
                    Row(children: [
                      _ChartLegend(color: AppColors.income, label: 'Income'),
                      SizedBox(width: rs.sp(10)),
                      _ChartLegend(color: AppColors.expense, label: 'Expense'),
                    ]),
                  ]),
                  SizedBox(height: rs.sp(18)),
                  // Bars — clipped so box shadows never escape the container
                  // ValueKey(period) forces full rebuild when period changes,
                  // preventing AnimatedContainer from animating old→new heights.
                  ClipRect(
                    child: SizedBox(
                      height: rs.sp(140),
                      child: loading
                          ? const _ChartLoadingShimmer()
                          : Row(
                        key: ValueKey(period),
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: bars
                            .asMap()
                            .entries
                            .map((e) => _BarGroup(
                          d: e.value,
                          maxVal: maxVal,
                          rs: rs,
                          index: e.key,
                        ))
                            .toList(),
                      ),
                    ),
                  ),
                  SizedBox(height: rs.sp(10)),
                  // Period count label
                  Row(children: [
                    Container(
                      width: rs.sp(6), height: rs.sp(6),
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.violet.withOpacity(0.7)),
                    ),
                    SizedBox(width: rs.sp(6)),
                    Text('${bars.length} periods',
                        style: TextStyle(
                            fontSize: rs.sp(13), color: Colors.white60)),
                  ]),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.color, required this.label});
  final Color  color;
  final String label;
  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Row(children: [
      Container(width: rs.sp(6), height: rs.sp(6),
          decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
      SizedBox(width: rs.sp(4)),
      Text(label, style: TextStyle(
          fontSize: rs.sp(13), color: Colors.white60, fontWeight: FontWeight.w500)),
    ]);
  }
}

class _ChartLoadingShimmer extends StatelessWidget {
  const _ChartLoadingShimmer();
  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(6, (i) => Expanded(child: Padding(
        padding: EdgeInsets.symmetric(horizontal: rs.sp(4)),
        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          AnalyticsShimmer(
              width: double.infinity,
              height: rs.sp(40.0 + (i % 3) * 20),
              radius: 4, dark: true),
        ]),
      ))),
    );
  }
}

class _BarGroup extends StatefulWidget {
  const _BarGroup({required this.d, required this.maxVal, required this.rs, required this.index});
  final BarData d;
  final double  maxVal;
  final Rs      rs;
  final int     index;
  @override
  State<_BarGroup> createState() => _BarGroupState();
}

class _BarGroupState extends State<_BarGroup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutQuart);
    // Stagger each bar by 60ms so they rise one after another left→right
    Future.delayed(Duration(milliseconds: widget.index * 60), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final rs      = widget.rs;
    const maxH    = 100.0;
    const ghostH  = 6.0;
    final mx      = widget.maxVal == 0 ? 1.0 : widget.maxVal;

    final incTarget = widget.d.income  > 0
        ? (widget.d.income  / mx * maxH).clamp(8.0, maxH) : ghostH;
    final expTarget = widget.d.expense > 0
        ? (widget.d.expense / mx * maxH).clamp(8.0, maxH) : ghostH;

    final incIsGhost = widget.d.income  == 0;
    final expIsGhost = widget.d.expense == 0;

    return Expanded(
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) {
          final incH = incIsGhost ? ghostH : incTarget * _anim.value;
          final expH = expIsGhost ? ghostH : expTarget * _anim.value;

          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Income bar
                  Container(
                    width: rs.sp(13),
                    height: incH.clamp(ghostH, maxH),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: incIsGhost
                            ? [Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.05)]
                            : const [Color(0xFF00FFB3), Color(0xFF00C48C)],
                      ),
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(rs.sp(5))),
                      boxShadow: incIsGhost ? null : [BoxShadow(
                          color: AppColors.income.withOpacity(0.55),
                          blurRadius: 8, offset: const Offset(0, -2))],
                    ),
                  ),
                  SizedBox(width: rs.sp(3)),
                  // Expense bar
                  Container(
                    width: rs.sp(13),
                    height: expH.clamp(ghostH, maxH),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: expIsGhost
                            ? [Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.05)]
                            : const [Color(0xFFFF8FA8), Color(0xFFFF647C)],
                      ),
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(rs.sp(5))),
                      boxShadow: expIsGhost ? null : [BoxShadow(
                          color: AppColors.expense.withOpacity(0.45),
                          blurRadius: 8, offset: const Offset(0, -2))],
                    ),
                  ),
                ],
              ),
              SizedBox(height: rs.sp(8)),
              Text(widget.d.label,
                  style: TextStyle(
                      fontSize: rs.sp(11),
                      color: Colors.white60,
                      fontWeight: FontWeight.w600)),
            ],
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// BUDGET LIST
// ════════════════════════════════════════════════════════════════
class AnalyticsBudgetList extends StatelessWidget {
  const AnalyticsBudgetList({
    super.key,
    required this.budgets, required this.catTotals,
    required this.symbol,  required this.onEdit, required this.onDelete,
  });
  final List<BudgetEntity>          budgets;
  final Map<String, double>         catTotals;
  final String                      symbol;
  final void Function(BudgetEntity) onEdit;
  final void Function(BudgetEntity) onDelete;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(rs.sp(22)),
        boxShadow: [
          BoxShadow(color: AppColors.royalBlue.withOpacity(0.07),
              blurRadius: 20, offset: const Offset(0, 6)),
          BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: budgets.asMap().entries.map((e) => AnalyticsBudgetRow(
          budget:   e.value,
          spent:    catTotals[e.value.category] ?? 0.0,
          symbol:   symbol,
          isLast:   e.key == budgets.length - 1,
          index:    e.key,
          onEdit:   () => onEdit(e.value),
          onDelete: () => onDelete(e.value),
        )).toList(),
      ),
    );
  }
}

// ── Budget shimmer ────────────────────────────────────────────
class AnalyticsBudgetShimmer extends StatelessWidget {
  const AnalyticsBudgetShimmer({super.key, required this.symbol});
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Container(
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(rs.sp(22)),
          boxShadow: [BoxShadow(
              color: AppColors.royalBlue.withOpacity(0.06),
              blurRadius: 16, offset: const Offset(0, 4))]),
      padding: EdgeInsets.all(rs.sp(16)),
      child: Column(children: List.generate(5, (_) => Padding(
        padding: EdgeInsets.symmetric(vertical: rs.sp(10)),
        child: Row(children: [
          AnalyticsShimmer(width: rs.sp(44), height: rs.sp(44),
              radius: rs.sp(13)),
          SizedBox(width: rs.sp(12)),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              AnalyticsShimmer(width: rs.sp(90), height: rs.sp(12), radius: 5),
              const Spacer(),
              AnalyticsShimmer(width: rs.sp(38), height: rs.sp(22), radius: 20),
            ]),
            SizedBox(height: rs.sp(8)),
            AnalyticsShimmer(width: double.infinity, height: rs.sp(6), radius: 4),
          ])),
        ]),
      ))),
    );
  }
}

// ── Budget row ────────────────────────────────────────────────
class AnalyticsBudgetRow extends StatelessWidget {
  const AnalyticsBudgetRow({
    super.key,
    required this.budget, required this.spent,   required this.symbol,
    required this.isLast, required this.index,
    required this.onEdit, required this.onDelete,
  });
  final BudgetEntity budget;
  final double       spent;
  final String       symbol;
  final bool         isLast;
  final int          index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static const _palettes = [
    [Color(0xFF0033FF), Color(0xFF977DFF)],
    [Color(0xFF00BFA5), Color(0xFF00E5A0)],
    [Color(0xFF7C4DFF), Color(0xFFB39DDB)],
    [Color(0xFFFF8500), Color(0xFFFFCC00)],
    [Color(0xFF0099FF), Color(0xFF66CCFF)],
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
                bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.80), width: 1.0))),
        padding: EdgeInsets.fromLTRB(
            rs.sp(16), rs.sp(14), rs.sp(16), rs.sp(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [

          // Icon tile
          ClipRRect(
            borderRadius: BorderRadius.circular(rs.sp(14)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(
                  width: rs.sp(46), height: rs.sp(46),
                  decoration: BoxDecoration(
                      color: accent.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(rs.sp(14)),
                      border: Border.all(
                          color: accent.withOpacity(0.25), width: 1)),
                  child: Center(child: Text(budget.emoji,
                      style: TextStyle(fontSize: rs.sp(22))))),
            ),
          ),
          SizedBox(width: rs.sp(12)),

          // Label + progress
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(budget.label, style: TextStyle(
                  fontSize: rs.sp(13), fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface))),
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: rs.sp(9), vertical: rs.sp(4)),
                decoration: BoxDecoration(
                    color: accent.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(rs.sp(20)),
                    border: Border.all(
                        color: accent.withOpacity(0.25), width: 1)),
                child: Text(
                    budget.limitAmount > 0
                        ? '${pct.toStringAsFixed(0)}%' : 'Set',
                    style: TextStyle(
                        fontSize: rs.sp(12), fontWeight: FontWeight.w800,
                        color: accent)),
              ),
            ]),
            SizedBox(height: rs.sp(7)),
            // ── Animated progress bar ──────────────────────────
            // Track: always visible in both light + dark mode
            // Fill:  TweenAnimationBuilder for smooth entry
            SizedBox(
              height: rs.sp(8),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: 0.0,
                  end: (pct / 100).clamp(0.0, 1.0),
                ),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (_, value, __) => LayoutBuilder(
                  builder: (ctx2, constraints) {
                    final trackW = constraints.maxWidth;
                    final fillW  = trackW * value;
                    return Stack(alignment: Alignment.centerLeft, children: [
                      // ── Empty track ──────────────────────────
                      // Uses dividerColor so it's always visible
                      // regardless of card background in dark/light
                      Container(
                        width:  trackW,
                        height: rs.sp(8),
                        decoration: BoxDecoration(
                          color:        Theme.of(context).dividerColor
                              .withOpacity(0.45),
                          borderRadius: BorderRadius.circular(rs.sp(8)),
                        ),
                      ),
                      // ── Filled portion ───────────────────────
                      if (fillW > 0)
                        Container(
                          width:  fillW.clamp(rs.sp(8), trackW),
                          height: rs.sp(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: colors),
                            borderRadius: BorderRadius.circular(rs.sp(8)),
                            boxShadow: [
                              BoxShadow(
                                color:      accent.withOpacity(0.50),
                                blurRadius: 8,
                                offset:     const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                    ]);
                  },
                ),
              ),
            ),
            SizedBox(height: rs.sp(5)),
            Row(children: [
              Text('$symbol${_compact(spent)}', style: TextStyle(
                  fontSize: rs.sp(13), fontWeight: FontWeight.w600,
                  color: over ? AppColors.expense : Theme.of(context).colorScheme.onSurface.withOpacity(0.65))),
              Text(budget.limitAmount > 0
                  ? '  /  $symbol${_compact(budget.limitAmount)}'
                  : '  Tap to set limit',
                  style: TextStyle(
                      fontSize: rs.sp(12), color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
            ]),
          ])),

          // Delete button
          GestureDetector(
            onTap: onDelete,
            child: Container(
              margin: EdgeInsets.only(left: rs.sp(8)),
              width: rs.sp(34), height: rs.sp(34),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFFFF647C), Color(0xFFFF8A9B)]),
                borderRadius: BorderRadius.circular(rs.sp(11)),
                boxShadow: [BoxShadow(
                    color: AppColors.expense.withOpacity(0.28),
                    blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: Icon(Icons.delete_outline_rounded,
                  color: Colors.white, size: rs.sp(16)),
            ),
          ),
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
  final List<BarData> bars;
  final String        symbol;

  @override
  Widget build(BuildContext context) {
    final rs       = Rs.of(context);
    final reversed = bars.reversed.toList();
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(rs.sp(22)),
        boxShadow: [
          BoxShadow(color: AppColors.royalBlue.withOpacity(0.07),
              blurRadius: 20, offset: const Offset(0, 6)),
          BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: reversed.asMap().entries.map((e) => _HistoryRow(
          bar: e.value, symbol: symbol,
          index: e.key, isLast: e.key == reversed.length - 1,
        )).toList(),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    super.key,
    required this.bar, required this.symbol,
    required this.index, required this.isLast,
  });
  final BarData bar;
  final String  symbol;
  final int     index;
  final bool    isLast;

  static const _gradients = [
    [Color(0xFF0033FF), Color(0xFF977DFF)],
    [Color(0xFF00BFA5), Color(0xFF00E5A0)],
    [Color(0xFF7C4DFF), Color(0xFFCC99FF)],
    [Color(0xFFFF8500), Color(0xFFFFCC00)],
    [Color(0xFF0099FF), Color(0xFF66BBFF)],
    [Color(0xFFE91E63), Color(0xFFF48FB1)],
  ];

  @override
  Widget build(BuildContext context) {
    final rs     = Rs.of(context);
    final net    = bar.income - bar.expense;
    final isPos  = net >= 0;
    final grad   = _gradients[index % _gradients.length];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Alternating row tint — theme-aware.
    // Light:  white / very-light lavender (unchanged look)
    // Dark:   card / slightly elevated card (no jarring white)
    final rowColor = index.isEven
        ? Theme.of(context).colorScheme.surface
        : (isDark
        ? const Color(0xFF1A2336)       // DarkColors.cardElevated
        : const Color(0xFFF9F8FF));     // original light lavender tint

    // Divider also becomes theme-aware — a very faint dark stroke on light,
    // a visible-but-subtle blue-grey stroke on dark.
    final dividerColor = isDark
        ? const Color(0xFF1E2D45)           // DarkColors.divider
        : const Color(0x10000000);          // near-transparent on light

    return Container(
      decoration: BoxDecoration(
          color: rowColor,
          border: isLast
              ? null
              : Border(
              bottom: BorderSide(color: dividerColor, width: 0.8))),
      padding: EdgeInsets.symmetric(
          horizontal: rs.sp(16), vertical: rs.sp(13)),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(rs.sp(14)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              width: rs.sp(46), height: rs.sp(46),
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: grad,
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(rs.sp(14)),
                  boxShadow: [BoxShadow(
                      color: grad[0].withOpacity(0.30),
                      blurRadius: 8, offset: const Offset(0, 3))]),
              child: Center(child: Text(
                  bar.label.length >= 3
                      ? bar.label.substring(0, 3) : bar.label,
                  style: TextStyle(fontSize: rs.sp(13),
                      fontWeight: FontWeight.w900, color: Colors.white,
                      fontFamily: 'Sora'))),
            ),
          ),
        ),
        SizedBox(width: rs.sp(12)),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(bar.label, style: TextStyle(
              fontSize: rs.sp(13), fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface)),
          SizedBox(height: rs.sp(3)),
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: rs.sp(7), vertical: rs.sp(2)),
            decoration: BoxDecoration(
                color: isPos
                    ? AppColors.income.withOpacity(0.08)
                    : AppColors.expense.withOpacity(0.08),
                borderRadius: BorderRadius.circular(rs.sp(20))),
            child: Text(
                isPos ? 'Saved $symbol${_compact(net)}'
                    : 'Over $symbol${_compact(net.abs())}',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: rs.sp(12), fontWeight: FontWeight.w700,
                    color: isPos ? AppColors.income : AppColors.expense)),
          ),
        ])),
        // Right column — constrained so long numbers don't overflow
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: rs.sp(110)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _AmtRow(symbol: symbol, value: bar.income,
                color: AppColors.income, prefix: '+', rs: rs),
            SizedBox(height: rs.sp(4)),
            _AmtRow(symbol: symbol, value: bar.expense,
                color: AppColors.expense, prefix: '-', rs: rs),
          ]),
        ),
      ]),
    );
  }
}

class _AmtRow extends StatelessWidget {
  const _AmtRow({
    required this.symbol, required this.value,
    required this.color,  required this.prefix, required this.rs,
  });
  final String symbol, prefix;
  final double value;
  final Color  color;
  final Rs     rs;

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: rs.sp(5), height: rs.sp(5),
      margin: EdgeInsets.only(right: rs.sp(4)),
      decoration: BoxDecoration(
          shape: BoxShape.circle, color: color,
          boxShadow: [BoxShadow(
              color: color.withOpacity(0.5), blurRadius: 3)]),
    ),
    Flexible(child: Text('$prefix$symbol${_compact(value)}',
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: rs.sp(12), fontWeight: FontWeight.w700,
            color: color))),
  ]);
}

// ════════════════════════════════════════════════════════════════
// BUDGET SHEETS — Edit, Add, Delete
// ════════════════════════════════════════════════════════════════

// ── Edit budget ───────────────────────────────────────────────
class BudgetEditSheet extends StatefulWidget {
  const BudgetEditSheet({super.key, required this.budget, required this.symbol});
  final BudgetEntity budget;
  final String       symbol;
  @override
  State<BudgetEditSheet> createState() => _BudgetEditSheetState();
}

class _BudgetEditSheetState extends State<BudgetEditSheet> {
  late final _ctrl = TextEditingController(
      text: widget.budget.limitAmount > 0
          ? widget.budget.limitAmount.toStringAsFixed(0) : '');

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  void _save() {
    final amount = double.tryParse(_ctrl.text.trim());
    if (amount == null || amount <= 0) return;
    final now = DateTime.now();
    context.read<BudgetCubit>().saveBudget(
      existingId: widget.budget.id.isNotEmpty ? widget.budget.id : null,
      category:   widget.budget.category,
      label:      widget.budget.label,
      emoji:      widget.budget.emoji,
      limitAmount: amount,
      currency:   widget.budget.currency.isNotEmpty
          ? widget.budget.currency : 'BDT',
      month: widget.budget.month > 0 ? widget.budget.month : now.month,
      year:  widget.budget.year  > 0 ? widget.budget.year  : now.year,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _BottomSheet(child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SheetHandle(),
        _SheetTitle('${widget.budget.emoji}  ${widget.budget.label}',
            'Set your monthly spending limit', rs),
        SizedBox(height: rs.sp(22)),
        _AmountField(symbol: widget.symbol, ctrl: _ctrl, rs: rs),
        SizedBox(height: rs.sp(24)),
        _SaveButton(onTap: _save, rs: rs),
      ])),
    );
  }
}

// ── Add budget ────────────────────────────────────────────────
class BudgetAddSheet extends StatefulWidget {
  const BudgetAddSheet({super.key, required this.symbol});
  final String symbol;
  @override
  State<BudgetAddSheet> createState() => _BudgetAddSheetState();
}

class _BudgetAddSheetState extends State<BudgetAddSheet> {
  final _limitCtrl = TextEditingController();
  AppCategory? _selected;

  // Only offer categories that don't already have a budget this month
  List<AppCategory> _available(BudgetState budgetState) {
    final now   = DateTime.now();
    final saved = budgetState is BudgetLoaded ? budgetState.budgets : <BudgetEntity>[];
    final existing = {
      for (final b in saved)
        if (b.month == now.month && b.year == now.year && b.limitAmount != -1)
          b.category
    };
    // Exclude 'other' from budget picker — too vague to track meaningfully
    return expenseCategories
        .where((c) => c.value != 'other' && !existing.contains(c.value))
        .toList();
  }

  @override
  void dispose() {
    _limitCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final cat    = _selected;
    final amount = double.tryParse(_limitCtrl.text.trim());
    if (cat == null || amount == null || amount <= 0) return;
    final now = DateTime.now();
    context.read<BudgetCubit>().saveBudget(
      // category value matches TransactionEntity.category exactly
      category:    cat.value,
      label:       cat.label,
      emoji:       cat.emoji,
      limitAmount: amount,
      currency:    context.read<AppCubit>().state.currency,
      month:       now.month,
      year:        now.year,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _BottomSheet(child: BlocBuilder<BudgetCubit, BudgetState>(
        builder: (_, budgetState) {
          final available = _available(budgetState);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SheetHandle(),
              _SheetTitle('Add Budget', 'Pick a category to track', rs),
              SizedBox(height: rs.sp(16)),
              _FieldLabel('Expense Category', rs),
              SizedBox(height: rs.sp(10)),

              // ── Category grid ──────────────────────────────
              if (available.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: rs.sp(16)),
                  child: Center(child: Text(
                    'All expense categories already have budgets!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: rs.sp(13),
                      color: cs.onSurface.withOpacity(0.55),
                    ),
                  )),
                )
              else
                Wrap(
                  spacing: rs.sp(8),
                  runSpacing: rs.sp(8),
                  children: available.map((cat) {
                    final isSel = _selected?.value == cat.value;
                    return GestureDetector(
                      onTap: () => setState(() => _selected = cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: EdgeInsets.symmetric(
                            horizontal: rs.sp(12), vertical: rs.sp(8)),
                        decoration: BoxDecoration(
                          gradient: isSel ? AppColors.buttonGradient : null,
                          color:    isSel ? null
                              : cs.onSurface.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(rs.sp(14)),
                          border: isSel
                              ? Border.all(
                              color: AppColors.royalBlue.withOpacity(0.4),
                              width: 1.5)
                              : null,
                          boxShadow: isSel ? [BoxShadow(
                            color: AppColors.royalBlue.withOpacity(0.25),
                            blurRadius: 10,
                          )] : null,
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(cat.emoji,
                              style: TextStyle(fontSize: rs.sp(16))),
                          SizedBox(width: rs.sp(6)),
                          Text(cat.label, style: TextStyle(
                            fontSize:   rs.sp(12),
                            fontWeight: FontWeight.w700,
                            color: isSel
                                ? Colors.white
                                : cs.onSurface,
                          )),
                        ]),
                      ),
                    );
                  }).toList(),
                ),

              if (available.isNotEmpty) ...[
                SizedBox(height: rs.sp(18)),
                _FieldLabel('Monthly limit (${widget.symbol})', rs),
                SizedBox(height: rs.sp(8)),
                _AmountField(symbol: widget.symbol, ctrl: _limitCtrl, rs: rs),
                SizedBox(height: rs.sp(22)),
                _SaveButton(
                  onTap: (_selected != null) ? _save : null,
                  rs:    rs,
                ),
              ],
            ],
          );
        },
      )),
    );
  }
}

// ── Delete confirm sheet ──────────────────────────────────────
class BudgetDeleteSheet extends StatelessWidget {
  const BudgetDeleteSheet({
    super.key,
    required this.budget,
    required this.onDelete,
    required this.onCancel,
  });
  final BudgetEntity budget;
  final VoidCallback onDelete;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Container(
      margin: EdgeInsets.fromLTRB(rs.sp(12), 0, rs.sp(12),
          rs.sp(12) + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(rs.sp(28)),
        boxShadow: [BoxShadow(
            color: AppColors.midnight.withOpacity(0.14),
            blurRadius: 40, offset: const Offset(0, -4))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Red gradient handle
        Center(child: Container(
          width: rs.sp(36), height: rs.sp(4),
          margin: EdgeInsets.symmetric(vertical: rs.sp(14)),
          decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppColors.expense, Color(0xFFFF8A9B)]),
              borderRadius: BorderRadius.circular(2)),
        )),
        Padding(
          padding: EdgeInsets.fromLTRB(rs.sp(22), 0, rs.sp(22), rs.sp(28)),
          child: Column(children: [
            Container(
              width: rs.sp(64), height: rs.sp(64),
              decoration: BoxDecoration(
                color: AppColors.expense.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.expense.withOpacity(0.20), width: 1.5),
              ),
              child: Center(child: Text(budget.emoji,
                  style: TextStyle(fontSize: rs.sp(28)))),
            ),
            SizedBox(height: rs.sp(14)),
            Text('Remove "${budget.label}"?',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Sora', fontWeight: FontWeight.w800,
                    fontSize: rs.sp(17), color: Theme.of(context).colorScheme.onSurface)),
            SizedBox(height: rs.sp(8)),
            Text('This budget category will be removed\nfrom your overview.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: rs.sp(13), color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    height: 1.5)),
            SizedBox(height: rs.sp(24)),
            // Remove
            GestureDetector(
              onTap: onDelete,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: rs.sp(16)),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFFF647C), Color(0xFFFF8A9B)]),
                  borderRadius: BorderRadius.circular(rs.sp(18)),
                  boxShadow: [BoxShadow(
                      color: AppColors.expense.withOpacity(0.35),
                      blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: Center(child: Text('Remove Budget',
                    style: TextStyle(
                        color: Colors.white, fontSize: rs.sp(15),
                        fontWeight: FontWeight.w700, letterSpacing: 0.2))),
              ),
            ),
            SizedBox(height: rs.sp(12)),
            // Cancel
            GestureDetector(
              onTap: onCancel,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: rs.sp(15)),
                decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(rs.sp(18))),
                child: Center(child: Text('Cancel',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65), fontSize: rs.sp(15),
                        fontWeight: FontWeight.w600))),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SHARED SHEET COMPONENTS
// ════════════════════════════════════════════════════════════════

class _BottomSheet extends StatelessWidget {
  const _BottomSheet({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
          rs.sp(22), rs.sp(14), rs.sp(22), rs.sp(36)),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(rs.sp(30))),
        boxShadow: [BoxShadow(
            color: AppColors.midnight.withOpacity(0.12),
            blurRadius: 40, offset: const Offset(0, -4))],
      ),
      child: child,
    );
  }
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Center(child: Container(
      width: rs.sp(36), height: rs.sp(4),
      margin: EdgeInsets.only(bottom: rs.sp(18)),
      decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [AppColors.royalBlue, AppColors.violet]),
          borderRadius: BorderRadius.circular(2)),
    ));
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle(this.title, this.subtitle, this.rs);
  final String title, subtitle;
  final Rs     rs;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(
            fontSize: rs.sp(17), fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface, fontFamily: 'Sora')),
        SizedBox(height: rs.sp(3)),
        Text(subtitle, style: TextStyle(
            fontSize: rs.sp(12), color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
      ]);
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, this.rs);
  final String text;
  final Rs     rs;

  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          fontSize: rs.sp(12), fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65), letterSpacing: 0.2));
}

class _TextField extends StatelessWidget {
  const _TextField({required this.ctrl, required this.hint, required this.rs});
  final TextEditingController ctrl;
  final String                hint;
  final Rs                    rs;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.6),
        borderRadius: BorderRadius.circular(rs.sp(14)),
        border: Border.all(
            color: AppColors.royalBlue.withOpacity(0.15), width: 1)),
    padding: EdgeInsets.symmetric(
        horizontal: rs.sp(16), vertical: rs.sp(4)),
    child: TextField(
      controller: ctrl,
      style: TextStyle(fontSize: rs.sp(14),
          fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
      decoration: InputDecoration(
          border: InputBorder.none, hintText: hint,
          hintStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: rs.sp(14))),
    ),
  );
}

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.symbol, required this.ctrl, required this.rs,
  });
  final String                symbol;
  final TextEditingController ctrl;
  final Rs                    rs;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.6),
        borderRadius: BorderRadius.circular(rs.sp(14)),
        border: Border.all(
            color: AppColors.royalBlue.withOpacity(0.15), width: 1)),
    padding: EdgeInsets.symmetric(
        horizontal: rs.sp(16), vertical: rs.sp(4)),
    child: Row(children: [
      Text(symbol, style: TextStyle(
          fontSize: rs.sp(20), fontWeight: FontWeight.w800,
          color: AppColors.royalBlue)),
      SizedBox(width: rs.sp(8)),
      Expanded(child: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(fontSize: rs.sp(20),
            fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface),
        decoration: InputDecoration(
            border: InputBorder.none, hintText: '0',
            hintStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: rs.sp(20))),
      )),
    ]),
  );
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.onTap, required this.rs});
  final VoidCallback? onTap;  // nullable — null = disabled (no category selected)
  final Rs            rs;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: rs.sp(17)),
          decoration: BoxDecoration(
            gradient: enabled ? AppColors.buttonGradient : null,
            color:    enabled ? null : Theme.of(context).colorScheme.onSurface.withOpacity(0.12),
            borderRadius: BorderRadius.circular(rs.sp(18)),
            boxShadow: enabled ? [BoxShadow(
                color: AppColors.royalBlue.withOpacity(0.40),
                blurRadius: 20, offset: const Offset(0, 6))] : null,
          ),
          child: Center(child: Text('Save Budget',
              style: TextStyle(
                  fontSize: rs.sp(15), fontWeight: FontWeight.w700,
                  color: enabled ? Colors.white
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.35),
                  letterSpacing: 0.3))),
        ),
      ),
    );
  }  // end build
}    // end _SaveButton