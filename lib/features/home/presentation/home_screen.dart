// lib/features/home/presentation/home_screen.dart
//
// v27 FIXES:
//   • BudgetCubit now a lazySingleton in getIt — same instance shared by
//     Home and Analytics. Budget changes in Analytics immediately visible here.
//   • _runBudgetCheck now passes _resolveBudgets() to checkBudgets — includes
//     both default seeds AND user-saved custom budgets, not just raw Hive data.
//   • BlocProvider.value() used for BudgetCubit (consistent with other cubits).

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_categories.dart'
    show expenseCategories, AppCategory;
import '../../../core/cubit/app_cubit.dart';
import '../../../core/notifications/notification_cubit.dart';
import '../../../core/notifications/notification_widgets.dart';
import '../../../core/di/service_locator.dart';
import '../../budget/domain/entities/budget_entity.dart';
import '../../budget/presentation/cubit/budget_cubit.dart';
import '../../budget/presentation/cubit/budget_state.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../transactions/presentation/cubit/balance_cubit.dart';
import '../../transactions/presentation/cubit/balance_state.dart';
import '../../transactions/presentation/cubit/transaction_cubit.dart';
import '../../transactions/presentation/cubit/transaction_state.dart';
import '../../ai/cubit/finance_assistant_cubit.dart';
import '../../ai/data/finance_assistant_prefs.dart';
import '../../ai/presentation/flow_advisor_card.dart';
import '../widgets/home_widgets.dart';
import '../../../core/widgets/delete_toast.dart';

// ══════════════════════════════════════════════════════════════
// ENTRY POINT
// ══════════════════════════════════════════════════════════════
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final balanceCubit = context.read<BalanceCubit>();
    if (balanceCubit.state is BalanceInitial) {
      balanceCubit.watchBalance(userId);
    }
    // Use the lazySingleton BudgetCubit — shared across Home AND Analytics.
    // BlocProvider.value() avoids ownership so getIt retains lifecycle control.
    final now         = DateTime.now();
    final budgetCubit = getIt<BudgetCubit>()..loadForMonth(now.month, now.year);
    return _HomeView(budgetCubit: budgetCubit);
  }
}

// ══════════════════════════════════════════════════════════════
// VIEW
// ══════════════════════════════════════════════════════════════
class _HomeView extends StatefulWidget {
  const _HomeView({required this.budgetCubit});
  final BudgetCubit budgetCubit;
  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> with WidgetsBindingObserver {

  final _scrollCtrl    = ScrollController();
  double _scrollOffset = 0;
  DeleteToastHandle? _toastHandle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollCtrl.addListener(
            () => setState(() => _scrollOffset = _scrollCtrl.offset));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FinanceAssistantPrefs.syncFromDisk();
      _pulseAdvisor(context);
    });
  }

  void _pulseAdvisor(BuildContext ctx) {
    getIt<FinanceAssistantCubit>().scheduleRefresh(
      tx:           ctx.read<TransactionCubit>().state,
      bal:          ctx.read<BalanceCubit>().state,
      // Use widget.budgetCubit directly — avoids reading BudgetCubit from
      // context before BlocProvider<BudgetCubit>.value() is in the tree.
      bud:          widget.budgetCubit.state,
      currencyCode: getIt<AppCubit>().state.currency,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollCtrl.dispose();
    super.dispose();
  }

  // Default budget limits — seeded for first-time users.
  // MUST match expenseCategories values in app_categories.dart.
  static const _kDefaultLimits = {
    'food':      8000.0,
    'transport': 3000.0,
    'bills':     6000.0,
    'shopping':  4000.0,
    'health':    2500.0,
  };

  // Resolve the full budget list: default seeds + user-saved custom budgets.
  // This is the SAME logic as analytics_screen._resolveBudgets() — both screens
  // must pass identical budget lists to checkBudgets() for consistent alerts.
  List<BudgetEntity> _resolveBudgets(BudgetState budState) {
    final now      = DateTime.now();
    final saved    = budState is BudgetLoaded ? budState.budgets : <BudgetEntity>[];
    final savedMap = {for (final b in saved) b.category: b};
    final result   = <BudgetEntity>[];

    // 1. Add default-seeded categories (user may have customized the limit)
    for (final cat in expenseCategories) {
      final defaultLimit = _kDefaultLimits[cat.value];
      if (defaultLimit == null) continue;  // no default for this category

      final s = savedMap[cat.value];
      if (s != null && s.limitAmount == -1) continue; // tombstoned by user

      result.add(s ?? BudgetEntity(
        id:          '',
        category:    cat.value,
        label:       cat.label,
        emoji:       cat.emoji,
        limitAmount: defaultLimit,
        currency:    getIt<AppCubit>().state.currency,
        month:       now.month,
        year:        now.year,
      ));
    }

    // 2. Append user-added custom categories not in the default set
    final defaultCats = _kDefaultLimits.keys.toSet();
    for (final b in saved) {
      if (!defaultCats.contains(b.category) && b.limitAmount != -1) {
        result.add(b);
      }
    }

    return result;
  }

  // ── Core: check budgets and show banner for any new alerts ──────────────
  // Called on every TransactionLoaded and BudgetLoaded emission.
  // Passes the RESOLVED budget list so both default seeds and user-added
  // custom categories (Shopping, Education, Rent, etc.) are all monitored.
  void _runBudgetCheck(BuildContext ctx) {
    final txState  = ctx.read<TransactionCubit>().state;
    final budState = widget.budgetCubit.state;
    if (txState is! TransactionLoaded) return;

    final resolved = _resolveBudgets(budState);
    final newAlerts = getIt<NotificationCubit>().checkBudgets(
      transactions: txState.transactions,
      budgets:      resolved,
    );

    // Show top banner for the most severe new alert
    if (newAlerts.isNotEmpty && mounted) {
      final banner = mostSevereBudgetAlert(newAlerts);
      BudgetAlertBanner.show(context, notification: banner);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);

    final headerOpacity = (1.0 -
        ((_scrollOffset - 60.0) / 140.0).clamp(0.0, 1.0));

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness:     Brightness.dark,
    ));

    return BlocProvider<BudgetCubit>.value(
      value: widget.budgetCubit,
      child: MultiBlocListener(
        listeners: [

          // ── Listen to transaction changes ────────────────────
          BlocListener<TransactionCubit, TransactionState>(
            listener: (ctx, txState) {
              if (txState is! TransactionLoading &&
                  txState is! TransactionInitial) {
                _pulseAdvisor(ctx);
              }
              if (txState is TransactionLoaded) {
                _runBudgetCheck(ctx);
              }
              if (txState is TransactionDeleted) {
                _toastHandle?.dismiss();
                _toastHandle = showDeleteToast(
                  ctx,
                  onUndo: () => ctx.read<TransactionCubit>().undoDelete(txState.deletedId),
                );
              }
            },
          ),

          BlocListener<BalanceCubit, BalanceState>(
            listener: (ctx, balState) {
              if (balState is BalanceLoaded) _pulseAdvisor(ctx);
            },
          ),

          BlocListener<BudgetCubit, BudgetState>(
            listener: (ctx, budState) {
              if (budState is BudgetLoaded) {
                _runBudgetCheck(ctx);
                _pulseAdvisor(ctx);
              }
            },
          ),

          BlocListener<AppCubit, AppSettings>(
            bloc: getIt<AppCubit>(),
            listenWhen: (p, c) =>
                p.currency != c.currency || p.languageCode != c.languageCode,
            listener: (ctx, _) => _pulseAdvisor(ctx),
          ),

        ],
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor:          Colors.transparent,
            statusBarIconBrightness: Brightness.light,
          ),
          child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            extendBodyBehindAppBar: true,
            body: Stack(children: [

              // ── Layer 1: gradient header (fades on scroll) ─────
              Positioned.fill(
                child: HomeHeader(bgOpacity: headerOpacity),
              ),

              // ── Layer 2: scrollable content card ───────────────
              Positioned.fill(
                child: SingleChildScrollView(
                  controller: _scrollCtrl,
                  physics: const BouncingScrollPhysics(),
                  child: Column(children: [
                    SizedBox(height: rs.sp(343)),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.vertical(
                            top: Radius.circular(rs.sp(28))),
                      ),
                      padding: EdgeInsets.fromLTRB(
                        rs.sp(16), rs.sp(20), rs.sp(16),
                        MediaQuery.of(context).padding.bottom + rs.sp(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const WalletCard(),
                          SizedBox(height: rs.sp(16)),

                          ValueListenableBuilder<bool>(
                            valueListenable:
                            FinanceAssistantPrefs.visibleListenable,
                            builder: (_, showAdvisor, __) {
                              if (!showAdvisor) {
                                return const SizedBox.shrink();
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  FlowAdvisorCard(
                                    onDismiss: () =>
                                        setState(() {}),
                                    onRefresh: () => _pulseAdvisor(context),
                                  ),
                                  SizedBox(height: rs.sp(16)),
                                ],
                              );
                            },
                          ),

                          const QuickActionsRow(),
                          SizedBox(height: rs.sp(24)),
                          RecentHeader(rs: rs),
                          SizedBox(height: rs.sp(12)),
                          const RecentTxnsList(),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),

              // ── Layer 3: notification bell (above scroll, always tappable)
              Positioned(
                top:   MediaQuery.of(context).padding.top + rs.sp(12),
                right: rs.sp(20),
                child: Opacity(
                  opacity: headerOpacity.clamp(0.0, 1.0),
                  child: IgnorePointer(
                    ignoring: headerOpacity < 0.05,
                    child: const NotificationBell(),
                  ),
                ),
              ),

            ]),
          ),
        ),
      ),
    );
  }
}