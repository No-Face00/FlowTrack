// lib/features/home/widgets/transaction_list_item.dart
//
// Matches your UI exactly: emoji icon tile + name/sub + amount + chevron.
// Supports swipe-to-delete which triggers soft delete in cubit.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../transactions/domain/entities/transaction_entity.dart';

// ── Category → emoji map ──────────────────────────────────────────────
const _categoryIcons = {
  // Expense
  'food':          '🛒',
  'transport':     '🚗',
  'shopping':      '🛍️',
  'health':        '💊',
  'entertainment': '🎬',
  'bills':         '💧',
  'education':     '📚',
  'rent':          '🔑',
  // Income
  'salary':        '💰',
  'freelance':     '💻',
  'investment':    '📈',
  'business':      '🏢',
  'gift':          '🎁',
  // Default
  'other':         '💳',
  'transfer':      '🔄',
};

class TransactionListItem extends StatelessWidget {
  const TransactionListItem({
    super.key,
    required this.tx,
    required this.onDelete,
    this.isLast = false,
  });

  final TransactionEntity tx;
  final VoidCallback       onDelete;
  final bool               isLast;

  @override
  Widget build(BuildContext context) {
    final isIncome = tx.type == 'income';
    final icon     = _categoryIcons[tx.category] ?? '💳';
    final color    = isIncome ? AppColors.income : AppColors.expense;
    final amtText  = '${isIncome ? "+" : "-"}${NumberFormat.currency(symbol: "\$", decimalDigits: 2).format(tx.amount)}';
    final dateFmt  = DateFormat('MMM d').format(tx.date);

    return Dismissible(
      key: Key(tx.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.expense.withOpacity(0.12),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.expense),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // Cubit handles the actual removal via soft delete
      },
      child: Container(
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(
            bottom: BorderSide(color: Color(0x0A000000)),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          child: Row(
            children: [
              // Icon tile
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: isIncome
                      ? const Color(0xFFE6FFF7)
                      : const Color(0xFFEEF0FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(icon, style: const TextStyle(fontSize: 21)),
                ),
              ),
              const SizedBox(width: 12),
              // Name + sub
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          _capitalize(tx.category),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const Text(
                          ' · ',
                          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                        Text(
                          dateFmt,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                        // Sync indicator
                        if (!tx.isSynced) ...[
                          const SizedBox(width: 4),
                          const Text('⏳', style: TextStyle(fontSize: 9)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Amount
              Text(
                amtText,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFFCBD5E1), size: 18),
            ],
          ),
        ),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}