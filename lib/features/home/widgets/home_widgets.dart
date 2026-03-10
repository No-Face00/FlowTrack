// lib/features/home/widgets/home_widgets.dart
//
// FIXES:
//  - WalletCard, AiInsightCard, QuickActionsRow all use Rs for responsive sizing
//  - Currency symbol always read from BalanceCubit (BDT=৳ etc.)
//  - Beautiful glassmorphism cards, smooth gradients

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/appRouter.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../transactions/domain/entities/transaction_entity.dart';
import '../../transactions/presentation/cubit/balance_cubit.dart';
import '../../transactions/presentation/cubit/balance_state.dart';
import '../../transactions/presentation/cubit/transaction_cubit.dart';
import '../../transactions/presentation/cubit/transaction_state.dart';
import 'transaction_list_item.dart';

// ══════════════════════════════════════════════════════════════
// HERO NAV BUTTON
// ══════════════════════════════════════════════════════════════
class HeroNavBtn extends StatelessWidget {
  const HeroNavBtn({
    super.key,
    required this.icon,
    this.badge = false,
    required this.onTap,
  });
  final IconData icon;
  final bool badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Stack(children: [
        Container(
          width: rs.sp(42),
          height: rs.sp(42),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(rs.sp(14)),
            border: Border.all(
                color: Colors.white.withOpacity(0.18), width: 1),
          ),
          child: Icon(icon, color: Colors.white, size: rs.sp(20)),
        ),
        if (badge)
          Positioned(
            top: rs.sp(9),
            right: rs.sp(9),
            child: Container(
              width: rs.sp(9),
              height: rs.sp(9),
              decoration: BoxDecoration(
                color: AppColors.expense,
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.midnight.withOpacity(0.8),
                    width: 2),
              ),
            ),
          ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// HERO DATE PILL
// ══════════════════════════════════════════════════════════════
class HeroDatePill extends StatelessWidget {
  const HeroDatePill({super.key});

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    final now = DateTime.now();
    final days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'];
    final label = '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: rs.sp(15), vertical: rs.sp(8)),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(rs.sp(22)),
        border: Border.all(
            color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.calendar_today_rounded,
            size: rs.sp(13), color: Colors.white70),
        SizedBox(width: rs.sp(7)),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: rs.sp(13),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// HERO ORBS (decorative background circles)
// ══════════════════════════════════════════════════════════════
List<Widget> buildHeroOrbs() => [
  _orb(220, -70, -80, 0.06),
  _orb(140, 290, 10, 0.05),
  _orb(80, 200, 115, 0.08),
];

Widget _orb(double size, double left, double top, double opacity) =>
    Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(opacity),
          ),
        ),
      ),
    );

// ══════════════════════════════════════════════════════════════
// WALLET CARD (live balance — symbol from BalanceCubit)
// ══════════════════════════════════════════════════════════════
class WalletCard extends StatelessWidget {
  const WalletCard({super.key});

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return BlocBuilder<BalanceCubit, BalanceState>(
      builder: (_, state) {
        final balance = state is BalanceLoaded ? state.balance : 0.0;
        final symbol  = state is BalanceLoaded ? state.symbol  : '\$';
        final loading = state is BalanceLoading;

        final formatted = NumberFormat.currency(
          symbol: symbol,
          decimalDigits: 2,
        ).format(balance.abs());

        return Container(
          padding: EdgeInsets.all(rs.sp(18)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(rs.sp(24)),
            boxShadow: [
              BoxShadow(
                color: AppColors.royalBlue.withOpacity(0.08),
                blurRadius: 28,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(children: [
            // Icon
            Container(
              width: rs.sp(52),
              height: rs.sp(52),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppColors.violet, AppColors.royalBlue]),
                borderRadius: BorderRadius.circular(rs.sp(16)),
              ),
              child: Center(
                child: Icon(Icons.account_balance_wallet_rounded,
                    color: Colors.white, size: rs.sp(24)),
              ),
            ),
            SizedBox(width: rs.sp(14)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SPENDING WALLET',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: rs.sp(10),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: rs.sp(4)),
                  loading
                      ? Container(
                    height: rs.sp(22),
                    width: rs.sp(130),
                    decoration: BoxDecoration(
                      color: AppColors.bgLavender,
                      borderRadius:
                      BorderRadius.circular(rs.sp(6)),
                    ),
                  )
                      : Text(
                    formatted,
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontSize: rs.sp(22),
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Sora',
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: rs.sp(34),
              height: rs.sp(34),
              decoration: BoxDecoration(
                color: AppColors.bgLavender,
                borderRadius: BorderRadius.circular(rs.sp(11)),
              ),
              child: Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted, size: rs.sp(18)),
            ),
          ]),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════
// AI INSIGHT CARD
// ══════════════════════════════════════════════════════════════
class AiInsightCard extends StatelessWidget {
  const AiInsightCard({super.key, required this.onDismiss});
  final VoidCallback onDismiss;

  String _insight(BalanceState state) {
    if (state is! BalanceLoaded) return 'Loading your financial insights... 📊';
    final inc = state.income;
    final exp = state.expense;
    final bal = state.balance;
    if (inc == 0 && exp == 0) return 'Add your first transaction to start tracking 🚀';
    if (inc == 0) return 'You have expenses but no income recorded. Add income to see balance. 💡';
    if (exp == 0) return 'Great start! Add expenses to track where your money goes. 📊';
    final rate = ((bal / inc) * 100).clamp(-100.0, 100.0);
    if (rate >= 50) return 'Excellent! Saving ${rate.toStringAsFixed(0)}% of income. Amazing! 🎉';
    if (rate >= 20) return 'Good job! Saving ${rate.toStringAsFixed(0)}% of income. Keep it up! 👍';
    if (rate >= 0)  return 'Saving ${rate.toStringAsFixed(0)}% of income. Try to cut back more. 💪';
    return 'Spending ${(-rate).toStringAsFixed(0)}% more than you earn. Review your budget! ⚠️';
  }

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return BlocBuilder<BalanceCubit, BalanceState>(
      builder: (_, state) => Container(
        padding: EdgeInsets.symmetric(
            horizontal: rs.sp(17), vertical: rs.sp(16)),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.midnight, AppColors.deepBlue],
          ),
          borderRadius: BorderRadius.circular(rs.sp(22)),
          boxShadow: [
            BoxShadow(
              color: AppColors.midnight.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(children: [
          Container(
            width: rs.sp(42),
            height: rs.sp(42),
            decoration: BoxDecoration(
              color: AppColors.violet.withOpacity(0.2),
              borderRadius: BorderRadius.circular(rs.sp(13)),
              border: Border.all(
                  color: AppColors.violet.withOpacity(0.3), width: 1),
            ),
            child: Center(
              child: Icon(Icons.auto_awesome_rounded,
                  color: AppColors.violet, size: rs.sp(20)),
            ),
          ),
          SizedBox(width: rs.sp(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI INSIGHT',
                  style: TextStyle(
                    color: AppColors.violet,
                    fontSize: rs.sp(9),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: rs.sp(4)),
                Text(
                  _insight(state),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: rs.sp(13),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: Container(
              width: rs.sp(28),
              height: rs.sp(28),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(rs.sp(8)),
              ),
              child: Icon(Icons.close_rounded,
                  color: Colors.white.withOpacity(0.5),
                  size: rs.sp(14)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// QUICK ACTIONS ROW
// ══════════════════════════════════════════════════════════════
class QuickActionsRow extends StatelessWidget {
  const QuickActionsRow({super.key});

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    final actions = [
      _QA(icon: Icons.add_circle_outline_rounded, label: 'Income',
          grad: const [Color(0xFF00C48C), Color(0xFF00A876)],
          onTap: () => context.push(AppRoutes.addTransaction, extra: 'income')),
      _QA(icon: Icons.remove_circle_outline_rounded, label: 'Expense',
          grad: const [AppColors.expense, Color(0xFFFF3D5A)],
          onTap: () => context.push(AppRoutes.addTransaction, extra: 'expense')),
      _QA(icon: Icons.swap_horiz_rounded, label: 'Transfer',
          grad: const [AppColors.royalBlue, AppColors.deepBlue],
          onTap: () => context.push(AppRoutes.addTransaction, extra: 'transfer')),
      _QA(icon: Icons.pie_chart_outline_rounded, label: 'Budget',
          grad: const [AppColors.violet, Color(0xFF7B5CFF)],
          onTap: () {}),
    ];

    return Container(
      padding: EdgeInsets.all(rs.sp(18)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(rs.sp(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: actions.map((a) => _QABtn(a: a, rs: rs)).toList(),
      ),
    );
  }
}

class _QA {
  final IconData icon;
  final String label;
  final List<Color> grad;
  final VoidCallback onTap;
  const _QA({required this.icon, required this.label,
    required this.grad, required this.onTap});
}

class _QABtn extends StatelessWidget {
  const _QABtn({required this.a, required this.rs});
  final _QA a;
  final Rs rs;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: a.onTap,
      child: Column(children: [
        Container(
          width: rs.sp(56),
          height: rs.sp(56),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: a.grad),
            borderRadius: BorderRadius.circular(rs.sp(18)),
            boxShadow: [
              BoxShadow(
                color: a.grad.first.withOpacity(0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(a.icon, color: Colors.white, size: rs.sp(26)),
        ),
        SizedBox(height: rs.sp(8)),
        Text(a.label,
            style: TextStyle(
              fontSize: rs.sp(11),
              fontWeight: FontWeight.w600,
              color: AppColors.textMid,
            )),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// RECENT TRANSACTIONS LIST
// ══════════════════════════════════════════════════════════════
class RecentTxnsList extends StatelessWidget {
  const RecentTxnsList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TransactionCubit, TransactionState>(
      builder: (ctx, state) {
        if (state is TransactionLoading) return const TxnShimmerList();

        final txns = state is TransactionLoaded
            ? state.transactions.take(20).toList()
            : <TransactionEntity>[];

        if (txns.isEmpty) return const TxnEmptyState();

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.royalBlue.withOpacity(0.07),
                blurRadius: 28,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              children: txns
                  .asMap()
                  .entries
                  .map((e) => TransactionListItem(
                tx: e.value,
                isLast: e.key == txns.length - 1,
                onDelete: () =>
                    ctx.read<TransactionCubit>().softDelete(e.value.id),
              ))
                  .toList(),
            ),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SHIMMER LOADING
// ══════════════════════════════════════════════════════════════
class TxnShimmerList extends StatelessWidget {
  const TxnShimmerList({super.key});

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(rs.sp(24))),
      child: Column(
        children: List.generate(
          4,
              (i) => Padding(
            padding: EdgeInsets.symmetric(
                horizontal: rs.sp(18), vertical: rs.sp(14)),
            child: Row(children: [
              _box(rs.sp(46), rs.sp(46), r: rs.sp(14)),
              SizedBox(width: rs.sp(12)),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _box(rs.sp(12), rs.sp(140)),
                      SizedBox(height: rs.sp(6)),
                      _box(rs.sp(10), rs.sp(90)),
                    ]),
              ),
              _box(rs.sp(14), rs.sp(60)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _box(double h, double w, {double r = 6}) => Container(
    height: h,
    width: w,
    decoration: BoxDecoration(
      color: const Color(0xFFEEF0FF),
      borderRadius: BorderRadius.circular(r),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// EMPTY STATE
// ══════════════════════════════════════════════════════════════
class TxnEmptyState extends StatelessWidget {
  const TxnEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Container(
      padding: EdgeInsets.all(rs.sp(40)),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(rs.sp(24))),
      child: Column(children: [
        Container(
          width: rs.sp(72),
          height: rs.sp(72),
          decoration: BoxDecoration(
            color: AppColors.iconTile,
            borderRadius: BorderRadius.circular(rs.sp(22)),
          ),
          child: Icon(Icons.receipt_long_outlined,
              color: AppColors.textMuted, size: rs.sp(36)),
        ),
        SizedBox(height: rs.sp(16)),
        Text(
          'No transactions yet',
          style: TextStyle(
              fontSize: rs.sp(16),
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
              fontFamily: 'Sora'),
        ),
        SizedBox(height: rs.sp(6)),
        Text(
          'Tap + to add your first transaction',
          style: TextStyle(
              fontSize: rs.sp(13), color: AppColors.textMuted),
        ),
      ]),
    );
  }
}