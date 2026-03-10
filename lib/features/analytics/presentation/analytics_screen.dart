// lib/features/analytics/presentation/analytics_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../transactions/domain/entities/transaction_entity.dart';
import '../../transactions/presentation/cubit/balance_cubit.dart';
import '../../transactions/presentation/cubit/balance_state.dart';
import '../../transactions/presentation/cubit/transaction_cubit.dart';
import '../../transactions/presentation/cubit/transaction_state.dart';
import '../widgets/analytics_widgets.dart';

const _kBudgets = [
  BudgetItem('🍔  Food & Dining',   'food',          5000),
  BudgetItem('🚗  Transport',        'transport',     3000),
  BudgetItem('🛍️  Shopping',        'shopping',      3500),
  BudgetItem('🎬  Entertainment',    'entertainment', 1500),
];

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
            create: (_) => getIt<TransactionCubit>()..loadTransactions()),
        BlocProvider(
            create: (_) => getIt<BalanceCubit>()
              ..watchBalance(
                  FirebaseAuth.instance.currentUser?.uid ?? '')),
      ],
      child: const _AnalyticsView(),
    );
  }
}

class _AnalyticsView extends StatelessWidget {
  const _AnalyticsView();

  List<BarData> _buildBars(List<TransactionEntity> txns) {
    final now = DateTime.now();
    return List.generate(6, (i) {
      final dt = DateTime(now.year, now.month - (5 - i), 1);
      final m = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
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
    final map = <String, double>{};
    for (final tx in txns) {
      if (tx.type == 'expense') {
        map[tx.category] = (map[tx.category] ?? 0) + tx.amount;
      }
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Scaffold(
      backgroundColor: AppColors.bgLavender,
      body: BlocBuilder<TransactionCubit, TransactionState>(
        builder: (_, txState) {
          final txns = txState is TransactionLoaded
              ? txState.transactions : <TransactionEntity>[];
          final bars      = _buildBars(txns);
          final catTotals = _catTotals(txns);
          final maxVal    = bars.fold(0.0,
                  (m, b) => b.income > m ? b.income : m);

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Beautiful gradient header ─────────────────
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: AppColors.heroGradient,
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                          rs.sp(20), rs.sp(14), rs.sp(20), rs.sp(24)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text(
                              'Analytics',
                              style: TextStyle(
                                fontSize: rs.sp(28),
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                fontFamily: 'Sora',
                              ),
                            ),
                            const Spacer(),
                            const AnalyticsPeriodChip(),
                          ]),
                          SizedBox(height: rs.sp(20)),
                          // Quick stats in header
                          BlocBuilder<BalanceCubit, BalanceState>(
                            builder: (_, s) {
                              final sym = s is BalanceLoaded ? s.symbol : '\$';
                              final bal = s is BalanceLoaded ? s.balance : 0.0;
                              return _HeaderStat(
                                  balance: bal, symbol: sym, rs: rs);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Body ────────────────────────────────────
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                    rs.sp(18), rs.sp(20), rs.sp(18), 110),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Summary row
                    BlocBuilder<BalanceCubit, BalanceState>(
                      builder: (_, s) => AnalyticsSummaryRow(
                        income:  s is BalanceLoaded ? s.income  : 0,
                        expense: s is BalanceLoaded ? s.expense : 0,
                        symbol:  s is BalanceLoaded ? s.symbol  : '\$',
                      ),
                    ),
                    SizedBox(height: rs.sp(20)),

                    AnalyticsBarChart(bars: bars, maxVal: maxVal),
                    SizedBox(height: rs.sp(24)),

                    _SectionTitle(title: 'Budget Overview', rs: rs),
                    SizedBox(height: rs.sp(12)),
                    AnalyticsBudgetList(budgets: _kBudgets, catTotals: catTotals),
                    SizedBox(height: rs.sp(24)),

                    _SectionTitle(title: 'Monthly History', rs: rs),
                    SizedBox(height: rs.sp(12)),
                    AnalyticsHistoryList(bars: bars),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Header net balance stat ───────────────────────────────────
class _HeaderStat extends StatelessWidget {
  const _HeaderStat({required this.balance, required this.symbol, required this.rs});
  final double balance;
  final String symbol;
  final Rs rs;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: symbol, decimalDigits: 2)
        .format(balance.abs());
    return Container(
      padding: EdgeInsets.all(rs.sp(16)),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(rs.sp(18)),
        border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
      ),
      child: Row(children: [
        Icon(Icons.account_balance_rounded,
            color: Colors.white70, size: rs.sp(22)),
        SizedBox(width: rs.sp(12)),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Net Balance',
              style: TextStyle(
                  color: Colors.white60,
                  fontSize: rs.sp(11),
                  fontWeight: FontWeight.w500)),
          SizedBox(height: rs.sp(2)),
          Text(fmt,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: rs.sp(20),
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Sora')),
        ]),
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.rs});
  final String title;
  final Rs rs;

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: TextStyle(
      fontSize: rs.sp(18),
      fontWeight: FontWeight.w800,
      color: AppColors.textDark,
      fontFamily: 'Sora',
    ),
  );
}