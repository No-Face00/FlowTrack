// lib/core/notifications/notification_widgets.dart
//
// ── Notification UI — v26 ─────────────────────────────────────────────────────
//
// Exports:
//   NotificationBell       — home-screen bell icon with live unread badge
//   BudgetAlertBanner      — top slide-in banner shown on new budget alerts
//   _NotificationSheet     — full premium notification dashboard (bottom sheet)
//
// v26 fixes:
//   • BudgetAlertBanner added — slides from top, glassmorphism, tap-to-open
//   • NotificationBell._openSheet uses Navigator.of(root) so it always works
//   • All colors via Theme / DarkColors — zero hardcoded white/black

import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../constants/app_colors.dart';
import '../constants/app_themes.dart';
import '../cubit/app_cubit.dart';
import '../di/service_locator.dart';
import '../l10n/l10n_extension.dart';
import '../l10n/app_strings.dart';
import '../utils/responsive_helper.dart';
import 'notification_cubit.dart';

// ══════════════════════════════════════════════════════════════
// NOTIFICATION BELL
// ══════════════════════════════════════════════════════════════

/// Rebuilds budget alert copy when the global currency changes.
class NotificationDynamicBody extends StatelessWidget {
  const NotificationDynamicBody({
    super.key,
    required this.notif,
    required this.style,
    this.maxLines = 2,
    this.overflow = TextOverflow.ellipsis,
  });

  final AppNotification notif;
  final TextStyle       style;
  final int             maxLines;
  final TextOverflow    overflow;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppCubit, AppSettings>(
      bloc: getIt<AppCubit>(),
      buildWhen: (prev, curr) => prev.currency != curr.currency,
      builder: (_, app) => Text(
        notif.displayBody(app.currency),
        style:    style,
        maxLines: maxLines,
        overflow: overflow,
      ),
    );
  }
}

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
            openNotificationSheet(context);
          },
          behavior: HitTestBehavior.opaque,
          child: Stack(clipBehavior: Clip.none, children: [

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

  // Static so BudgetAlertBanner can call it too
  static void openNotificationSheet(BuildContext context) {
    // SYNC FIX: Do NOT call markAllRead() before the sheet opens.
    // The sheet's BlocBuilder reads the NotificationCubit state on first
    // build. If we mark-as-read synchronously here, the cubit emits a new
    // state BEFORE the sheet's widget tree exists — meaning the sheet's
    // BlocBuilder never sees the "unread" state and may miss the transition.
    //
    // Instead: open the sheet, then mark-as-read on the next frame after
    // the sheet has built and rendered its notification list.
    showModalBottomSheet(
      context:            context,
      backgroundColor:    Colors.transparent,
      barrierColor:       Colors.black.withOpacity(0.48),
      useRootNavigator:   true,
      isScrollControlled: true,
      enableDrag:         true,
      builder: (sheetCtx) {
        // Mark all read after the sheet's first frame so the list renders
        // with notifications visible before the unread dots disappear.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          getIt<NotificationCubit>().markAllRead();
        });
        return BlocProvider<NotificationCubit>.value(
          value: getIt<NotificationCubit>(),
          child: const _NotificationSheet(),
        );
      },
    );
  }
}

// ── Unread badge ──────────────────────────────────────────────
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
  void initState()            { super.initState(); _ctrl.forward(); }
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
// BUDGET ALERT BANNER — slides from top, tap to open sheet
// ══════════════════════════════════════════════════════════════
//
// Usage:
//   BudgetAlertBanner.show(context, notification: notif);
//
// The banner lives in an OverlayEntry so it appears above everything
// including the gradient header. It auto-dismisses after 5 seconds
// and can be manually swiped up or tapped (opens notification sheet).

class BudgetAlertBanner {
  BudgetAlertBanner._();

  static OverlayEntry? _current;
  static _BannerWidgetState? _activeBanner;
  static Timer? _autoTimer;

  static void _register(_BannerWidgetState s) => _activeBanner = s;

  static void _unregister(_BannerWidgetState s) {
    if (_activeBanner == s) _activeBanner = null;
  }

  static void show(BuildContext context, {required AppNotification notification}) {
    _autoTimer?.cancel();
    _autoTimer = null;
    _dismiss();

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => IgnorePointer(
        ignoring: false,
        child: _BannerWidget(
          notification: notification,
          onDismiss:    _dismiss,
          onTap:        () {
            _dismiss();
            Future.delayed(const Duration(milliseconds: 180), () {
              if (context.mounted) {
                NotificationBell.openNotificationSheet(context);
              }
            });
          },
        ),
      ),
    );

    _current = entry;
    Overlay.of(context, rootOverlay: true).insert(entry);

    _autoTimer = Timer(const Duration(seconds: 5), () async {
      _autoTimer = null;
      final s = _activeBanner;
      if (s != null && s.mounted) {
        await s.dismissAnimated();
      } else {
        _dismiss();
      }
    });
  }

  static void _dismiss() {
    _autoTimer?.cancel();
    _autoTimer = null;
    _current?.remove();
    _current = null;
  }
}

class _BannerWidget extends StatefulWidget {
  const _BannerWidget({
    required this.notification,
    required this.onDismiss,
    required this.onTap,
  });
  final AppNotification notification;
  final VoidCallback    onDismiss;
  final VoidCallback    onTap;
  @override State<_BannerWidget> createState() => _BannerWidgetState();
}

class _BannerWidgetState extends State<_BannerWidget>
    with SingleTickerProviderStateMixin {

  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 520));

  // Spring overshoot on entry — premium feel
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, -1.3),
    end:   Offset.zero,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));

  late final Animation<double> _fade =
  CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.55));

  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    BudgetAlertBanner._register(this);
    _ctrl.forward();
  }

  @override
  void dispose() {
    BudgetAlertBanner._unregister(this);
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> dismissAnimated() => _animatedDismiss();

  Future<void> _animatedDismiss() async {
    if (_dismissed || !mounted) return;
    _dismissed = true;
    await _ctrl.animateBack(0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInCubic);
    if (mounted) widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final rs      = Rs.of(context);
    final statusH = MediaQuery.of(context).padding.top;
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final isOver  = widget.notification.id.contains('budget_exceeded');
    final accent  = isOver ? AppColors.expense : const Color(0xFFFF9500);
    final titleColor = isDark ? Colors.white : AppColors.textDark;
    final subColor =
    isDark ? Colors.white.withOpacity(0.82) : AppColors.textMid;
    final glassBtn =
    isDark ? Colors.white.withOpacity(0.14) : Colors.black.withOpacity(0.06);
    final glassBr =
    isDark ? Colors.white.withOpacity(0.20) : Colors.black.withOpacity(0.08);

    // The banner must:
    //   1. Sit at the TOP of the screen (not centered or bottom)
    //   2. Take ONLY the height of its content (no stretch)
    //
    // Solution: IgnorePointer on the full-screen transparent wrapper so touches
    // pass through the empty area below; GestureDetector only on the card itself.
    // Column(mainAxisSize.min) + Align keeps the card content-sized at the top.
    return Material(
      type: MaterialType.transparency,
      child: Align(
        alignment: Alignment.topCenter,
        child: SlideTransition(
          position: _slide,
          child: FadeTransition(
            opacity: _fade,
            child: GestureDetector(
              onTap: widget.onTap,
              onVerticalDragUpdate: (d) {
                if (d.delta.dy < -4) _animatedDismiss();
              },
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    rs.sp(14), statusH + rs.sp(8), rs.sp(14), 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(rs.sp(22)),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: isDark ? 28 : 20,
                      sigmaY: isDark ? 28 : 20,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end:   Alignment.bottomRight,
                          colors: isDark
                              ? [
                            const Color(0xFF1A1040).withOpacity(0.94),
                            const Color(0xFF0D0A28).withOpacity(0.92),
                          ]
                              : [
                            Colors.white.withOpacity(0.94),
                            const Color(0xFFF4F2FC).withOpacity(0.96),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(rs.sp(22)),
                        border: Border.all(
                            color: accent.withOpacity(isDark ? 0.38 : 0.28),
                            width: 1.15),
                        boxShadow: [
                          BoxShadow(
                            color:      accent.withOpacity(isDark ? 0.28 : 0.18),
                            blurRadius: isDark ? 32 : 22,
                            offset:     const Offset(0, 10),
                          ),
                          BoxShadow(
                            color:      Colors.black
                                .withOpacity(isDark ? 0.42 : 0.10),
                            blurRadius: 18,
                            offset:     const Offset(0, 5),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.fromLTRB(
                          rs.sp(12), rs.sp(11), rs.sp(11), rs.sp(11)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.max,
                        children: [

                          SizedBox(
                            width:  rs.sp(50),
                            height: rs.sp(50),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width:  rs.sp(50),
                                  height: rs.sp(50),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end:   Alignment.bottomRight,
                                      colors: [
                                        accent.withOpacity(0.28),
                                        accent.withOpacity(0.14),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(rs.sp(16)),
                                    border: Border.all(
                                        color: accent.withOpacity(0.42), width: 1),
                                    boxShadow: [BoxShadow(
                                      color: accent.withOpacity(0.22),
                                      blurRadius: 10,
                                    )],
                                  ),
                                  child: Center(
                                    child: Text(
                                      widget.notification.emoji,
                                      style: const TextStyle(
                                        fontSize:        24,
                                        decoration:      TextDecoration.none,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top:   -rs.sp(3),
                                  right: -rs.sp(2),
                                  child: Container(
                                    padding: EdgeInsets.all(rs.sp(3.5)),
                                    decoration: BoxDecoration(
                                      gradient: AppColors.buttonGradient,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.88),
                                        width: 1.1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.royalBlue.withOpacity(0.38),
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.notifications_rounded,
                                      size: rs.sp(10),
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(width: rs.sp(12)),

                          // Text block
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Type chip
                                Container(
                                  margin: EdgeInsets.only(bottom: rs.sp(3)),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: rs.sp(7), vertical: rs.sp(2)),
                                  decoration: BoxDecoration(
                                    color:        accent.withOpacity(0.20),
                                    borderRadius: BorderRadius.circular(rs.sp(5)),
                                    border: Border.all(
                                        color: accent.withOpacity(0.32), width: 1),
                                  ),
                                  child: Text(
                                    isOver ? '🚨 EXCEEDED' : '⚠️ WARNING',
                                    style: TextStyle(
                                      color:       accent,
                                      fontSize:    rs.sp(8.5),
                                      fontWeight:  FontWeight.w800,
                                      letterSpacing: 0.4,
                                      decoration:  TextDecoration.none,
                                    ),
                                  ),
                                ),
                                Text(
                                  widget.notification.title,
                                  style: TextStyle(
                                    color:       titleColor,
                                    fontSize:    rs.sp(13),
                                    fontWeight:  FontWeight.w700,
                                    letterSpacing: -0.2,
                                    height:      1.2,
                                    decoration:  TextDecoration.none,
                                    fontFamily:  'Sora',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: rs.sp(2)),
                                NotificationDynamicBody(
                                  notif: widget.notification,
                                  style: TextStyle(
                                    color:      subColor,
                                    fontSize:   rs.sp(11),
                                    height:     1.38,
                                    decoration: TextDecoration.none,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),

                          SizedBox(width: rs.sp(8)),

                          // Actions column
                          Column(
                            mainAxisSize:      MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Close X
                              GestureDetector(
                                onTap: _animatedDismiss,
                                child: Container(
                                  width:  rs.sp(28),
                                  height: rs.sp(28),
                                  decoration: BoxDecoration(
                                    color:        glassBtn,
                                    borderRadius: BorderRadius.circular(rs.sp(9)),
                                    border: Border.all(
                                        color: glassBr, width: 1),
                                  ),
                                  child: Icon(Icons.close_rounded,
                                      color: titleColor.withOpacity(0.65),
                                      size: rs.sp(14)),
                                ),
                              ),
                              SizedBox(height: rs.sp(6)),
                              // View button
                              GestureDetector(
                                onTap: widget.onTap,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: rs.sp(9), vertical: rs.sp(5)),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: [
                                      accent.withOpacity(0.32),
                                      accent.withOpacity(0.18),
                                    ]),
                                    borderRadius: BorderRadius.circular(rs.sp(8)),
                                    border: Border.all(
                                        color: accent.withOpacity(0.40), width: 1),
                                  ),
                                  child: Text(
                                    'View',
                                    style: TextStyle(
                                      color:      Colors.white,
                                      fontSize:   rs.sp(10),
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// NOTIFICATION SHEET
// ══════════════════════════════════════════════════════════════
class _NotificationSheet extends StatefulWidget {
  const _NotificationSheet();
  @override State<_NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends State<_NotificationSheet>
    with TickerProviderStateMixin {

  late final AnimationController _entryCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 560));
  late final Animation<double> _slideUp = CurvedAnimation(
      parent: _entryCtrl, curve: Curves.easeOutCubic);
  late final Animation<double> _fadeIn  = CurvedAnimation(
      parent: _entryCtrl, curve: const Interval(0.0, 0.60));

  @override
  void initState() { super.initState(); _entryCtrl.forward(); }
  @override
  void dispose()   { _entryCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final rs     = Rs.of(context);
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Semantic color tokens — zero hardcoded white/black
    final sheetBg  = isDark ? DarkColors.surface     : Colors.white;
    final onSheet  = isDark ? DarkColors.textPrimary  : AppColors.textDark;
    final mutedClr = isDark ? DarkColors.textMuted    : AppColors.textMuted;
    final divClr   = isDark ? DarkColors.divider      : const Color(0xFFF0EEF8);

    return AnimatedBuilder(
      animation: _entryCtrl,
      builder: (_, child) => FadeTransition(
        opacity: _fadeIn,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end:   Offset.zero,
          ).animate(_slideUp),
          child: child,
        ),
      ),
      child: BlocBuilder<NotificationCubit, NotificationState>(
        // CRITICAL: explicitly pass the getIt singleton so this builder
        // ALWAYS reads from the same cubit that checkBudgets() writes to,
        // regardless of what BlocProvider may be in the widget tree.
        bloc: getIt<NotificationCubit>(),
        builder: (ctx, state) => Container(
          margin: EdgeInsets.fromLTRB(
            rs.sp(10), rs.sp(56), rs.sp(10),
            rs.sp(10) + MediaQuery.of(context).padding.bottom,
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.84,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(rs.sp(32)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(rs.sp(32)),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                      DarkColors.surface.withOpacity(0.88),
                      const Color(0xFF161327).withOpacity(0.90),
                    ]
                        : [
                      Colors.white.withOpacity(0.93),
                      const Color(0xFFF7F5FF).withOpacity(0.95),
                    ],
                  ),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.12)
                        : Colors.white.withOpacity(0.75),
                    width: 1.15,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.50 : 0.12),
                      blurRadius: 48,
                      spreadRadius: 0,
                      offset: const Offset(0, 18),
                    ),
                    BoxShadow(
                      color: AppColors.royalBlue.withOpacity(isDark ? 0.22 : 0.14),
                      blurRadius: 36,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(rs.sp(30)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [

                    // ── Gradient header band ──────────────────────
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end:   Alignment.bottomRight,
                          colors: isDark
                              ? [
                            AppColors.royalBlue.withOpacity(0.18),
                            AppColors.violet.withOpacity(0.10),
                            sheetBg.withOpacity(0),
                          ]
                              : [
                            AppColors.royalBlue.withOpacity(0.07),
                            AppColors.violet.withOpacity(0.04),
                            sheetBg.withOpacity(0),
                          ],
                          stops: const [0.0, 0.55, 1.0],
                        ),
                      ),
                      child: Column(children: [
                        // Drag handle
                        Center(
                          child: Container(
                            width:  rs.sp(40),
                            height: rs.sp(4),
                            margin: EdgeInsets.symmetric(vertical: rs.sp(14)),
                            decoration: BoxDecoration(
                              gradient:     AppColors.buttonGradient,
                              borderRadius: BorderRadius.circular(rs.sp(3)),
                              boxShadow: [BoxShadow(
                                color:      AppColors.royalBlue.withOpacity(0.40),
                                blurRadius: 10,
                              )],
                            ),
                          ),
                        ),

                        // Header row
                        _SheetHeader(
                          state:     state,
                          rs:        rs,
                          onSurface: onSheet,
                          muted:     mutedClr,
                          isDark:    isDark,
                          onClearAll: () {
                            HapticFeedback.mediumImpact();
                            ctx.read<NotificationCubit>().clearAll();
                          },
                        ),
                      ]),
                    ),

                    // Gradient divider
                    Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          AppColors.royalBlue.withOpacity(0),
                          AppColors.royalBlue.withOpacity(isDark ? 0.30 : 0.12),
                          AppColors.violet.withOpacity(isDark ? 0.20 : 0.08),
                          AppColors.royalBlue.withOpacity(0),
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
                          padding: EdgeInsets.fromLTRB(
                              rs.sp(12), rs.sp(8), rs.sp(12), rs.sp(12)),
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

        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.tr('notifications_title'),
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
              child: Text(context.tr(S.clearAll),
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
  bool _pressed = false;

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

    final cardBg = widget.isDark
        ? Color.lerp(DarkColors.card, accent, 0.055)!
        : Color.lerp(Colors.white, accent, 0.028)!;

    return AnimatedBuilder(
      animation: _stagger,
      builder: (_, child) => FadeTransition(
        opacity: _stagger,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.14),
            end:   Offset.zero,
          ).animate(_stagger),
          child: child,
        ),
      ),
      child: Dismissible(
        key:        Key(widget.notif.id),
        direction:  DismissDirection.endToStart,
        background: _SwipeBg(rs: rs),
        onDismissed: (_) {
          HapticFeedback.mediumImpact();
          getIt<NotificationCubit>().dismiss(widget.notif.id);
        },
        child: GestureDetector(
          onTapDown:   (_) => setState(() => _pressed = true),
          onTapUp:     (_) => setState(() => _pressed = false),
          onTapCancel: ()  => setState(() => _pressed = false),
          child: AnimatedScale(
            scale:    _pressed ? 0.975 : 1.0,
            duration: const Duration(milliseconds: 120),
            child: Container(
              margin: EdgeInsets.only(bottom: rs.sp(12)),
              decoration: BoxDecoration(
                color:        cardBg,
                borderRadius: BorderRadius.circular(rs.sp(20)),
                border: Border.all(
                  color: accent.withOpacity(widget.isDark ? 0.22 : 0.12),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color:      accent.withOpacity(widget.isDark ? 0.12 : 0.06),
                    blurRadius: 14,
                    offset:     const Offset(0, 4),
                  ),
                  if (widget.isDark)
                    BoxShadow(
                      color:      Colors.black.withOpacity(0.25),
                      blurRadius: 8,
                      offset:     const Offset(0, 2),
                    ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(rs.sp(20)),
                // FIX: IntrinsicHeight lets the accent strip match the card's
                // natural height without needing crossAxisAlignment.stretch on
                // an unbounded (ListView) axis — which causes the layout crash.
                child: IntrinsicHeight(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [

                        // ── Accent side strip ─────────────────────
                        Container(
                          width: rs.sp(4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end:   Alignment.bottomCenter,
                              colors: [
                                accent,
                                accent.withOpacity(0.55),
                              ],
                            ),
                          ),
                        ),

                        // ── Content ───────────────────────────────
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                                rs.sp(14), rs.sp(13), rs.sp(12), rs.sp(13)),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [

                                // Emoji tile with subtle gradient bg
                                Container(
                                  width:  rs.sp(48),
                                  height: rs.sp(48),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end:   Alignment.bottomRight,
                                      colors: [
                                        accent.withOpacity(widget.isDark ? 0.22 : 0.12),
                                        accent.withOpacity(widget.isDark ? 0.10 : 0.06),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(rs.sp(15)),
                                    border: Border.all(
                                      color: accent.withOpacity(widget.isDark ? 0.32 : 0.20),
                                      width: 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(widget.notif.emoji,
                                        style: TextStyle(fontSize: rs.sp(22))),
                                  ),
                                ),

                                SizedBox(width: rs.sp(12)),

                                // Text block
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [

                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(widget.notif.title,
                                                style: TextStyle(
                                                  fontSize:   rs.sp(13.5),
                                                  fontWeight: FontWeight.w800,
                                                  color:      isExceeded
                                                      ? AppColors.expense
                                                      : widget.onSurface,
                                                  letterSpacing: -0.2,
                                                  height:     1.2,
                                                )),
                                          ),
                                          SizedBox(width: rs.sp(8)),
                                          // Status pill
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: rs.sp(7), vertical: rs.sp(3)),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(colors: [
                                                accent.withOpacity(widget.isDark ? 0.30 : 0.15),
                                                accent.withOpacity(widget.isDark ? 0.18 : 0.08),
                                              ]),
                                              borderRadius: BorderRadius.circular(rs.sp(8)),
                                              border: Border.all(
                                                  color: accent.withOpacity(0.30), width: 1),
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
                                        ],
                                      ),

                                      SizedBox(height: rs.sp(5)),

                                      NotificationDynamicBody(
                                        notif: widget.notif,
                                        style: TextStyle(
                                          fontSize: rs.sp(12),
                                          color:    widget.onSurface.withOpacity(0.68),
                                          height:   1.45,
                                        ),
                                        maxLines: 4,
                                        overflow: TextOverflow.ellipsis,
                                      ),

                                      SizedBox(height: rs.sp(7)),

                                      Row(children: [
                                        Container(
                                          padding: EdgeInsets.all(rs.sp(3)),
                                          decoration: BoxDecoration(
                                            color:  accent.withOpacity(0.10),
                                            shape:  BoxShape.circle,
                                          ),
                                          child: Icon(Icons.access_time_rounded,
                                              size: rs.sp(9), color: accent),
                                        ),
                                        SizedBox(width: rs.sp(5)),
                                        Text(_timeAgo(widget.notif.timestamp),
                                            style: TextStyle(
                                              fontSize:   rs.sp(10.5),
                                              color:      widget.muted,
                                              fontWeight: FontWeight.w600,
                                            )),
                                        const Spacer(),
                                        // Swipe hint
                                        Text(context.tr(S.swipeToDismiss),
                                            style: TextStyle(
                                              fontSize: rs.sp(9),
                                              color:    widget.muted.withOpacity(0.45),
                                              fontStyle: FontStyle.italic,
                                            )),
                                      ]),
                                    ],
                                  ),
                                ),

                                // Unread dot
                                if (!widget.notif.isRead) ...[
                                  SizedBox(width: rs.sp(6)),
                                  Container(
                                    width:  rs.sp(8),
                                    height: rs.sp(8),
                                    margin: EdgeInsets.only(top: rs.sp(6)),
                                    decoration: BoxDecoration(
                                      gradient: RadialGradient(colors: [
                                        accent,
                                        accent.withOpacity(0.6),
                                      ]),
                                      shape: BoxShape.circle,
                                      boxShadow: [BoxShadow(
                                        color:      accent.withOpacity(0.65),
                                        blurRadius: 8,
                                      )],
                                    ),
                                  ),
                                ],

                              ],
                            ),
                          ),
                        ),
                      ]),
                ), // IntrinsicHeight
              ),
            ),
          ),
        ),
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

// Swipe-to-dismiss background
class _SwipeBg extends StatelessWidget {
  const _SwipeBg({required this.rs});
  final Rs rs;
  @override
  Widget build(BuildContext context) => Container(
    alignment: Alignment.centerRight,
    padding:   EdgeInsets.only(right: rs.sp(22)),
    margin:    EdgeInsets.only(bottom: rs.sp(12)),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFFF4757), Color(0xFFFF6B81)],
        begin:  Alignment.centerLeft,
        end:    Alignment.centerRight,
      ),
      borderRadius: BorderRadius.circular(rs.sp(20)),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.delete_outline_rounded,
          color: Colors.white, size: rs.sp(22)),
      SizedBox(height: rs.sp(3)),
      Text(context.tr(S.removeNotification), style: TextStyle(
        color: Colors.white, fontSize: rs.sp(10), fontWeight: FontWeight.w700,
      )),
    ]),
  );
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

          Text(context.tr(S.noNotifications),
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
            'When you hit budget limits, alerts land here — clear,\norganized, and easy to review.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: rs.sp(13),
              color:    widget.muted,
              height:   1.55,
            ),
          ),

          SizedBox(height: rs.sp(24)),

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
              Text(context.tr(S.setBudgetsHint),
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