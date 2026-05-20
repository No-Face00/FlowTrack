// lib/features/transactions/presentation/add_transaction_screen.dart
//
// ══════════════════════════════════════════════════════════════
// REDESIGNED v2 — Improved hierarchy, spacing & visibility
// ══════════════════════════════════════════════════════════════

import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_categories.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/widgets/premium_snackbar.dart';
import 'cubit/balance_cubit.dart';
import 'cubit/balance_state.dart';
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

class _AddTransactionScreenState extends State<AddTransactionScreen>
    with SingleTickerProviderStateMixin {

  final _formKey    = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _titleCtrl  = TextEditingController();
  final _noteCtrl   = TextEditingController();

  late String  _type;
  String?      _category;
  DateTime     _date        = DateTime.now();
  bool         _showTitleSuggestion = true;
  /// Last title auto-filled from category (used for safe re-sync on category change).
  String?      _lastAutoFilledTitle;
  bool         _titleManuallyEdited = false;

  // Entrance animation
  late final AnimationController _entranceCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500));
  late final Animation<double> _fadeAnim =
  CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
  late final Animation<Offset> _slideAnim =
  Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
      .animate(CurvedAnimation(
      parent: _entranceCtrl, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    _type = widget.initialType ?? 'expense';
    if (_type == 'transfer') _category = 'transfer';
    _titleCtrl.addListener(_onTitleEdited);
    WidgetsBinding.instance.addPostFrameCallback(
            (_) => _entranceCtrl.forward());
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

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

  TxnCategory? get _selectedCategory {
    if (_category == null) return null;
    for (final c in _cats) {
      if (c.value == _category) return c;
    }
    return null;
  }

  /// Localized category label for the title suggestion chip.
  String? get _titleSuggestion => _selectedCategory?.label;

  bool get _shouldShowTitleSuggestion {
    if (_type == 'transfer' || _titleSuggestion == null) return false;
    return _showTitleSuggestion &&
        _titleCtrl.text.trim() != _titleSuggestion!.trim();
  }

  void _onTitleEdited() {
    final suggest = _titleSuggestion;
    if (suggest == null) return;
    final manual = _titleCtrl.text.trim() != suggest.trim();
    if (manual != _titleManuallyEdited) {
      setState(() => _titleManuallyEdited = manual);
    }
  }

  void _selectCategory(String value) {
    final cat = _cats.firstWhere((c) => c.value == value);
    final prevAuto = _lastAutoFilledTitle;
    final current  = _titleCtrl.text.trim();
    final shouldAutoFill = current.isEmpty ||
        (!_titleManuallyEdited &&
            (prevAuto == null || current == prevAuto));

    setState(() {
      _category = value;
      _showTitleSuggestion = true;
    });

    if (shouldAutoFill) {
      _titleCtrl.text = cat.label;
      _titleCtrl.selection =
          TextSelection.collapsed(offset: cat.label.length);
      _lastAutoFilledTitle = cat.label;
      _titleManuallyEdited = false;
    }
  }

  void _fillTitleFromSuggestion() {
    final label = _titleSuggestion;
    if (label == null) return;
    _titleCtrl.text = label;
    _titleCtrl.selection = TextSelection.collapsed(offset: label.length);
    setState(() {
      _lastAutoFilledTitle = label;
      _titleManuallyEdited = false;
      _showTitleSuggestion = false;
    });
  }

  String get _symbol {
    try {
      final bs = context.read<BalanceCubit>().state;
      if (bs is BalanceLoaded) return bs.symbol;
    } catch (_) {}
    return '৳';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary:   AppColors.royalBlue,
            surface:   Color(0xFF0A0A3E),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save(BuildContext ctx) {
    if (!_formKey.currentState!.validate()) return;
    if (_category == null) {
      AppSnack.show(
        ctx,
        message: context.tr('select_category'),
        type: SnackType.warning,
      );
      return;
    }

    String currency = 'BDT';
    try {
      final bs = ctx.read<BalanceCubit>().state;
      if (bs is BalanceLoaded) currency = bs.currency;
    } catch (_) {}

    ctx.read<TransactionCubit>().addTransaction(
      amount:   double.tryParse(_amountCtrl.text.trim()) ?? 0,
      type:     _type,
      category: _category!,
      title:    _titleCtrl.text.trim(),
      note:     _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      currency: currency,
      date:     _date,
    );
  }

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor:          Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: BlocConsumer<TransactionCubit, TransactionState>(
        listenWhen: (_, current) =>
        current is TransactionSaved || current is TransactionError,
        listener: (ctx, state) {
          if (state is TransactionSaved) {
            ctx.pop();
          }
          if (state is TransactionError) {
            AppSnack.show(
              ctx,
              message: state.message,
              type: SnackType.error,
            );
          }
        },
        builder: (ctx, state) {
          // TransactionSubmitting is no longer emitted — save is instant.
          // _isSubmitting in the cubit still guards against double-taps.
          const isSubmitting = false;

          return Scaffold(
            backgroundColor: AppColors.midnight,
            extendBodyBehindAppBar: true,
            body: Stack(children: [

              // ── Gradient background ──────────────────────────
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin:  Alignment.topLeft,
                      end:    Alignment.bottomRight,
                      colors: [
                        Color(0xFF00023A),
                        Color(0xFF0500A0),
                        Color(0xFF0033FF),
                        Color(0xFF5533BB),
                      ],
                      stops: [0.0, 0.35, 0.70, 1.0],
                    ),
                  ),
                ),
              ),

              // ── Decorative orbs ──────────────────────────────
              Positioned(top: -60, left: -60,
                  child: _Orb(rs.sp(220), 0.07)),
              Positioned(top: 40,  right: -50,
                  child: _Orb(rs.sp(170), 0.06)),
              Positioned(top: 200, right: 30,
                  child: _Orb(rs.sp(80),  0.05)),
              Positioned(bottom: 80, left: 20,
                  child: _Orb(rs.sp(120), 0.05)),

              // ── Content ──────────────────────────────────────
              SafeArea(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Column(children: [

                      Padding(
                        padding: EdgeInsets.symmetric(vertical: rs.sp(8)),
                        child: AddTxnHeader(onBack: () => ctx.pop()),
                      ),

                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                              rs.sp(20), rs.sp(8), rs.sp(20), rs.sp(48)),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [

                                // Type toggle
                                TypeToggleRow(
                                  activeType: _type,
                                  onSelect: (t) => setState(() {
                                    _type = t;
                                    _category = t == 'transfer' ? 'transfer' : null;
                                    _titleManuallyEdited = false;
                                    _lastAutoFilledTitle = null;
                                    _showTitleSuggestion = true;
                                    if (t == 'transfer') {
                                      _titleCtrl.clear();
                                    }
                                  }),
                                ),
                                SizedBox(height: rs.sp(20)),  // ↑ was 16

                                // Amount
                                AmountField(
                                  controller:     _amountCtrl,
                                  typeColor:      _typeColor,
                                  currencySymbol: _symbol,
                                  validator: (v) {
                                    final n = double.tryParse(v ?? '');
                                    if (n == null || n <= 0) {
                                      return ctx.tr('valid_amount');
                                    }
                                    return null;
                                  },
                                ),
                                SizedBox(height: rs.sp(24)),  // ↑ was 22

                                // Category
                                TxnSectionLabel(context.tr('category')),
                                SizedBox(height: rs.sp(14)),  // ↑ was 12
                                CategoryChipList(
                                  categories: _cats,
                                  selected:   _category,
                                  onSelect: _selectCategory,
                                ),
                                SizedBox(height: rs.sp(20)),  // ↑ was 16

                                // AI badge
                                if (_shouldShowTitleSuggestion) ...[
                                  AiSuggestionBadge(
                                    suggestion: _titleSuggestion!,
                                    onAccept: _fillTitleFromSuggestion,
                                    onDismiss: () => setState(
                                        () => _showTitleSuggestion = false),
                                  ),
                                  SizedBox(height: rs.sp(20)),  // ↑ was 20
                                ],

                                // Details section with divider for hierarchy


                                TxnSectionLabel(context.tr('details')),
                                SizedBox(height: rs.sp(14)),  // ↑ was 12

                                TxnInputCard(
                                  child: _DarkTextField(
                                    controller: _titleCtrl,
                                    hint:       ctx.tr('title_hint'),
                                    icon:       Icons.edit_outlined,
                                    maxLength:  50,
                                    rs:         rs,
                                    validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? ctx.tr('title_required')
                                        : null,
                                  ),
                                ),
                                SizedBox(height: rs.sp(12)),  // ↑ was 10

                                TxnInputCard(
                                  child: TxnDateRow(
                                      date: _date, onTap: _pickDate),
                                ),
                                SizedBox(height: rs.sp(12)),  // ↑ was 10

                                TxnInputCard(
                                  child: _DarkTextField(
                                    controller: _noteCtrl,
                                    hint:       ctx.tr('note_hint'),
                                    icon:       Icons.notes_rounded,
                                    maxLength:  200,
                                    maxLines:   2,
                                    rs:         rs,
                                  ),
                                ),
                                SizedBox(height: rs.sp(32)),  // ↑ was 28

                                SaveButton(
                                  isSubmitting: isSubmitting,
                                  onTap:        () => _save(ctx),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}

// ── Subtle gradient divider for section separation ─────────────
class _SectionDivider extends StatelessWidget {
  const _SectionDivider();
  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.transparent,
          Colors.white.withOpacity(0.15),
          Colors.transparent,
        ],
      ),
    ),
  );
}

// ── Reusable dark text field — improved icon & hint opacity ────
class _DarkTextField extends StatelessWidget {
  const _DarkTextField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.rs,
    this.maxLength,
    this.maxLines = 1,
    this.validator,
  });
  final TextEditingController       controller;
  final String                      hint;
  final IconData                    icon;
  final int?                        maxLength;
  final int                         maxLines;
  final Rs                          rs;
  final FormFieldValidator<String>?  validator;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: rs.sp(2)),
          child: Icon(icon,
              color: Colors.white.withOpacity(0.75),  // ↑ was 0.40
              size:  rs.sp(18)),
        ),
        SizedBox(width: rs.sp(12)),
        Expanded(
          child: TextFormField(
            controller:  controller,
            maxLength:   maxLength,
            maxLines:    maxLines,
            style: TextStyle(
              fontSize:   rs.sp(14),
              fontWeight: FontWeight.w500,
              color:      Colors.white.withOpacity(0.95),  // ↑ sharper
            ),
            decoration: InputDecoration(
              border:         InputBorder.none,
              enabledBorder:  InputBorder.none,
              focusedBorder:  InputBorder.none,
              errorBorder:    InputBorder.none,
              // CRITICAL: override the global theme's filled:true + white fillColor
              // Without these two lines, ThemeData.inputDecorationTheme paints
              // a solid white box inside the glass card.
              filled:         true,
              fillColor:      Colors.transparent,
              counterText:    '',
              isDense:        true,
              contentPadding: EdgeInsets.zero,
              hintText:       hint,
              hintStyle: TextStyle(
                color:    Colors.white.withOpacity(0.50),
                fontSize: rs.sp(14),
              ),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }
}

// ── Decorative orb ─────────────────────────────────────────────
class _Orb extends StatelessWidget {
  const _Orb(this.size, this.opacity);
  final double size, opacity;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacity),
      ),
    ),
  );
}