// lib/features/account/widgets/account_widgets.dart

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive_helper.dart';

// ══════════════════════════════════════════════════════════════
// LAYER 1 — GRADIENT HEADER (fades as content card scrolls over)
// Mirrors HomeHeader / AnalyticsHeader pattern exactly.
// ══════════════════════════════════════════════════════════════
class AccountHeader extends StatelessWidget {
  const AccountHeader({
    super.key,
    required this.name,
    required this.email,
    required this.initial,
    this.bgOpacity    = 1.0,
    this.txnCount     = 0,
    this.monthSpend   = 0.0,
    this.savingsRate  = 0,
    this.symbol       = '৳',
  });

  final String name, email, initial;
  final double bgOpacity;
  final int    txnCount;
  final double monthSpend;
  final int    savingsRate;   // 0-100, clamped; negative income → 0
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final rs      = Rs.of(context);
    final statusH = MediaQuery.of(context).padding.top;

    return Stack(clipBehavior: Clip.none, children: [
      // ── Gradient fill ────────────────────────────────────────
      Positioned.fill(
        child: Opacity(
          opacity: bgOpacity,
          child: const DecoratedBox(
            decoration: BoxDecoration(gradient: AppColors.heroGradient),
          ),
        ),
      ),

      // ── Decorative orbs (same pattern as HomeHeader) ─────────
      Positioned(top: -50, left:  -50, child: Opacity(opacity: bgOpacity, child: _Orb(200, 0.06))),
      Positioned(top:   8, right: -60, child: Opacity(opacity: bgOpacity, child: _Orb(160, 0.05))),
      Positioned(top: 160, right:  20, child: Opacity(opacity: bgOpacity, child: _Orb(90,  0.07))),
      Positioned(top: 200, left:   60, child: Opacity(opacity: bgOpacity, child: _Orb(60,  0.04))),

      // ── Content ───────────────────────────────────────────────
      Opacity(
        opacity: bgOpacity,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            rs.sp(22),
            statusH + rs.sp(10),
            rs.sp(22),
            rs.sp(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page title
              Text(
                'Account',
                style: TextStyle(
                  color:      Colors.white,
                  fontSize:   rs.sp(26),
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Sora',
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: rs.sp(20)),

              // Profile row
              Row(children: [
                // Avatar with gradient border
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Colors.white, AppColors.violet]),
                    borderRadius: BorderRadius.circular(rs.sp(24)),
                  ),
                  child: Container(
                    width:  rs.sp(64),
                    height: rs.sp(64),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(rs.sp(20)),
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: TextStyle(
                          color:      Colors.white,
                          fontSize:   rs.sp(26),
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Sora',
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: rs.sp(16)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color:      Colors.white,
                          fontSize:   rs.sp(20),
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Sora',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (email.isNotEmpty) ...[
                        SizedBox(height: rs.sp(3)),
                        Text(
                          email,
                          style: TextStyle(
                            color:    Colors.white.withOpacity(0.65),
                            fontSize: rs.sp(12),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      SizedBox(height: rs.sp(8)),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: rs.sp(10), vertical: rs.sp(5)),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(rs.sp(12)),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.25), width: 1),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.workspace_premium_rounded,
                              color: const Color(0xFFFFD700), size: rs.sp(12)),
                          SizedBox(width: rs.sp(5)),
                          Text(
                            'Premium Member',
                            style: TextStyle(
                              color:      Colors.white.withOpacity(0.9),
                              fontSize:   rs.sp(11),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ]),
                      ),
                    ],
                  ),
                ),
              ]),
              SizedBox(height: rs.sp(22)),

              // Stats row
              _AccountStatsRow(
                rs:           rs,
                txnCount:     txnCount,
                monthSpend:   monthSpend,
                savingsRate:  savingsRate,
                symbol:       symbol,
              ),
            ],
          ),
        ),
      ),
    ]);
  }
}

class _Orb extends StatelessWidget {
  const _Orb(this.size, this.opacity);
  final double size, opacity;
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withOpacity(opacity),
    ),
  );
}

class _AccountStatsRow extends StatelessWidget {
  const _AccountStatsRow({
    required this.rs,
    required this.txnCount,
    required this.monthSpend,
    required this.savingsRate,
    required this.symbol,
  });
  final Rs     rs;
  final int    txnCount;
  final double monthSpend;
  final int    savingsRate;  // 0-100, already clamped
  final String symbol;

  // Compact formatter: 12500 → '12.5K', 1200000 → '1.2M'
  String _compact(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}K';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _stat('$txnCount',                   'Transactions'),
      _divider(),
      _stat('$symbol${_compact(monthSpend)}', 'This Month'),
      _divider(),
      _stat('$savingsRate%',               'Saved'),
    ]);
  }

  Widget _stat(String val, String label) => Expanded(
    child: Column(children: [
      Text(
        val,
        style: TextStyle(
          color:      Colors.white,
          fontSize:   rs.sp(18),
          fontWeight: FontWeight.w800,
          fontFamily: 'Sora',
        ),
        overflow: TextOverflow.ellipsis,
      ),
      SizedBox(height: rs.sp(3)),
      Text(
        label,
        style: TextStyle(
          color:      Colors.white60,
          fontSize:   rs.sp(11),
          fontWeight: FontWeight.w500,
        ),
      ),
    ]),
  );

  Widget _divider() => Container(
    width: 1, height: 36,
    color: Colors.white.withOpacity(0.2),
  );
}

// ══════════════════════════════════════════════════════════════
// PROFILE HERO  (kept for backward-compat; no longer used by
// AccountScreen after the 3-layer refactor)
// ══════════════════════════════════════════════════════════════
class AccountProfileHero extends StatelessWidget {
  const AccountProfileHero({
    super.key,
    required this.name,
    required this.email,
    required this.initial,
    required this.topPadding,
  });
  final String name, email, initial;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.heroGradient),
      child: Stack(
        children: [
          Positioned(left: -50,  top: -60,    child: _orb(rs.sp(200), 0.06)),
          Positioned(right: -30, top: 20,     child: _orb(rs.sp(120), 0.05)),
          Positioned(left: 140,  bottom: -20, child: _orb(rs.sp(80),  0.07)),

          Padding(
            padding: EdgeInsets.only(
              top:    topPadding + rs.sp(16),
              left:   rs.sp(22),
              right:  rs.sp(22),
              bottom: rs.sp(32),
            ),
            child: Column(
              children: [
                Row(children: [
                  // Avatar with gradient border
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Colors.white, AppColors.violet]),
                      borderRadius: BorderRadius.circular(rs.sp(24)),
                    ),
                    child: Container(
                      width:  rs.sp(72),
                      height: rs.sp(72),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(rs.sp(22)),
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: TextStyle(
                            color:      Colors.white,
                            fontSize:   rs.sp(30),
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Sora',
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: rs.sp(16)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                          style: TextStyle(
                            color:      Colors.white,
                            fontSize:   rs.sp(22),
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Sora',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (email.isNotEmpty) ...[
                          SizedBox(height: rs.sp(3)),
                          Text(email,
                            style: TextStyle(
                              color:    Colors.white.withOpacity(0.65),
                              fontSize: rs.sp(13),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        SizedBox(height: rs.sp(10)),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: rs.sp(10), vertical: rs.sp(5)),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(rs.sp(12)),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.25),
                                width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.workspace_premium_rounded,
                                  color: const Color(0xFFFFD700),
                                  size: rs.sp(13)),
                              SizedBox(width: rs.sp(5)),
                              Text('Premium Member',
                                style: TextStyle(
                                  color:      Colors.white.withOpacity(0.9),
                                  fontSize:   rs.sp(11),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
                SizedBox(height: rs.sp(22)),
                _StatsRow(rs: rs),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _orb(double size, double opacity) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withOpacity(opacity),
    ),
  );
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.rs});
  final Rs rs;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _stat(rs, '12', 'Transactions'),
      _divider(),
      _stat(rs, '3',  'Budgets'),
      _divider(),
      _stat(rs, '2',  'Wallets'),
    ]);
  }

  Widget _stat(Rs rs, String val, String label) => Expanded(
    child: Column(children: [
      Text(val,
          style: TextStyle(
              color:      Colors.white,
              fontSize:   rs.sp(20),
              fontWeight: FontWeight.w800,
              fontFamily: 'Sora')),
      SizedBox(height: rs.sp(3)),
      Text(label,
          style: TextStyle(
              color:      Colors.white60,
              fontSize:   rs.sp(11),
              fontWeight: FontWeight.w500)),
    ]),
  );

  Widget _divider() => Container(
    width: 1, height: 36,
    color: Colors.white.withOpacity(0.2),
  );
}

// ══════════════════════════════════════════════════════════════
// SECTION CONTAINER
// ══════════════════════════════════════════════════════════════
class AccountSection extends StatelessWidget {
  const AccountSection(
      {super.key, required this.title, required this.rows});
  final String       title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: rs.sp(9), left: rs.sp(4)),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize:      rs.sp(11),
              fontWeight:    FontWeight.w700,
              color:         Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              letterSpacing: 1.1,
            ),
          ),
        ),
        Container(
          clipBehavior: Clip.antiAlias,          // ← prevents border bleeding outside radius
          decoration: BoxDecoration(
            color:        Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(rs.sp(22)),
            boxShadow: [
              BoxShadow(
                color:      AppColors.royalBlue.withOpacity(0.06),
                blurRadius: 20,
                offset:     const Offset(0, 4),
              ),
            ],
          ),
          child: Column(children: rows),
        ),
        SizedBox(height: rs.sp(20)),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SETTING ROW
// ══════════════════════════════════════════════════════════════
class AccountSettingRow extends StatelessWidget {
  const AccountSettingRow({
    super.key,
    required this.icon,
    required this.label,
    required this.trailing,
    this.subtitle,
    this.iconColor,
    this.iconBg,
    this.onTap,
    this.isLast = false,
  });
  final IconData      icon;
  final String        label;
  final Widget        trailing;
  final String?       subtitle;
  final Color?        iconColor, iconBg;
  final VoidCallback? onTap;
  final bool          isLast;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    final ic = iconColor ?? AppColors.royalBlue;
    final bg = iconBg ?? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: rs.sp(18), vertical: rs.sp(14)),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
            bottom: BorderSide(
              // Subtle divider — 60% opacity keeps it visible without being harsh
              color: Theme.of(context).dividerColor.withOpacity(0.60),
              width: 0.8,
            ),
          ),
        ),
        child: Row(children: [
          Container(
            width:  rs.sp(40),
            height: rs.sp(40),
            decoration: BoxDecoration(
              color:        bg,
              borderRadius: BorderRadius.circular(rs.sp(13)),
            ),
            child: Icon(icon, size: rs.sp(20), color: ic),
          ),
          SizedBox(width: rs.sp(14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize:   rs.sp(14),
                        fontWeight: FontWeight.w600,
                        color:      Theme.of(context).colorScheme.onSurface)),
                if (subtitle != null) ...[
                  SizedBox(height: rs.sp(2)),
                  Text(subtitle!,
                      style: TextStyle(
                          fontSize: rs.sp(11),
                          color:    Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
                ],
              ],
            ),
          ),
          trailing,
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TRAILING HELPERS
// ══════════════════════════════════════════════════════════════
class AccountChevron extends StatelessWidget {
  const AccountChevron({super.key});
  @override
  Widget build(BuildContext context) => Icon(
    Icons.chevron_right_rounded,
    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
    size:  Rs.of(context).sp(20),
  );
}

class AccountTrailingLabel extends StatelessWidget {
  const AccountTrailingLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color:      AppColors.royalBlue,
      fontSize:   Rs.of(context).sp(13),
      fontWeight: FontWeight.w700,
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// ANIMATED TOGGLE
// ══════════════════════════════════════════════════════════════
class AccountToggle extends StatelessWidget {
  const AccountToggle(
      {super.key, required this.value, required this.onChanged});
  final bool               value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width:  rs.sp(48),
        height: rs.sp(27),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(rs.sp(14)),
          gradient: value
              ? const LinearGradient(
              colors: [AppColors.royalBlue, AppColors.violet])
              : null,
          color: value ? null : Theme.of(context).colorScheme.onSurface.withOpacity(0.20),
        ),
        child: AnimatedAlign(
          duration:  const Duration(milliseconds: 220),
          curve:     Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: EdgeInsets.all(rs.sp(3)),
            width:  rs.sp(21),
            height: rs.sp(21),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color:      Colors.black.withOpacity(0.18),
                  blurRadius: 4,
                  offset:     const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SIGN OUT BUTTON
// ══════════════════════════════════════════════════════════════
class AccountSignOutBtn extends StatelessWidget {
  const AccountSignOutBtn({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: rs.sp(56),
        decoration: BoxDecoration(
          color: AppColors.expense.withOpacity(0.08),
          borderRadius: BorderRadius.circular(rs.sp(18)),
          border: Border.all(
              color: AppColors.expense.withOpacity(0.25), width: 1),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded,
                  color: AppColors.expense, size: rs.sp(20)),
              SizedBox(width: rs.sp(10)),
              Text(
                'Sign Out',
                style: TextStyle(
                  color:      AppColors.expense,
                  fontSize:   rs.sp(15),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}