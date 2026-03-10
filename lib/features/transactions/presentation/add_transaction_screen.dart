// lib/features/transactions/presentation/add_transaction_screen.dart
//
// AddTransactionScreen — state + save logic only. All widgets live in:
//   lib/features/transactions/presentation/widgets/add_transaction_widgets.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../Widgets/add_transaction_widgets.dart';
import 'cubit/transaction_cubit.dart';
import 'cubit/transaction_state.dart';

class AddTransactionScreen extends StatefulWidget {
  final String? initialType;
  const AddTransactionScreen({super.key, this.initialType});

  @override
  State<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _titleCtrl  = TextEditingController();
  final _noteCtrl   = TextEditingController();

  late String _type;
  String?     _category;
  DateTime    _date        = DateTime.now();
  bool        _showAiBadge = true;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType ?? 'expense';
    if (_type == 'transfer') _category = 'transfer';
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  // ── Derived helpers ─────────────────────────────────────────
  List<TxnCategory> get _cats => switch (_type) {
    'income'   => incomeCategories,
    'transfer' => transferCategories,
    _          => expenseCategories,
  };

  Color get _typeColor => switch (_type) {
    'income'   => AppColors.income,
    'transfer' => AppColors.royalBlue,
    _          => AppColors.expense,
  };

  String get _aiSuggestion => switch (_type) {
    'income'   => 'Salary',
    'transfer' => 'Transfer',
    _          => 'Food',
  };

  // ── Date picker ──────────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
          const ColorScheme.light(primary: AppColors.royalBlue),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  // ── Save ─────────────────────────────────────────────────────
  void _save(BuildContext ctx) {
    if (!_formKey.currentState!.validate()) return;
    if (_category == null) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: const Text('Please select a category'),
        backgroundColor: AppColors.expense,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    ctx.read<TransactionCubit>().addTransaction(
      amount:   double.tryParse(_amountCtrl.text.trim()) ?? 0,
      type:     _type,
      category: _category!,
      title:    _titleCtrl.text.trim(),
      note:     _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      currency: 'USD',
      date:     _date,
    );
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<TransactionCubit>(),
      child: BlocConsumer<TransactionCubit, TransactionState>(
        listener: (ctx, state) {
          if (state is TransactionLoaded) ctx.pop();
          if (state is TransactionError) {
            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.expense,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ));
          }
        },
        builder: (ctx, state) {
          final isSubmitting = state is TransactionSubmitting;

          return Scaffold(
            backgroundColor: AppColors.bgLavender,
            body: SafeArea(
              child: Column(
                children: [
                  AddTxnHeader(onBack: () => ctx.pop()),

                  Expanded(
                    child: SingleChildScrollView(
                      padding:
                      const EdgeInsets.fromLTRB(20, 18, 20, 36),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [

                            // Type toggle
                            TypeToggleRow(
                              activeType: _type,
                              onSelect: (t) => setState(() {
                                _type = t;
                                _category =
                                t == 'transfer' ? 'transfer' : null;
                              }),
                            ),
                            const SizedBox(height: 20),

                            // Amount
                            AmountField(
                              controller: _amountCtrl,
                              typeColor: _typeColor,
                              validator: (v) {
                                final n = double.tryParse(v ?? '');
                                if (n == null || n <= 0) {
                                  return 'Enter a valid amount greater than 0';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // Category label
                            const Text(
                              'Category',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 10),

                            // Category chips
                            CategoryChipList(
                              categories: _cats,
                              selected: _category,
                              onSelect: (v) =>
                                  setState(() => _category = v),
                            ),
                            const SizedBox(height: 16),

                            // AI badge
                            if (_showAiBadge && _type != 'transfer') ...[
                              AiSuggestionBadge(
                                suggestion: _aiSuggestion,
                                onAccept: () {
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
                                onDismiss: () =>
                                    setState(() => _showAiBadge = false),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Title
                            TxnInputCard(
                              child: TextFormField(
                                controller: _titleCtrl,
                                maxLength: 50,
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textDark),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  counterText: '',
                                  hintText: '✏️  Title / Description',
                                  hintStyle: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 14),
                                ),
                                validator: (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Title is required'
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 9),

                            // Date
                            TxnInputCard(
                              child: TxnDateRow(
                                  date: _date, onTap: _pickDate),
                            ),
                            const SizedBox(height: 9),

                            // Note
                            TxnInputCard(
                              child: TextFormField(
                                controller: _noteCtrl,
                                maxLength: 200,
                                maxLines: 2,
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textDark),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  counterText: '',
                                  hintText: '📝  Note (optional)',
                                  hintStyle: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 14),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Save
                            SaveButton(
                              isSubmitting: isSubmitting,
                              onTap: () => _save(ctx),
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
}