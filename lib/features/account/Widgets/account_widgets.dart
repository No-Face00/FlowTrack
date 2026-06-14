

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/cubit/app_cubit.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/services/profile_image_service.dart'; // NEW
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/responsive_helper.dart';

// ══════════════════════════════════════════════════════════════
// LAYER 1 — GRADIENT HEADER (fades as content card scrolls over)
// ══════════════════════════════════════════════════════════════
class AccountHeader extends StatelessWidget {
  const AccountHeader({
    super.key,
    required this.name,
    required this.email,
    required this.initial,
    this.photoUrl,
    this.bgOpacity   = 1.0,
    this.txnCount    = 0,
    this.monthSpend  = 0.0,
    this.savingsRate = 0,
    this.symbol      = '৳',
  });

  final String  name, email, initial;
  final String? photoUrl;
  final double  bgOpacity;
  final int     txnCount;
  final double  monthSpend;
  final int     savingsRate;
  final String  symbol;

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

      // ── Decorative orbs ───────────────────────────────────────
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
              Text(
                context.tr(S.account),
                style: TextStyle(
                  color:         Colors.white,
                  fontSize:      rs.sp(26),
                  fontWeight:    FontWeight.w800,
                  fontFamily:    'Sora',
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: rs.sp(20)),

              // ── Profile row with live avatar ─────────────────
              Row(children: [
                // CHANGED: wrap avatar in ValueListenableBuilder so it
                // refreshes the instant ProfileImageService broadcasts a
                // new URL after upload.
                // Wrap avatar in ValueListenableBuilder so it refreshes the
                // instant ProfileImageService broadcasts new bytes after a
                // Firestore base64 save — no network round-trip needed.
                ValueListenableBuilder<Uint8List?>(
                  valueListenable: ProfileImageService.instance.bytesNotifier,
                  builder: (_, liveBytes, __) {
                    // If we have in-memory bytes use them; otherwise fall back
                    // to the URL prop (covers the first load from Firestore
                    // before the service has cached the bytes).
                    return _ProfileAvatar(
                      rs:          rs,
                      url:         photoUrl,
                      initial:     initial,
                      cachedBytes: liveBytes,
                    );
                  },
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
                          color:        Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(rs.sp(12)),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.25),
                              width: 1),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.workspace_premium_rounded,
                              color: const Color(0xFFFFD700),
                              size: rs.sp(12)),
                          SizedBox(width: rs.sp(5)),
                          Text(
                            context.tr(S.premiumMember),
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

              _AccountStatsRow(
                rs:          rs,
                txnCount:    txnCount,
                monthSpend:  monthSpend,
                savingsRate: savingsRate,
                symbol:      symbol,
              ),
            ],
          ),
        ),
      ),
    ]);
  }
}

// ──────────────────────────────────────────────────────────────
// PROFILE AVATAR (extracted for clarity + cache-busting support)
// ──────────────────────────────────────────────────────────────
class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.rs,
    required this.initial,
    this.url,
    this.cachedBytes,
  });

  final Rs         rs;
  final String     initial;
  final String?    url;
  final Uint8List? cachedBytes; // base64-decoded bytes from ProfileImageService

  @override
  Widget build(BuildContext context) {
    // Prefer in-memory bytes (instant, no network) over a remote URL.
    final ImageProvider<Object>? imageProvider = cachedBytes != null
        ? MemoryImage(cachedBytes!)
        : (url != null && url!.isNotEmpty)
        ? NetworkImage(url!)
        : null;

    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Colors.white, AppColors.violet]),
        borderRadius: BorderRadius.circular(rs.sp(24)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(rs.sp(20)),
        child: Container(
          width:  rs.sp(64),
          height: rs.sp(64),
          color: Colors.white.withOpacity(0.15),
          child: imageProvider != null
              ? Image(
            image:        imageProvider,
            fit:          BoxFit.cover,
            width:        rs.sp(64),
            height:       rs.sp(64),
            // Keying on cachedBytes identity ensures the widget rebuilds
            // immediately when new bytes arrive from ProfileImageService.
            key:          ValueKey(cachedBytes ?? url),
            errorBuilder: (_, __, ___) =>
                _InitialFallback(rs: rs, initial: initial),
          )
              : _InitialFallback(rs: rs, initial: initial),
        ),
      ),
    );
  }
}

class _InitialFallback extends StatelessWidget {
  const _InitialFallback({required this.rs, required this.initial});
  final Rs rs; final String initial;
  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      initial,
      style: TextStyle(
        color:      Colors.white,
        fontSize:   rs.sp(26),
        fontWeight: FontWeight.w800,
        fontFamily: 'Sora',
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// ORB
// ══════════════════════════════════════════════════════════════
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

// ══════════════════════════════════════════════════════════════
// STATS ROW
// ══════════════════════════════════════════════════════════════
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
  final int    savingsRate;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
      label: context.tr(S.transactions),
      value: context.fmtInt(txnCount),
      icon: Icons.swap_horiz_rounded,
      ),
      (
      label: context.tr(S.filterThisMonth),
      value: '$symbol${context.fmtFull(monthSpend)}',
      icon: Icons.calendar_today_rounded,
      ),
      (
      label: context.tr(S.savingsRate),
      value: '${context.fmtInt(savingsRate)}%',
      icon: Icons.savings_rounded,
      ),
    ];

    return Row(
      children: items.map((item) {
        final isLast = item == items.last;
        return Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(
                vertical: rs.sp(12), horizontal: rs.sp(8)),
            margin: EdgeInsets.only(right: isLast ? 0 : rs.sp(8)),
            decoration: BoxDecoration(
              color:        Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(rs.sp(16)),
              border: Border.all(
                  color: Colors.white.withOpacity(0.18), width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.icon, color: Colors.white70, size: rs.sp(16)),
                SizedBox(height: rs.sp(4)),
                Text(
                  item.value,
                  style: TextStyle(
                    color:      Colors.white,
                    fontSize:   rs.sp(14),
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Sora',
                  ),
                ),
                SizedBox(height: rs.sp(2)),
                Text(
                  item.label,
                  style: TextStyle(
                    color:    Colors.white.withOpacity(0.65),
                    fontSize: rs.sp(11),
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Sora',
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SECTION WRAPPER
// ══════════════════════════════════════════════════════════════
class AccountSection extends StatelessWidget {
  const AccountSection({
    super.key,
    required this.title,
    required this.rows,
  });
  final String       title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
              left: rs.sp(4), bottom: rs.sp(8), top: rs.sp(4)),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize:      rs.sp(11),
              fontWeight:    FontWeight.w700,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withOpacity(0.5),
              letterSpacing: 1.1,
            ),
          ),
        ),
        Container(
          clipBehavior: Clip.antiAlias,
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
    final bg = iconBg ??
        Theme.of(context)
            .colorScheme
            .primaryContainer
            .withOpacity(0.5);

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
              color: Theme.of(context)
                  .dividerColor
                  .withOpacity(0.60),
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
                        color: Theme.of(context).colorScheme.onSurface)),
                if (subtitle != null) ...[
                  SizedBox(height: rs.sp(2)),
                  Text(subtitle!,
                      style: TextStyle(
                          fontSize: rs.sp(11),
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.5))),
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
          color: value
              ? null
              : Theme.of(context)
              .colorScheme
              .onSurface
              .withOpacity(0.20),
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
          color:        AppColors.expense.withOpacity(0.08),
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
                context.tr(S.signOut),
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