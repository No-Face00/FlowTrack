// lib/features/home/widgets/transaction_list_item.dart
// ── All overflow errors fixed ─────────────────────────────────
// • Row at line 143: icon + Expanded(title/sub) + ConstrainedBox(amount)
// • Sub-row at line 171: all Text wrapped in Flexible
// • Amount column: Flexible + ellipsis

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
  'groceries':     Icons.shopping_cart_rounded,
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
  'groceries':     Color(0xFF8BC34A),
  'other':         Color(0xFF9E9E9E),
  'transfer':      Color(0xFF0600AB),
};

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
    this.onTap,
  });

  final TransactionEntity tx;
  final VoidCallback      onDelete;
  final bool              isLast;
  final VoidCallback?     onTap;

  @override
  Widget build(BuildContext context) {
    final rs         = Rs.of(context);
    final isIncome   = tx.type == 'income';
    final isTransfer = tx.type == 'transfer';

    String symbol = '৳';
    try {
      final bs = context.read<BalanceCubit>().state;
      if (bs is BalanceLoaded) symbol = bs.symbol;
    } catch (_) {
      symbol = _symbolMap[tx.currency] ?? tx.currency;
    }

    final color    = isIncome   ? AppColors.income
        : isTransfer ? AppColors.royalBlue
        : AppColors.expense;
    final prefix   = isIncome ? '+' : '-';
    final catColor = _catColors[tx.category] ?? AppColors.textMuted;
    final catIcon  = _catIcons[tx.category]  ?? Icons.category_rounded;

    // Compact amount — avoids overflow on large numbers
    final amtDisplay = '$prefix$symbol${_compact(tx.amount)}';
    final dateFmt    = DateFormat('MMM d').format(tx.date);

    return Dismissible(
      key: Key(tx.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        margin: EdgeInsets.symmetric(vertical: rs.sp(2)),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF4757), Color(0xFFFF6B81)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: isLast
              ? const BorderRadius.only(
              bottomLeft:  Radius.circular(24),
              bottomRight: Radius.circular(24))
              : BorderRadius.circular(rs.sp(16)),
          boxShadow: [
            BoxShadow(
              color: AppColors.expense.withOpacity(0.3),
              blurRadius: 12, offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.only(right: rs.sp(22)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: rs.sp(38), height: rs.sp(38),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(rs.sp(12)),
                ),
                child: Icon(Icons.delete_outline_rounded,
                    color: Colors.white, size: rs.sp(20)),
              ),
              SizedBox(height: rs.sp(4)),
              Text('Delete', style: TextStyle(
                  color: Colors.white, fontSize: rs.sp(10),
                  fontWeight: FontWeight.w700, letterSpacing: 0.3)),
            ],
          ),
        ),
      ),
      confirmDismiss: (_) async { onDelete(); return false; },
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            border: isLast ? null : const Border(
                bottom: BorderSide(color: Color(0x08000000))),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: rs.sp(18), vertical: rs.sp(13)),
            // ── Main row — FIXED: no unconstrained Rows ──────────
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [

                // Icon tile — fixed size, never grows
                Container(
                  width: rs.sp(48), height: rs.sp(48),
                  decoration: BoxDecoration(
                    color: catColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(rs.sp(14)),
                  ),
                  child: Icon(catIcon, color: catColor, size: rs.sp(22)),
                ),
                SizedBox(width: rs.sp(13)),

                // Title + subtitle — Expanded so it takes remaining space
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tx.title,
                          style: TextStyle(
                              fontSize: rs.sp(14), fontWeight: FontWeight.w600,
                              color: AppColors.textDark),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1),
                      SizedBox(height: rs.sp(3)),
                      // Sub-row — all items Flexible to prevent overflow
                      Row(children: [
                        Flexible(child: Text(_cap(tx.category),
                            style: TextStyle(fontSize: rs.sp(11),
                                color: AppColors.textMuted),
                            overflow: TextOverflow.ellipsis)),
                        Text(' · ', style: TextStyle(
                            fontSize: rs.sp(11), color: AppColors.textMuted)),
                        Flexible(child: Text(dateFmt,
                            style: TextStyle(fontSize: rs.sp(11),
                                color: AppColors.textMuted),
                            overflow: TextOverflow.ellipsis)),
                        if (!tx.isSynced) ...[
                          SizedBox(width: rs.sp(4)),
                          Icon(Icons.cloud_off_rounded,
                              size: rs.sp(10), color: AppColors.textMuted),
                        ],
                      ]),
                    ],
                  ),
                ),

                SizedBox(width: rs.sp(8)),

                // Amount — ConstrainedBox prevents it growing too wide
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: rs.sp(90)),
                  child: Text(amtDisplay,
                      style: TextStyle(
                          fontSize: rs.sp(14), fontWeight: FontWeight.w700,
                          color: color),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end),
                ),

                SizedBox(width: rs.sp(4)),
                Icon(Icons.chevron_right_rounded,
                    color: const Color(0xFFCBD5E1), size: rs.sp(18)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  // Show full number up to 9,99,999 → compact only for 1M+
  String _compact(double v) {
    if (v >= 1000000000) return '${(v / 1000000000).toStringAsFixed(1)}B';
    if (v >= 1000000)    return '${(v / 1000000).toStringAsFixed(1)}M';
    return NumberFormat('#,##0', 'en_US').format(v);
  }
}