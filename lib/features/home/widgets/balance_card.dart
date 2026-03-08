// lib/features/home/widgets/balance_card.dart
//
// Matches your UI: large balance number + income/expense chips below.
// Uses BlocBuilder<BalanceCubit> — only this widget rebuilds on balance change.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';

import '../../transactions/presentation/cubit/balance_cubit.dart';
import '../../transactions/presentation/cubit/balance_state.dart';

class BalanceCard extends StatelessWidget {
  const BalanceCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BalanceCubit, BalanceState>(
      builder: (context, state) {
        final income  = state is BalanceLoaded ? state.income  : 0.0;
        final expense = state is BalanceLoaded ? state.expense : 0.0;
        final balance = state is BalanceLoaded ? state.balance : 0.0;
        final isLoading = state is BalanceLoading;

        return Container(
          decoration: const BoxDecoration(
            gradient: AppColors.heroGradient,
          ),
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
          child: Column(
            children: [
              // ── Main balance ──────────────────────────────────────
              const SizedBox(height: 12),
              Text(
                'This Month Spend',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              isLoading
                  ? const SizedBox(
                height: 56,
                child: Center(
                  child: CircularProgressIndicator(
                    color: Colors.white54,
                    strokeWidth: 2,
                  ),
                ),
              )
                  : Text(
                _fmt(balance),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 52,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Sora',
                  height: 1,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(height: 10),
              // Trend badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      balance >= 0 ? '↓ Saved' : '↑ Over budget',
                      style: TextStyle(
                        color: balance >= 0 ? const Color(0xFF00E89B) : AppColors.expense,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'from last month',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // ── Income / Expense chips ─────────────────────────────
              Row(
                children: [
                  _StatChip(label: 'Income',   value: income,  arrow: '↑', color: AppColors.income),
                  const SizedBox(width: 12),
                  _StatChip(label: 'Expenses', value: expense, arrow: '↓', color: AppColors.expense),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _fmt(double v) => NumberFormat.currency(
    symbol: '\$',
    decimalDigits: 2,
  ).format(v.abs());
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.arrow,
    required this.color,
  });

  final String label;
  final double value;
  final String arrow;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    final formatted = NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(value);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.11),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Center(
                    child: Text(arrow, style: TextStyle(color: color, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    formatted,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}