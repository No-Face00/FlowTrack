// lib/features/analytics/presentation/analytics_screen.dart
// ── Screen is intentionally thin ─────────────────────────────
// All widget building lives in analytics_widgets.dart.
// This file owns: BLoC wiring, state, data helpers, sheet launchers.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../budget/domain/entities/budget_entity.dart';
import '../../budget/presentation/cubit/budget_cubit.dart';
import '../../budget/presentation/cubit/budget_state.dart';
import '../../transactions/domain/entities/transaction_entity.dart';
import '../../transactions/presentation/cubit/balance_cubit.dart';
import '../../transactions/presentation/cubit/balance_state.dart';
import '../../transactions/presentation/cubit/transaction_cubit.dart';
import '../../transactions/presentation/cubit/transaction_state.dart';
import '../Widgets/analytics_widgets.dart';

// ── Default budget seeds ──────────────────────────────────────
const _kDefaultBudgets = [
  _BT('🍔', 'Food & Dining',    'food',      8000),
  _BT('🚗', 'Transport',        'transport', 3000),
  _BT('🏠', 'Bills & Utilities','bills',     6000),
  _BT('🛒', 'Groceries',        'groceries', 4000),
  _BT('💊', 'Health & Medical', 'health',    2500),
];

class _BT {
  final String emoji, label, category;
  final double limit;
  const _BT(this.emoji, this.label, this.category, this.limit);
}

// ══════════════════════════════════════════════════════════════
// ENTRY POINT — wires up BLoCs then hands off to _AnalyticsView
// ══════════════════════════════════════════════════════════════
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final now    = DateTime.now();
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<TransactionCubit>()..loadTransactions()),
        BlocProvider(create: (_) => getIt<BalanceCubit>()..watchBalance(userId)),
        BlocProvider(create: (_) => getIt<BudgetCubit>()..loadForMonth(now.month, now.year)),
      ],
      child: const _AnalyticsView(),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// VIEW — manages scroll, period, budget state
// ══════════════════════════════════════════════════════════════
class _AnalyticsView extends StatefulWidget {
  const _AnalyticsView();
  @override
  State<_AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends State<_AnalyticsView> {
  // ── State ──────────────────────────────────────────────────
  String             _period        = 'monthly';
  double             _scrollOffset  = 0;
  List<BudgetEntity> _lastBudgets   = [];
  final Set<String>  _hiddenDefaults = {};
  final _scrollCtrl  = ScrollController();

  static const _kPeriodKey = 'analytics_period';

  // ── Lifecycle ──────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(
            () => setState(() => _scrollOffset = _scrollCtrl.offset));
    _loadPeriod();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Period persistence ─────────────────────────────────────
  Future<void> _loadPeriod() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kPeriodKey);
    if (saved != null && ['daily', 'monthly', 'yearly'].contains(saved)) {
      setState(() => _period = saved);
    }
  }

  Future<void> _savePeriod(String p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPeriodKey, p);
  }

  void _onPeriodChanged(String p) {
    setState(() => _period = p);
    _savePeriod(p);
  }

  // ── Data helpers ───────────────────────────────────────────
  String _pad(int n) => n.toString().padLeft(2, '0');

  List<BarData> _buildBars(List<TransactionEntity> txns) {
    final now = DateTime.now();

    if (_period == 'daily') {
      return List.generate(7, (i) {
        final day  = now.subtract(Duration(days: 6 - i));
        final dStr = '${day.year}-${_pad(day.month)}-${_pad(day.day)}';
        double inc = 0, exp = 0;
        for (final tx in txns) {
          final d = tx.date;
          if ('${d.year}-${_pad(d.month)}-${_pad(d.day)}' == dStr) {
            if (tx.type == 'income')  inc += tx.amount;
            if (tx.type == 'expense') exp += tx.amount;
          }
        }
        return BarData(label: DateFormat('EEE').format(day), income: inc, expense: exp);
      });
    }

    if (_period == 'yearly') {
      return List.generate(5, (i) {
        final yr = now.year - (4 - i);
        double inc = 0, exp = 0;
        for (final tx in txns) {
          if (tx.month.startsWith('$yr-')) {
            if (tx.type == 'income')  inc += tx.amount;
            if (tx.type == 'expense') exp += tx.amount;
          }
        }
        return BarData(label: '$yr', income: inc, expense: exp);
      });
    }

    // monthly (default)
    return List.generate(6, (i) {
      final dt = DateTime(now.year, now.month - (5 - i), 1);
      final m  = '${dt.year}-${_pad(dt.month)}';
      double inc = 0, exp = 0;
      for (final tx in txns) {
        if (tx.month == m) {
          if (tx.type == 'income')  inc += tx.amount;
          if (tx.type == 'expense') exp += tx.amount;
        }
      }
      return BarData(label: DateFormat('MMM').format(dt), income: inc, expense: exp);
    });
  }

  Map<String, double> _catTotals(List<TransactionEntity> txns) {
    final now  = DateTime.now();
    final key  = '${now.year}-${_pad(now.month)}';
    final map  = <String, double>{};
    for (final tx in txns) {
      if (tx.type == 'expense' && tx.month == key) {
        map[tx.category] = (map[tx.category] ?? 0) + tx.amount;
      }
    }
    return map;
  }

  // Resolves the visible budget list.
  // Returns cached list during transient BudgetLoading to avoid flicker.
  List<BudgetEntity> _resolveBudgets(BudgetState state) {
    if (state is BudgetLoading && _lastBudgets.isNotEmpty) return _lastBudgets;

    final now      = DateTime.now();
    final saved    = state is BudgetLoaded ? state.budgets : <BudgetEntity>[];
    final savedMap = {for (final b in saved) b.category: b};
    final result   = <BudgetEntity>[];

    for (final t in _kDefaultBudgets) {
      if (_hiddenDefaults.contains(t.category)) continue;
      final s = savedMap[t.category];
      if (s != null && s.limitAmount == -1) continue; // tombstone
      result.add(s ?? BudgetEntity(
        id: '', category: t.category, label: t.label,
        emoji: t.emoji, limitAmount: t.limit, currency: 'BDT',
        month: now.month, year: now.year,
      ));
    }

    final defaultCats = _kDefaultBudgets.map((t) => t.category).toSet();
    for (final b in saved) {
      if (!defaultCats.contains(b.category) && b.limitAmount != -1) result.add(b);
    }

    return _lastBudgets = result;
  }

  // ── Symbol helper ──────────────────────────────────────────
  String get _sym {
    try {
      final s = context.read<BalanceCubit>().state;
      return s is BalanceLoaded ? s.symbol : '৳';
    } catch (_) { return '৳'; }
  }

  // ── Sheet launchers ────────────────────────────────────────
  void _openEdit(BudgetEntity b) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<BudgetCubit>(),
        child: BudgetEditSheet(budget: b, symbol: _sym),
      ),
    );
  }

  void _openAdd() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<BudgetCubit>(),
        child: BudgetAddSheet(symbol: _sym),
      ),
    );
  }

  void _confirmDelete(BudgetEntity b) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (sheetCtx) => BudgetDeleteSheet(
        budget:   b,
        onDelete: () { Navigator.pop(sheetCtx); _doDelete(b); },
        onCancel: () => Navigator.pop(sheetCtx),
      ),
    );
  }

  void _doDelete(BudgetEntity b) {
    final now = DateTime.now();
    if (b.id.isNotEmpty) {
      context.read<BudgetCubit>().deleteBudget(
        b.id,
        b.month > 0 ? b.month : now.month,
        b.year  > 0 ? b.year  : now.year,
      );
    } else {
      // Default with no Firestore doc — hide locally + persist tombstone
      setState(() => _hiddenDefaults.add(b.category));
      context.read<BudgetCubit>().saveBudget(
        category:    b.category,
        label:       b.label,
        emoji:       b.emoji,
        limitAmount: -1, // tombstone marker
        currency:    'BDT',
        month:       now.month,
        year:        now.year,
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final rs          = Rs.of(context);
    final statusBarH  = MediaQuery.of(context).padding.top;
    final headerOpacity = (1.0 -
        ((_scrollOffset - 80.0) / 140.0).clamp(0.0, 1.0));

    return Scaffold(
      backgroundColor: AppColors.bgLavender,
      extendBodyBehindAppBar: true,
      body: BlocBuilder<TransactionCubit, TransactionState>(
        builder: (_, txState) {
          final txns     = txState is TransactionLoaded
              ? txState.transactions : <TransactionEntity>[];
          final bars     = _buildBars(txns);
          final catTotals = _catTotals(txns);
          final maxVal   = bars.fold(0.0, (m, b) => b.income > m ? b.income : m);

          return Stack(children: [

            // ── Layer 1 : gradient header — fades as card scrolls over it
            Positioned.fill(
              child: AnalyticsHeader(bgOpacity: headerOpacity),
            ),

            // ── Layer 2 : scrollable content card
            Positioned.fill(
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                physics: const BouncingScrollPhysics(),
                child: Column(children: [
                  SizedBox(height: rs.sp(290)), // transparent header spacer
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.bgLavender,
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(rs.sp(28))),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      rs.sp(16), rs.sp(20), rs.sp(16),
                      MediaQuery.of(context).padding.bottom + rs.sp(8),
                    ),
                    child: AnalyticsBody(
                      bars:           bars,
                      maxVal:         maxVal,
                      catTotals:      catTotals,
                      symbol:         _sym,
                      resolveBudgets: _resolveBudgets,
                      onEditBudget:   _openEdit,
                      onAddBudget:    _openAdd,
                      onDeleteBudget: _confirmDelete,
                    ),
                  ),
                ]),
              ),
            ),

            // ── Layer 3 : period chip — above scroll for tap priority,
            //             fades in sync with the header via same opacity.
            Positioned(
              top:   statusBarH + rs.sp(14),
              right: rs.sp(20),
              child: Opacity(
                opacity: headerOpacity,
                child: IgnorePointer(
                  ignoring: headerOpacity < 0.05,
                  child: AnalyticsPeriodChip(
                    selected:  _period,
                    onChanged: _onPeriodChanged,
                  ),
                ),
              ),
            ),

          ]);
        },
      ),
    );
  }
}