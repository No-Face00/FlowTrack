// lib/features/home/widgets/home_widgets.dart
// ── All Home screen widgets — mirrors Analytics design system ─
// • Gradient header with orbs, balance, stat chips
// • Wallet card, AI insight, quick actions, transaction list
// • Glass morphism throughout, consistent with AppColors

import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/appRouter.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../main_navigation.dart';
import '../../analytics/presentation/analytics_screen.dart';
import '../../transactions/domain/entities/transaction_entity.dart';
import '../../transactions/presentation/cubit/balance_cubit.dart';
import '../../transactions/presentation/cubit/balance_state.dart';
import '../../transactions/presentation/cubit/transaction_cubit.dart';
import '../../transactions/presentation/cubit/transaction_state.dart';
import 'transaction_list_item.dart';

// ════════════════════════════════════════════════════════════════
// HOME HEADER — gradient + orbs + balance + stat chips
// Same pattern as AnalyticsHeader — fades via bgOpacity
// ════════════════════════════════════════════════════════════════
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, this.bgOpacity = 1.0});
  final double bgOpacity;

  @override
  Widget build(BuildContext context) {
    final rs        = Rs.of(context);
    final statusH   = MediaQuery.of(context).padding.top;

    return Stack(clipBehavior: Clip.none, children: [
      // Gradient background
      Positioned.fill(child: Opacity(
        opacity: bgOpacity,
        child: const DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.heroGradient),
        ),
      )),

      // Decorative orbs
      Positioned(top: -50, left:  -50, child: Opacity(opacity: bgOpacity, child: _Orb(220, 0.06))),
      Positioned(top:   8, right: -60, child: Opacity(opacity: bgOpacity, child: _Orb(180, 0.05))),
      Positioned(top: 200, right:  20, child: Opacity(opacity: bgOpacity, child: _Orb(100, 0.07))),
      Positioned(top: 250, left:   60, child: Opacity(opacity: bgOpacity, child: _Orb(70,  0.04))),

      // Content
      Opacity(
        opacity: bgOpacity,
        child: Padding(
          padding: EdgeInsets.fromLTRB(rs.sp(20), statusH + rs.sp(12), rs.sp(20), 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Top row: greeting + actions
            Row(children: [
              // Greeting
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BlocBuilder<BalanceCubit, BalanceState>(
                    builder: (_, s) {
                      final name = _firstName();
                      return Text('Hello, $name 👋',
                          style: TextStyle(
                              fontSize: rs.sp(22), fontWeight: FontWeight.w800,
                              color: Colors.white, fontFamily: 'Sora',
                              letterSpacing: -0.5));
                    },
                  ),
                  SizedBox(height: rs.sp(2)),
                  Text(_todayLabel(),
                      style: TextStyle(
                          fontSize: rs.sp(12), color: Colors.white54)),
                ],
              )),

              // Notification btn only — date pill removed (date shown above)
              _GlassIconBtn(
                icon: Icons.notifications_outlined,
                badge: true,
                onTap: () {},
              ),
            ]),

            SizedBox(height: rs.sp(20)),

            // Balance section
            BlocBuilder<BalanceCubit, BalanceState>(
              builder: (_, s) {
                final loading = s is BalanceLoading || s is BalanceInitial;
                final balance = s is BalanceLoaded ? s.balance : 0.0;
                final symbol  = s is BalanceLoaded ? s.symbol  : '৳';
                final income  = s is BalanceLoaded ? s.income  : 0.0;
                final expense = s is BalanceLoaded ? s.expense : 0.0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('Total Balance',
                        style: TextStyle(
                            fontSize: rs.sp(12), color: Colors.white54,
                            letterSpacing: 1.2, fontWeight: FontWeight.w600)),
                    SizedBox(height: rs.sp(6)),

                    // Main balance — centered
                    loading
                        ? _HeaderShimmer(width: rs.sp(200), height: rs.sp(44))
                        : Text(
                      '${balance >= 0 ? "" : "-"}$symbol${NumberFormat("#,##0.00", "en_US").format(balance.abs())}',
                      style: TextStyle(
                          fontSize: rs.sp(40), fontWeight: FontWeight.w800,
                          color: Colors.white, fontFamily: 'Sora',
                          letterSpacing: -2, height: 1),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: rs.sp(10)),

                    // Surplus / Deficit badge
                    if (!loading)
                      _SurplusBadge(balance: balance, rs: rs),

                    SizedBox(height: rs.sp(18)),

                    // Income / Expense chips
                    Row(children: [
                      _BalanceChip(
                          label: 'Income', value: income, symbol: symbol,
                          icon: Icons.arrow_upward_rounded,
                          color: AppColors.income, loading: loading),
                      SizedBox(width: rs.sp(12)),
                      _BalanceChip(
                          label: 'Expenses', value: expense, symbol: symbol,
                          icon: Icons.arrow_downward_rounded,
                          color: AppColors.expense, loading: loading),
                    ]),
                  ],
                );
              },
            ),

            SizedBox(height: rs.sp(24)),
          ]),
        ),
      ),
    ]);
  }

  String _firstName() {
    try {
      final user = FirebaseAuth.instance.currentUser; // ignore: unused_import
      final name = user?.displayName ?? '';
      return name.split(' ').first.isNotEmpty
          ? name.split(' ').first : 'there';
    } catch (_) { return 'there'; }
  }

  String _todayLabel() {
    final now = DateTime.now();
    const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }
}

// ── Orb ───────────────────────────────────────────────────────
class _Orb extends StatelessWidget {
  const _Orb(this.size, this.opacity);
  final double size, opacity;
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacity)),
  );
}

// ── Header shimmer ────────────────────────────────────────────
class _HeaderShimmer extends StatefulWidget {
  const _HeaderShimmer({required this.width, required this.height});
  final double width, height;
  @override State<_HeaderShimmer> createState() => _HeaderShimmerState();
}
class _HeaderShimmerState extends State<_HeaderShimmer>
    with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) => Container(
      width: widget.width, height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment(-1.5 + _ctrl.value * 3, 0),
          end:   Alignment( 0.5 + _ctrl.value * 3, 0),
          colors: const [Color(0x20FFFFFF), Color(0x55FFFFFF), Color(0x20FFFFFF)],
        ),
      ),
    ),
  );
}

// ── Surplus / Deficit badge ───────────────────────────────────
class _SurplusBadge extends StatelessWidget {
  const _SurplusBadge({required this.balance, required this.rs});
  final double balance;
  final Rs     rs;
  @override
  Widget build(BuildContext context) {
    final isPos = balance >= 0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: rs.sp(12), vertical: rs.sp(6)),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(rs.sp(20)),
        border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(isPos ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            color: isPos ? AppColors.income : AppColors.expense,
            size: rs.sp(14)),
        SizedBox(width: rs.sp(5)),
        Text(isPos ? '✓  Surplus' : '⚠  Over budget',
            style: TextStyle(
                color: isPos ? AppColors.income : AppColors.expense,
                fontSize: rs.sp(12), fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ── Balance chip (Income / Expense) ──────────────────────────
class _BalanceChip extends StatelessWidget {
  const _BalanceChip({
    required this.label, required this.value, required this.symbol,
    required this.icon,  required this.color, required this.loading,
  });
  final String   label, symbol;
  final double   value;
  final IconData icon;
  final Color    color;
  final bool     loading;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(rs.sp(16)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: rs.sp(14), vertical: rs.sp(12)),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.11),
              borderRadius: BorderRadius.circular(rs.sp(16)),
              border: Border.all(color: Colors.white.withOpacity(0.14), width: 1),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label.toUpperCase(), style: TextStyle(
                  color: Colors.white.withOpacity(0.55), fontSize: rs.sp(9),
                  fontWeight: FontWeight.w700, letterSpacing: 1.0)),
              SizedBox(height: rs.sp(6)),
              Row(children: [
                Container(
                  width: rs.sp(22), height: rs.sp(22),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.20),
                      borderRadius: BorderRadius.circular(rs.sp(7))),
                  child: Icon(icon, color: color, size: rs.sp(13)),
                ),
                SizedBox(width: rs.sp(7)),
                Expanded(child: loading
                    ? _HeaderShimmer(width: rs.sp(60), height: rs.sp(14))
                    : Text(
                  '$symbol${_compact(value)}',
                  style: TextStyle(color: Colors.white,
                      fontSize: rs.sp(15), fontWeight: FontWeight.w700,
                      letterSpacing: -0.3),
                  overflow: TextOverflow.ellipsis,
                )),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  String _compact(double v) {
    if (v >= 1000000000) return '${(v / 1000000000).toStringAsFixed(1)}B';
    if (v >= 1000000)    return '${(v / 1000000).toStringAsFixed(1)}M';
    // Show full number — only compact at 1M+
    return NumberFormat('#,##0', 'en_US').format(v);
  }
}

// ── Date pill ─────────────────────────────────────────────────
class _DatePill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final rs  = Rs.of(context);
    final now = DateTime.now();
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'];
    final label = '${now.day} ${months[now.month - 1]}';
    return ClipRRect(
      borderRadius: BorderRadius.circular(rs.sp(22)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: rs.sp(12), vertical: rs.sp(8)),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(rs.sp(22)),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.calendar_today_rounded,
                size: rs.sp(12), color: Colors.white70),
            SizedBox(width: rs.sp(6)),
            Text(label, style: TextStyle(
                color: Colors.white, fontSize: rs.sp(12),
                fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

// ── Glass icon button ─────────────────────────────────────────
class _GlassIconBtn extends StatelessWidget {
  const _GlassIconBtn({required this.icon, this.badge = false, required this.onTap});
  final IconData icon;
  final bool     badge;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Stack(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(rs.sp(14)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              width: rs.sp(42), height: rs.sp(42),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                borderRadius: BorderRadius.circular(rs.sp(14)),
                border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
              ),
              child: Icon(icon, color: Colors.white, size: rs.sp(20)),
            ),
          ),
        ),
        if (badge)
          Positioned(top: rs.sp(9), right: rs.sp(9),
              child: Container(
                width: rs.sp(9), height: rs.sp(9),
                decoration: BoxDecoration(
                    color: AppColors.expense, shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.midnight.withOpacity(0.8), width: 2)),
              )),
      ]),
    );
  }
}

// ── Exported nav button (used in home_screen.dart) ────────────
class HeroNavBtn extends StatelessWidget {
  const HeroNavBtn({super.key, required this.icon,
    this.badge = false, required this.onTap});
  final IconData icon;
  final bool badge;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) =>
      _GlassIconBtn(icon: icon, badge: badge, onTap: onTap);
}

class HeroDatePill extends StatelessWidget {
  const HeroDatePill({super.key});
  @override
  Widget build(BuildContext context) => _DatePill();
}

// ════════════════════════════════════════════════════════════════
// WALLET CARD
// ════════════════════════════════════════════════════════════════
class WalletCard extends StatelessWidget {
  const WalletCard({super.key});

  void _showWalletSheet(BuildContext context, BalanceState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: context.read<BalanceCubit>(),
        child: const _WalletDetailSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return BlocBuilder<BalanceCubit, BalanceState>(
      builder: (ctx, state) {
        final balance = state is BalanceLoaded ? state.balance : 0.0;
        final symbol  = state is BalanceLoaded ? state.symbol  : '৳';
        final loading = state is BalanceLoading || state is BalanceInitial;
        final isNeg   = balance < 0;
        final formatted = '${isNeg ? "-" : ""}$symbol${NumberFormat("#,##0.00","en_US").format(balance.abs())}';

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            _showWalletSheet(ctx, state);
          },
          child: Container(
            padding: EdgeInsets.all(rs.sp(18)),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(rs.sp(24)),
              boxShadow: [BoxShadow(
                  color: AppColors.royalBlue.withOpacity(0.08),
                  blurRadius: 28, offset: const Offset(0, 6))],
            ),
            child: Row(children: [
              Container(
                width: rs.sp(52), height: rs.sp(52),
                decoration: BoxDecoration(
                  gradient: AppColors.buttonGradient,
                  borderRadius: BorderRadius.circular(rs.sp(16)),
                ),
                child: Icon(Icons.account_balance_wallet_rounded,
                    color: Colors.white, size: rs.sp(24)),
              ),
              SizedBox(width: rs.sp(14)),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SPENDING WALLET', style: TextStyle(
                      color: AppColors.textMuted, fontSize: rs.sp(10),
                      fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                  SizedBox(height: rs.sp(4)),
                  loading
                      ? Container(height: rs.sp(22), width: rs.sp(130),
                      decoration: BoxDecoration(color: AppColors.bgLavender,
                          borderRadius: BorderRadius.circular(rs.sp(6))))
                      : Text(formatted, style: TextStyle(
                      color: isNeg ? AppColors.expense : AppColors.textDark,
                      fontSize: rs.sp(22),
                      fontWeight: FontWeight.w800, fontFamily: 'Sora',
                      letterSpacing: -0.5),
                      overflow: TextOverflow.ellipsis),
                  if (!loading) ...[
                    SizedBox(height: rs.sp(3)),
                    Text(isNeg ? 'Over budget this month' : 'Available balance',
                        style: TextStyle(
                            color: isNeg ? AppColors.expense.withOpacity(0.7)
                                : AppColors.income.withOpacity(0.8),
                            fontSize: rs.sp(10), fontWeight: FontWeight.w600)),
                  ],
                ],
              )),
              Container(
                width: rs.sp(34), height: rs.sp(34),
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.royalBlue.withOpacity(0.08),
                        AppColors.violet.withOpacity(0.08)],
                    ),
                    borderRadius: BorderRadius.circular(rs.sp(11))),
                child: Icon(Icons.keyboard_arrow_up_rounded,
                    color: AppColors.royalBlue, size: rs.sp(20)),
              ),
            ]),
          ),
        );
      },
    );
  }
}

// ── Wallet Detail Bottom Sheet ────────────────────────────────
class _WalletDetailSheet extends StatelessWidget {
  const _WalletDetailSheet();

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return BlocBuilder<BalanceCubit, BalanceState>(
      builder: (_, state) {
        final income  = state is BalanceLoaded ? state.income   : 0.0;
        final expense = state is BalanceLoaded ? state.expense  : 0.0;
        final balance = state is BalanceLoaded ? state.balance  : 0.0;
        final symbol  = state is BalanceLoaded ? state.symbol   : '৳';
        final isNeg   = balance < 0;
        final savePct = income > 0
            ? ((balance / income) * 100).clamp(-100.0, 100.0) : 0.0;

        String fmt(double v) =>
            '$symbol${NumberFormat("#,##0.00", "en_US").format(v.abs())}';

        return Container(
          margin: EdgeInsets.fromLTRB(rs.sp(12), 0, rs.sp(12),
              rs.sp(12) + MediaQuery.of(context).padding.bottom),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(rs.sp(28)),
            boxShadow: [BoxShadow(
                color: AppColors.midnight.withOpacity(0.14),
                blurRadius: 40, offset: const Offset(0, -4))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Handle
            Center(child: Container(
              width: rs.sp(36), height: rs.sp(4),
              margin: EdgeInsets.symmetric(vertical: rs.sp(14)),
              decoration: BoxDecoration(
                  gradient: AppColors.buttonGradient,
                  borderRadius: BorderRadius.circular(2)),
            )),

            // Gradient hero
            Container(
              width: double.infinity,
              margin: EdgeInsets.fromLTRB(rs.sp(20), 0, rs.sp(20), 0),
              padding: EdgeInsets.symmetric(
                  horizontal: rs.sp(22), vertical: rs.sp(22)),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.midnight, AppColors.deepBlue,
                    AppColors.royalBlue, AppColors.violet],
                  stops: [0.0, 0.35, 0.70, 1.0],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(rs.sp(22)),
                boxShadow: [BoxShadow(
                    color: AppColors.royalBlue.withOpacity(0.28),
                    blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: Column(children: [
                Text('SPENDING WALLET', style: TextStyle(
                    color: Colors.white.withOpacity(0.60),
                    fontSize: rs.sp(10), fontWeight: FontWeight.w700,
                    letterSpacing: 1.5)),
                SizedBox(height: rs.sp(8)),
                Text(
                  '${isNeg ? "-" : ""}${fmt(balance)}',
                  style: TextStyle(
                      color: isNeg ? AppColors.expense : Colors.white,
                      fontSize: rs.sp(36), fontWeight: FontWeight.w800,
                      fontFamily: 'Sora', letterSpacing: -1.5),
                ),
                SizedBox(height: rs.sp(6)),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: rs.sp(12), vertical: rs.sp(5)),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(rs.sp(20)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                        isNeg ? Icons.trending_down_rounded
                            : Icons.trending_up_rounded,
                        color: isNeg ? AppColors.expense : AppColors.income,
                        size: rs.sp(13)),
                    SizedBox(width: rs.sp(5)),
                    Text(
                        isNeg
                            ? 'Over budget by ${(-savePct).toStringAsFixed(0)}%'
                            : 'Saving ${savePct.toStringAsFixed(0)}% of income',
                        style: TextStyle(
                            color: isNeg ? AppColors.expense : AppColors.income,
                            fontSize: rs.sp(12), fontWeight: FontWeight.w700)),
                  ]),
                ),
              ]),
            ),

            // Income / Expense breakdown
            Padding(
              padding: EdgeInsets.fromLTRB(rs.sp(20), rs.sp(16), rs.sp(20), rs.sp(20)),
              child: Column(children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.bgLavender,
                    borderRadius: BorderRadius.circular(rs.sp(20)),
                  ),
                  child: Column(children: [
                    _WalletRow(
                      icon: Icons.arrow_upward_rounded,
                      iconColor: AppColors.income,
                      label: 'Total Income',
                      value: fmt(income),
                      valueColor: AppColors.income,
                      rs: rs,
                    ),
                    Container(height: 1,
                        color: Colors.white.withOpacity(0.80),
                        margin: EdgeInsets.symmetric(horizontal: rs.sp(16))),
                    _WalletRow(
                      icon: Icons.arrow_downward_rounded,
                      iconColor: AppColors.expense,
                      label: 'Total Expenses',
                      value: fmt(expense),
                      valueColor: AppColors.expense,
                      rs: rs,
                    ),
                    Container(height: 1,
                        color: Colors.white.withOpacity(0.80),
                        margin: EdgeInsets.symmetric(horizontal: rs.sp(16))),
                    _WalletRow(
                      icon: Icons.account_balance_wallet_rounded,
                      iconColor: isNeg ? AppColors.expense : AppColors.royalBlue,
                      label: 'Net Balance',
                      value: '${isNeg ? "-" : "+"}${fmt(balance)}',
                      valueColor: isNeg ? AppColors.expense : AppColors.income,
                      rs: rs,
                      bold: true,
                    ),
                  ]),
                ),
                SizedBox(height: rs.sp(16)),
                // Progress bar: expense vs income
                if (income > 0) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Spent', style: TextStyle(
                          color: AppColors.textMuted, fontSize: rs.sp(11),
                          fontWeight: FontWeight.w600)),
                      Text('${((expense / income) * 100).clamp(0, 100).toStringAsFixed(0)}% of income',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: rs.sp(11),
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                  SizedBox(height: rs.sp(6)),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(rs.sp(6)),
                    child: LinearProgressIndicator(
                      value: (expense / income).clamp(0.0, 1.0),
                      minHeight: rs.sp(8),
                      backgroundColor: AppColors.bgLavender,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          expense > income ? AppColors.expense : AppColors.royalBlue),
                    ),
                  ),
                  SizedBox(height: rs.sp(16)),
                ],
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: rs.sp(16)),
                    decoration: BoxDecoration(
                      gradient: AppColors.buttonGradient,
                      borderRadius: BorderRadius.circular(rs.sp(18)),
                      boxShadow: [BoxShadow(
                          color: AppColors.royalBlue.withOpacity(0.35),
                          blurRadius: 14, offset: const Offset(0, 5))],
                    ),
                    child: Center(child: Text('Close',
                        style: TextStyle(color: Colors.white,
                            fontSize: rs.sp(15), fontWeight: FontWeight.w700))),
                  ),
                ),
              ]),
            ),
          ]),
        );
      },
    );
  }
}

class _WalletRow extends StatelessWidget {
  const _WalletRow({
    required this.icon, required this.iconColor,
    required this.label, required this.value, required this.valueColor,
    required this.rs, this.bold = false,
  });
  final IconData icon;
  final Color    iconColor, valueColor;
  final String   label, value;
  final Rs       rs;
  final bool     bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: rs.sp(16), vertical: rs.sp(13)),
      child: Row(children: [
        Container(
          width: rs.sp(34), height: rs.sp(34),
          decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(rs.sp(11))),
          child: Icon(icon, color: iconColor, size: rs.sp(17)),
        ),
        SizedBox(width: rs.sp(12)),
        Expanded(child: Text(label, style: TextStyle(
            fontSize: rs.sp(13), color: AppColors.textMid,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500))),
        Text(value, style: TextStyle(
            fontSize: rs.sp(14), color: valueColor,
            fontWeight: FontWeight.w800, fontFamily: 'Sora')),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// AI INSIGHT CARD
// ════════════════════════════════════════════════════════════════
class AiInsightCard extends StatelessWidget {
  const AiInsightCard({super.key, required this.onDismiss});
  final VoidCallback onDismiss;

  String _insight(BalanceState s) {
    if (s is! BalanceLoaded) return 'Loading your financial insights… 📊';
    final inc = s.income;
    final exp = s.expense;
    final bal = s.balance;
    if (inc == 0 && exp == 0) return 'Add your first transaction to start tracking 🚀';
    if (inc == 0) return 'You have expenses but no income recorded. Add income! 💡';
    if (exp == 0) return 'Great start! Add expenses to track spending. 📊';
    final rate = ((bal / inc) * 100).clamp(-100.0, 100.0);
    if (rate >= 50) return 'Excellent! Saving ${rate.toStringAsFixed(0)}% of income. Amazing! 🎉';
    if (rate >= 20) return 'Good job! Saving ${rate.toStringAsFixed(0)}% of income. Keep it up! 👍';
    if (rate >= 0)  return 'Saving ${rate.toStringAsFixed(0)}% of income. Try to cut back more. 💪';
    return 'Spending ${(-rate).toStringAsFixed(0)}% more than you earn. Review your budget! ⚠️';
  }

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return BlocBuilder<BalanceCubit, BalanceState>(
      builder: (_, s) => Container(
        padding: EdgeInsets.symmetric(
            horizontal: rs.sp(17), vertical: rs.sp(16)),
        decoration: BoxDecoration(
          gradient: AppColors.aiCardGradient,
          borderRadius: BorderRadius.circular(rs.sp(22)),
          boxShadow: [BoxShadow(
              color: AppColors.midnight.withOpacity(0.30),
              blurRadius: 20, offset: const Offset(0, 6))],
        ),
        child: Row(children: [
          Container(
            width: rs.sp(42), height: rs.sp(42),
            decoration: BoxDecoration(
              color: AppColors.violet.withOpacity(0.2),
              borderRadius: BorderRadius.circular(rs.sp(13)),
              border: Border.all(
                  color: AppColors.violet.withOpacity(0.3), width: 1),
            ),
            child: Icon(Icons.auto_awesome_rounded,
                color: AppColors.violet, size: rs.sp(20)),
          ),
          SizedBox(width: rs.sp(12)),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AI INSIGHT', style: TextStyle(
                  color: AppColors.violet, fontSize: rs.sp(9),
                  fontWeight: FontWeight.w800, letterSpacing: 1.5)),
              SizedBox(height: rs.sp(4)),
              Text(_insight(s), style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: rs.sp(13), height: 1.5)),
            ],
          )),
          GestureDetector(
            onTap: onDismiss,
            child: Container(
              width: rs.sp(28), height: rs.sp(28),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(rs.sp(8))),
              child: Icon(Icons.close_rounded,
                  color: Colors.white.withOpacity(0.5), size: rs.sp(14)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// QUICK ACTIONS ROW
// ════════════════════════════════════════════════════════════════
class QuickActionsRow extends StatelessWidget {
  const QuickActionsRow({super.key});

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    final actions = [
      _QA(icon: Icons.add_circle_outline_rounded,    label: 'Income',
          grad: const [Color(0xFF00C48C), Color(0xFF00A876)],
          onTap: () { HapticFeedback.selectionClick(); context.push(AppRoutes.addTransaction, extra: 'income'); }),
      _QA(icon: Icons.remove_circle_outline_rounded, label: 'Expense',
          grad: const [AppColors.expense, Color(0xFFFF3D5A)],
          onTap: () { HapticFeedback.selectionClick(); context.push(AppRoutes.addTransaction, extra: 'expense'); }),
      _QA(icon: Icons.swap_horiz_rounded,            label: 'Transfer',
          grad: const [AppColors.royalBlue, AppColors.deepBlue],
          onTap: () { HapticFeedback.selectionClick(); context.push(AppRoutes.addTransaction, extra: 'transfer'); }),
      _QA(icon: Icons.pie_chart_outline_rounded,     label: 'Budget',
          grad: const [AppColors.violet, Color(0xFF7B5CFF)],
          onTap: () {
            HapticFeedback.selectionClick();
            // Switch to Analytics tab (index 2) then scroll to Budget Overview
            final nav = context.findAncestorStateOfType<MainNavigationState>();
            nav?.onTabTap(2);
            // After the tab switch renders, scroll to budget section
            AnalyticsScreen.scrollToBudget();
          }),
    ];

    return Container(
      padding: EdgeInsets.all(rs.sp(18)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(rs.sp(24)),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Quick Actions', style: TextStyle(
            fontSize: rs.sp(14), fontWeight: FontWeight.w800,
            color: AppColors.textDark, fontFamily: 'Sora')),
        SizedBox(height: rs.sp(16)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: actions.map((a) => _QABtn(a: a)).toList(),
        ),
      ]),
    );
  }
}

class _QA {
  final IconData       icon;
  final String         label;
  final List<Color>    grad;
  final VoidCallback   onTap;
  const _QA({required this.icon, required this.label,
    required this.grad, required this.onTap});
}

class _QABtn extends StatelessWidget {
  const _QABtn({required this.a});
  final _QA a;
  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return GestureDetector(
      onTap: a.onTap,
      child: Column(children: [
        Container(
          width: rs.sp(56), height: rs.sp(56),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: a.grad),
            borderRadius: BorderRadius.circular(rs.sp(18)),
            boxShadow: [BoxShadow(
                color: a.grad.first.withOpacity(0.35),
                blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Icon(a.icon, color: Colors.white, size: rs.sp(26)),
        ),
        SizedBox(height: rs.sp(8)),
        Text(a.label, style: TextStyle(
            fontSize: rs.sp(12), fontWeight: FontWeight.w600,
            color: AppColors.textMid)),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// RECENT HEADER
// ════════════════════════════════════════════════════════════════
class RecentHeader extends StatelessWidget {
  const RecentHeader({super.key, required this.rs});
  final Rs rs;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          Container(
            width: rs.sp(4), height: rs.sp(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [AppColors.royalBlue, AppColors.violet]),
              borderRadius: BorderRadius.circular(rs.sp(3)),
            ),
          ),
          SizedBox(width: rs.sp(10)),
          Text('Recent Transactions', style: TextStyle(
              fontSize: rs.sp(16), fontWeight: FontWeight.w800,
              color: AppColors.textDark, fontFamily: 'Sora',
              letterSpacing: -0.3)),
        ]),
        GestureDetector(
          onTap: () {
            final nav = context.findAncestorStateOfType<MainNavigationState>();
            if (nav != null) nav.onTabTap(1);
            else context.go('/home');
          },
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: rs.sp(13), vertical: rs.sp(7)),
            decoration: BoxDecoration(
              gradient: AppColors.buttonGradient,
              borderRadius: BorderRadius.circular(rs.sp(22)),
              boxShadow: [BoxShadow(
                  color: AppColors.royalBlue.withOpacity(0.30),
                  blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: Text('See All', style: TextStyle(
                fontSize: rs.sp(12), color: Colors.white,
                fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// RECENT TRANSACTIONS LIST
// ════════════════════════════════════════════════════════════════
class RecentTxnsList extends StatelessWidget {
  const RecentTxnsList({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TransactionCubit, TransactionState>(
      // Rebuild on EVERY state change — this is what makes add/delete instant
      buildWhen: (_, curr) => true,
      builder: (ctx, state) {
        if (state is TransactionLoading) return const TxnShimmerList();

        final txns = state is TransactionLoaded
            ? state.transactions.take(20).toList()
            : <TransactionEntity>[];

        if (txns.isEmpty) return const TxnEmptyState();

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(rs(context).sp(24)),
            boxShadow: [BoxShadow(
                color: AppColors.royalBlue.withOpacity(0.07),
                blurRadius: 28, offset: const Offset(0, 6))],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: txns.asMap().entries.map((e) => TransactionListItem(
              tx:       e.value,
              isLast:   e.key == txns.length - 1,
              onDelete: () => ctx.read<TransactionCubit>().softDelete(e.value.id),
              onTap:    () => _showDetail(context, e.value),
            )).toList(),
          ),
        );
      },
    );
  }

  Rs rs(BuildContext ctx) => Rs.of(ctx);

  void _showDetail(BuildContext context, TransactionEntity tx) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: context.read<BalanceCubit>(),
        child: TransactionDetailSheet(tx: tx),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SHIMMER + EMPTY STATE
// ════════════════════════════════════════════════════════════════
class TxnShimmerList extends StatelessWidget {
  const TxnShimmerList({super.key});
  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Container(
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(rs.sp(24))),
      child: Column(children: List.generate(5, (i) => Padding(
        padding: EdgeInsets.symmetric(
            horizontal: rs.sp(18), vertical: rs.sp(14)),
        child: Row(children: [
          _box(rs.sp(46), rs.sp(46), r: rs.sp(14)),
          SizedBox(width: rs.sp(12)),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            _box(rs.sp(12), rs.sp(140)),
            SizedBox(height: rs.sp(6)),
            _box(rs.sp(10), rs.sp(90)),
          ])),
          _box(rs.sp(14), rs.sp(60)),
        ]),
      ))),
    );
  }
  Widget _box(double h, double w, {double r = 6}) => Container(
      height: h, width: w,
      decoration: BoxDecoration(
          color: AppColors.bgLavender,
          borderRadius: BorderRadius.circular(r)));
}

class TxnEmptyState extends StatelessWidget {
  const TxnEmptyState({super.key});
  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Container(
      padding: EdgeInsets.all(rs.sp(40)),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(rs.sp(24))),
      child: Column(children: [
        Container(
          width: rs.sp(72), height: rs.sp(72),
          decoration: BoxDecoration(color: AppColors.iconTile,
              borderRadius: BorderRadius.circular(rs.sp(22))),
          child: Icon(Icons.receipt_long_outlined,
              color: AppColors.textMuted, size: rs.sp(36)),
        ),
        SizedBox(height: rs.sp(16)),
        Text('No transactions yet', style: TextStyle(
            fontSize: rs.sp(16), fontWeight: FontWeight.w700,
            color: AppColors.textDark, fontFamily: 'Sora')),
        SizedBox(height: rs.sp(6)),
        Text('Tap + to add your first transaction',
            style: TextStyle(fontSize: rs.sp(13), color: AppColors.textMuted)),
      ]),
    );
  }
}
// ════════════════════════════════════════════════════════════════
// ════════════════════════════════════════════════════════════════
// TRANSACTION DETAIL SHEET  — redesigned
// ════════════════════════════════════════════════════════════════
class TransactionDetailSheet extends StatelessWidget {
  const TransactionDetailSheet({super.key, required this.tx});
  final TransactionEntity tx;

  static const _catIcons = <String, IconData>{
    'food':          Icons.restaurant_rounded,
    'transport':     Icons.directions_car_rounded,
    'shopping':      Icons.shopping_bag_rounded,
    'health':        Icons.favorite_rounded,
    'entertainment': Icons.movie_rounded,
    'bills':         Icons.bolt_rounded,
    'education':     Icons.school_rounded,
    'rent':          Icons.home_rounded,
    'salary':        Icons.work_rounded,
    'freelance':     Icons.laptop_rounded,
    'investment':    Icons.trending_up_rounded,
    'business':      Icons.business_rounded,
    'gift':          Icons.card_giftcard_rounded,
    'groceries':     Icons.shopping_cart_rounded,
    'other':         Icons.category_rounded,
    'transfer':      Icons.swap_horiz_rounded,
  };

  static const _catColors = <String, Color>{
    'food':          Color(0xFFFF8C42),
    'transport':     Color(0xFF4ECDC4),
    'shopping':      Color(0xFFFF6B9D),
    'health':        Color(0xFFFF4757),
    'entertainment': Color(0xFF7B5CFF),
    'bills':         Color(0xFF2196F3),
    'education':     Color(0xFF00BCD4),
    'rent':          Color(0xFF607D8B),
    'salary':        Color(0xFF00C48C),
    'freelance':     Color(0xFF00A876),
    'investment':    Color(0xFF0033FF),
    'business':      Color(0xFF3F51B5),
    'gift':          Color(0xFFE91E63),
    'groceries':     Color(0xFF8BC34A),
    'other':         Color(0xFF9E9E9E),
    'transfer':      Color(0xFF0600AB),
  };

  @override
  Widget build(BuildContext context) {
    final rs         = Rs.of(context);
    final isIncome   = tx.type == 'income';
    final isTransfer = tx.type == 'transfer';
    final catColor   = _catColors[tx.category] ?? AppColors.textMuted;
    final catIcon    = _catIcons[tx.category]  ?? Icons.category_rounded;
    final amtColor   = isIncome   ? AppColors.income
        : isTransfer ? AppColors.royalBlue
        : AppColors.expense;
    final prefix     = isIncome ? '+' : '-';
    final typeLabel  = isIncome ? 'Income' : isTransfer ? 'Transfer' : 'Expense';

    String symbol = '৳';
    try {
      final bs = context.read<BalanceCubit>().state;
      if (bs is BalanceLoaded) symbol = bs.symbol;
    } catch (_) {}

    final amtFormatted =
        '$prefix$symbol${NumberFormat("#,##0.00", "en_US").format(tx.amount)}';

    return Container(
      margin: EdgeInsets.fromLTRB(rs.sp(12), 0, rs.sp(12),
          rs.sp(12) + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(rs.sp(28)),
        boxShadow: [BoxShadow(
            color: AppColors.midnight.withOpacity(0.14),
            blurRadius: 40, offset: const Offset(0, -4))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // ── Gradient pill handle ─────────────────────────────
        Center(child: Container(
          width: rs.sp(36), height: rs.sp(4),
          margin: EdgeInsets.symmetric(vertical: rs.sp(14)),
          decoration: BoxDecoration(
              gradient: AppColors.buttonGradient,
              borderRadius: BorderRadius.circular(2)),
        )),

        // ── Gradient hero band ───────────────────────────────
        Container(
          width: double.infinity,
          margin: EdgeInsets.fromLTRB(rs.sp(20), 0, rs.sp(20), 0),
          padding: EdgeInsets.symmetric(
              horizontal: rs.sp(20), vertical: rs.sp(20)),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [catColor.withOpacity(0.80), catColor],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(rs.sp(22)),
            boxShadow: [BoxShadow(
                color: catColor.withOpacity(0.30),
                blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Row(children: [
            Container(
              width: rs.sp(52), height: rs.sp(52),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.20),
                borderRadius: BorderRadius.circular(rs.sp(16)),
                border: Border.all(color: Colors.white.withOpacity(0.30), width: 1.5),
              ),
              child: Icon(catIcon, color: Colors.white, size: rs.sp(26)),
            ),
            SizedBox(width: rs.sp(14)),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.title,
                    style: TextStyle(
                        fontSize: rs.sp(16), fontWeight: FontWeight.w800,
                        color: Colors.white, fontFamily: 'Sora',
                        letterSpacing: -0.3),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                SizedBox(height: rs.sp(6)),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: rs.sp(10), vertical: rs.sp(4)),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(rs.sp(20)),
                  ),
                  child: Text(typeLabel, style: TextStyle(
                      color: Colors.white, fontSize: rs.sp(11),
                      fontWeight: FontWeight.w700)),
                ),
              ],
            )),
            Text(amtFormatted, style: TextStyle(
                fontSize: rs.sp(18), fontWeight: FontWeight.w800,
                color: Colors.white, fontFamily: 'Sora', letterSpacing: -0.8),
                textAlign: TextAlign.end),
          ]),
        ),

        // ── Details grid ─────────────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(rs.sp(20), rs.sp(16), rs.sp(20), rs.sp(20)),
          child: Column(children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.bgLavender,
                borderRadius: BorderRadius.circular(rs.sp(20)),
              ),
              child: Column(children: [
                _DetailRow2(
                    label: 'Category',
                    value: _cap(tx.category),
                    icon: catIcon, iconColor: catColor, rs: rs),
                _DetailDivider(),
                _DetailRow2(
                    label: 'Date',
                    value: DateFormat('EEEE, d MMM yyyy').format(tx.date),
                    icon: Icons.calendar_today_rounded,
                    iconColor: AppColors.royalBlue, rs: rs),
                _DetailDivider(),
                _DetailRow2(
                    label: 'Currency',
                    value: tx.currency,
                    icon: Icons.language_rounded,
                    iconColor: AppColors.violet, rs: rs),
                if (tx.note != null && tx.note!.isNotEmpty) ...[
                  _DetailDivider(),
                  _DetailRow2(
                      label: 'Note',
                      value: tx.note!,
                      icon: Icons.notes_rounded,
                      iconColor: AppColors.textMid, rs: rs),
                ],
                _DetailDivider(),
                _DetailRow2(
                    label: 'Sync status',
                    value: tx.isSynced ? 'Synced to cloud ✓' : 'Pending sync',
                    icon: tx.isSynced
                        ? Icons.cloud_done_rounded
                        : Icons.cloud_off_rounded,
                    iconColor: tx.isSynced ? AppColors.income : AppColors.textMuted,
                    rs: rs),
              ]),
            ),
            SizedBox(height: rs.sp(16)),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: rs.sp(16)),
                decoration: BoxDecoration(
                  gradient: AppColors.buttonGradient,
                  borderRadius: BorderRadius.circular(rs.sp(18)),
                  boxShadow: [BoxShadow(
                      color: AppColors.royalBlue.withOpacity(0.35),
                      blurRadius: 14, offset: const Offset(0, 5))],
                ),
                child: Center(child: Text('Done',
                    style: TextStyle(
                        color: Colors.white, fontSize: rs.sp(15),
                        fontWeight: FontWeight.w700))),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _DetailRow2 extends StatelessWidget {
  const _DetailRow2({required this.label, required this.value,
    required this.icon, required this.iconColor, required this.rs});
  final String   label, value;
  final IconData icon;
  final Color    iconColor;
  final Rs       rs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: rs.sp(16), vertical: rs.sp(13)),
      child: Row(children: [
        Container(
          width: rs.sp(34), height: rs.sp(34),
          decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(rs.sp(11))),
          child: Icon(icon, color: iconColor, size: rs.sp(17)),
        ),
        SizedBox(width: rs.sp(12)),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(
              fontSize: rs.sp(10), color: AppColors.textMuted,
              fontWeight: FontWeight.w600, letterSpacing: 0.3)),
          SizedBox(height: rs.sp(2)),
          Text(value, style: TextStyle(
              fontSize: rs.sp(13), color: AppColors.textDark,
              fontWeight: FontWeight.w700)),
        ])),
      ]),
    );
  }
}

class _DetailDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      height: 1, color: Colors.white.withOpacity(0.80),
      margin: const EdgeInsets.symmetric(horizontal: 16));
}