// lib/core/notifications/notification_widgets.dart
//
// ── Notification UI Components ────────────────────────────────────────────────
//
// NotificationBell  — home screen top-right bell with unread badge
// NotificationSheet — bottom sheet listing all notifications

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../constants/app_colors.dart';
import '../di/service_locator.dart';
import '../utils/responsive_helper.dart';
import 'notification_cubit.dart';

// ══════════════════════════════════════════════════════════════
// NOTIFICATION BELL — drop-in for the home header
// ══════════════════════════════════════════════════════════════
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return BlocBuilder<NotificationCubit, NotificationState>(
      builder: (ctx, state) {
        final unread = state.unreadCount;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            _showSheet(context);
          },
          child: Stack(clipBehavior: Clip.none, children: [
            // Glass pill button
            Container(
              width:  rs.sp(40),
              height: rs.sp(40),
              decoration: BoxDecoration(
                color:        Colors.white.withOpacity(0.14),
                borderRadius: BorderRadius.circular(rs.sp(14)),
                border: Border.all(
                    color: Colors.white.withOpacity(0.22), width: 0.8),
              ),
              child: Icon(
                unread > 0
                    ? Icons.notifications_rounded
                    : Icons.notifications_outlined,
                color: Colors.white,
                size:  rs.sp(20),
              ),
            ),

            // Unread badge
            if (unread > 0)
              Positioned(
                top:   -rs.sp(4),
                right: -rs.sp(4),
                child: Container(
                  constraints: BoxConstraints(
                      minWidth:  rs.sp(16), minHeight: rs.sp(16)),
                  padding: EdgeInsets.symmetric(horizontal: rs.sp(4)),
                  decoration: BoxDecoration(
                    gradient:     AppColors.buttonGradient,
                    shape:        unread > 9
                        ? BoxShape.rectangle : BoxShape.circle,
                    borderRadius: unread > 9
                        ? BorderRadius.circular(rs.sp(8)) : null,
                    border: Border.all(
                        color: Colors.white.withOpacity(0.80), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color:      AppColors.royalBlue.withOpacity(0.55),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      unread > 99 ? '99+' : unread.toString(),
                      style: TextStyle(
                        color:      Colors.white,
                        fontSize:   rs.sp(9),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        );
      },
    );
  }

  void _showSheet(BuildContext context) {
    showModalBottomSheet(
      context:            context,
      backgroundColor:    Colors.transparent,
      useRootNavigator:   true,
      isScrollControlled: true,
      // Use getIt singleton directly — avoids losing BlocProvider
      // context when useRootNavigator creates a new route context.
      builder: (_) => BlocProvider<NotificationCubit>.value(
        value: getIt<NotificationCubit>(),
        child: const _NotificationSheet(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// NOTIFICATION SHEET
// ══════════════════════════════════════════════════════════════
class _NotificationSheet extends StatefulWidget {
  const _NotificationSheet();
  @override
  State<_NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends State<_NotificationSheet> {
  @override
  void initState() {
    super.initState();
    // Mark all read when sheet opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationCubit>().markAllRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final rs         = Rs.of(context);
    final surface    = Theme.of(context).colorScheme.surface;
    final onSurface  = Theme.of(context).colorScheme.onSurface;
    final muted      = onSurface.withOpacity(0.45);
    final divColor   = Theme.of(context).dividerColor;

    return BlocBuilder<NotificationCubit, NotificationState>(
      builder: (ctx, state) {
        return Container(
          margin: EdgeInsets.fromLTRB(
            rs.sp(12), 0, rs.sp(12),
            rs.sp(12) + MediaQuery.of(context).padding.bottom,
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.78,
          ),
          decoration: BoxDecoration(
            color:        surface,
            borderRadius: BorderRadius.circular(rs.sp(28)),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withOpacity(0.18),
                blurRadius: 40,
                offset:     const Offset(0, -4),
              ),
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [

            // ── Handle ──────────────────────────────────────
            Center(child: Container(
              width:  rs.sp(36),
              height: rs.sp(4),
              margin: EdgeInsets.symmetric(vertical: rs.sp(14)),
              decoration: BoxDecoration(
                gradient:     AppColors.buttonGradient,
                borderRadius: BorderRadius.circular(2),
              ),
            )),

            // ── Header row ──────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                  rs.sp(22), 0, rs.sp(16), rs.sp(12)),
              child: Row(children: [
                // Icon
                Container(
                  width:  rs.sp(38),
                  height: rs.sp(38),
                  decoration: BoxDecoration(
                    gradient:     AppColors.buttonGradient,
                    borderRadius: BorderRadius.circular(rs.sp(12)),
                  ),
                  child: Icon(Icons.notifications_rounded,
                      color: Colors.white, size: rs.sp(20)),
                ),
                SizedBox(width: rs.sp(12)),
                // Title
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Notifications',
                          style: TextStyle(
                            fontSize:   rs.sp(17),
                            fontWeight: FontWeight.w800,
                            color:      onSurface,
                            fontFamily: 'Sora',
                          )),
                      if (state.notifications.isNotEmpty)
                        Text('${state.notifications.length} alerts',
                            style: TextStyle(
                                fontSize: rs.sp(11), color: muted)),
                    ],
                  ),
                ),
                // Clear all
                if (state.notifications.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ctx.read<NotificationCubit>().clearAll();
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: rs.sp(12), vertical: rs.sp(7)),
                      decoration: BoxDecoration(
                        color:        Theme.of(context)
                            .scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(rs.sp(10)),
                        border:       Border.all(
                            color: divColor, width: 1),
                      ),
                      child: Text('Clear all',
                          style: TextStyle(
                            fontSize:   rs.sp(11),
                            fontWeight: FontWeight.w600,
                            color:      muted,
                          )),
                    ),
                  ),
              ]),
            ),

            Divider(height: 1, color: divColor),

            // ── List ────────────────────────────────────────
            if (state.notifications.isEmpty)
              _EmptyNotifications(rs: rs, muted: muted)
            else
              Flexible(
                child: ListView.separated(
                  padding:    EdgeInsets.symmetric(vertical: rs.sp(8)),
                  itemCount:  state.notifications.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: divColor, indent: rs.sp(72)),
                  itemBuilder: (_, i) => _NotifCard(
                    notif: state.notifications[i],
                    rs:    rs,
                  ),
                ),
              ),

          ]),
        );
      },
    );
  }
}

// ── Individual notification card ─────────────────────────────────────────────
class _NotifCard extends StatelessWidget {
  const _NotifCard({required this.notif, required this.rs});
  final AppNotification notif;
  final Rs              rs;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final muted     = onSurface.withOpacity(0.45);
    final isExceeded = notif.id.contains('budget_exceeded');

    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: rs.sp(16), vertical: rs.sp(12)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Emoji / icon tile
        Container(
          width:  rs.sp(46),
          height: rs.sp(46),
          decoration: BoxDecoration(
            color:        isExceeded
                ? AppColors.expense.withOpacity(0.12)
                : AppColors.royalBlue.withOpacity(0.10),
            borderRadius: BorderRadius.circular(rs.sp(14)),
            border: Border.all(
              color: isExceeded
                  ? AppColors.expense.withOpacity(0.25)
                  : AppColors.royalBlue.withOpacity(0.20),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              notif.emoji,
              style: TextStyle(fontSize: rs.sp(22)),
            ),
          ),
        ),

        SizedBox(width: rs.sp(12)),

        // Text content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row with severity chip
              Row(children: [
                Expanded(
                  child: Text(notif.title,
                      style: TextStyle(
                        fontSize:   rs.sp(13.5),
                        fontWeight: FontWeight.w700,
                        color:      isExceeded
                            ? AppColors.expense
                            : onSurface,
                        letterSpacing: -0.1,
                      )),
                ),
                // Severity chip
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: rs.sp(7), vertical: rs.sp(3)),
                  decoration: BoxDecoration(
                    color:        isExceeded
                        ? AppColors.expense.withOpacity(0.12)
                        : AppColors.royalBlue.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(rs.sp(6)),
                  ),
                  child: Text(
                    isExceeded ? 'Exceeded' : '80%+',
                    style: TextStyle(
                      fontSize:   rs.sp(9),
                      fontWeight: FontWeight.w700,
                      color:      isExceeded
                          ? AppColors.expense
                          : AppColors.royalBlue,
                    ),
                  ),
                ),
              ]),

              SizedBox(height: rs.sp(4)),

              Text(notif.body,
                  style: TextStyle(
                    fontSize:   rs.sp(12),
                    color:      onSurface.withOpacity(0.65),
                    height:     1.4,
                  )),

              SizedBox(height: rs.sp(5)),

              Text(_timeAgo(notif.timestamp),
                  style: TextStyle(
                    fontSize:   rs.sp(10.5),
                    color:      muted,
                    fontWeight: FontWeight.w500,
                  )),
            ],
          ),
        ),
      ]),
    );
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1)  return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    if (diff.inDays    < 7)  return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(t);
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications({required this.rs, required this.muted});
  final Rs    rs;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
          vertical: rs.sp(48), horizontal: rs.sp(24)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width:  rs.sp(72),
          height: rs.sp(72),
          decoration: BoxDecoration(
            color:        Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(rs.sp(22)),
          ),
          child: Icon(Icons.notifications_off_outlined,
              color: muted, size: rs.sp(34)),
        ),
        SizedBox(height: rs.sp(16)),
        Text('No Notifications',
            style: TextStyle(
              fontSize:   rs.sp(16),
              fontWeight: FontWeight.w700,
              color:      Theme.of(context).colorScheme.onSurface,
              fontFamily: 'Sora',
            )),
        SizedBox(height: rs.sp(6)),
        Text('Budget alerts will appear here\nwhen your spending exceeds limits.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: rs.sp(12.5),
              color:    muted,
              height:   1.5,
            )),
      ]),
    );
  }
}