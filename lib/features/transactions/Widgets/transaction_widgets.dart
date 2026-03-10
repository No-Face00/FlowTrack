// lib/features/transactions/presentation/widgets/transaction_widgets.dart

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/responsive_helper.dart';

// ── Search bar (works on dark gradient background) ────────────
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
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: rs.sp(16), vertical: rs.sp(2)),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(rs.sp(18)),
        border: Border.all(
            color: Colors.white.withOpacity(0.25), width: 1),
      ),
      child: Row(children: [
        Icon(Icons.search_rounded, color: Colors.white70, size: rs.sp(20)),
        SizedBox(width: rs.sp(10)),
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            style: TextStyle(
                fontSize: rs.sp(14), color: Colors.white),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'Search transactions...',
              hintStyle: TextStyle(
                  fontSize: rs.sp(14),
                  color: Colors.white54),
            ),
          ),
        ),
        if (query.isNotEmpty)
          GestureDetector(
            onTap: onClear,
            child: Icon(Icons.close_rounded,
                size: rs.sp(18), color: Colors.white60),
          ),
      ]),
    );
  }
}

// ── Filter chips ──────────────────────────────────────────────
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
        padding: EdgeInsets.symmetric(horizontal: rs.sp(18)),
        itemCount: filters.length,
        separatorBuilder: (_, __) => SizedBox(width: rs.sp(8)),
        itemBuilder: (_, i) {
          final f = filters[i];
          final isActive = active == f;
          return GestureDetector(
            onTap: () => onSelect(f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: rs.sp(18)),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: isActive
                    ? const LinearGradient(colors: [
                  AppColors.royalBlue,
                  AppColors.violet,
                ])
                    : null,
                color: isActive ? null : AppColors.bgLavender,
                borderRadius: BorderRadius.circular(rs.sp(22)),
                boxShadow: isActive
                    ? [
                  BoxShadow(
                    color: AppColors.royalBlue.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  )
                ]
                    : null,
              ),
              child: Text(
                f,
                style: TextStyle(
                  fontSize: rs.sp(12),
                  fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : AppColors.textMid,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Date label ────────────────────────────────────────────────
class TxnDateLabel extends StatelessWidget {
  const TxnDateLabel({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: rs.sp(9), top: rs.sp(4)),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: rs.sp(10),
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
          letterSpacing: 0.9,
        ),
      ),
    );
  }
}

// ── Date group card ───────────────────────────────────────────
class TxnDateGroupCard extends StatelessWidget {
  const TxnDateGroupCard({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(rs.sp(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
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

// ── Empty state ───────────────────────────────────────────────
class TxnScreenEmptyState extends StatelessWidget {
  const TxnScreenEmptyState({super.key, required this.filter});
  final String filter;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: rs.sp(80),
            height: rs.sp(80),
            decoration: BoxDecoration(
              color: AppColors.iconTile,
              borderRadius: BorderRadius.circular(rs.sp(24)),
            ),
            child: Icon(Icons.receipt_long_outlined,
                color: AppColors.textMuted, size: rs.sp(40)),
          ),
          SizedBox(height: rs.sp(18)),
          Text(
            filter == 'All'
                ? 'No transactions yet'
                : 'No $filter transactions',
            style: TextStyle(
              fontSize: rs.sp(17),
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
              fontFamily: 'Sora',
            ),
          ),
          SizedBox(height: rs.sp(8)),
          Text(
            'Tap + to add your first transaction',
            style: TextStyle(
                fontSize: rs.sp(13), color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ── Filter icon button ────────────────────────────────────────
class TxnFilterIconBtn extends StatelessWidget {
  const TxnFilterIconBtn({super.key, required this.icon, required this.onTap});
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(rs.sp(13)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 10),
          ],
        ),
        child: Icon(icon, size: rs.sp(20), color: AppColors.textDark),
      ),
    );
  }
}