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
              ScaffoldMessenger.of(ctx)
                ..clearSnackBars()
                ..showSnackBar(_undoSnackBar(ctx, state.deletedId));
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

  SnackBar _undoSnackBar(BuildContext ctx, String id) {
    return SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: EdgeInsets.zero,
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.10), width: 1),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF312E81).withOpacity(0.55),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.expense.withOpacity(0.18),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: AppColors.expense.withOpacity(0.30), width: 1),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.expense, size: 18),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Transaction Deleted',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      )),
                  SizedBox(height: 2),
                  Text('Tap Undo to restore it',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      )),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
                ctx.read<TransactionCubit>().undoDelete(id);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: AppColors.buttonGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.royalBlue.withOpacity(0.40),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Text('UNDO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}