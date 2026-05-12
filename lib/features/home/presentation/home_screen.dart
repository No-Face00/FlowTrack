// lib/features/home/presentation/home_screen.dart
//
// v26 FIXES:
//   • BlocListener<BudgetCubit> added alongside TransactionCubit listener —
//     budget changes (edit/create) now also trigger checkBudgets().
//   • checkBudgets() return value used — new alerts immediately show a
//     BudgetAlertBanner overlay (top slide-in banner).
//   • Banner is shown with the HOME screen's context so the Overlay is
//     the root overlay (above nav bar, above sheets).

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/cubit/app_cubit.dart';
import '../../../core/notifications/notification_cubit.dart';
import '../../../core/notifications/notification_widgets.dart';
import '../../../core/di/service_locator.dart';
import '../../budget/presentation/cubit/budget_cubit.dart';
import '../../budget/presentation/cubit/budget_state.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../transactions/presentation/cubit/balance_cubit.dart';
import '../../transactions/presentation/cubit/balance_state.dart';
import '../../transactions/presentation/cubit/transaction_cubit.dart';
import '../../transactions/presentation/cubit/transaction_state.dart';
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
    final now = DateTime.now();
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
  bool _showAiInsight  = true;
  DeleteToastHandle? _toastHandle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollCtrl.addListener(
            () => setState(() => _scrollOffset = _scrollCtrl.offset));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Core: check budgets and show banner for any new alerts ──────────────
  void _runBudgetCheck(BuildContext ctx) {
    final txState  = ctx.read<TransactionCubit>().state;
    final budState = widget.budgetCubit.state;
    if (txState is! TransactionLoaded) return;
    if (budState is! BudgetLoaded)     return;

    final symbol   = getIt<AppCubit>().state.symbol;
    final newAlerts = getIt<NotificationCubit>().checkBudgets(
      transactions: txState.transactions,
      budgets:      budState.budgets,
      symbol:       symbol,
    );

    // Show a top banner for the most severe new alert (exceeded > warning)
    if (newAlerts.isNotEmpty && mounted) {
      // Prefer "exceeded" over "warning" for the banner
      final banner = newAlerts.firstWhere(
            (n) => n.id.contains('budget_exceeded'),
        orElse: () => newAlerts.first,
      );
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

    final symbol = getIt<AppCubit>().state.symbol;

    return BlocProvider<BudgetCubit>.value(
      value: widget.budgetCubit,
      child: MultiBlocListener(
        listeners: [

          // ── Listen to transaction changes ────────────────────
          BlocListener<TransactionCubit, TransactionState>(
            listener: (ctx, txState) {
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

          // ── Listen to budget changes ─────────────────────────
          // CRITICAL FIX: Budget edits (new limit, new category) must
          // also trigger a budget check so alerts fire immediately when
          // a budget is created while spending already exceeds the limit.
          BlocListener<BudgetCubit, BudgetState>(
            listener: (ctx, budState) {
              if (budState is BudgetLoaded) {
                _runBudgetCheck(ctx);
              }
            },
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
                    SizedBox(height: rs.sp(345)),
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

                          if (_showAiInsight) ...[
                            AiInsightCard(
                              onDismiss: () =>
                                  setState(() => _showAiInsight = false),
                            ),
                            SizedBox(height: rs.sp(16)),
                          ],

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