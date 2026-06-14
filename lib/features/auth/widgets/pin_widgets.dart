

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive_helper.dart';
import 'pin_layout.dart';

// ══════════════════════════════════════════════════════════════
//  PIN DOTS
// ══════════════════════════════════════════════════════════════
class PinDots extends StatelessWidget {
  const PinDots({
    super.key,
    required this.filled,
    required this.rs,
    this.dark = false,
  });
  final int filled;
  final Rs rs;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: List.generate(
        4,
            (i) => _PinDot(
          key: ValueKey(i),
          filled: i < filled,
          rs: rs,
          dark: dark,
        ),
      ),
    );
  }
}

class _PinDot extends StatefulWidget {
  const _PinDot({
    super.key,
    required this.filled,
    required this.rs,
    this.dark = false,
  });
  final bool filled;
  final Rs rs;
  final bool dark;

  @override
  State<_PinDot> createState() => _PinDotState();
}

class _PinDotState extends State<_PinDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: widget.filled ? 1.0 : 0.0,
    );
    _progress =
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
  }

  @override
  void didUpdateWidget(_PinDot old) {
    super.didUpdateWidget(old);
    if (widget.filled != old.filled) {
      widget.filled ? _ctrl.forward() : _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emptySize = widget.rs.sp(14).clamp(10.0, 18.0);
    final filledSize = widget.rs.sp(16).clamp(12.0, 20.0);

    return AnimatedBuilder(
      animation: _progress,
      builder: (_, __) {
        final t = _progress.value.clamp(0.0, 1.0);
        final size = emptySize + (filledSize - emptySize) * t;
        final emptyColor = widget.dark
            ? Colors.white.withOpacity(0.25)
            : const Color(0xFFCCCCDD);
        final filledColor =
        widget.dark ? Colors.white : AppColors.royalBlue;
        final shadowColor =
        widget.dark ? Colors.white : AppColors.royalBlue;
        final color = Color.lerp(emptyColor, filledColor, t)!;

        return Container(
          margin: EdgeInsets.symmetric(
              horizontal: widget.rs.sp(10).clamp(6.0, 14.0)),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: shadowColor.withOpacity(0.45 * t),
                blurRadius: 10,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  NumPad — LEGACY WRAPPER
//  Kept for backward compatibility. Delegates to AdaptiveNumPad
//  with sizes computed from rs so existing callers still compile.
//  New screens should use PinScaffold which calls AdaptiveNumPad
//  directly with layout-computed sizes.
// ══════════════════════════════════════════════════════════════
class NumPad extends StatelessWidget {
  const NumPad({
    super.key,
    required this.onKey,
    required this.onDelete,
    required this.rs,
    this.dark = false,
  });
  final void Function(String) onKey;
  final VoidCallback onDelete;
  final Rs rs;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final avW = constraints.maxWidth;
      final hPad = avW * 0.06;
      final gap = avW * 0.038;
      final keyW = ((avW - 2 * hPad - 2 * gap) / 3).clamp(64.0, 110.0);
      final keyH = (keyW * 1.13).clamp(56.0, 100.0);
      final rowVPad = 5.0;

      return AdaptiveNumPad(
        onKey: onKey,
        onDelete: onDelete,
        keySize: keyW,
        keyHeight: keyH,
        gap: gap,
        rowVPad: rowVPad,
        hPad: hPad,
        dark: dark,
        rs: rs,
      );
    });
  }
}