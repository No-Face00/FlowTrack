// lib/features/transactions/presentation/widgets/transaction_widgets.dart

import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/appRouter.dart';
import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/utils/responsive_helper.dart';

// ══════════════════════════════════════════════════════════════
// SEARCH BAR — backdrop-blur glass on gradient header
// ══════════════════════════════════════════════════════════════
class TxnSearchBar extends StatelessWidget {
  const TxnSearchBar({
    super.key,
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    // The search bar lives on Layer 3 — Positioned ABOVE the scrollable card,
    // always rendered on top of the gradient header background.
    // We therefore always use white-glass styling so it blends with the dark
    // gradient regardless of light/dark theme mode.
    // The TextField fill is forced to Colors.transparent here to prevent
    // Flutter's InputDecorationTheme.fillColor from drawing a visible box.
    return ClipRRect(
      borderRadius: BorderRadius.circular(rs.sp(18)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: rs.sp(16), vertical: rs.sp(11)),
          decoration: BoxDecoration(
            // Slightly more opaque = better readability on the gradient.
            // Still clearly translucent = glassmorphism preserved.
            color:        Colors.white.withOpacity(0.13),
            borderRadius: BorderRadius.circular(rs.sp(18)),
            border: Border.all(
                color: Colors.white.withOpacity(0.22), width: 0.8),
          ),
          child: Row(children: [
            Icon(Icons.search_rounded,
                color: Colors.white.withOpacity(0.65), size: rs.sp(20)),
            SizedBox(width: rs.sp(10)),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                style: TextStyle(
                    fontSize: rs.sp(14),
                    color: Colors.white,
                    fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  isDense:  true,
                  filled:   true,
                  // Force transparent fill — prevents the theme's
                  // InputDecorationTheme.fillColor from showing a solid box
                  fillColor: Colors.transparent,
                  border:         InputBorder.none,
                  enabledBorder:  InputBorder.none,
                  focusedBorder:  InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: 'Search transactions...',
                  hintStyle: TextStyle(
                      fontSize: rs.sp(14),
                      color: Colors.white.withOpacity(0.42),
                      fontWeight: FontWeight.w400),
                ),
              ),
            ),
            if (query.isNotEmpty)
              GestureDetector(
                onTap: onClear,
                child: Container(
                  width: rs.sp(24),
                  height: rs.sp(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close_rounded,
                      size: rs.sp(14),
                      color: Colors.white.withOpacity(0.85)),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// FILTER CHIPS — pill style, gradient active + shadow
// ══════════════════════════════════════════════════════════════
class TxnFilterChips extends StatelessWidget {
  const TxnFilterChips({
    super.key,
    required this.filters,
    required this.active,
    required this.onSelect,
  });
  final List<String> filters;
  final String active;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return SizedBox(
      height: rs.sp(38),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: rs.sp(20)),
        itemCount: filters.length,
        separatorBuilder: (_, __) => SizedBox(width: rs.sp(8)),
        itemBuilder: (_, i) {
          final f = filters[i];
          final isActive = active == f;
          return GestureDetector(
            onTap: () => onSelect(f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(horizontal: rs.sp(18)),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: isActive
                    ? const LinearGradient(
                  colors: [AppColors.royalBlue, AppColors.violet],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
                    : null,
                color: isActive ? null : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(rs.sp(22)),
                border: isActive
                    ? null
                    : Border.all(
                  color: const Color(0xFFE6E4F0),
                  width: 1.5,
                ),
                boxShadow: isActive
                    ? [
                  BoxShadow(
                    color: AppColors.royalBlue.withOpacity(0.32),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
                    : [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.surface,
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                context.tr(f),
                style: TextStyle(
                  fontSize: rs.sp(12.5),
                  fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : Theme.of(context).colorScheme.onSurface,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// DATE LABEL — section header with gradient accent bar + fading rule
// ══════════════════════════════════════════════════════════════
class TxnDateLabel extends StatelessWidget {
  const TxnDateLabel({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: rs.sp(10), top: rs.sp(4)),
      child: Row(
        children: [
          // Gradient accent bar (matches RecentHeader)
          Container(
            width: rs.sp(4),
            height: rs.sp(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.royalBlue, AppColors.violet],
              ),
              borderRadius: BorderRadius.circular(rs.sp(3)),
            ),
          ),
          SizedBox(width: rs.sp(9)),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: rs.sp(10.5),
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              letterSpacing: 1.1,
            ),
          ),
          SizedBox(width: rs.sp(10)),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppColors.textMuted.withOpacity(0.18),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// DATE GROUP CARD — white card with layered shadow
// ══════════════════════════════════════════════════════════════
class TxnDateGroupCard extends StatelessWidget {
  const TxnDateGroupCard({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(rs.sp(22)),
        boxShadow: [
          BoxShadow(
            color: AppColors.royalBlue.withOpacity(0.07),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Theme.of(context).colorScheme.surface,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(rs.sp(22)),
        child: Column(children: children),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// EMPTY STATE — premium illustrated empty screen
// ══════════════════════════════════════════════════════════════
class TxnScreenEmptyState extends StatelessWidget {
  const TxnScreenEmptyState({super.key, required this.filterKey});
  final String filterKey;

  IconData get _icon => switch (filterKey) {
    'filter_income' => Icons.savings_rounded,
    'filter_expense' => Icons.shopping_bag_outlined,
    'filter_transfer' => Icons.swap_horiz_rounded,
    'filter_this_month' => Icons.calendar_month_rounded,
    _ => Icons.receipt_long_rounded,
  };

  String? get _ctaType => switch (filterKey) {
    'filter_income' => 'income',
    'filter_expense' => 'expense',
    'filter_transfer' => 'transfer',
    _ => null,
  };

  String _title(BuildContext c) => switch (filterKey) {
        'filter_income' => c.tr('empty_income_title'),
        'filter_expense' => c.tr('empty_expense_title'),
        'filter_transfer' => c.tr('empty_transfer_title'),
        'filter_this_month' => c.tr('empty_month_title'),
        _ => c.tr('no_transactions_yet'),
      };

  String _subtitle(BuildContext c) => switch (filterKey) {
        'filter_income' => c.tr('empty_income_sub'),
        'filter_expense' => c.tr('empty_expense_sub'),
        'filter_transfer' => c.tr('empty_transfer_sub'),
        'filter_this_month' => c.tr('empty_month_sub'),
        _ => c.tr('empty_all_sub'),
      };

  String? _ctaLabel(BuildContext c) => switch (filterKey) {
        'filter_income' => c.tr('add_income'),
        'filter_expense' => c.tr('add_expense_btn'),
        'filter_transfer' => c.tr('add_transfer_btn'),
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    final cta = _ctaLabel(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: rs.sp(21)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [


          // ── Layered illustration ──────────────────────
          SizedBox(
            width:  rs.sp(160),
            height: rs.sp(160),
            child: Stack(alignment: Alignment.center, children: [

              // Outer soft ring
              Container(
                width:  rs.sp(160),
                height: rs.sp(160),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    AppColors.royalBlue.withOpacity(0.08),
                    AppColors.violet.withOpacity(0.03),
                    Colors.transparent,
                  ]),
                ),
              ),

              // Middle ring
              Container(
                width:  rs.sp(118),
                height: rs.sp(118),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color:      AppColors.royalBlue.withOpacity(0.10),
                      blurRadius: 24,
                      offset:     const Offset(0, 8),
                    ),
                  ],
                ),
              ),

              // Inner gradient tile
              Container(
                width:  rs.sp(82),
                height: rs.sp(82),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.royalBlue, AppColors.violet],
                    begin: Alignment.topLeft,
                    end:   Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(rs.sp(26)),
                  boxShadow: [
                    BoxShadow(
                      color:      AppColors.royalBlue.withOpacity(0.30),
                      blurRadius: 20,
                      offset:     const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  _icon,
                  color: Colors.white,
                  size:  rs.sp(36),
                ),
              ),

              // Floating accent dot — top right
              Positioned(
                top:   rs.sp(18),
                right: rs.sp(18),
                child: Container(
                  width:  rs.sp(14),
                  height: rs.sp(14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.violet.withOpacity(0.25),
                  ),
                ),
              ),

              // Floating accent dot — bottom left
              Positioned(
                bottom: rs.sp(20),
                left:   rs.sp(20),
                child: Container(
                  width:  rs.sp(10),
                  height: rs.sp(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.royalBlue.withOpacity(0.20),
                  ),
                ),
              ),
            ]),
          ),

          SizedBox(height: rs.sp(15)),

          // ── Heading ──────────────────────────────────
          Text(
            _title(context),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize:      rs.sp(20),
              fontWeight:    FontWeight.w800,
              color:         Theme.of(context).colorScheme.onSurface,
              fontFamily:    'Sora',
              letterSpacing: -0.4,
              height:        1.2,
            ),
          ),

          SizedBox(height: rs.sp(7)),

          // ── Subtitle ─────────────────────────────────
          Text(
            _subtitle(context),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize:   rs.sp(13.5),
              color:      Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              fontWeight: FontWeight.w400,
              height:     1.5,
            ),
          ),

          // ── CTA pill — only for Income / Expense / Transfer ─
          if (cta != null) ...[
            SizedBox(height: rs.sp(25)),
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                context.push(AppRoutes.addTransaction, extra: _ctaType);
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: rs.sp(24), vertical: rs.sp(13)),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.royalBlue, AppColors.violet],
                    begin: Alignment.centerLeft,
                    end:   Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(rs.sp(50)),
                  boxShadow: [
                    BoxShadow(
                      color:      AppColors.royalBlue.withOpacity(0.30),
                      blurRadius: 16,
                      offset:     const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width:  rs.sp(22),
                      height: rs.sp(22),
                      decoration: BoxDecoration(
                        color:  Colors.white.withOpacity(0.22),
                        shape:  BoxShape.circle,
                      ),
                      child: Icon(Icons.add_rounded,
                          color: Colors.white, size: rs.sp(14)),
                    ),
                    SizedBox(width: rs.sp(8)),
                    Text(
                      cta,
                      style: TextStyle(
                        fontSize:      rs.sp(13.5),
                        fontWeight:    FontWeight.w700,
                        color:         Colors.white,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: rs.sp(20)),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// FILTER ICON BUTTON (kept for reuse)
// ══════════════════════════════════════════════════════════════
class TxnFilterIconBtn extends StatelessWidget {
  const TxnFilterIconBtn(
      {super.key, required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: rs.sp(40),
        height: rs.sp(40),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(rs.sp(13)),
          boxShadow: [
            BoxShadow(
                color: Theme.of(context).shadowColor.withOpacity(0.06), blurRadius: 10),
          ],
        ),
        child: Icon(icon, size: rs.sp(20), color: Theme.of(context).colorScheme.onSurface),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// CATEGORY MAPS — shared lookup tables (mirrors home_widgets)
// ══════════════════════════════════════════════════════════════
const Map<String, IconData> kTxnCatIcons = {
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

const Map<String, Color> kTxnCatColors = {
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