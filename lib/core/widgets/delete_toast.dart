// lib/core/widgets/delete_toast.dart
//
// Custom overlay toast that replaces the native SnackBar for delete actions.
//
// WHY NOT SnackBar:
//   Flutter's ScaffoldMessenger always draws a rectangular opaque background
//   behind the SnackBar content regardless of backgroundColor: transparent —
//   causing the "square shadow behind rounded card" visual bug.
//
// HOW THIS WORKS:
//   • Uses an OverlayEntry inserted at the root Navigator level.
//   • A StatefulWidget drives a slide-up entry + slide-down exit via
//     AnimationController + CurvedAnimation.
//   • Auto-dismisses after [duration] (default 3 s).
//   • Swipe-down gesture cancels the timer and triggers exit.
//   • Undo button calls the provided callback and hides immediately.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

// ── Public API ────────────────────────────────────────────────────────────────

/// Shows the delete toast over the current screen.
/// Returns a handle that can be used to hide it programmatically.
DeleteToastHandle showDeleteToast(
    BuildContext context, {
      required VoidCallback onUndo,
      Duration duration = const Duration(milliseconds: 1800),
    }) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  late DeleteToastHandle handle;

  entry = OverlayEntry(
    builder: (_) => _DeleteToastWidget(
      duration:  duration,
      onUndo:    onUndo,
      onDismiss: () => handle.dismiss(),
    ),
  );

  handle = DeleteToastHandle._(entry);
  overlay.insert(entry);
  return handle;
}

/// Opaque handle returned by [showDeleteToast].
class DeleteToastHandle {
  DeleteToastHandle._(this._entry);

  final OverlayEntry _entry;
  bool _dismissed = false;

  /// Removes the toast immediately (the widget itself animates out first).
  void dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    // The widget handles its own exit animation; we remove from the overlay
    // only after it signals back via [onDismiss].
    _entry.remove();
  }
}

// ── Internal widget ───────────────────────────────────────────────────────────

class _DeleteToastWidget extends StatefulWidget {
  const _DeleteToastWidget({
    required this.duration,
    required this.onUndo,
    required this.onDismiss,
  });

  final Duration     duration;
  final VoidCallback onUndo;
  final VoidCallback onDismiss;

  @override
  State<_DeleteToastWidget> createState() => _DeleteToastWidgetState();
}

class _DeleteToastWidgetState extends State<_DeleteToastWidget>
    with SingleTickerProviderStateMixin {

  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 1.6),  // starts below the screen
    end:   Offset.zero,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

  late final Animation<double> _fade = Tween<double>(begin: 0, end: 1)
      .animate(CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(0, 0.45, curve: Curves.easeOut),
  ));

  Timer?  _autoTimer;
  double  _dragOffset = 0;
  bool    _exiting    = false;

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
    _autoTimer = Timer(widget.duration, _exit);
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  // ── Exit: reverse animation then call onDismiss ───────────────────────────
  Future<void> _exit() async {
    if (_exiting) return;
    _exiting = true;
    _autoTimer?.cancel();
    await _ctrl.reverse();
    widget.onDismiss();
  }

  // ── Undo tapped ───────────────────────────────────────────────────────────
  void _handleUndo() {
    HapticFeedback.selectionClick();
    _autoTimer?.cancel();
    widget.onUndo();
    _exit();
  }

  // ── Drag gesture: swipe down to dismiss ───────────────────────────────────
  void _onDragUpdate(DragUpdateDetails d) {
    if (d.delta.dy > 0) {
      setState(() => _dragOffset += d.delta.dy);
    }
  }

  void _onDragEnd(DragEndDetails d) {
    if (_dragOffset > 60 || (d.velocity.pixelsPerSecond.dy > 400)) {
      _exit();
    } else {
      setState(() => _dragOffset = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq      = MediaQuery.of(context);
    final bottomY = mq.padding.bottom + 24.0 - _dragOffset;

    return Positioned(
      left:   16,
      right:  16,
      bottom: bottomY,
      child: Material(
        color:       Colors.transparent,
        child: SlideTransition(
          position: _slide,
          child: FadeTransition(
            opacity: _fade,
            child: GestureDetector(
              onVerticalDragUpdate: _onDragUpdate,
              onVerticalDragEnd:    _onDragEnd,
              child: _ToastCard(
                onUndo: _handleUndo,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Card UI ───────────────────────────────────────────────────────────────────

class _ToastCard extends StatelessWidget {
  const _ToastCard({required this.onUndo});
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF2D2A72)],
          begin: Alignment.centerLeft,
          end:   Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color:      const Color(0xFF1E1B4B).withOpacity(0.50),
            blurRadius: 28,
            spreadRadius: 0,
            offset:     const Offset(0, 10),
          ),
          BoxShadow(
            color:      Colors.black.withOpacity(0.14),
            blurRadius: 10,
            offset:     const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Delete icon tile ──────────────────────────────
          Container(
            width:  38,
            height: 38,
            decoration: BoxDecoration(
              color:        AppColors.expense.withOpacity(0.16),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.expense.withOpacity(0.28), width: 1),
            ),
            child: const Icon(Icons.delete_outline_rounded,
                color: AppColors.expense, size: 19),
          ),

          const SizedBox(width: 12),

          // ── Label ─────────────────────────────────────────
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize:       MainAxisSize.min,
              children: [
                Text(
                  'Transaction Deleted',
                  style: TextStyle(
                    color:       Colors.white,
                    fontSize:    13.5,
                    fontWeight:  FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Swipe down or tap Undo',
                  style: TextStyle(
                    color:      Colors.white54,
                    fontSize:   11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // ── UNDO button ───────────────────────────────────
          GestureDetector(
            onTap: onUndo,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
              decoration: BoxDecoration(
                gradient:     AppColors.buttonGradient,
                borderRadius: BorderRadius.circular(13),
                boxShadow: [
                  BoxShadow(
                    color:      AppColors.royalBlue.withOpacity(0.42),
                    blurRadius: 12,
                    offset:     const Offset(0, 4),
                  ),
                ],
              ),
              child: const Text(
                'UNDO',
                style: TextStyle(
                  color:         Colors.white,
                  fontSize:      12,
                  fontWeight:    FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}