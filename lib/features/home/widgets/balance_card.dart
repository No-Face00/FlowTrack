// lib/features/home/widgets/balance_card.dart
//
// FIXES:
//  - No BoxDecoration gradient here — card sits INSIDE the gradient header
//    so background is transparent. Hero gradient is applied by the parent.
//  - Currency symbol from BalanceCubit (BDT=৳, USD=$, etc.)
//  - Rs responsive sizing

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../transactions/presentation/cubit/balance_cubit.dart';
import '../../transactions/presentation/cubit/balance_state.dart';

class BalanceCard extends StatelessWidget {
  const BalanceCard({super.key});

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return BlocBuilder<BalanceCubit, BalanceState>(
      builder: (_, state) {
        final income  = state is BalanceLoaded ? state.income   : 0.0;
        final expense = state is BalanceLoaded ? state.expense  : 0.0;
        final balance = state is BalanceLoaded ? state.balance  : 0.0;
        final symbol  = state is BalanceLoaded ? state.symbol   : '\$';
        final loading = state is BalanceLoading;

        return Padding(
          padding: EdgeInsets.fromLTRB(
              rs.sp(22), 0, rs.sp(22), rs.sp(28)),
          child: Column(children: [
            SizedBox(height: rs.sp(8)),

            // Label
            Text(
              'This Month Spend',
              style: TextStyle(
                color: Colors.white.withOpacity(0.65),
                fontSize: rs.sp(12),
                fontWeight: FontWeight.w500,
                letterSpacing: 1.8,
              ),
            ),
            SizedBox(height: rs.sp(10)),

            // Main balance amount
            loading
                ? SizedBox(
              height: rs.sp(56),
              child: const Center(
                child: CircularProgressIndicator(
                    color: Colors.white54, strokeWidth: 2),
              ),
            )
                : _AnimatedBalance(balance: balance, symbol: symbol),

            SizedBox(height: rs.sp(12)),

            // Saved / Over budget badge
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: rs.sp(14), vertical: rs.sp(6)),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                borderRadius: BorderRadius.circular(rs.sp(20)),
                border: Border.all(
                    color: Colors.white.withOpacity(0.15), width: 1),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  balance >= 0
                      ? Icons.trending_down_rounded
                      : Icons.trending_up_rounded,
                  color: balance >= 0
                      ? AppColors.income
                      : AppColors.expense,
                  size: rs.sp(14),
                ),
                SizedBox(width: rs.sp(5)),
                Text(
                  balance >= 0 ? 'Saved' : 'Over budget',
                  style: TextStyle(
                    color: balance >= 0
                        ? AppColors.income
                        : AppColors.expense,
                    fontWeight: FontWeight.w700,
                    fontSize: rs.sp(12),
                  ),
                ),
                SizedBox(width: rs.sp(5)),
                Text(
                  'from last month',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: rs.sp(12)),
                ),
              ]),
            ),

            SizedBox(height: rs.sp(20)),

            // Income / Expense chips
            Row(children: [
              _StatChip(
                  label: 'Income',
                  value: income,
                  symbol: symbol,
                  icon: Icons.arrow_upward_rounded,
                  color: AppColors.income),
              SizedBox(width: rs.sp(12)),
              _StatChip(
                  label: 'Expenses',
                  value: expense,
                  symbol: symbol,
                  icon: Icons.arrow_downward_rounded,
                  color: AppColors.expense),
            ]),
          ]),
        );
      },
    );
  }
}

// ── Animated balance number ───────────────────────────────────
class _AnimatedBalance extends StatelessWidget {
  const _AnimatedBalance({required this.balance, required this.symbol});
  final double balance;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    // Format with correct symbol — handles multi-char symbols like ৳
    final formatted = NumberFormat.currency(
      symbol: symbol,
      decimalDigits: 2,
    ).format(balance.abs());

    return Text(
      formatted,
      style: TextStyle(
        color: Colors.white,
        fontSize: rs.sp(48),
        fontWeight: FontWeight.w800,
        fontFamily: 'Sora',
        height: 1,
        letterSpacing: -2,
      ),
      textAlign: TextAlign.center,
    );
  }
}

// ── Income / Expense stat chip ────────────────────────────────
class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.symbol,
    required this.icon,
    required this.color,
  });
  final String label, symbol;
  final double value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    final formatted = NumberFormat.currency(
      symbol: symbol,
      decimalDigits: 2,
    ).format(value);

    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: rs.sp(14), vertical: rs.sp(13)),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.11),
          borderRadius: BorderRadius.circular(rs.sp(18)),
          border:
          Border.all(color: Colors.white.withOpacity(0.14), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: rs.sp(9),
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
            SizedBox(height: rs.sp(6)),
            Row(children: [
              Container(
                width: rs.sp(22),
                height: rs.sp(22),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(rs.sp(7)),
                ),
                child: Icon(icon, color: color, size: rs.sp(13)),
              ),
              SizedBox(width: rs.sp(7)),
              Expanded(
                child: Text(
                  formatted,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: rs.sp(15),
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}