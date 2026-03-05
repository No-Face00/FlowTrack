// lib/features/pin/widgets/pin_widgets.dart
//
// Shared by PinSetupScreen and PinLockScreen.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive_helper.dart';

// ══════════════════════════════════════════════════════════════
//  PIN DOTS
//
//  AnimatedContainer's BoxDecoration.lerp crashes when one state
//  has a BoxShadow and the other doesn't — it interpolates blurRadius
//  through negative values mid-animation.
//
//  Fix: replace AnimatedContainer with a StatefulWidget that uses
//  an explicit AnimationController. We manually lerp color/size and
//  scale the shadow opacity via `t` — blurRadius is always a fixed
//  positive value and NEVER gets lerped.
// ══════════════════════════════════════════════════════════════
class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.filled, required this.rs, this.dark = false});
  final int filled;
  final Rs  rs;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize:      MainAxisSize.max,
      children: List.generate(4, (i) => _PinDot(
        key:    ValueKey(i),
        filled: i < filled,
        rs:     rs,
        dark:   dark,
      )),
    );
  }
}

class _PinDot extends StatefulWidget {
  const _PinDot({super.key, required this.filled, required this.rs, this.dark = false});
  final bool filled;
  final Rs   rs;
  final bool dark;
  @override
  State<_PinDot> createState() => _PinDotState();
}

class _PinDotState extends State<_PinDot>
    with SingleTickerProviderStateMixin {

  late AnimationController _ctrl;
  late Animation<double>   _progress;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 200),
      value:    widget.filled ? 1.0 : 0.0,
    );
    _progress = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
  }

  @override
  void didUpdateWidget(_PinDot old) {
    super.didUpdateWidget(old);
    if (widget.filled != old.filled) {
      widget.filled ? _ctrl.forward() : _ctrl.reverse();
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final emptySize  = widget.rs.sp(14);
    final filledSize = widget.rs.sp(16);

    return AnimatedBuilder(
      animation: _progress,
      builder: (_, __) {
        final t    = _progress.value.clamp(0.0, 1.0);
        final size = emptySize + (filledSize - emptySize) * t;
        final emptyColor = widget.dark
            ? Colors.white.withOpacity(0.25)
            : const Color(0xFFCCCCDD);
        final filledColor = widget.dark
            ? Colors.white
            : AppColors.royalBlue;
        final shadowColor = widget.dark
            ? Colors.white
            : AppColors.royalBlue;
        final color = Color.lerp(emptyColor, filledColor, t)!;

        return Container(
          margin: EdgeInsets.symmetric(horizontal: widget.rs.sp(10)),
          width:  size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            // blurRadius is a fixed constant — never interpolated.
            // Only the shadow color opacity scales with t, which is
            // always in [0,1] and never produces a negative value.
            boxShadow: [
              BoxShadow(
                color:      shadowColor.withOpacity(0.45 * t),
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
//  NUMPAD
//
//  ROOT CAUSE OF 99418px OVERFLOW:
//  Previous code used Expanded → Column(mainAxisAlignment: spaceEvenly)
//  which forced the column to fill all remaining space and then
//  spaceEvenly tried to stretch rows infinitely.
//
//  FIX: Column with mainAxisSize.min + fixed vertical padding on
//  each row. No Expanded wrapper around NumPad.
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
  final VoidCallback           onDelete;
  final Rs                     rs;
  final bool                   dark;

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['',  '0', 'del'],
  ];

  static const _sub = {
    '2': 'ABC', '3': 'DEF',
    '4': 'JKL', '5': 'MNO', '6': 'PQRS',
    '7': 'TUV', '8': 'WXYZ',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: rs.sp(24)),
      child: Column(
        mainAxisSize:      MainAxisSize.min,  // KEY: only take needed space
        mainAxisAlignment: MainAxisAlignment.start,
        children: _rows.map((row) => Padding(
          padding: EdgeInsets.symmetric(vertical: rs.sp(6)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((key) {
              if (key.isEmpty)  return SizedBox(width: rs.sp(86));
              if (key == 'del') return _DeleteKey(onDelete: onDelete, rs: rs, dark: dark);
              return _NumKey(
                digit: key,
                sub:   _sub[key] ?? '',
                onTap: () => onKey(key),
                rs:    rs,
                dark:  dark,
              );
            }).toList(),
          ),
        )).toList(),
      ),
    );
  }
}

// ── Number key ───────────────────────────────────────────────────
class _NumKey extends StatefulWidget {
  const _NumKey({
    required this.digit,
    required this.sub,
    required this.onTap,
    required this.rs,
    this.dark = false,
  });
  final String       digit;
  final String       sub;
  final VoidCallback onTap;
  final Rs           rs;
  final bool         dark;

  @override
  State<_NumKey> createState() => _NumKeyState();
}

class _NumKeyState extends State<_NumKey>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 90));
    _scale = Tween(begin: 1.0, end: 0.88).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _onTap() async {
    HapticFeedback.lightImpact();
    await _ctrl.forward();
    await _ctrl.reverse();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final rs = widget.rs;
    return GestureDetector(
      onTap: _onTap,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width:  rs.sp(86),
          height: rs.sp(76),
          decoration: BoxDecoration(
            color: widget.dark
                ? Colors.white.withOpacity(0.12)
                : Colors.white,
            borderRadius: BorderRadius.circular(rs.sp(20)),
            border: widget.dark
                ? Border.all(color: Colors.white.withOpacity(0.15), width: 1)
                : null,
            boxShadow: [
              BoxShadow(
                color: widget.dark
                    ? Colors.black.withOpacity(0.2)
                    : Colors.black.withOpacity(0.06),
                blurRadius: widget.dark ? 16 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.digit,
                style: GoogleFonts.sora(
                  fontSize:   rs.sp(26),
                  fontWeight: FontWeight.w700,
                  color: widget.dark ? Colors.white : const Color(0xFF0A0A2E),
                ),
              ),
              if (widget.sub.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  widget.sub,
                  style: GoogleFonts.dmSans(
                    fontSize:      rs.sp(9),
                    fontWeight:    FontWeight.w600,
                    color: widget.dark
                        ? Colors.white.withOpacity(0.45)
                        : const Color(0xFF7B78A8),
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Delete key ───────────────────────────────────────────────────
class _DeleteKey extends StatelessWidget {
  const _DeleteKey({required this.onDelete, required this.rs, this.dark = false});
  final VoidCallback onDelete;
  final Rs           rs;
  final bool         dark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onDelete();
      },
      child: Container(
        width:  rs.sp(86),
        height: rs.sp(76),
        decoration: BoxDecoration(
          color: dark
              ? Colors.white.withOpacity(0.10)
              : const Color(0xFFE8E6F3),
          borderRadius: BorderRadius.circular(rs.sp(20)),
          border: dark
              ? Border.all(color: Colors.white.withOpacity(0.12), width: 1)
              : null,
        ),
        child: Icon(
          Icons.backspace_outlined,
          color: dark ? Colors.white.withOpacity(0.7) : const Color(0xFF3D3B6E),
          size:  24,
        ),
      ),
    );
  }
}