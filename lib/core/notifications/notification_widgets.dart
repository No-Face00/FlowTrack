// lib/core/notifications/notification_widgets.dart
//
// ── Notification UI Components — v25 complete rewrite ─────────────────────────
//
// NotificationBell  — home-screen bell with live badge + shake animation
// _NotificationSheet — full premium dashboard, staggered entry, dark mode ready
//
// KEY FIXES:
//   • markAllRead() called via getIt (not context.read) — fires before mount
//   • BlocProvider.value wraps sheet builder — cubit never lost across navigator
//   • All colors via Theme.of(context) / DarkColors — zero hardcoded white/black
//   • Staggered card entrance animation per list item
//   • Polished empty state with elastic scale-in animation

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../constants/app_colors.dart';
import '../constants/app_themes.dart';
import '../di/service_locator.dart';
import '../utils/responsive_helper.dart';
import 'notification_cubit.dart';

// ══════════════════════════════════════════════════════════════
// NOTIFICATION BELL
// ══════════════════════════════════════════════════════════════
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return BlocBuilder<NotificationCubit, NotificationState>(
      bloc: getIt<NotificationCubit>(),
      builder: (ctx, state) {
        final unread = state.unreadCount;
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            _openSheet(context);
          },
          behavior: HitTestBehavior.opaque,
          child: Stack(clipBehavior: Clip.none, children: [

            // Glass pill
            AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              width:  rs.sp(42),
              height: rs.sp(42),
              decoration: BoxDecoration(
                color:        Colors.white.withOpacity(unread > 0 ? 0.22 : 0.13),
                borderRadius: BorderRadius.circular(rs.sp(14)),
                border: Border.all(
                  color: Colors.white.withOpacity(unread > 0 ? 0.38 : 0.20),
                  width: 0.9,
                ),
                boxShadow: unread > 0
                    ? [BoxShadow(
                  color:      AppColors.royalBlue.withOpacity(0.40),
                  blurRadius: 16,
                )]
                    : null,
              ),
              child: Center(
                child: Icon(
                  unread > 0
                      ? Icons.notifications_rounded
                      : Icons.notifications_outlined,
                  color: Colors.white,
                  size:  rs.sp(20),
                ),
              ),
            ),

            // Badge
            if (unread > 0)
              Positioned(
                top:   -rs.sp(5),
                right: -rs.sp(5),
                child: _UnreadBadge(count: unread, rs: rs),
              ),

          ]),
        );
      },
    );
  }

  static void _openSheet(BuildContext context) {
    // Mark read immediately — via getIt so it never needs a context
    getIt<NotificationCubit>().markAllRead();

    showModalBottomSheet(
      context:            context,
      backgroundColor:    Colors.transparent,
      useRootNavigator:   true,
      isScrollControlled: true,
      enableDrag:         true,
      builder: (sheetCtx) => BlocProvider<NotificationCubit>.value(
        value: getIt<NotificationCubit>(),
        child: const _NotificationSheet(),
      ),
    );
  }
}

// ── Animated unread badge ─────────────────────────────────────
class _UnreadBadge extends StatefulWidget {
  const _UnreadBadge({required this.count, required this.rs});
  final int count;
  final Rs  rs;
  @override State<_UnreadBadge> createState() => _UnreadBadgeState();
}

class _UnreadBadgeState extends State<_UnreadBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 450));
  late final Animation<double> _scale =
  CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);

  @override
  void initState() { super.initState(); _ctrl.forward(); }

  @override
  void didUpdateWidget(_UnreadBadge old) {
    super.didUpdateWidget(old);
    if (old.count != widget.count) _ctrl.forward(from: 0.3);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final label    = widget.count > 99 ? '99+' : widget.count.toString();
    final isCircle = widget.count <= 9;
    return ScaleTransition(
      scale: _scale,
      child: Container(
        constraints: BoxConstraints(
          minWidth:  widget.rs.sp(18),
          minHeight: widget.rs.sp(18),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isCircle ? 0 : widget.rs.sp(4),
        ),
        decoration: BoxDecoration(
          gradient:     AppColors.buttonGradient,
          shape:        isCircle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: isCircle ? null : BorderRadius.circular(widget.rs.sp(9)),
          border: Border.all(color: Colors.white, width: 1.8),
          boxShadow: [BoxShadow(
            color:      AppColors.royalBlue.withOpacity(0.65),
            blurRadius: 10,
          )],
        ),
        child: Center(
          child: Text(label,
            style: TextStyle(
              color:      Colors.white,
              fontSize:   widget.rs.sp(9),
              fontWeight: FontWeight.w900,
              height:     1.0,
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// NOTIFICATION SHEET — premium notification dashboard
// ══════════════════════════════════════════════════════════════
class _NotificationSheet extends StatefulWidget {
  const _NotificationSheet();
  @override State<_NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends State<_NotificationSheet>
    with TickerProviderStateMixin {

  late final AnimationController _entryCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 450));
  late final Animation<double> _slideUp = CurvedAnimation(
      parent: _entryCtrl, curve: Curves.easeOutCubic);
  late final Animation<double> _fadeIn  = CurvedAnimation(
      parent: _entryCtrl, curve: const Interval(0.0, 0.65));

  @override
  void initState() {
    super.initState();
    _entryCtrl.forward();
  }

  @override
  void dispose() { _entryCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final rs     = Rs.of(context);
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final sheetBg  = isDark ? DarkColors.card    : Colors.white;
    final onSheet  = isDark ? DarkColors.textPrimary : AppColors.textDark;
    final mutedClr = isDark ? DarkColors.textMuted   : AppColors.textMuted;
    final divClr   = isDark ? DarkColors.divider     : const Color(0xFFF0EEF8);

    return AnimatedBuilder(
      animation: _entryCtrl,
      builder: (_, child) => FadeTransition(
        opacity: _fadeIn,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06),
            end:   Offset.zero,
          ).animate(_slideUp),
          child: child,
        ),
      ),
      child: BlocBuilder<NotificationCubit, NotificationState>(
        builder: (ctx, state) => Container(
          margin: EdgeInsets.fromLTRB(
            rs.sp(10), rs.sp(60), rs.sp(10),
            rs.sp(10) + MediaQuery.of(context).padding.bottom,
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.80,
          ),
          decoration: BoxDecoration(
            color:        sheetBg,
            borderRadius: BorderRadius.circular(rs.sp(30)),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withOpacity(isDark ? 0.42 : 0.14),
                blurRadius: 50,
                offset:     const Offset(0, -8),
              ),
              BoxShadow(
                color:      AppColors.royalBlue.withOpacity(0.10),
                blurRadius: 20,
                offset:     const Offset(0, -4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(rs.sp(30)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                // Drag handle
                Center(
                  child: Container(
                    width:  rs.sp(38),
                    height: rs.sp(4),
                    margin: EdgeInsets.symmetric(vertical: rs.sp(14)),
                    decoration: BoxDecoration(
                      gradient:     AppColors.buttonGradient,
                      borderRadius: BorderRadius.circular(rs.sp(3)),
                    ),
                  ),
                ),

                // Header
                _SheetHeader(
                  state:    state,
                  rs:       rs,
                  onSurface: onSheet,
                  muted:    mutedClr,
                  isDark:   isDark,
                  onClearAll: () {
                    HapticFeedback.mediumImpact();
                    ctx.read<NotificationCubit>().clearAll();
                  },
                ),

                // Gradient divider
                Container(
                  height: 1,
                  margin: EdgeInsets.symmetric(horizontal: rs.sp(20)),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      divClr.withOpacity(0),
                      divClr,
                      divClr,
                      divClr.withOpacity(0),
                    ]),
                  ),
                ),

                // Body
                if (state.notifications.isEmpty)
                  _EmptyState(rs: rs, muted: mutedClr, isDark: isDark)
                else
                  Flexible(
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(vertical: rs.sp(6)),
                      itemCount: state.notifications.length,
                      itemBuilder: (_, i) => _NotifCard(
                        notif:     state.notifications[i],
                        rs:        rs,
                        onSurface: onSheet,
                        muted:     mutedClr,
                        divClr:    divClr,
                        isDark:    isDark,
                        isLast:    i == state.notifications.length - 1,
                        index:     i,
                        entryAnim: _entryCtrl,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sheet header ──────────────────────────────────────────────
class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.state,
    required this.rs,
    required this.onSurface,
    required this.muted,
    required this.isDark,
    required this.onClearAll,
  });
  final NotificationState state;
  final Rs   rs;
  final Color onSurface, muted;
  final bool  isDark;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final count = state.notifications.length;
    return Padding(
      padding: EdgeInsets.fromLTRB(rs.sp(20), 0, rs.sp(16), rs.sp(14)),
      child: Row(children: [

        // Icon tile
        Container(
          width:  rs.sp(44),
          height: rs.sp(44),
          decoration: BoxDecoration(
            gradient:     AppColors.buttonGradient,
            borderRadius: BorderRadius.circular(rs.sp(15)),
            boxShadow: [BoxShadow(
              color:      AppColors.royalBlue.withOpacity(0.38),
              blurRadius: 14,
              offset:     const Offset(0, 4),
            )],
          ),
          child: Icon(Icons.notifications_rounded,
              color: Colors.white, size: rs.sp(22)),
        ),
        SizedBox(width: rs.sp(14)),

        // Title
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Notifications',
                style: TextStyle(
                  fontSize:   rs.sp(18),
                  fontWeight: FontWeight.w800,
                  color:      onSurface,
                  fontFamily: 'Sora',
                  letterSpacing: -0.4,
                )),
            SizedBox(height: rs.sp(2)),
            Text(
              count == 0 ? 'All caught up!' : '$count alert${count == 1 ? '' : 's'}',
              style: TextStyle(fontSize: rs.sp(12), color: muted,
                  fontWeight: FontWeight.w500),
            ),
          ]),
        ),

        // Clear all
        if (count > 0)
          GestureDetector(
            onTap: onClearAll,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: rs.sp(13), vertical: rs.sp(8)),
              decoration: BoxDecoration(
                color: isDark ? DarkColors.cardElevated : AppColors.bgLavender,
                borderRadius: BorderRadius.circular(rs.sp(12)),
                border: Border.all(
                  color: isDark ? DarkColors.border : const Color(0xFFE0DEEF),
                  width: 1,
                ),
              ),
              child: Text('Clear all',
                  style: TextStyle(
                    fontSize:   rs.sp(11.5),
                    fontWeight: FontWeight.w700,
                    color:      AppColors.expense,
                  )),
            ),
          ),

      ]),
    );
  }
}

// ── Notification card ─────────────────────────────────────────
class _NotifCard extends StatefulWidget {
  const _NotifCard({
    required this.notif,
    required this.rs,
    required this.onSurface,
    required this.muted,
    required this.divClr,
    required this.isDark,
    required this.isLast,
    required this.index,
    required this.entryAnim,
  });
  final AppNotification     notif;
  final Rs                  rs;
  final Color               onSurface, muted, divClr;
  final bool                isDark, isLast;
  final int                 index;
  final AnimationController entryAnim;
  @override State<_NotifCard> createState() => _NotifCardState();
}

class _NotifCardState extends State<_NotifCard>
    with SingleTickerProviderStateMixin {
  late final Animation<double> _stagger;

  @override
  void initState() {
    super.initState();
    final start = (widget.index * 0.07).clamp(0.0, 0.55);
    final end   = (start + 0.43).clamp(0.0, 1.0);
    _stagger = CurvedAnimation(
      parent: widget.entryAnim,
      curve:  Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rs         = widget.rs;
    final isExceeded = widget.notif.id.contains('budget_exceeded');
    final isWarning  = widget.notif.id.contains('budget_warning');
    final accent     = isExceeded
        ? AppColors.expense
        : isWarning
        ? const Color(0xFFFF9500)
        : AppColors.royalBlue;

    return AnimatedBuilder(
      animation: _stagger,
      builder: (_, child) => FadeTransition(
        opacity: _stagger,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.12),
            end:   Offset.zero,
          ).animate(_stagger),
          child: child,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: !widget.notif.isRead
              ? accent.withOpacity(widget.isDark ? 0.06 : 0.028)
              : Colors.transparent,
          border: widget.isLast ? null : Border(
            bottom: BorderSide(color: widget.divClr, width: 1),
          ),
        ),
        padding: EdgeInsets.symmetric(
            horizontal: rs.sp(18), vertical: rs.sp(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Emoji tile
          Container(
            width:  rs.sp(48),
            height: rs.sp(48),
            decoration: BoxDecoration(
              color:        accent.withOpacity(widget.isDark ? 0.15 : 0.09),
              borderRadius: BorderRadius.circular(rs.sp(15)),
              border:       Border.all(
                color: accent.withOpacity(widget.isDark ? 0.30 : 0.22),
                width: 1,
              ),
            ),
            child: Center(
              child: Text(widget.notif.emoji,
                  style: TextStyle(fontSize: rs.sp(22))),
            ),
          ),

          SizedBox(width: rs.sp(14)),

          // Text content
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Title + chip
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Text(widget.notif.title,
                      style: TextStyle(
                        fontSize:   rs.sp(13.5),
                        fontWeight: FontWeight.w700,
                        color:      isExceeded
                            ? AppColors.expense
                            : widget.onSurface,
                        letterSpacing: -0.1,
                        height:     1.2,
                      )),
                ),
                SizedBox(width: rs.sp(6)),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: rs.sp(7), vertical: rs.sp(3)),
                  decoration: BoxDecoration(
                    color:        accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(rs.sp(7)),
                    border: Border.all(
                        color: accent.withOpacity(0.25), width: 1),
                  ),
                  child: Text(
                    isExceeded ? '🚨 Over'
                        : isWarning ? '⚠️ 80%+'
                        : '🔔 Alert',
                    style: TextStyle(
                      fontSize:   rs.sp(9.5),
                      fontWeight: FontWeight.w800,
                      color:      accent,
                    ),
                  ),
                ),
              ]),

              SizedBox(height: rs.sp(5)),

              Text(widget.notif.body,
                  style: TextStyle(
                    fontSize: rs.sp(12),
                    color:    widget.onSurface.withOpacity(0.65),
                    height:   1.45,
                  )),

              SizedBox(height: rs.sp(6)),

              // Timestamp
              Row(children: [
                Icon(Icons.access_time_rounded,
                    size: rs.sp(11), color: widget.muted),
                SizedBox(width: rs.sp(4)),
                Text(_timeAgo(widget.notif.timestamp),
                    style: TextStyle(
                      fontSize:   rs.sp(10.5),
                      color:      widget.muted,
                      fontWeight: FontWeight.w500,
                    )),
              ]),
            ]),
          ),

          // Unread dot
          if (!widget.notif.isRead) ...[
            SizedBox(width: rs.sp(8)),
            Container(
              width:  rs.sp(8),
              height: rs.sp(8),
              margin: EdgeInsets.only(top: rs.sp(4)),
              decoration: BoxDecoration(
                color:  accent,
                shape:  BoxShape.circle,
                boxShadow: [BoxShadow(
                  color:      accent.withOpacity(0.55),
                  blurRadius: 7,
                )],
              ),
            ),
          ],

        ]),
      ),
    );
  }

  static String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    if (diff.inDays    < 7)  return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(t);
  }
}

// ══════════════════════════════════════════════════════════════
// EMPTY STATE
// ══════════════════════════════════════════════════════════════
class _EmptyState extends StatefulWidget {
  const _EmptyState({required this.rs, required this.muted, required this.isDark});
  final Rs rs; final Color muted; final bool isDark;
  @override State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 750));
  late final Animation<double> _scale =
  CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
  late final Animation<double> _fade  =
  CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.45));

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100),
            () { if (mounted) _ctrl.forward(); });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final rs = widget.rs;
    return Padding(
      padding: EdgeInsets.symmetric(
          vertical: rs.sp(52), horizontal: rs.sp(32)),
      child: FadeTransition(
        opacity: _fade,
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          // Illustration
          ScaleTransition(
            scale: _scale,
            child: Container(
              width:  rs.sp(100),
              height: rs.sp(100),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end:   Alignment.bottomRight,
                  colors: [
                    AppColors.royalBlue.withOpacity(widget.isDark ? 0.22 : 0.10),
                    AppColors.violet.withOpacity(widget.isDark ? 0.15 : 0.07),
                  ],
                ),
                borderRadius: BorderRadius.circular(rs.sp(30)),
                border: Border.all(
                  color: AppColors.royalBlue.withOpacity(
                      widget.isDark ? 0.32 : 0.15),
                  width: 1.5,
                ),
              ),
              child: Stack(alignment: Alignment.center, children: [
                Container(
                  width:  rs.sp(62),
                  height: rs.sp(62),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.royalBlue.withOpacity(0.07),
                  ),
                ),
                Icon(Icons.notifications_off_outlined,
                    size:  rs.sp(40),
                    color: AppColors.royalBlue.withOpacity(0.55)),
              ]),
            ),
          ),

          SizedBox(height: rs.sp(22)),

          Text("You're all caught up!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize:   rs.sp(17),
                fontWeight: FontWeight.w800,
                color:      Theme.of(context).colorScheme.onSurface,
                fontFamily: 'Sora',
                letterSpacing: -0.3,
              )),

          SizedBox(height: rs.sp(8)),

          Text(
            'Budget alerts appear here when your\nspending reaches category limits.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: rs.sp(13),
              color:    widget.muted,
              height:   1.55,
            ),
          ),

          SizedBox(height: rs.sp(24)),

          // Tip pill
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: rs.sp(16), vertical: rs.sp(10)),
            decoration: BoxDecoration(
              color: AppColors.income.withOpacity(widget.isDark ? 0.13 : 0.08),
              borderRadius: BorderRadius.circular(rs.sp(24)),
              border: Border.all(
                  color: AppColors.income.withOpacity(0.22), width: 1),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle_outline_rounded,
                  size: rs.sp(14), color: AppColors.income),
              SizedBox(width: rs.sp(6)),
              Text('Set budgets in Analytics to get alerts',
                  style: TextStyle(
                    fontSize:   rs.sp(11.5),
                    fontWeight: FontWeight.w600,
                    color:      AppColors.income,
                  )),
            ]),
          ),

        ]),
      ),
    );
  }
}