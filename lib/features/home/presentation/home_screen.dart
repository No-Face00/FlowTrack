// lib/features/home/presentation/home_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/router/appRouter.dart';
import '../../transactions/domain/entities/transaction_entity.dart';
import '../../transactions/presentation/cubit/balance_cubit.dart';
import '../../transactions/presentation/cubit/balance_state.dart';
import '../../transactions/presentation/cubit/transaction_cubit.dart';
import '../../transactions/presentation/cubit/transaction_state.dart';
import '../widgets/balance_card.dart';
import '../widgets/transaction_list_item.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => getIt<TransactionCubit>()..loadTransactions(),
        ),
        BlocProvider(
          create: (_) => getIt<BalanceCubit>()
            ..watchBalance(FirebaseAuth.instance.currentUser?.uid ?? ''),
        ),
      ],
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatefulWidget {
  const _HomeView();
  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  bool _showAiInsight = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLavender,
      body: BlocListener<TransactionCubit, TransactionState>(
        listener: (ctx, state) {
          if (state is TransactionDeleted) {
            ScaffoldMessenger.of(ctx).clearSnackBars();
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: const Text('Transaction deleted'),
                backgroundColor: const Color(0xFF3D3B6E),
                duration: const Duration(seconds: 4),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                action: SnackBarAction(
                  label: 'UNDO',
                  textColor: AppColors.violet,
                  onPressed: () =>
                      ctx.read<TransactionCubit>().undoDelete(state.deletedId),
                ),
              ),
            );
          }
        },
        child: CustomScrollView(
          slivers: [
            // ── Hero header ────────────────────────────────────
            SliverToBoxAdapter(
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                        gradient: AppColors.heroGradient),
                    child: Column(
                      children: [
                        SizedBox(
                            height: MediaQuery.of(context).padding.top),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 12),
                          child: Row(
                            children: [
                              _NavBtn(icon: '⚙️', onTap: () {}),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 15, vertical: 7),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.13),
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: Row(children: [
                                  const Text('📅',
                                      style: TextStyle(fontSize: 14)),
                                  const SizedBox(width: 7),
                                  Text(_todayLabel(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      )),
                                ]),
                              ),
                              const Spacer(),
                              _NavBtn(
                                  icon: '🔔', badge: true, onTap: () {}),
                            ],
                          ),
                        ),
                        const BalanceCard(),
                      ],
                    ),
                  ),
                  ..._orbs,
                ],
              ),
            ),

            // ── Body ───────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _WalletCard(),
                  const SizedBox(height: 16),

                  if (_showAiInsight) ...[
                    _AiInsightCard(
                        onDismiss: () =>
                            setState(() => _showAiInsight = false)),
                    const SizedBox(height: 18),
                  ],

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Recent Transactions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                            fontFamily: 'Sora',
                          )),
                      GestureDetector(
                        onTap: () {},
                        child: const Text('See All',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.royalBlue,
                              fontWeight: FontWeight.w700,
                            )),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),

                  BlocBuilder<TransactionCubit, TransactionState>(
                    builder: (ctx, state) {
                      if (state is TransactionLoading) {
                        return _ShimmerList();
                      }
                      List<TransactionEntity> txns = [];
                      if (state is TransactionLoaded) {
                        txns = state.transactions.take(20).toList();
                      }
                      if (txns.isEmpty) return _EmptyState();

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.royalBlue.withOpacity(0.07),
                              blurRadius: 24,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Column(
                            children: txns
                                .asMap()
                                .entries
                                .map((e) => TransactionListItem(
                              tx:       e.value,
                              isLast:   e.key == txns.length - 1,
                              onDelete: () => ctx
                                  .read<TransactionCubit>()
                                  .softDelete(e.value.id),
                            ))
                                .toList(),
                          ),
                        ),
                      );
                    },
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),


    );
  }

  String _todayLabel() {
    final now = DateTime.now();
    const days   = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';
  }

  List<Widget> get _orbs => [
    _orb(200, -60,  -70, 0.07),
    _orb(130, 280,    8, 0.05),
    _orb(70,  190,  110, 0.10),
  ];

  Widget _orb(double size, double left, double top, double opacity) =>
      Positioned(
        left: left, top: top,
        child: IgnorePointer(
          child: Container(
            width: size, height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(opacity),
            ),
          ),
        ),
      );
}

// ── Widgets ───────────────────────────────────────────────────────────

class _NavBtn extends StatelessWidget {
  const _NavBtn({required this.icon, this.badge = false, required this.onTap});
  final String icon;
  final bool   badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Center(
              child: Text(icon, style: const TextStyle(fontSize: 19))),
        ),
        if (badge)
          Positioned(
            top: 9, right: 9,
            child: Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: AppColors.expense,
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.midnight.withOpacity(0.8), width: 2),
              ),
            ),
          ),
      ]),
    );
  }
}

class _WalletCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BalanceCubit, BalanceState>(
      builder: (context, state) {
        final balance = state is BalanceLoaded ? state.balance : 0.0;
        final symbol  = state is BalanceLoaded ? state.symbol  : '\$';
        final formatted = NumberFormat.currency(
          symbol: symbol, decimalDigits: 2,
        ).format(balance.abs());

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppColors.royalBlue.withOpacity(0.09),
                blurRadius: 24, offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppColors.violet, AppColors.royalBlue]),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Center(
                  child: Text('💳', style: TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('SPENDING WALLET',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      )),
                  Text(formatted,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Sora',
                      )),
                ],
              ),
            ),
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppColors.bgLavender,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted, size: 18),
            ),
          ]),
        );
      },
    );
  }
}

class _AiInsightCard extends StatelessWidget {
  const _AiInsightCard({required this.onDismiss});
  final VoidCallback onDismiss;

  String _insight(BalanceState state) {
    if (state is! BalanceLoaded) return 'Loading your financial insights...';
    final balance = state.balance;
    final income  = state.income;
    final expense = state.expense;

    if (income == 0 && expense == 0) {
      return 'Add your first transaction to start tracking your finances! 🚀';
    }
    if (income == 0) {
      return 'You have expenses but no income recorded this month. Add income transactions to track your balance. 💡';
    }
    if (expense == 0) {
      return 'Great start! You have income recorded. Add expenses to track your spending. 📊';
    }
    final savingsRate = ((balance / income) * 100).clamp(-100, 100);
    if (savingsRate >= 50) {
      return 'Excellent! You\'re saving ${savingsRate.toStringAsFixed(0)}% of your income this month. Amazing discipline! 🎉';
    } else if (savingsRate >= 20) {
      return 'Good job! You\'re saving ${savingsRate.toStringAsFixed(0)}% of your income. Keep it up! 👍';
    } else if (savingsRate >= 0) {
      return 'You\'re saving ${savingsRate.toStringAsFixed(0)}% of your income. Try to cut back on expenses to save more. 💪';
    } else {
      return 'You\'re spending ${(-savingsRate).toStringAsFixed(0)}% more than you earn this month. Time to review your budget! ⚠️';
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BalanceCubit, BalanceState>(
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [AppColors.midnight, AppColors.deepBlue]),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: AppColors.violet.withOpacity(0.25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                  child: Text('🤖', style: TextStyle(fontSize: 18))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AI INSIGHT',
                      style: TextStyle(
                        color: AppColors.violet,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      )),
                  const SizedBox(height: 4),
                  Text(
                    _insight(state),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13, height: 1.55),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onDismiss,
              child: Text('✕',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.3), fontSize: 16)),
            ),
          ]),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(22)),
      child: Column(children: [
        const Text('💸', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        const Text('No transactions yet',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark)),
        const SizedBox(height: 6),
        Text('Tap + to add your first transaction',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
      ]),
    );
  }
}

class _ShimmerList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(22)),
      child: Column(
        children: List.generate(
          4,
              (i) => Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(children: [
              _box(46, 46, r: 14),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _box(12, 120),
                      const SizedBox(height: 6),
                      _box(10, 80),
                    ]),
              ),
              _box(14, 60),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _box(double h, double w, {double r = 6}) => Container(
    height: h, width: w,
    decoration: BoxDecoration(
      color: const Color(0xFFEEF0FF),
      borderRadius: BorderRadius.circular(r),
    ),
  );
}