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
import '../../../core/cubit/app_cubit.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/notifications/notification_cubit.dart';
import '../../../core/notifications/notification_widgets.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../budget/domain/entities/budget_entity.dart';
import '../../budget/presentation/cubit/budget_cubit.dart';
import '../../budget/presentation/cubit/budget_state.dart';
import '../../transactions/domain/entities/transaction_entity.dart';
import '../../transactions/presentation/cubit/balance_cubit.dart';
import '../../transactions/presentation/cubit/balance_state.dart';
import '../../transactions/presentation/cubit/transaction_cubit.dart';
import '../../transactions/presentation/cubit/transaction_state.dart';
// Hide any names that conflict with service_locator.dart
import '../Widgets/analytics_widgets.dart';

// ── Default budget seeds — built from centralized expenseCategories ────────────
//
// IMPORTANT: `category` values MUST match AppCategory.value from app_categories.dart
// AND TransactionEntity.category stored in Firestore.
// Budget progress is computed by matching tx.category == budget.category.
// If these values drift, spending will never register against budgets.

import '../../../core/constants/app_categories.dart' show expenseCategories;

// Default monthly limits seeded on first launch (user can edit/remove)
const _kDefaultBudgetLimits = {
  'food':          8000.0,
  'transport':     3000.0,
  'bills':         6000.0,
  'shopping':      4000.0,
  'health':        2500.0,
};

// ══════════════════════════════════════════════════════════════
// ENTRY POINT — wires up BLoCs then hands off to _AnalyticsView
// ══════════════════════════════════════════════════════════════
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  /// Public entry point called by Home quick-action "Budget" button.
  /// Delegates to the live _AnalyticsViewState instance.
  static void scrollToBudget() =>
      _AnalyticsViewState.instance?.scrollToBudget();

  @override
  Widget build(BuildContext context) {
    final now    = DateTime.now();
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return MultiBlocProvider(
      providers: [
        // ── CRITICAL: use BlocProvider.value() for singletons ──────────
        // BlocProvider(create:) takes ownership and calls close() when
        // the widget is disposed (e.g. user navigates to another tab).
        // After close(), BalanceCubit.refreshCurrency() hits the isClosed
        // guard and silently does nothing → currency stops updating.
        // BlocProvider.value() makes the cubit available WITHOUT ownership.
        BlocProvider.value(value: getIt<TransactionCubit>()
          ..loadTransactions()),
        BlocProvider.value(value: getIt<BalanceCubit>()
          ..watchBalance(userId)),
        // BlocProvider.value for BudgetCubit — it's now a lazySingleton
        // shared with HomeScreen. Changes here are immediately visible on Home.
        BlocProvider.value(value: getIt<BudgetCubit>()
          ..loadForMonth(now.month, now.year)),
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
  // GlobalKey so scrollToBudget() can find the exact render position
  final budgetSectionKey = GlobalKey();

  static const _kPeriodKey = 'analytics_period';

  // ── Static handle so Home quick-action can trigger scroll ───
  static _AnalyticsViewState? instance;

  // ── Lifecycle ──────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    instance = this;
    _scrollCtrl.addListener(
            () => setState(() => _scrollOffset = _scrollCtrl.offset));
    _loadPeriod();
  }

  @override
  void dispose() {
    if (instance == this) instance = null;
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Called by Home "Budget" quick-action after tab switch.
  /// Uses GlobalKey to find the exact render position of the Budget section.
  void scrollToBudget() {
    Future.delayed(const Duration(milliseconds: 380), () {
      if (!_scrollCtrl.hasClients) return;
      final ctx = budgetSectionKey.currentContext;
      if (ctx != null) {
        // Get the RenderBox of the budget section and find its offset
        // relative to the scroll view's viewport
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeOutCubic,
          alignment: 0.0, // top of the section at top of viewport
        );
      } else {
        // Fallback: estimate offset if key not yet attached
        _scrollCtrl.animateTo(
          780,
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeOutCubic,
        );
      }
    });
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

    // Build defaults from centralized expenseCategories that have a default limit
    for (final cat in expenseCategories) {
      final defaultLimit = _kDefaultBudgetLimits[cat.value];
      if (defaultLimit == null) continue;                    // no default for this cat
      if (_hiddenDefaults.contains(cat.value)) continue;    // user dismissed it

      final s = savedMap[cat.value];
      if (s != null && s.limitAmount == -1) continue;       // user tombstoned it

      result.add(s ?? BudgetEntity(
        id:          '',
        category:    cat.value,   // matches TransactionEntity.category exactly
        label:       cat.label,
        emoji:       cat.emoji,
        limitAmount: defaultLimit,
        currency:    getIt<AppCubit>().state.currency,
        month:       now.month,
        year:        now.year,
      ));
    }

    // Append any user-saved budgets whose category isn't in the defaults
    final defaultCats = _kDefaultBudgetLimits.keys.toSet();
    for (final b in saved) {
      if (!defaultCats.contains(b.category) && b.limitAmount != -1) result.add(b);
    }

    return _lastBudgets = result;
  }

  // ── Budget alert check ─────────────────────────────────────────────────────
  // Uses _resolveBudgets() — same logic as HomeScreen — so both screens
  // monitor identical budget sets and produce identical alerts.
  void _runBudgetCheck(BuildContext ctx, {BudgetState? budStateOverride}) {
    final txState  = ctx.read<TransactionCubit>().state;
    final budState = budStateOverride ?? ctx.read<BudgetCubit>().state;
    if (txState is! TransactionLoaded) return;

    final symbol    = getIt<AppCubit>().state.symbol;
    final resolved  = _resolveBudgets(budState); // ← full set, not raw list
    final newAlerts = getIt<NotificationCubit>().checkBudgets(
      transactions: txState.transactions,
      budgets:      resolved,
      symbol:       symbol,
    );

    if (newAlerts.isNotEmpty && mounted) {
      final banner = newAlerts.firstWhere(
            (n) => n.id.contains('budget_exceeded'),
        orElse: () => newAlerts.first,
      );
      BudgetAlertBanner.show(context, notification: banner);
    }
  }

  // ── Symbol helper — REACTIVE via AppCubit ─────────────────
  // context.read() is a one-time snapshot and does NOT rebuild
  // when currency changes. We use AppCubit directly here because
  // AppCubit emits synchronously on setCurrency() before the
  // BalanceCubit stream fires.
  String get _sym => CurrencyHelper.symbol(
      context.read<AppCubit>().state.currency);

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
      context.read<BudgetCubit>().deleteBudget(b);
    } else {
      // Default with no Firestore doc — hide locally + persist tombstone
      setState(() => _hiddenDefaults.add(b.category));
      context.read<BudgetCubit>().saveBudget(
        category:    b.category,
        label:       b.label,
        emoji:       b.emoji,
        limitAmount: -1, // tombstone marker
        currency:    getIt<AppCubit>().state.currency,
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      body: MultiBlocListener(
        listeners: [
          // Fire check whenever transactions change
          BlocListener<TransactionCubit, TransactionState>(
            listener: (ctx, txState) {
              if (txState is TransactionLoaded) _runBudgetCheck(ctx);
            },
          ),
          // Fire check whenever budgets change (edit/save/delete)
          BlocListener<BudgetCubit, BudgetState>(
            listener: (ctx, budState) {
              if (budState is BudgetLoaded) _runBudgetCheck(ctx, budStateOverride: budState);
            },
          ),
        ],
        child: BlocBuilder<TransactionCubit, TransactionState>(
          builder: (_, txState) {
            final txns     = txState is TransactionLoaded
                ? txState.transactions : <TransactionEntity>[];
            final bars     = _buildBars(txns);
            final catTotals = _catTotals(txns);
            final maxVal   = bars.fold<double>(0.0, (m, b) {
              final peak = (b.income) > (b.expense) ? b.income : b.expense;
              return peak > m ? peak : m;
            });

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
                    SizedBox(height: rs.sp(310)), // transparent header spacer
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.vertical(
                            top: Radius.circular(rs.sp(28))),
                      ),
                      padding: EdgeInsets.fromLTRB(
                        rs.sp(16), rs.sp(20), rs.sp(16),
                        MediaQuery.of(context).padding.bottom + rs.sp(8),
                      ),
                      child: BlocBuilder<AppCubit, AppSettings>(
                        buildWhen: (p, c) => p.currency != c.currency,
                        builder: (_, __) => AnalyticsBody(
                          bars:             bars,
                          maxVal:           maxVal,
                          catTotals:        catTotals,
                          symbol:           _sym,
                          period:           _period,
                          resolveBudgets:   _resolveBudgets,
                          onEditBudget:     _openEdit,
                          onAddBudget:      _openAdd,
                          onDeleteBudget:   _confirmDelete,
                          budgetSectionKey: budgetSectionKey,
                        ),
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
      ), // MultiBlocListener
    );
  }
}