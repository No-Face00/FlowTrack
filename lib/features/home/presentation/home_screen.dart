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
import '../../../core/di/service_locator.dart';
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
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) {
          final c = getIt<TransactionCubit>();
          // Always load on screen creation — won't shimmer if data exists
          c.loadTransactions();
          return c;
        }),
        BlocProvider(create: (_) {
          final c = getIt<BalanceCubit>();
          if (c.state is BalanceInitial) c.watchBalance(userId);
          return c;
        }),
      ],
      child: const _HomeView(),
    );
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
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<TransactionCubit>().loadTransactions();
    }
  }

  // ── Reload every time this route becomes active ────────────
  // This fires when returning from AddTransactionScreen
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Schedule after frame so context is fully ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<TransactionCubit>().loadTransactions();
      }
    });
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
                  SizedBox(height: rs.sp(360)),

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

  SnackBar _undoSnackBar(BuildContext ctx, String id) => SnackBar(
    content: const Text('Transaction deleted'),
    backgroundColor: const Color(0xFF3D3B6E),
    duration: const Duration(seconds: 4),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    action: SnackBarAction(
      label: 'UNDO',
      textColor: AppColors.violet,
      onPressed: () => ctx.read<TransactionCubit>().undoDelete(id),
    ),
  );
}