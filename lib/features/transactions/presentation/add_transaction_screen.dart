// lib/features/transaction/presentation/add_transaction_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import 'cubit/transaction_cubit.dart';
import 'cubit/transaction_state.dart';

// ── Category definitions ──────────────────────────────────────────────
class _Cat {
  final String emoji;
  final String label;
  final String value;
  const _Cat(this.emoji, this.label, this.value);
}

const _expenseCats = [
  _Cat('🛒', 'Food',       'food'),
  _Cat('🚗', 'Transport',  'transport'),
  _Cat('🛍️', 'Shopping',  'shopping'),
  _Cat('💊', 'Health',     'health'),
  _Cat('🎬', 'Fun',        'entertainment'),
  _Cat('💧', 'Bills',      'bills'),
  _Cat('📚', 'Education',  'education'),
  _Cat('🔑', 'Rent',       'rent'),
  _Cat('💳', 'Other',      'other'),
];

const _incomeCats = [
  _Cat('💰', 'Salary',     'salary'),
  _Cat('💻', 'Freelance',  'freelance'),
  _Cat('📈', 'Investment', 'investment'),
  _Cat('🏢', 'Business',   'business'),
  _Cat('🎁', 'Gift',       'gift'),
  _Cat('💳', 'Other',      'other'),
];

const _transferCats = [_Cat('🔄', 'Transfer', 'transfer')];

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _titleCtrl  = TextEditingController();
  final _noteCtrl   = TextEditingController();

  String   _type        = 'expense';
  String?  _category;
  DateTime _date        = DateTime.now();
  bool     _showAiBadge = true;

  List<_Cat> get _cats => switch (_type) {
    'income'   => _incomeCats,
    'transfer' => _transferCats,
    _          => _expenseCats,
  };

  String get _aiSuggestion => switch (_type) {
    'income'   => 'Salary',
    'transfer' => 'Transfer',
    _          => 'Food',
  };

  @override
  void dispose() {
    _amountCtrl.dispose();
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.royalBlue),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save(BuildContext ctx) {
    if (!_formKey.currentState!.validate()) return;
    if (_category == null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    ctx.read<TransactionCubit>().addTransaction(
      amount:   amount,
      type:     _type,
      category: _category!,
      title:    _titleCtrl.text.trim(),
      note:     _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      currency: 'BDT',
      date:     _date,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<TransactionCubit>(),
      child: BlocConsumer<TransactionCubit, TransactionState>(
        listener: (ctx, state) {
          if (state is TransactionLoaded) ctx.pop();
          if (state is TransactionError) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.expense,
              ),
            );
          }
        },
        builder: (ctx, state) {
          final isSubmitting = state is TransactionSubmitting;

          return Scaffold(
            backgroundColor: AppColors.bgLavender,
            body: SafeArea(
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: Column(
                      children: [
                        Container(
                          width: 44, height: 5,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => ctx.pop(),
                              child: Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    size: 16,
                                    color: AppColors.textDark),
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
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Body
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Type toggle
                            Container(
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
                                children: ['expense', 'income', 'transfer']
                                    .map((t) => _TypeTab(
                                  label: _capitalize(t),
                                  active: _type == t,
                                  onTap: () => setState(() {
                                    _type = t;
                                    _category = null;
                                  }),
                                ))
                                    .toList(),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Amount
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: TextFormField(
                                controller: _amountCtrl,
                                keyboardType: const TextInputType.numberWithOptions(
                                    decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d+\.?\d{0,2}')),
                                ],
                                style: const TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textDark,
                                  fontFamily: 'Sora',
                                  letterSpacing: -1.5,
                                ),
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: '\$0.00',
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
                                validator: (v) {
                                  final n = double.tryParse(v ?? '');
                                  if (n == null || n <= 0) {
                                    return 'Enter a valid amount';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Category
                            const Text('Category',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textMuted,
                                )),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 90,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: _cats
                                    .map((cat) => _CatChip(
                                  cat:      cat,
                                  selected: _category == cat.value,
                                  onTap: () => setState(
                                          () => _category = cat.value),
                                ))
                                    .toList(),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // AI badge
                            if (_showAiBadge)
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 11),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppColors.midnight,
                                      AppColors.deepBlue
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    const Text('🤖',
                                        style: TextStyle(fontSize: 18)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: RichText(
                                        text: TextSpan(
                                          style: TextStyle(
                                            color: Colors.white
                                                .withOpacity(0.85),
                                            fontSize: 12,
                                          ),
                                          children: [
                                            const TextSpan(
                                                text: 'AI suggests: '),
                                            TextSpan(
                                              text: _aiSuggestion,
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
                                      onTap: () {
                                        final match = _cats
                                            .where((c) =>
                                        c.label.toLowerCase() ==
                                            _aiSuggestion.toLowerCase())
                                            .firstOrNull;
                                        if (match != null) {
                                          setState(
                                                  () => _category = match.value);
                                        }
                                        setState(() => _showAiBadge = false);
                                      },
                                      child: const Text('✓',
                                          style: TextStyle(
                                              fontSize: 20,
                                              color: AppColors.income,
                                              fontWeight: FontWeight.w700)),
                                    ),
                                    const SizedBox(width: 12),
                                    GestureDetector(
                                      onTap: () =>
                                          setState(() => _showAiBadge = false),
                                      child: const Text('✗',
                                          style: TextStyle(
                                              fontSize: 20,
                                              color: AppColors.expense,
                                              fontWeight: FontWeight.w700)),
                                    ),
                                  ],
                                ),
                              ),

                            // Title
                            _InputCard(
                              child: TextFormField(
                                controller: _titleCtrl,
                                maxLength: 50,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  counterText: '',
                                  hintText: '✏️  Title / Description',
                                  hintStyle: TextStyle(
                                      color: AppColors.textMuted, fontSize: 14),
                                ),
                                style: const TextStyle(
                                    fontSize: 14, color: AppColors.textDark),
                                validator: (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Title is required'
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 9),

                            // Date
                            _InputCard(
                              child: GestureDetector(
                                onTap: _pickDate,
                                behavior: HitTestBehavior.opaque,
                                child: Row(
                                  children: [
                                    const Text('📅  ',
                                        style: TextStyle(fontSize: 14)),
                                    Text(
                                      DateFormat('EEE, d MMM yyyy')
                                          .format(_date),
                                      style: const TextStyle(
                                          fontSize: 14,
                                          color: AppColors.textDark),
                                    ),
                                    const Spacer(),
                                    const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: AppColors.textMuted,
                                        size: 18),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 9),

                            // Note
                            _InputCard(
                              child: TextFormField(
                                controller: _noteCtrl,
                                maxLength: 200,
                                maxLines: 2,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  counterText: '',
                                  hintText: '📝  Note (optional)',
                                  hintStyle: TextStyle(
                                      color: AppColors.textMuted, fontSize: 14),
                                ),
                                style: const TextStyle(
                                    fontSize: 14, color: AppColors.textDark),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Save button
                            GestureDetector(
                              onTap: isSubmitting ? null : () => _save(ctx),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                height: 58,
                                decoration: BoxDecoration(
                                  gradient: isSubmitting
                                      ? null
                                      : const LinearGradient(
                                    colors: [
                                      AppColors.royalBlue,
                                      AppColors.violet,
                                    ],
                                  ),
                                  color: isSubmitting
                                      ? const Color(0xFFCBD5E1)
                                      : null,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: isSubmitting
                                      ? null
                                      : [
                                    BoxShadow(
                                      color: AppColors.royalBlue
                                          .withOpacity(0.4),
                                      blurRadius: 28,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: isSubmitting
                                      ? const SizedBox(
                                    width: 22, height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
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
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _TypeTab extends StatelessWidget {
  const _TypeTab(
      {required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(
                colors: [AppColors.royalBlue, AppColors.violet])
                : null,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : const Color(0xFF3D3B6E),
            ),
          ),
        ),
      ),
    );
  }
}

class _CatChip extends StatelessWidget {
  const _CatChip(
      {required this.cat, required this.selected, required this.onTap});
  final _Cat cat;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
              colors: [AppColors.royalBlue, AppColors.violet])
              : null,
          color: selected ? null : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? AppColors.royalBlue.withOpacity(0.32)
                  : Colors.black.withOpacity(0.06),
              blurRadius: selected ? 18 : 8,
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
                color: selected ? Colors.white : const Color(0xFF3D3B6E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  const _InputCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
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