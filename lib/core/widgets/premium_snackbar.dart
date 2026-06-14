

import 'dart:async';
import 'dart:collection';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';

/// Global navigator key — set from [MaterialApp.router].
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

enum SnackType { success, error, warning, info }

class _SnackRequest {
  _SnackRequest({
    required this.message,
    this.subtitle,
    required this.type,
    required this.icon,
    this.duration,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? subtitle;
  final SnackType type;
  final IconData icon;
  final Duration? duration;
  final String? actionLabel;
  final VoidCallback? onAction;
}

/// Public API for app-wide snackbars.
class AppSnack {
  AppSnack._();

  static final _queue = Queue<_SnackRequest>();
  static bool _showing = false;
  static OverlayEntry? _current;

  static void show(
    BuildContext context, {
    required String message,
    String? subtitle,
    SnackType type = SnackType.info,
    IconData? icon,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _enqueue(
      _SnackRequest(
        message: message,
        subtitle: subtitle,
        type: type,
        icon: icon ?? _iconFor(type),
        duration: duration,
        actionLabel: actionLabel,
        onAction: onAction,
      ),
      context,
    );
  }

  static void showGlobal({
    required String message,
    String? subtitle,
    SnackType type = SnackType.info,
    IconData? icon,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final ctx = appNavigatorKey.currentContext;
    if (ctx == null) return;
    show(
      ctx,
      message: message,
      subtitle: subtitle,
      type: type,
      icon: icon,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static IconData _iconFor(SnackType t) => switch (t) {
        SnackType.success => Icons.check_circle_rounded,
        SnackType.error => Icons.error_outline_rounded,
        SnackType.warning => Icons.warning_amber_rounded,
        SnackType.info => Icons.info_outline_rounded,
      };

  static Color _accentFor(SnackType t) => switch (t) {
        SnackType.success => AppColors.income,
        SnackType.error => AppColors.expense,
        SnackType.warning => const Color(0xFFFFB020),
        SnackType.info => AppColors.royalBlue,
      };

  static void _enqueue(_SnackRequest req, BuildContext context) {
    _queue.add(req);
    if (!_showing) _showNext(context);
  }

  static Future<void> _showNext(BuildContext context) async {
    if (_queue.isEmpty) {
      _showing = false;
      return;
    }
    _showing = true;
    final req = _queue.removeFirst();

    final overlay = Overlay.of(context, rootOverlay: true);
    final completer = Completer<void>();

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _PremiumSnackOverlay(
        message: req.message,
        subtitle: req.subtitle,
        icon: req.icon,
        accent: _accentFor(req.type),
        displayDuration:
            req.duration ?? const Duration(milliseconds: 3200),
        actionLabel: req.actionLabel,
        onAction: req.onAction,
        onRemove: () {
          entry.remove();
          _current = null;
          if (!completer.isCompleted) completer.complete();
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
    HapticFeedback.lightImpact();
    await completer.future;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (context.mounted) _showNext(context);
    else _showing = false;
  }

  static void dismissCurrent() {
    _current?.remove();
    _current = null;
    _showing = false;
    _queue.clear();
  }
}

/// Backward-compatible helper.
void showPremiumSnackBar(
  BuildContext context, {
  required String message,
  String? subtitle,
  IconData icon = Icons.notifications_active_rounded,
  bool isError = false,
  Duration displayDuration = const Duration(milliseconds: 2800),
}) {
  AppSnack.show(
    context,
    message: message,
    subtitle: subtitle,
    type: isError ? SnackType.error : SnackType.success,
    icon: icon,
    duration: displayDuration,
  );
}

class _PremiumSnackOverlay extends StatefulWidget {
  const _PremiumSnackOverlay({
    required this.message,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.displayDuration,
    required this.onRemove,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? subtitle;
  final IconData icon;
  final Color accent;
  final Duration displayDuration;
  final VoidCallback onRemove;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  State<_PremiumSnackOverlay> createState() => _PremiumSnackOverlayState();
}

class _PremiumSnackOverlayState extends State<_PremiumSnackOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 440),
    reverseDuration: const Duration(milliseconds: 360),
  );

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, -1.2),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

  late final Animation<double> _fade = CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
  );

  Timer? _timer;
  bool _exiting = false;

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
    _timer = Timer(widget.displayDuration, _exit);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _exit() async {
    if (_exiting || !mounted) return;
    _exiting = true;
    _timer?.cancel();
    await _ctrl.reverse();
    widget.onRemove();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top + 10;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.accent;

    return Positioned(
      left: 14,
      right: 14,
      top: top,
      child: Material(
        color: Colors.transparent,
        child: SlideTransition(
          position: _slide,
          child: FadeTransition(
            opacity: _fade,
            child: GestureDetector(
              onVerticalDragUpdate: (d) {
                if (d.delta.dy < -6) _exit();
              },
              onTap: _exit,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                const Color(0xFF1A1830).withOpacity(0.92),
                                const Color(0xFF0E0C18).withOpacity(0.94),
                              ]
                            : [
                                Colors.white.withOpacity(0.90),
                                const Color(0xFFF4F2FF).withOpacity(0.94),
                              ],
                      ),
                      border: Border.all(
                        color: accent.withOpacity(isDark ? 0.40 : 0.26),
                        width: 1.15,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withOpacity(0.24),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.40 : 0.10),
                          blurRadius: 16,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                accent.withOpacity(0.30),
                                accent.withOpacity(0.10),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: accent.withOpacity(0.35),
                            ),
                          ),
                          child: Icon(widget.icon, color: accent, size: 21),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.message,
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.15,
                                  height: 1.2,
                                ),
                              ),
                              if (widget.subtitle != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  widget.subtitle!,
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.55),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (widget.actionLabel != null &&
                            widget.onAction != null)
                          TextButton(
                            onPressed: () {
                              widget.onAction!();
                              _exit();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: accent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                            child: Text(
                              widget.actionLabel!,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.35),
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
    );
  }
}
