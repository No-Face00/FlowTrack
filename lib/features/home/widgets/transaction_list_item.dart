// lib/features/home/widgets/transaction_list_item.dart
//
// FIXES:
//  - Currency symbol pulled from BalanceCubit if available (BDT=৳)
//  - Falls back to tx.currency symbol map if Cubit not in context
//  - Beautiful icon tiles with gradient for income
//  - Rs responsive

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../transactions/domain/entities/transaction_entity.dart';
import '../../transactions/presentation/cubit/balance_cubit.dart';
import '../../transactions/presentation/cubit/balance_state.dart';

// ── Category icon map ─────────────────────────────────────────
const _catIcons = <String, IconData>{
  'food':          Icons.restaurant_rounded,
  'transport':     Icons.directions_car_rounded,
  'shopping':      Icons.shopping_bag_rounded,
  'health':        Icons.favorite_rounded,
  'entertainment': Icons.movie_rounded,
  'bills':         Icons.bolt_rounded,
  'education':     Icons.school_rounded,
  'rent':          Icons.home_rounded,
  'salary':        Icons.work_rounded,
  'freelance':     Icons.laptop_rounded,
  'investment':    Icons.trending_up_rounded,
  'business':      Icons.business_rounded,
  'gift':          Icons.card_giftcard_rounded,
  'other':         Icons.category_rounded,
  'transfer':      Icons.swap_horiz_rounded,
};

// ── Category colour map ───────────────────────────────────────
const _catColors = <String, Color>{
  'food':          Color(0xFFFF8C42),
  'transport':     Color(0xFF4ECDC4),
  'shopping':      Color(0xFFFF6B9D),
  'health':        Color(0xFFFF4757),
  'entertainment': Color(0xFF7B5CFF),
  'bills':         Color(0xFF2196F3),
  'education':     Color(0xFF00BCD4),
  'rent':          Color(0xFF607D8B),
  'salary':        Color(0xFF00C48C),
  'freelance':     Color(0xFF00A876),
  'investment':    Color(0xFF0033FF),
  'business':      Color(0xFF3F51B5),
  'gift':          Color(0xFFE91E63),
  'other':         Color(0xFF9E9E9E),
  'transfer':      Color(0xFF0600AB),
};

// ── Symbol map (fallback if BalanceCubit not in scope) ─────────
const _symbolMap = <String, String>{
  'BDT': '৳', 'USD': '\$', 'EUR': '€', 'GBP': '£',
  'INR': '₹', 'JPY': '¥', 'CAD': 'CA\$', 'AUD': 'A\$',
};

class TransactionListItem extends StatelessWidget {
  const TransactionListItem({
    super.key,
    required this.tx,
    required this.onDelete,
    this.isLast = false,
  });

  final TransactionEntity tx;
  final VoidCallback onDelete;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final rs       = Rs.of(context);
    final isIncome = tx.type == 'income';
    final isTransfer = tx.type == 'transfer';

    // Always get the correct symbol — prefer Cubit, fallback to tx.currency
    String symbol = '\$';
    try {
      final bs = context.read<BalanceCubit>().state;
      if (bs is BalanceLoaded) symbol = bs.symbol;
    } catch (_) {
      symbol = _symbolMap[tx.currency] ?? tx.currency;
    }

    final color  = isIncome ? AppColors.income
        : isTransfer ? AppColors.royalBlue
        : AppColors.expense;
    final prefix = isIncome ? '+' : '-';
    final amtText = '$prefix${NumberFormat.currency(
        symbol: symbol, decimalDigits: 2).format(tx.amount)}';
    final dateFmt = DateFormat('MMM d').format(tx.date);

    final catColor = _catColors[tx.category] ?? AppColors.textMuted;
    final catIcon  = _catIcons[tx.category]  ?? Icons.category_rounded;

    return Dismissible(
      key: Key(tx.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: rs.sp(20)),
        decoration: BoxDecoration(
          color: AppColors.expense.withOpacity(0.1),
          borderRadius: isLast
              ? const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24))
              : BorderRadius.zero,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline_rounded,
                color: AppColors.expense, size: rs.sp(20)),
            SizedBox(width: rs.sp(6)),
            Text('Delete',
                style: TextStyle(
                    color: AppColors.expense,
                    fontSize: rs.sp(12),
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: Container(
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(
              bottom: BorderSide(color: Color(0x08000000))),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: rs.sp(18), vertical: rs.sp(13)),
          child: Row(children: [
            // Icon tile
            Container(
              width: rs.sp(48),
              height: rs.sp(48),
              decoration: BoxDecoration(
                color: catColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(rs.sp(14)),
              ),
              child: Icon(catIcon, color: catColor, size: rs.sp(22)),
            ),
            SizedBox(width: rs.sp(13)),

            // Name + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.title,
                    style: TextStyle(
                      fontSize: rs.sp(14),
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: rs.sp(2)),
                  Row(children: [
                    Text(
                      _cap(tx.category),
                      style: TextStyle(
                          fontSize: rs.sp(11),
                          color: AppColors.textMuted),
                    ),
                    Text(' · ',
                        style: TextStyle(
                            fontSize: rs.sp(11),
                            color: AppColors.textMuted)),
                    Text(
                      dateFmt,
                      style: TextStyle(
                          fontSize: rs.sp(11),
                          color: AppColors.textMuted),
                    ),
                    if (!tx.isSynced) ...[
                      SizedBox(width: rs.sp(4)),
                      Icon(Icons.cloud_off_rounded,
                          size: rs.sp(10),
                          color: AppColors.textMuted),
                    ],
                  ]),
                ],
              ),
            ),

            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amtText,
                  style: TextStyle(
                    fontSize: rs.sp(14),
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
            SizedBox(width: rs.sp(6)),
            Icon(Icons.chevron_right_rounded,
                color: const Color(0xFFCBD5E1), size: rs.sp(18)),
          ]),
        ),
      ),
    );
  }

  String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}