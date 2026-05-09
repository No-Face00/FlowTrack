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
import '../../../core/notifications/notification_cubit.dart';
import '../../../core/notifications/notification_widgets.dart';
import '../../../core/cubit/app_cubit.dart';
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
                      return Text('Hello, $name ',
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

              // Live notification bell — shows unread count badge,
              // taps open the NotificationSheet
              const NotificationBell(),
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
// MONTHLY SPEND CARD
// Shows top spending categories this month — genuinely different
// from the header (which shows total balance/income/expense).
// Tap opens a full breakdown bottom sheet.
// ════════════════════════════════════════════════════════════════
class WalletCard extends StatelessWidget {
  const WalletCard({super.key});

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    // context.select must be called directly inside build(), not inside
    // a BlocBuilder callback — doing so there triggers a provider assertion.
    final symbol = context.select<BalanceCubit, String>((c) {
      final s = c.state;
      return s is BalanceLoaded ? s.symbol : '৳';
    });

    return BlocBuilder<TransactionCubit, TransactionState>(
      builder: (ctx, txState) {
        final now      = DateTime.now();
        final monthKey = '${now.year}-${now.month.toString().padLeft(2, "0")}';

        final txns = txState is TransactionLoaded
            ? txState.transactions
            .where((t) => t.month == monthKey && t.type == 'expense')
            .toList()
            : <TransactionEntity>[];

        // Build category totals
        final catTotals = <String, double>{};
        for (final t in txns) {
          catTotals[t.category] = (catTotals[t.category] ?? 0) + t.amount;
        }
        final sorted = catTotals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final top3 = sorted.take(3).toList();
        final totalSpent = txns.fold<double>(0, (s, t) => s + t.amount);

        final loading = txState is TransactionLoading || txState is TransactionInitial;

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            showModalBottomSheet(
              context: ctx,
              backgroundColor: Colors.transparent,
              useRootNavigator: true,
              isScrollControlled: true,
              builder: (_) => MultiBlocProvider(
                providers: [
                  BlocProvider.value(value: ctx.read<TransactionCubit>()),
                  BlocProvider.value(value: ctx.read<BalanceCubit>()),
                ],
                child: _SpendBreakdownSheet(
                  monthKey: monthKey, symbol: symbol,
                ),
              ),
            );
          },
          child: Container(
            padding: EdgeInsets.all(rs.sp(18)),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(rs.sp(24)),
              boxShadow: [BoxShadow(
                  color: AppColors.royalBlue.withOpacity(0.08),
                  blurRadius: 28, offset: const Offset(0, 6))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header row
              Row(children: [
                Container(
                  width: rs.sp(42), height: rs.sp(42),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(rs.sp(13)),
                  ),
                  child: Icon(Icons.insights_rounded,
                      color: Colors.white, size: rs.sp(22)),
                ),
                SizedBox(width: rs.sp(12)),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("THIS MONTH'S SPENDING",
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.50),
                            fontSize: rs.sp(10), fontWeight: FontWeight.w700,
                            letterSpacing: 1.1)),
                    SizedBox(height: rs.sp(3)),
                    loading
                        ? Container(height: rs.sp(20), width: rs.sp(110),
                        decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(rs.sp(5))))
                        : Text(
                        '$symbol${NumberFormat("#,##0.00", "en_US").format(totalSpent)}',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface,
                            fontSize: rs.sp(20), fontWeight: FontWeight.w800,
                            fontFamily: 'Sora', letterSpacing: -0.5)),
                  ],
                )),
                Container(
                  width: rs.sp(32), height: rs.sp(32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      AppColors.royalBlue.withOpacity(0.08),
                      AppColors.violet.withOpacity(0.08),
                    ]),
                    borderRadius: BorderRadius.circular(rs.sp(10)),
                  ),
                  child: Icon(Icons.keyboard_arrow_up_rounded,
                      color: AppColors.royalBlue, size: rs.sp(18)),
                ),
              ]),

              if (!loading && top3.isNotEmpty) ...[
                SizedBox(height: rs.sp(14)),
                // Divider
                Container(height: 1,
                    color: Theme.of(context).scaffoldBackgroundColor,
                    margin: EdgeInsets.only(bottom: rs.sp(12))),
                // Top categories
                ...top3.asMap().entries.map((e) {
                  final cat   = e.value.key;
                  final amt   = e.value.value;
                  final pct   = totalSpent > 0 ? (amt / totalSpent) : 0.0;
                  final color = _catColors[cat] ?? AppColors.textMuted;
                  final icon  = _catIcons[cat]  ?? Icons.category_rounded;
                  return Padding(
                    padding: EdgeInsets.only(bottom: e.key < top3.length - 1 ? rs.sp(10) : 0),
                    child: Row(children: [
                      Container(
                        width: rs.sp(30), height: rs.sp(30),
                        decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(rs.sp(9))),
                        child: Icon(icon, color: color, size: rs.sp(15)),
                      ),
                      SizedBox(width: rs.sp(10)),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_cap(cat), style: TextStyle(
                                  fontSize: rs.sp(12), fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurface)),
                              Text('$symbol${NumberFormat("#,##0", "en_US").format(amt)}',
                                  style: TextStyle(
                                      fontSize: rs.sp(12), fontWeight: FontWeight.w700,
                                      color: color)),
                            ],
                          ),
                          SizedBox(height: rs.sp(4)),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(rs.sp(4)),
                            child: LinearProgressIndicator(
                              value: pct.clamp(0.0, 1.0),
                              minHeight: rs.sp(5),
                              backgroundColor: color.withOpacity(0.12),
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                            ),
                          ),
                        ],
                      )),
                    ]),
                  );
                }),
              ] else if (!loading && top3.isEmpty) ...[
                SizedBox(height: rs.sp(12)),
                Center(child: Text('No expenses this month yet',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
                        fontSize: rs.sp(12)))),
              ],
            ]),
          ),
        );
      },
    );
  }

  static const _catIcons = <String, IconData>{
    'food': Icons.restaurant_rounded,
    'transport': Icons.directions_car_rounded,
    'shopping': Icons.shopping_bag_rounded,
    'health': Icons.favorite_rounded,
    'entertainment': Icons.movie_rounded,
    'bills': Icons.bolt_rounded,
    'education': Icons.school_rounded,
    'rent': Icons.home_rounded,
    'salary': Icons.work_rounded,
    'freelance': Icons.laptop_rounded,
    'investment': Icons.trending_up_rounded,
    'business': Icons.business_rounded,
    'gift': Icons.card_giftcard_rounded,
    'groceries': Icons.shopping_cart_rounded,
    'other': Icons.category_rounded,
    'transfer': Icons.swap_horiz_rounded,
  };

  static const _catColors = <String, Color>{
    'food': Color(0xFFFF8C42),
    'transport': Color(0xFF4ECDC4),
    'shopping': Color(0xFFFF6B9D),
    'health': Color(0xFFFF4757),
    'entertainment': Color(0xFF7B5CFF),
    'bills': Color(0xFF2196F3),
    'education': Color(0xFF00BCD4),
    'rent': Color(0xFF607D8B),
    'salary': Color(0xFF00C48C),
    'freelance': Color(0xFF00A876),
    'investment': Color(0xFF0033FF),
    'business': Color(0xFF3F51B5),
    'gift': Color(0xFFE91E63),
    'groceries': Color(0xFF8BC34A),
    'other': Color(0xFF9E9E9E),
    'transfer': Color(0xFF0600AB),
  };

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ── Full Spend Breakdown Sheet ─────────────────────────────────
class _SpendBreakdownSheet extends StatelessWidget {
  const _SpendBreakdownSheet({
    required this.monthKey,
    required this.symbol,
  });
  final String monthKey, symbol;

  static const _catIcons = <String, IconData>{
    'food': Icons.restaurant_rounded,
    'transport': Icons.directions_car_rounded,
    'shopping': Icons.shopping_bag_rounded,
    'health': Icons.favorite_rounded,
    'entertainment': Icons.movie_rounded,
    'bills': Icons.bolt_rounded,
    'education': Icons.school_rounded,
    'rent': Icons.home_rounded,
    'salary': Icons.work_rounded,
    'freelance': Icons.laptop_rounded,
    'investment': Icons.trending_up_rounded,
    'business': Icons.business_rounded,
    'gift': Icons.card_giftcard_rounded,
    'groceries': Icons.shopping_cart_rounded,
    'other': Icons.category_rounded,
    'transfer': Icons.swap_horiz_rounded,
  };
  static const _catColors = <String, Color>{
    'food': Color(0xFFFF8C42),
    'transport': Color(0xFF4ECDC4),
    'shopping': Color(0xFFFF6B9D),
    'health': Color(0xFFFF4757),
    'entertainment': Color(0xFF7B5CFF),
    'bills': Color(0xFF2196F3),
    'education': Color(0xFF00BCD4),
    'rent': Color(0xFF607D8B),
    'salary': Color(0xFF00C48C),
    'freelance': Color(0xFF00A876),
    'investment': Color(0xFF0033FF),
    'business': Color(0xFF3F51B5),
    'gift': Color(0xFFE91E63),
    'groceries': Color(0xFF8BC34A),
    'other': Color(0xFF9E9E9E),
    'transfer': Color(0xFF0600AB),
  };

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return BlocBuilder<TransactionCubit, TransactionState>(
      builder: (_, txState) {
        final txns = txState is TransactionLoaded
            ? txState.transactions
            .where((t) => t.month == monthKey && t.type == 'expense')
            .toList()
            : <TransactionEntity>[];

        final catTotals = <String, double>{};
        for (final t in txns) {
          catTotals[t.category] = (catTotals[t.category] ?? 0) + t.amount;
        }
        final sorted = catTotals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final totalSpent = txns.fold<double>(0, (s, t) => s + t.amount);

        // Month label
        final parts   = monthKey.split('-');
        final dt      = DateTime(int.parse(parts[0]), int.parse(parts[1]));
        final mLabel  = DateFormat('MMMM yyyy').format(dt);

        String fmt(double v) =>
            '$symbol${NumberFormat("#,##0.00", "en_US").format(v)}';

        return Container(
          margin: EdgeInsets.fromLTRB(rs.sp(12), 0, rs.sp(12),
              rs.sp(12) + MediaQuery.of(context).padding.bottom),
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.80),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
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

            // Hero gradient band
            Container(
              width: double.infinity,
              margin: EdgeInsets.fromLTRB(rs.sp(20), 0, rs.sp(20), 0),
              padding: EdgeInsets.symmetric(
                  horizontal: rs.sp(20), vertical: rs.sp(18)),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(rs.sp(20)),
                boxShadow: [BoxShadow(
                    color: const Color(0xFFFF6B6B).withOpacity(0.28),
                    blurRadius: 18, offset: const Offset(0, 6))],
              ),
              child: Row(children: [
                Container(
                  width: rs.sp(44), height: rs.sp(44),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.20),
                    borderRadius: BorderRadius.circular(rs.sp(13)),
                    border: Border.all(color: Colors.white.withOpacity(0.30), width: 1.5),
                  ),
                  child: Icon(Icons.insights_rounded,
                      color: Colors.white, size: rs.sp(22)),
                ),
                SizedBox(width: rs.sp(12)),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SPENDING BREAKDOWN', style: TextStyle(
                        color: Colors.white.withOpacity(0.70),
                        fontSize: rs.sp(9), fontWeight: FontWeight.w700,
                        letterSpacing: 1.3)),
                    SizedBox(height: rs.sp(4)),
                    Text(fmt(totalSpent), style: TextStyle(
                        color: Colors.white, fontSize: rs.sp(24),
                        fontWeight: FontWeight.w800, fontFamily: 'Sora',
                        letterSpacing: -1)),
                    Text(mLabel, style: TextStyle(
                        color: Colors.white.withOpacity(0.70),
                        fontSize: rs.sp(11), fontWeight: FontWeight.w500)),
                  ],
                )),
                Text('${sorted.length} categories',
                    style: TextStyle(color: Colors.white.withOpacity(0.75),
                        fontSize: rs.sp(11), fontWeight: FontWeight.w600)),
              ]),
            ),

            // Category list
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                    rs.sp(20), rs.sp(14), rs.sp(20), rs.sp(4)),
                child: sorted.isEmpty
                    ? Padding(
                  padding: EdgeInsets.symmetric(vertical: rs.sp(24)),
                  child: Center(child: Text(
                      'No expenses recorded this month',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
                          fontSize: rs.sp(14)))),
                )
                    : Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(rs.sp(20)),
                  ),
                  child: Column(
                    children: sorted.asMap().entries.map((e) {
                      final cat   = e.value.key;
                      final amt   = e.value.value;
                      final pct   = totalSpent > 0 ? (amt / totalSpent) : 0.0;
                      final color = _catColors[cat] ?? AppColors.textMuted;
                      final icon  = _catIcons[cat]  ?? Icons.category_rounded;
                      final isLast = e.key == sorted.length - 1;
                      return Column(children: [
                        Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: rs.sp(16), vertical: rs.sp(13)),
                          child: Row(children: [
                            Container(
                              width: rs.sp(36), height: rs.sp(36),
                              decoration: BoxDecoration(
                                  color: color.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(rs.sp(11))),
                              child: Icon(icon, color: color, size: rs.sp(18)),
                            ),
                            SizedBox(width: rs.sp(12)),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_cap(cat), style: TextStyle(
                                        fontSize: rs.sp(13),
                                        fontWeight: FontWeight.w700,
                                        color: Theme.of(context).colorScheme.onSurface)),
                                    Text(fmt(amt), style: TextStyle(
                                        fontSize: rs.sp(13),
                                        fontWeight: FontWeight.w800,
                                        color: color,
                                        fontFamily: 'Sora')),
                                  ],
                                ),
                                SizedBox(height: rs.sp(5)),
                                Row(children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(rs.sp(4)),
                                      child: LinearProgressIndicator(
                                        value: pct.clamp(0.0, 1.0),
                                        minHeight: rs.sp(5),
                                        backgroundColor: color.withOpacity(0.12),
                                        valueColor: AlwaysStoppedAnimation<Color>(color),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: rs.sp(8)),
                                  Text('${(pct * 100).toStringAsFixed(0)}%',
                                      style: TextStyle(
                                          fontSize: rs.sp(10),
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textMuted)),
                                ]),
                              ],
                            )),
                          ]),
                        ),
                        if (!isLast) Container(
                            height: 1,
                            color: Colors.white.withOpacity(0.80),
                            margin: EdgeInsets.symmetric(horizontal: rs.sp(16))),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),

            // Close button
            Padding(
              padding: EdgeInsets.fromLTRB(rs.sp(20), rs.sp(8), rs.sp(20), rs.sp(16)),
              child: GestureDetector(
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
            ),
          ]),
        );
      },
    );
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(rs.sp(24)),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Quick Actions', style: TextStyle(
            fontSize: rs.sp(14), fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface, fontFamily: 'Sora')),
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
              color: Theme.of(context).colorScheme.onSurface, fontFamily: 'Sora',
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
// RecentTxnsList — StatefulWidget so we can track the displayed ids
// independently and remove Dismissible widgets *before* the BLoC state
// updates, avoiding the "dismissed widget still in tree" Flutter error.
class RecentTxnsList extends StatefulWidget {
  const RecentTxnsList({super.key});
  @override
  State<RecentTxnsList> createState() => _RecentTxnsListState();
}

class _RecentTxnsListState extends State<RecentTxnsList> {
  // Locally-tracked ids — we remove an id here immediately on swipe,
  // giving Flutter a frame to tear down the Dismissible before the
  // BLoC emits the updated TransactionLoaded (which also drops the id).
  List<String> _visibleIds = [];
  // Last authoritative loaded list — kept so TransactionDeleted frames
  // can still render without going blank (no more flash).
  List<TransactionEntity> _lastLoaded = [];

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return BlocBuilder<TransactionCubit, TransactionState>(
      // Rebuild on every meaningful state change including TransactionDeleted
      // so the list stays in sync with both screens instantly.
      buildWhen: (prev, curr) =>
      curr is TransactionLoaded ||
          curr is TransactionLoading ||
          curr is TransactionInitial,
      builder: (ctx, state) {
        if (state is TransactionLoading) return const TxnShimmerList();

        // ── Single source of truth ──────────────────────────────────
        // cubit always emits TransactionLoaded (with item removed)
        // before TransactionDeleted, so state here is always Loaded
        // when the list needs to render.
        if (state is TransactionLoaded) {
          final fresh = state.transactions.take(6).toList();
          _lastLoaded = fresh;
          // Reset swipe-ahead gate to the authoritative set.
          _visibleIds = fresh.map((t) => t.id).toList();
        }

        // _visibleIds gates only the swipe-ahead frame (item removed
        // before cubit responds). After TransactionLoaded fires the gate
        // matches the authoritative list exactly — zero effect.
        final renderList = _visibleIds.isEmpty
            ? _lastLoaded
            : _lastLoaded.where((t) => _visibleIds.contains(t.id)).toList();

        if (renderList.isEmpty) return const TxnEmptyState();

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(rs.sp(24)),
            boxShadow: [BoxShadow(
                color: AppColors.royalBlue.withOpacity(0.07),
                blurRadius: 28, offset: const Offset(0, 6))],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: renderList.asMap().entries.map((e) => TransactionListItem(
              key:      ValueKey(e.value.id),
              tx:       e.value,
              isLast:   e.key == renderList.length - 1,
              onDelete: () {
                // Remove from local list first (this frame),
                // then call softDelete so BLoC + Firestore update.
                setState(() => _visibleIds.remove(e.value.id));
                ctx.read<TransactionCubit>().softDelete(e.value.id);
              },
              onTap: () => _showDetail(context, e.value),
            )).toList(),
          ),
        );
      },
    );
  }

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
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(rs.sp(24))),
      child: Column(children: List.generate(5, (i) => Padding(
        padding: EdgeInsets.symmetric(
            horizontal: rs.sp(18), vertical: rs.sp(14)),
        child: Row(children: [
          _box(context, rs.sp(46), rs.sp(46), r: rs.sp(14)),
          SizedBox(width: rs.sp(12)),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            _box(context, rs.sp(12), rs.sp(140)),
            SizedBox(height: rs.sp(6)),
            _box(context, rs.sp(10), rs.sp(90)),
          ])),
          _box(context, rs.sp(14), rs.sp(60)),
        ]),
      ))),
    );
  }
  Widget _box(BuildContext context, double h, double w, {double r = 6}) => Container(
      height: h, width: w,
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
          borderRadius: BorderRadius.circular(r)));
}

class TxnEmptyState extends StatelessWidget {
  const TxnEmptyState({super.key});
  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(rs.sp(40)),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(rs.sp(24))),
      child: Column(children: [
        Container(
          width: rs.sp(72), height: rs.sp(72),
          decoration: BoxDecoration(color: AppColors.iconTile,
              borderRadius: BorderRadius.circular(rs.sp(22))),
          child: Icon(Icons.receipt_long_outlined,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45), size: rs.sp(36)),
        ),
        SizedBox(height: rs.sp(16)),
        Text('No transactions yet', style: TextStyle(
            fontSize: rs.sp(16), fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface, fontFamily: 'Sora')),
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

    // TransactionDetailSheet is shown via showModalBottomSheet — a new route
    // outside the MultiBlocProvider tree. BalanceCubit is not accessible there.
    // AppCubit IS accessible (provided at root in app.dart) and holds the symbol.
    final symbol = context.select<AppCubit, String>((c) => c.state.symbol);

    final amtFormatted =
        '$prefix$symbol${NumberFormat("#,##0.00", "en_US").format(tx.amount)}';

    return Container(
      margin: EdgeInsets.fromLTRB(rs.sp(12), 0, rs.sp(12),
          rs.sp(12) + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
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
                color: Theme.of(context).scaffoldBackgroundColor,
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
                      iconColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.55), rs: rs),
                ],
                _DetailDivider(),
                _DetailRow2(
                    label: 'Sync status',
                    value: tx.isSynced ? 'Synced to cloud ✓' : 'Pending sync',
                    icon: tx.isSynced
                        ? Icons.cloud_done_rounded
                        : Icons.cloud_off_rounded,
                    iconColor: tx.isSynced ? AppColors.income : Theme.of(context).colorScheme.onSurface.withOpacity(0.40),
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
              fontSize: rs.sp(10), color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
              fontWeight: FontWeight.w600, letterSpacing: 0.3)),
          SizedBox(height: rs.sp(2)),
          Text(value, style: TextStyle(
              fontSize: rs.sp(13), color: Theme.of(context).colorScheme.onSurface,
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