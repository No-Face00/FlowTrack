// lib/features/analytics/presentation/analytics_screen.dart
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../budget/domain/entities/budget_entity.dart';
import '../../budget/presentation/cubit/budget_cubit.dart';
import '../../budget/presentation/cubit/budget_state.dart';
import '../../transactions/domain/entities/transaction_entity.dart';
import '../../transactions/presentation/cubit/balance_cubit.dart';
import '../../transactions/presentation/cubit/balance_state.dart';
import '../../transactions/presentation/cubit/transaction_cubit.dart';
import '../../transactions/presentation/cubit/transaction_state.dart';
import '../Widgets/analytics_widgets.dart';

const _kDefaultBudgets = [
  _BT('🍔', 'Food & Dining',    'food',      8000),
  _BT('🚗', 'Transport',        'transport', 3000),
  _BT('🏠', 'Bills & Utilities','bills',     6000),
  _BT('🛒', 'Groceries',        'groceries', 4000),
  _BT('💊', 'Health & Medical', 'health',    2500),
];

class _BT {
  final String emoji, label, category;
  final double limit;
  const _BT(this.emoji, this.label, this.category, this.limit);
}

// ══════════════════════════════════════════════════════════════
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final now    = DateTime.now();
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<TransactionCubit>()..loadTransactions()),
        BlocProvider(create: (_) => getIt<BalanceCubit>()..watchBalance(userId)),
        BlocProvider(create: (_) => getIt<BudgetCubit>()..loadForMonth(now.month, now.year)),
      ],
      child: const _AnalyticsView(),
    );
  }
}

// ══════════════════════════════════════════════════════════════
class _AnalyticsView extends StatefulWidget {
  const _AnalyticsView();
  @override State<_AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends State<_AnalyticsView> {
  String _period = 'monthly';
  String _p(int n) => n.toString().padLeft(2, '0');

  List<BarData> _buildBars(List<TransactionEntity> txns) {
    final now = DateTime.now();
    if (_period == 'daily') {
      return List.generate(7, (i) {
        final day  = now.subtract(Duration(days: 6 - i));
        final dStr = '${day.year}-${_p(day.month)}-${_p(day.day)}';
        double inc = 0, exp = 0;
        for (final tx in txns) {
          DateTime d; try { d = tx.date as DateTime; } catch (_) { d = now; }
          if ('${d.year}-${_p(d.month)}-${_p(d.day)}' == dStr) {
            if (tx.type == 'income')  inc += tx.amount;
            if (tx.type == 'expense') exp += tx.amount;
          }
        }
        return BarData(label: DateFormat('EEE').format(day), income: inc, expense: exp);
      });
    }
    if (_period == 'yearly') {
      return List.generate(5, (i) {
        final yr = now.year - (4 - i);
        double inc = 0, exp = 0;
        for (final tx in txns) {
          if (tx.month.startsWith('$yr-')) {
            if (tx.type == 'income')  inc += tx.amount;
            if (tx.type == 'expense') exp += tx.amount;
          }
        }
        return BarData(label: '$yr', income: inc, expense: exp);
      });
    }
    return List.generate(6, (i) {
      final dt = DateTime(now.year, now.month - (5 - i), 1);
      final m  = '${dt.year}-${_p(dt.month)}';
      double inc = 0, exp = 0;
      for (final tx in txns) {
        if (tx.month == m) {
          if (tx.type == 'income')  inc += tx.amount;
          if (tx.type == 'expense') exp += tx.amount;
        }
      }
      return BarData(label: DateFormat('MMM').format(dt), income: inc, expense: exp);
    });
  }

  Map<String, double> _catTotals(List<TransactionEntity> txns) {
    final now   = DateTime.now();
    final this_ = '${now.year}-${_p(now.month)}';
    final map   = <String, double>{};
    for (final tx in txns) {
      if (tx.type == 'expense' && tx.month == this_) {
        map[tx.category] = (map[tx.category] ?? 0) + tx.amount;
      }
    }
    return map;
  }

  List<BudgetEntity> _resolveBudgets(BudgetState state) {
    final now      = DateTime.now();
    final saved    = state is BudgetLoaded ? state.budgets : <BudgetEntity>[];
    final savedMap = {for (final b in saved) b.category: b};
    final result   = _kDefaultBudgets.map((t) {
      final s = savedMap[t.category];
      return s ?? BudgetEntity(id: '', category: t.category, label: t.label,
          emoji: t.emoji, limitAmount: t.limit, currency: 'BDT',
          month: now.month, year: now.year);
    }).toList();
    final defaults = _kDefaultBudgets.map((t) => t.category).toSet();
    for (final b in saved) {
      if (!defaults.contains(b.category)) result.add(b);
    }
    return result;
  }

  String _sym(BuildContext ctx) {
    try {
      final s = ctx.read<BalanceCubit>().state;
      return s is BalanceLoaded ? s.symbol : '৳';
    } catch (_) { return '৳'; }
  }

  void _openEdit(BuildContext ctx, BudgetEntity b) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(value: ctx.read<BudgetCubit>(),
          child: _EditBudgetSheet(budget: b, symbol: _sym(ctx))),
    );
  }

  void _openAdd(BuildContext ctx) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(value: ctx.read<BudgetCubit>(),
          child: _AddBudgetSheet(symbol: _sym(ctx))),
    );
  }

  double _headerH(BuildContext ctx, Rs rs) {
    final top = MediaQuery.of(ctx).padding.top;
    return top + rs.sp(14) + rs.sp(50) + rs.sp(18) + rs.sp(80)
        + rs.sp(16) + rs.sp(54) + rs.sp(24) + 36;
  }

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Scaffold(
      backgroundColor: AppColors.bgLavender,
      body: NestedScrollView(
        headerSliverBuilder: (hCtx, _) => [
          SliverAppBar(
            pinned: false, floating: false, snap: false,
            elevation: 0, backgroundColor: Colors.transparent,
            toolbarHeight: _headerH(hCtx, rs),
            flexibleSpace: FlexibleSpaceBar(
              background: _AnalyticsHeader(
                period: _period,
                onPeriod: (p) => setState(() => _period = p),
              ),
            ),
          ),
        ],
        body: BlocBuilder<TransactionCubit, TransactionState>(
          builder: (ctx, txState) {
            final txns      = txState is TransactionLoaded ? txState.transactions : <TransactionEntity>[];
            final bars      = _buildBars(txns);
            final catTotals = _catTotals(txns);
            final maxVal    = bars.fold(0.0, (m, b) => b.income > m ? b.income : m);
            return ListView(
              padding: EdgeInsets.fromLTRB(rs.sp(18), rs.sp(20), rs.sp(18), 120),
              physics: const BouncingScrollPhysics(),
              children: [
                BlocBuilder<BalanceCubit, BalanceState>(
                  builder: (_, s) => AnalyticsSummaryRow(
                    income:  s is BalanceLoaded ? s.income  : 0,
                    expense: s is BalanceLoaded ? s.expense : 0,
                    symbol:  s is BalanceLoaded ? s.symbol  : '৳',
                  ),
                ),
                SizedBox(height: rs.sp(20)),
                AnalyticsBarChart(bars: bars, maxVal: maxVal),
                SizedBox(height: rs.sp(26)),
                _SectionRow(
                  title: 'Budget Overview',
                  subtitle: 'This month • tap row to edit',
                  action: GestureDetector(
                    onTap: () => _openAdd(ctx),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: rs.sp(13), vertical: rs.sp(8)),
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
                        Text('Add', style: TextStyle(color: Colors.white,
                            fontSize: rs.sp(12), fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ),
                SizedBox(height: rs.sp(14)),
                BlocBuilder<BudgetCubit, BudgetState>(
                  builder: (ctx, bs) {
                    if (bs is BudgetLoading) return const _BudgetShimmer();
                    return AnalyticsBudgetList(
                      budgets: _resolveBudgets(bs),
                      catTotals: catTotals,
                      symbol: _sym(ctx),
                      onEdit: (b) => _openEdit(ctx, b),
                    );
                  },
                ),
                SizedBox(height: rs.sp(26)),
                _SectionRow(
                    title: 'Monthly History',
                    subtitle: 'Income & expenses per period'),
                SizedBox(height: rs.sp(14)),
                BlocBuilder<BalanceCubit, BalanceState>(
                  builder: (_, s) => AnalyticsHistoryList(
                    bars: bars,
                    symbol: s is BalanceLoaded ? s.symbol : '৳',
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// ANALYTICS HEADER
// gradient bg + orbs + stat card + quick chips + wave divider
// ══════════════════════════════════════════════════════════════
class _AnalyticsHeader extends StatelessWidget {
  const _AnalyticsHeader({required this.period, required this.onPeriod});
  final String period;
  final ValueChanged<String> onPeriod;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Full-size gradient background
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [
                  AppColors.midnight,
                  AppColors.deepBlue,
                  AppColors.royalBlue,
                  AppColors.violet,
                ],
                stops: [0.0, 0.35, 0.70, 1.0],
              ),
            ),
          ),
        ),

        // Orbs
        Positioned(top: -50, left: -50,    child: _Orb(180, 0.06)),
        Positioned(top:   8, right: -60,   child: _Orb(200, 0.05)),
        Positioned(bottom: 60, right: 20,  child: _Orb(100, 0.07)),
        Positioned(bottom: 30, left:  60,  child: _Orb(70,  0.05)),

        // Content
        SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                rs.sp(20), rs.sp(14), rs.sp(20), 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + period chip
                Row(children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Analytics',
                        style: TextStyle(
                            fontSize:      rs.sp(30),
                            fontWeight:    FontWeight.w800,
                            color:         Colors.white,
                            fontFamily:    'Sora',
                            letterSpacing: -0.5)),
                    Text('Financial Overview',
                        style: TextStyle(
                            fontSize:   rs.sp(12),
                            color:      Colors.white38,
                            fontWeight: FontWeight.w400)),
                  ]),
                  const Spacer(),
                  _GlassPeriodChip(selected: period, onChanged: onPeriod),
                ]),
                SizedBox(height: rs.sp(18)),

                // Net balance glass card
                BlocBuilder<BalanceCubit, BalanceState>(
                  builder: (_, s) => _GlassStatCard(
                    balance: s is BalanceLoaded ? s.balance : 0.0,
                    symbol:  s is BalanceLoaded ? s.symbol  : '৳',
                  ),
                ),
                SizedBox(height: rs.sp(16)),

                // Quick-stat chips row — fills empty space,
                // gives at-a-glance income / spent / saved info
                BlocBuilder<BalanceCubit, BalanceState>(
                  builder: (_, s) {
                    final symbol  = s is BalanceLoaded ? s.symbol  : '৳';
                    final income  = s is BalanceLoaded ? s.income  : 0.0;
                    final expense = s is BalanceLoaded ? s.expense : 0.0;
                    final net     = income - expense;
                    final fmt     = NumberFormat('#,##0');
                    return Row(children: [
                      _QuickChip(
                        icon:  Icons.arrow_upward_rounded,
                        label: 'Income',
                        value: '$symbol${fmt.format(income)}',
                        color: AppColors.income,
                      ),
                      SizedBox(width: rs.sp(10)),
                      _QuickChip(
                        icon:  Icons.arrow_downward_rounded,
                        label: 'Spent',
                        value: '$symbol${fmt.format(expense)}',
                        color: AppColors.expense,
                      ),
                      SizedBox(width: rs.sp(10)),
                      _QuickChip(
                        icon:  Icons.savings_rounded,
                        label: 'Saved',
                        value: net >= 0
                            ? '$symbol${fmt.format(net)}'
                            : '-$symbol${fmt.format(net.abs())}',
                        color: net >= 0 ? AppColors.income : AppColors.expense,
                      ),
                    ]);
                  },
                ),
                SizedBox(height: rs.sp(24)),
              ],
            ),
          ),
        ),

        // Curved wave divider — eliminates the harsh flat
        // blue/white cut between header and scroll body.
        // Draws bgLavender as a concave arc curving INTO
        // the gradient — body looks like a raised card.
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: CustomPaint(
            size: const Size(double.infinity, 36),
            painter: _CurvedDividerPainter(color: AppColors.bgLavender),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// CURVED DIVIDER PAINTER
// ══════════════════════════════════════════════════════════════
class _CurvedDividerPainter extends CustomPainter {
  const _CurvedDividerPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.55)
      ..quadraticBezierTo(
        size.width * 0.5,    // control x — centre
        -size.height * 0.55, // control y — above top, bites into blue
        size.width,
        size.height * 0.55,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CurvedDividerPainter old) => old.color != color;
}

// ══════════════════════════════════════════════════════════════
// QUICK CHIP — glassmorphism mini-stat in header row
// ══════════════════════════════════════════════════════════════
class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String   label, value;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(rs.sp(16)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: rs.sp(10), vertical: rs.sp(10)),
            decoration: BoxDecoration(
              color:        Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(rs.sp(16)),
              border: Border.all(
                  color: Colors.white.withOpacity(0.18), width: 1),
            ),
            child: Row(children: [
              Container(
                width: rs.sp(28), height: rs.sp(28),
                decoration: BoxDecoration(
                  color:        color.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(rs.sp(8)),
                ),
                child: Icon(icon, color: color, size: rs.sp(14)),
              ),
              SizedBox(width: rs.sp(7)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontSize:   rs.sp(9),
                            color:      Colors.white54,
                            fontWeight: FontWeight.w500)),
                    Text(value,
                        style: TextStyle(
                            fontSize:   rs.sp(11),
                            color:      Colors.white,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Sora'),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// ORB
// ══════════════════════════════════════════════════════════════
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

// ══════════════════════════════════════════════════════════════
// GLASS STAT CARD
// ══════════════════════════════════════════════════════════════
class _GlassStatCard extends StatelessWidget {
  const _GlassStatCard({required this.balance, required this.symbol});
  final double balance; final String symbol;

  @override
  Widget build(BuildContext context) {
    final rs     = Rs.of(context);
    final isPos  = balance >= 0;
    final numStr = NumberFormat('#,##0', 'en_US').format(balance.abs());

    return ClipRRect(
      borderRadius: BorderRadius.circular(rs.sp(22)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.all(rs.sp(18)),
          decoration: BoxDecoration(
            color:        Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(rs.sp(22)),
            border: Border.all(
                color: Colors.white.withOpacity(0.18), width: 1),
          ),
          child: Row(children: [
            Container(
              width: rs.sp(44), height: rs.sp(44),
              decoration: BoxDecoration(
                color:        Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(rs.sp(14)),
                border: Border.all(
                    color: Colors.white.withOpacity(0.25), width: 1),
              ),
              child: Icon(Icons.account_balance_wallet_rounded,
                  color: Colors.white, size: rs.sp(22)),
            ),
            SizedBox(width: rs.sp(14)),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Net Balance',
                        style: TextStyle(
                            color:      Colors.white54,
                            fontSize:   rs.sp(11),
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5)),
                    SizedBox(height: rs.sp(3)),
                    Text('${isPos ? '+' : '-'}$symbol$numStr',
                        style: TextStyle(
                            color:      Colors.white,
                            fontSize:   rs.sp(20),
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Sora'),
                        overflow: TextOverflow.ellipsis),
                  ]),
            ),
            SizedBox(width: rs.sp(8)),
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: rs.sp(11), vertical: rs.sp(7)),
              decoration: BoxDecoration(
                color: isPos
                    ? AppColors.income.withOpacity(0.20)
                    : AppColors.expense.withOpacity(0.20),
                borderRadius: BorderRadius.circular(rs.sp(14)),
                border: Border.all(
                  color: isPos
                      ? AppColors.income.withOpacity(0.35)
                      : AppColors.expense.withOpacity(0.35),
                  width: 1,
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  isPos
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  color: isPos ? AppColors.income : AppColors.expense,
                  size: rs.sp(14),
                ),
                SizedBox(width: rs.sp(5)),
                Text(isPos ? 'Surplus' : 'Deficit',
                    style: TextStyle(
                        color: isPos ? AppColors.income : AppColors.expense,
                        fontSize:   rs.sp(11),
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// GLASS PERIOD CHIP
// ══════════════════════════════════════════════════════════════
class _GlassPeriodChip extends StatelessWidget {
  const _GlassPeriodChip({required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;
  static const _opts   = ['daily', 'monthly', 'yearly'];
  static const _labels = ['Daily', 'Monthly', 'Yearly'];

  @override
  Widget build(BuildContext context) {
    final rs  = Rs.of(context);
    final idx = _opts.indexOf(selected).clamp(0, 2);
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context, backgroundColor: Colors.transparent,
        builder: (_) => _PeriodSheet(
            selected: selected, onChanged: onChanged),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(rs.sp(22)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: rs.sp(16), vertical: rs.sp(10)),
            decoration: BoxDecoration(
              color:        Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(rs.sp(22)),
              border: Border.all(
                  color: Colors.white.withOpacity(0.25), width: 1),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_labels[idx],
                  style: TextStyle(
                      fontSize:   rs.sp(12),
                      fontWeight: FontWeight.w700,
                      color:      Colors.white,
                      letterSpacing: 0.3)),
              SizedBox(width: rs.sp(6)),
              Icon(Icons.keyboard_arrow_down_rounded,
                  size: rs.sp(16), color: Colors.white70),
            ]),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// PERIOD SHEET
// ══════════════════════════════════════════════════════════════
class _PeriodSheet extends StatelessWidget {
  const _PeriodSheet({required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;
  static const _opts   = ['daily',       'monthly',       'yearly'];
  static const _labels = ['Daily',       'Monthly',       'Yearly'];
  static const _icons  = [
    Icons.today_rounded,
    Icons.date_range_rounded,
    Icons.calendar_today_rounded,
  ];
  static const _descs  = ['Last 7 days', 'Last 6 months', 'Last 5 years'];

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Container(
      margin: EdgeInsets.fromLTRB(rs.sp(12), 0, rs.sp(12), rs.sp(12)),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(rs.sp(28)),
        boxShadow: [BoxShadow(
            color: AppColors.midnight.withOpacity(0.15),
            blurRadius: 30, offset: const Offset(0, -4))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: rs.sp(36), height: rs.sp(4),
          margin: EdgeInsets.only(top: rs.sp(14), bottom: rs.sp(18)),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [AppColors.royalBlue, AppColors.violet]),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: rs.sp(22)),
          child: Row(children: [
            Container(
              width: rs.sp(38), height: rs.sp(38),
              decoration: BoxDecoration(
                gradient:     AppColors.heroGradient,
                borderRadius: BorderRadius.circular(rs.sp(12)),
              ),
              child: Icon(Icons.tune_rounded,
                  color: Colors.white, size: rs.sp(18)),
            ),
            SizedBox(width: rs.sp(12)),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('View Period',
                  style: TextStyle(
                      fontSize:   rs.sp(17),
                      fontWeight: FontWeight.w800,
                      color:      AppColors.textDark,
                      fontFamily: 'Sora')),
              Text('Select time range for charts',
                  style: TextStyle(
                      fontSize: rs.sp(11),
                      color:    AppColors.textMuted)),
            ]),
          ]),
        ),
        SizedBox(height: rs.sp(20)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: rs.sp(16)),
          child: Column(
            children: _opts.asMap().entries.map((e) {
              final isSel = e.value == selected;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(e.value);
                  Navigator.pop(context);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin:  EdgeInsets.only(bottom: rs.sp(10)),
                  padding: EdgeInsets.all(rs.sp(16)),
                  decoration: BoxDecoration(
                    gradient: isSel
                        ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end:   Alignment.bottomRight,
                        colors: [Color(0xFFEEF2FF), Color(0xFFF5F0FF)])
                        : null,
                    color:        isSel ? null : AppColors.bgLavender,
                    borderRadius: BorderRadius.circular(rs.sp(18)),
                    border: isSel
                        ? Border.all(
                        color: AppColors.royalBlue.withOpacity(0.3),
                        width: 1.5)
                        : Border.all(
                        color: Colors.transparent, width: 1.5),
                    boxShadow: isSel
                        ? [BoxShadow(
                        color: AppColors.royalBlue.withOpacity(0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 4))]
                        : null,
                  ),
                  child: Row(children: [
                    Container(
                      width: rs.sp(40), height: rs.sp(40),
                      decoration: BoxDecoration(
                        gradient:     isSel ? AppColors.buttonGradient : null,
                        color:        isSel ? null : Colors.white,
                        borderRadius: BorderRadius.circular(rs.sp(12)),
                        boxShadow: [BoxShadow(
                            color: isSel
                                ? AppColors.royalBlue.withOpacity(0.30)
                                : Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 3))],
                      ),
                      child: Icon(_icons[e.key],
                          color: isSel ? Colors.white : AppColors.textMuted,
                          size: rs.sp(19)),
                    ),
                    SizedBox(width: rs.sp(14)),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_labels[e.key],
                                style: TextStyle(
                                    fontSize:   rs.sp(14),
                                    fontWeight: FontWeight.w700,
                                    color: isSel
                                        ? AppColors.royalBlue
                                        : AppColors.textDark)),
                            SizedBox(height: rs.sp(2)),
                            Text(_descs[e.key],
                                style: TextStyle(
                                    fontSize: rs.sp(11),
                                    color:    AppColors.textMuted)),
                          ]),
                    ),
                    if (isSel) ...[
                      SizedBox(width: rs.sp(8)),
                      Container(
                        width: rs.sp(24), height: rs.sp(24),
                        decoration: BoxDecoration(
                          gradient: AppColors.buttonGradient,
                          shape:    BoxShape.circle,
                          boxShadow: [BoxShadow(
                              color: AppColors.royalBlue.withOpacity(0.3),
                              blurRadius: 6)],
                        ),
                        child: Icon(Icons.check_rounded,
                            color: Colors.white, size: rs.sp(14)),
                      ),
                    ],
                  ]),
                ),
              );
            }).toList(),
          ),
        ),
        SizedBox(height: rs.sp(18)),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SECTION ROW
// ══════════════════════════════════════════════════════════════
class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required this.title, required this.subtitle, this.action,
  });
  final String title, subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Container(
        width: rs.sp(4), height: rs.sp(26),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [AppColors.royalBlue, AppColors.violet],
          ),
          borderRadius: BorderRadius.circular(rs.sp(3)),
        ),
      ),
      SizedBox(width: rs.sp(10)),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(
              fontSize:      rs.sp(17),
              fontWeight:    FontWeight.w800,
              color:         AppColors.textDark,
              fontFamily:    'Sora',
              letterSpacing: -0.3)),
          SizedBox(height: rs.sp(1)),
          Text(subtitle, style: TextStyle(
              fontSize: rs.sp(11), color: AppColors.textMuted)),
        ]),
      ),
      if (action != null) action!,
    ]);
  }
}

// ══════════════════════════════════════════════════════════════
// EDIT BUDGET SHEET
// ══════════════════════════════════════════════════════════════
class _EditBudgetSheet extends StatefulWidget {
  const _EditBudgetSheet({required this.budget, required this.symbol});
  final BudgetEntity budget; final String symbol;
  @override State<_EditBudgetSheet> createState() => _EditBudgetSheetState();
}
class _EditBudgetSheetState extends State<_EditBudgetSheet> {
  late final _ctrl = TextEditingController(
    text: widget.budget.limitAmount > 0
        ? widget.budget.limitAmount.toStringAsFixed(0) : '',
  );
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  void _save() {
    final amount = double.tryParse(_ctrl.text.trim());
    if (amount == null || amount <= 0) return;
    final now = DateTime.now();
    context.read<BudgetCubit>().saveBudget(
      existingId: widget.budget.id.isNotEmpty ? widget.budget.id : null,
      category:   widget.budget.category, label: widget.budget.label,
      emoji:      widget.budget.emoji,    limitAmount: amount,
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
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _Sheet(child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetHandle(rs),
          _sheetHeader(rs,
              '${widget.budget.emoji}  ${widget.budget.label}',
              'Set your monthly spending limit'),
          SizedBox(height: rs.sp(22)),
          _amountField(rs, widget.symbol, _ctrl),
          SizedBox(height: rs.sp(24)),
          _saveBtn(rs, _save),
        ],
      )),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// ADD BUDGET SHEET
// ══════════════════════════════════════════════════════════════
class _AddBudgetSheet extends StatefulWidget {
  const _AddBudgetSheet({required this.symbol});
  final String symbol;
  @override State<_AddBudgetSheet> createState() => _AddBudgetSheetState();
}
class _AddBudgetSheetState extends State<_AddBudgetSheet> {
  final _nameCtrl  = TextEditingController();
  final _limitCtrl = TextEditingController();
  String _emoji = '💰';
  static const _emojis = [
    '💰','🏋️','🎮','✈️','🎁','📱','🐾','🌿',
    '💄','🍕','⚽','🎵','🔧','🏦','🚀','🛒',
  ];

  @override void dispose() {
    _nameCtrl.dispose(); _limitCtrl.dispose(); super.dispose();
  }

  void _save() {
    final name   = _nameCtrl.text.trim();
    final amount = double.tryParse(_limitCtrl.text.trim());
    if (name.isEmpty || amount == null || amount <= 0) return;
    final now = DateTime.now();
    context.read<BudgetCubit>().saveBudget(
      category: name.toLowerCase().replaceAll(RegExp(r'\s+'), '_'),
      label: name, emoji: _emoji, limitAmount: amount,
      currency: 'BDT', month: now.month, year: now.year,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _Sheet(child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetHandle(rs),
          _sheetHeader(rs, 'Add Custom Budget',
              'Create your own spending category'),
          SizedBox(height: rs.sp(18)),
          _label(rs, 'Pick an icon'),
          SizedBox(height: rs.sp(10)),
          SizedBox(
            height: rs.sp(48),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _emojis.length,
              separatorBuilder: (_, __) => SizedBox(width: rs.sp(8)),
              itemBuilder: (_, i) {
                final sel = _emojis[i] == _emoji;
                return GestureDetector(
                  onTap: () => setState(() => _emoji = _emojis[i]),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: rs.sp(44), height: rs.sp(44),
                    decoration: BoxDecoration(
                      gradient:     sel ? AppColors.buttonGradient : null,
                      color:        sel ? null : AppColors.bgLavender,
                      borderRadius: BorderRadius.circular(rs.sp(12)),
                      boxShadow: sel
                          ? [BoxShadow(
                          color: AppColors.royalBlue.withOpacity(0.3),
                          blurRadius: 8)]
                          : null,
                    ),
                    child: Center(child: Text(_emojis[i],
                        style: TextStyle(fontSize: rs.sp(20)))),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: rs.sp(16)),
          _label(rs, 'Category name'),
          SizedBox(height: rs.sp(8)),
          _textField(rs, _nameCtrl, 'e.g. Gym, Travel, Pets'),
          SizedBox(height: rs.sp(14)),
          _label(rs, 'Monthly limit'),
          SizedBox(height: rs.sp(8)),
          _amountField(rs, widget.symbol, _limitCtrl),
          SizedBox(height: rs.sp(22)),
          _saveBtn(rs, _save),
        ],
      )),
    );
  }
}

// ── Sheet wrapper ─────────────────────────────────────────────
class _Sheet extends StatelessWidget {
  const _Sheet({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
          rs.sp(22), rs.sp(14), rs.sp(22), rs.sp(36)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(rs.sp(30))),
        boxShadow: [BoxShadow(
            color: AppColors.midnight.withOpacity(0.12),
            blurRadius: 40, offset: const Offset(0, -4))],
      ),
      child: child,
    );
  }
}

// ── Shared sheet helpers ──────────────────────────────────────
Widget _sheetHandle(Rs rs) => Center(
  child: Container(
    width: rs.sp(36), height: rs.sp(4),
    margin: EdgeInsets.only(bottom: rs.sp(18)),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
          colors: [AppColors.royalBlue, AppColors.violet]),
      borderRadius: BorderRadius.circular(2),
    ),
  ),
);

Widget _sheetHeader(Rs rs, String title, String subtitle) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(
          fontSize:   rs.sp(17),
          fontWeight: FontWeight.w800,
          color:      AppColors.textDark,
          fontFamily: 'Sora')),
      SizedBox(height: rs.sp(3)),
      Text(subtitle, style: TextStyle(
          fontSize: rs.sp(12), color: AppColors.textMuted)),
    ]);

Widget _label(Rs rs, String text) => Text(text,
    style: TextStyle(
        fontSize:   rs.sp(12),
        fontWeight: FontWeight.w700,
        color:      AppColors.textMid,
        letterSpacing: 0.2));

Widget _textField(Rs rs, TextEditingController ctrl, String hint) =>
    Container(
      decoration: BoxDecoration(
        color:        AppColors.bgLavender,
        borderRadius: BorderRadius.circular(rs.sp(14)),
        border: Border.all(
            color: AppColors.royalBlue.withOpacity(0.15), width: 1),
      ),
      padding: EdgeInsets.symmetric(
          horizontal: rs.sp(16), vertical: rs.sp(4)),
      child: TextField(
        controller: ctrl,
        style: TextStyle(fontSize: rs.sp(14), fontWeight: FontWeight.w600,
            color: AppColors.textDark),
        decoration: InputDecoration(
          border:    InputBorder.none,
          hintText:  hint,
          hintStyle: TextStyle(
              color: AppColors.textMuted, fontSize: rs.sp(14)),
        ),
      ),
    );

Widget _amountField(Rs rs, String symbol, TextEditingController ctrl) =>
    Container(
      decoration: BoxDecoration(
        color:        AppColors.bgLavender,
        borderRadius: BorderRadius.circular(rs.sp(14)),
        border: Border.all(
            color: AppColors.royalBlue.withOpacity(0.15), width: 1),
      ),
      padding: EdgeInsets.symmetric(
          horizontal: rs.sp(16), vertical: rs.sp(4)),
      child: Row(children: [
        Text(symbol, style: TextStyle(
            fontSize:   rs.sp(20),
            fontWeight: FontWeight.w800,
            color:      AppColors.royalBlue)),
        SizedBox(width: rs.sp(8)),
        Expanded(child: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(fontSize: rs.sp(20), fontWeight: FontWeight.w700,
              color: AppColors.textDark),
          decoration: InputDecoration(
            border:    InputBorder.none,
            hintText:  '0',
            hintStyle: TextStyle(
                color: AppColors.textMuted, fontSize: rs.sp(20)),
          ),
        )),
      ]),
    );

Widget _saveBtn(Rs rs, VoidCallback onTap) => SizedBox(
  width: double.infinity,
  child: GestureDetector(
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.symmetric(vertical: rs.sp(17)),
      decoration: BoxDecoration(
        gradient:     AppColors.buttonGradient,
        borderRadius: BorderRadius.circular(rs.sp(18)),
        boxShadow: [BoxShadow(
            color:      AppColors.royalBlue.withOpacity(0.40),
            blurRadius: 20,
            offset:     const Offset(0, 6))],
      ),
      child: Center(child: Text('Save Budget',
          style: TextStyle(
              fontSize:      rs.sp(15),
              fontWeight:    FontWeight.w700,
              color:         Colors.white,
              letterSpacing: 0.3))),
    ),
  ),
);

// ══════════════════════════════════════════════════════════════
// BUDGET SHIMMER
// ══════════════════════════════════════════════════════════════
class _BudgetShimmer extends StatelessWidget {
  const _BudgetShimmer();
  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Container(
      decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(rs.sp(24))),
      padding: EdgeInsets.all(rs.sp(18)),
      child: Column(children: List.generate(5, (i) => Padding(
        padding: EdgeInsets.symmetric(vertical: rs.sp(9)),
        child: Row(children: [
          Container(
              width: rs.sp(48), height: rs.sp(48),
              decoration: BoxDecoration(
                  color:        AppColors.bgLavender,
                  borderRadius: BorderRadius.circular(rs.sp(15)))),
          SizedBox(width: rs.sp(13)),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(width: rs.sp(100), height: rs.sp(12),
                      decoration: BoxDecoration(
                          color:        AppColors.bgLavender,
                          borderRadius: BorderRadius.circular(6))),
                  const Spacer(),
                  Container(width: rs.sp(38), height: rs.sp(20),
                      decoration: BoxDecoration(
                          color:        AppColors.bgLavender,
                          borderRadius: BorderRadius.circular(rs.sp(20)))),
                ]),
                SizedBox(height: rs.sp(10)),
                Container(height: rs.sp(7),
                    decoration: BoxDecoration(
                        color:        AppColors.bgLavender,
                        borderRadius: BorderRadius.circular(rs.sp(5)))),
              ])),
        ]),
      ))),
    );
  }
}