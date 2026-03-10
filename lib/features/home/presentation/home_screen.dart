// lib/features/home/presentation/home_screen.dart
//
// FIXES:
//   1. Hero gradient covers status bar exactly — no colour mismatch
//   2. Header is FIXED (not inside a scroll view) — only the body list scrolls
//   3. "See All" taps the Transactions tab via MainNavigationState
//   4. Currency symbol always reads from BalanceCubit (BDT=৳, USD=$, etc.)

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../main_navigation.dart';
import '../../transactions/presentation/cubit/balance_cubit.dart';
import '../../transactions/presentation/cubit/transaction_cubit.dart';
import '../../transactions/presentation/cubit/transaction_state.dart';
import '../widgets/balance_card.dart';
import '../widgets/home_widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => getIt<TransactionCubit>()..loadTransactions(),
        ),
        BlocProvider(
          create: (_) => getIt<BalanceCubit>()
            ..watchBalance(FirebaseAuth.instance.currentUser?.uid ?? ''),
        ),
      ],
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatefulWidget {
  const _HomeView();
  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  bool _showAiInsight = true;
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    // Make status bar icons white so they look right on dark gradient
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.bgLavender,
        // ── Use Stack: fixed gradient header + scrollable body ──
        body: Column(
          children: [
            // ─────────────── FIXED HERO HEADER ───────────────
            // Extends behind the status bar via top: 0 Container
            Container(
              decoration: const BoxDecoration(
                gradient: AppColors.heroGradient,
              ),
              child: Column(
                children: [
                  // Status bar space — gradient fills all the way up
                  SizedBox(height: MediaQuery.of(context).padding.top),
                  // Top bar row
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: rs.sp(22),
                      vertical: rs.sp(12),
                    ),
                    child: Row(children: [
                      HeroNavBtn(
                          icon: Icons.settings_outlined, onTap: () {}),
                      const Spacer(),
                      const HeroDatePill(),
                      const Spacer(),
                      HeroNavBtn(
                        icon: Icons.notifications_outlined,
                        badge: true,
                        onTap: () {},
                      ),
                    ]),
                  ),
                  // Balance card is part of the fixed header
                  const BalanceCard(),
                ],
              ),
            ),

            // ─────────────── SCROLLABLE BODY ─────────────────
            Expanded(
              child: BlocListener<TransactionCubit, TransactionState>(
                listener: (ctx, state) {
                  if (state is TransactionDeleted) {
                    ScaffoldMessenger.of(ctx)
                      ..clearSnackBars()
                      ..showSnackBar(_undoSnackBar(ctx, state.deletedId));
                  }
                },
                child: ListView(
                  controller: _scrollCtrl,
                  padding: EdgeInsets.fromLTRB(
                      rs.sp(18), rs.sp(18), rs.sp(18), 110),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // Wallet card
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
                    SizedBox(height: rs.sp(22)),

                    // Recent Transactions header
                    _RecentHeader(rs: rs),
                    SizedBox(height: rs.sp(12)),

                    // Transaction list
                    const RecentTxnsList(),
                  ],
                ),
              ),
            ),
          ],
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
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14)),
    action: SnackBarAction(
      label: 'UNDO',
      textColor: AppColors.violet,
      onPressed: () =>
          ctx.read<TransactionCubit>().undoDelete(id),
    ),
  );
}

// ── Recent transactions section header ────────────────────────
class _RecentHeader extends StatelessWidget {
  const _RecentHeader({required this.rs});
  final Rs rs;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Recent Transactions',
          style: TextStyle(
            fontSize: rs.sp(18),
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
            fontFamily: 'Sora',
          ),
        ),
        GestureDetector(
          onTap: () {
            // Navigate to Transactions tab (index 1) in MainNavigation
            final nav = context
                .findAncestorStateOfType<MainNavigationState>();
            if (nav != null) {
              nav.onTabTap(1);
            } else {
              context.go('/home');
            }
          },
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: rs.sp(12), vertical: rs.sp(6)),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.royalBlue, AppColors.violet],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'See All',
              style: TextStyle(
                fontSize: rs.sp(12),
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}