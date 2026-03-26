// lib/features/transactions/presentation/widgets/add_transaction_widgets.dart
//
// All reusable widgets for AddTransactionScreen:
//   - AddTxnHeader        → drag handle + back button + title
//   - TypeToggleRow       → Expense / Income / Transfer segmented control
//   - AmountField         → large amount TextFormField with type colour
//   - CategoryChipList    → horizontal scrollable category chips
//   - AiSuggestionBadge   → dismissible AI suggestion row
//   - TxnInputCard        → white card wrapper for form fields
//   - TxnDateRow          → date selector row (inside TxnInputCard)
//   - SaveButton          → gradient save button with loading state

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';

// ── Category model (shared within this feature) ───────────────
class TxnCategory {
  final String emoji, label, value;
  const TxnCategory(this.emoji, this.label, this.value);
}

const expenseCategories = [
  TxnCategory('🛒', 'Food', 'food'),
  TxnCategory('🚗', 'Transport', 'transport'),
  TxnCategory('🛍️', 'Shopping', 'shopping'),
  TxnCategory('💊', 'Health', 'health'),
  TxnCategory('🎬', 'Entertainment', 'entertainment'),
  TxnCategory('💧', 'Bills', 'bills'),
  TxnCategory('📚', 'Education', 'education'),
  TxnCategory('🔑', 'Rent', 'rent'),
  TxnCategory('💳', 'Other', 'other'),
];

const incomeCategories = [
  TxnCategory('💰', 'Salary', 'salary'),
  TxnCategory('💻', 'Freelance', 'freelance'),
  TxnCategory('📈', 'Investment', 'investment'),
  TxnCategory('🏢', 'Business', 'business'),
  TxnCategory('🎁', 'Gift', 'gift'),
  TxnCategory('💳', 'Other', 'other'),
];

const transferCategories = [
  TxnCategory('🔄', 'Transfer', 'transfer'),
];

// ══════════════════════════════════════════════════════════════
// HEADER  (drag handle + back + title)
// ══════════════════════════════════════════════════════════════
class AddTxnHeader extends StatelessWidget {
  const AddTxnHeader({super.key, required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(children: [
        // Drag handle
        Container(
          width: 44,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.12),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(11),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.07),
                      blurRadius: 8),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: AppColors.textDark,
              ),
            ),
          ),
          const Expanded(
            child: Text(
              'Add Transaction',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
                fontFamily: 'Sora',
              ),
            ),
          ),
          const SizedBox(width: 36),
        ]),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TYPE TOGGLE ROW
// ══════════════════════════════════════════════════════════════
class TypeToggleRow extends StatelessWidget {
  const TypeToggleRow({
    super.key,
    required this.activeType,
    required this.onSelect,
  });

  final String activeType;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: ['expense', 'income', 'transfer'].map((t) {
          final isActive = activeType == t;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(t),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: isActive
                      ? const LinearGradient(colors: [
                    AppColors.royalBlue,
                    AppColors.violet,
                  ])
                      : null,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  _cap(t),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isActive
                        ? Colors.white
                        : const Color(0xFF3D3B6E),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ══════════════════════════════════════════════════════════════
// AMOUNT FIELD
// ══════════════════════════════════════════════════════════════
class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.controller,
    required this.typeColor,
    required this.validator,
  });

  final TextEditingController controller;
  final Color typeColor;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType:
        const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
        ],
        style: TextStyle(
          fontSize: 42,
          fontWeight: FontWeight.w800,
          color: typeColor,
          fontFamily: 'Sora',
          letterSpacing: -1.5,
        ),
        textAlign: TextAlign.center,
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: '0.00',
          hintStyle: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.w800,
            color: Color(0xFFCBD5E1),
            fontFamily: 'Sora',
          ),
          prefixText: '\$ ',
          prefixStyle: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
          ),
        ),
        validator: validator,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// CATEGORY CHIP LIST
// ══════════════════════════════════════════════════════════════
class CategoryChipList extends StatelessWidget {
  const CategoryChipList({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  final List<TxnCategory> categories;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: categories
            .map((cat) => _CatChip(
          cat: cat,
          isSelected: selected == cat.value,
          onTap: () => onSelect(cat.value),
        ))
            .toList(),
      ),
    );
  }
}

class _CatChip extends StatelessWidget {
  const _CatChip(
      {required this.cat,
        required this.isSelected,
        required this.onTap});
  final TxnCategory cat;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 10),
        padding:
        const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
              colors: [AppColors.royalBlue, AppColors.violet])
              : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.royalBlue.withOpacity(0.32)
                  : Colors.black.withOpacity(0.06),
              blurRadius: isSelected ? 18 : 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(cat.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 5),
            Text(
              cat.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : const Color(0xFF3D3B6E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// AI SUGGESTION BADGE
// ══════════════════════════════════════════════════════════════
class AiSuggestionBadge extends StatelessWidget {
  const AiSuggestionBadge({
    super.key,
    required this.suggestion,
    required this.onAccept,
    required this.onDismiss,
  });

  final String suggestion;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [AppColors.midnight, AppColors.deepBlue]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        const Text('🤖', style: TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                  color: Colors.white.withOpacity(0.85), fontSize: 12),
              children: [
                const TextSpan(text: 'AI suggests: '),
                TextSpan(
                  text: suggestion,
                  style: const TextStyle(
                    color: AppColors.violet,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        GestureDetector(
          onTap: onAccept,
          child: const Text('✓',
              style: TextStyle(
                  fontSize: 20,
                  color: AppColors.income,
                  fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: onDismiss,
          child: const Text('✗',
              style: TextStyle(
                  fontSize: 20,
                  color: AppColors.expense,
                  fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// INPUT CARD WRAPPER
// ══════════════════════════════════════════════════════════════
class TxnInputCard extends StatelessWidget {
  const TxnInputCard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ══════════════════════════════════════════════════════════════
// DATE ROW  (used inside TxnInputCard)
// ══════════════════════════════════════════════════════════════
class TxnDateRow extends StatelessWidget {
  const TxnDateRow({
    super.key,
    required this.date,
    required this.onTap,
  });

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(children: [
        const Text('📅  ', style: TextStyle(fontSize: 14)),
        Text(
          DateFormat('EEE, d MMM yyyy').format(date),
          style: const TextStyle(fontSize: 14, color: AppColors.textDark),
        ),
        const Spacer(),
        const Icon(Icons.keyboard_arrow_down_rounded,
            color: AppColors.textMuted, size: 18),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SAVE BUTTON
// ══════════════════════════════════════════════════════════════
class SaveButton extends StatelessWidget {
  const SaveButton({
    super.key,
    required this.isSubmitting,
    required this.onTap,
  });

  final bool isSubmitting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isSubmitting ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 58,
        decoration: BoxDecoration(
          gradient: isSubmitting
              ? null
              : const LinearGradient(
              colors: [AppColors.royalBlue, AppColors.violet]),
          color: isSubmitting ? const Color(0xFFCBD5E1) : null,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSubmitting
              ? null
              : [
            BoxShadow(
              color: AppColors.royalBlue.withOpacity(0.4),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Center(
          child: isSubmitting
              ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: Colors.white),
          )
              : const Text(
            'Save Transaction',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              fontFamily: 'Sora',
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}