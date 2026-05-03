// lib/features/home/presentation/home_screen.dart
// ── Matches Analytics screen design system ───────────────────
// • Gradient header fades as white card scrolls over it (same as Analytics)
// • Singleton cubits — no shimmer on tab switch
// • All functionality complete: balance, transactions, quick actions, AI insight

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_colors.dart';
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
    // TransactionCubit is provided by MainNavigation — shared across all tabs.
    // We just kick off the balance watch here if not already running.
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final balanceCubit = context.read<BalanceCubit>();
    if (balanceCubit.state is BalanceInitial) {
      balanceCubit.watchBalance(userId);
    }
    return const _HomeView();
  }
}

// ══════════════════════════════════════════════════════════════
// VIEW
// ══════════════════════════════════════════════════════════════
class _HomeView extends StatefulWidget {
  const _HomeView();
  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView>
    with WidgetsBindingObserver {

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

  // ── Reload when app resumes from background ────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The Firestore stream reconnects automatically on resume —
    // no manual reload needed here.
  }

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);

    // Header fades: starts at 60px scroll, done at 200px
    final headerOpacity = (1.0 -
        ((_scrollOffset - 60.0) / 140.0).clamp(0.0, 1.0));

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:        Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness:   Brightness.dark,
    ));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor:        Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.bgLavender,
        extendBodyBehindAppBar: true,
        body: BlocListener<TransactionCubit, TransactionState>(
          listener: (ctx, state) {
            if (state is TransactionDeleted) {
              // Dismiss any existing toast first
              _toastHandle?.dismiss();
              _toastHandle = showDeleteToast(
                ctx,
                onUndo: () => ctx.read<TransactionCubit>().undoDelete(state.deletedId),
              );
            }
          },
          child: Stack(children: [

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
                  // Transparent spacer = header height
                  SizedBox(height: rs.sp(345)),

                  // White content card slides over gradient
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.bgLavender,
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

                        // Wallet balance card
                        const WalletCard(),
                        SizedBox(height: rs.sp(16)),

                        // AI insight (dismissible)
                        if (_showAiInsight) ...[
                          AiInsightCard(
                            onDismiss: () =>
                                setState(() => _showAiInsight = false),
                          ),
                          SizedBox(height: rs.sp(16)),
                        ],

                        // Quick actions
                        const QuickActionsRow(),
                        SizedBox(height: rs.sp(24)),

                        // Recent Transactions header
                        RecentHeader(rs: rs),
                        SizedBox(height: rs.sp(12)),

                        // Transaction list
                        const RecentTxnsList(),
                      ],
                    ),
                  ),
                ]),
              ),
            ),

          ]),
        ),
      ),
    );
  }

// _undoSnackBar removed — replaced by showDeleteToast overlay
}