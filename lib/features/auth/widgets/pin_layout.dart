// lib/features/pin/widgets/pin_layout.dart
//
// ══════════════════════════════════════════════════════════════════════
//  PinScaffold — Single responsive layout engine for ALL PIN screens.
//
//  DESIGN CONTRACT
//  ───────────────
//  The screen is split into two zones inside a SafeArea:
//
//    ┌──────────────────────────────────┐  ← SafeArea top
//    │  TOP ZONE  (flex, shrinks first) │  logo/icon/title/subtitle
//    ├──────────────────────────────────┤
//    │  GLASS CARD (intrinsic height)   │  drag handle + dots + numpad
//    └──────────────────────────────────┘  ← SafeArea bottom
//
//  Layout is computed inside a LayoutBuilder so every size is derived
//  from ACTUAL available pixels — no hardcoded heights, no fixed flex.
//
//  KEY RULES
//  ─────────
//  • NumPad button size is clamped to [minKeySize, maxKeySize] and is
//    computed so 3 keys + 2 gaps always fit in (availableWidth - 2*hPad).
//  • Vertical spacing inside the glass card is proportional to
//    available height, clamped to sensible min/max.
//  • SingleChildScrollView wraps the glass card content ONLY when the
//    computed glass card height exceeds 70 % of screen height.
//  • Entrance animations are driven by an external AnimationController
//    so the host screen fully controls timing.
// ══════════════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive_helper.dart';
import 'pin_widgets.dart';

// ─────────────────────────────────────────────────────────────
//  PinScaffold
// ─────────────────────────────────────────────────────────────
class PinScaffold extends StatefulWidget {
  const PinScaffold({
    super.key,
    // Top-zone content — title, subtitle, icon etc.
    required this.topContent,
    // How many dots are filled (0–4)
    required this.pinLength,
    // Shake animation for wrong PIN
    required this.shakeAnimation,
    // Numpad callbacks
    required this.onKey,
    required this.onDelete,
    // Optional extra row below numpad (biometrics, forgot-pin, hint)
    this.bottomExtra,
    // Whether top zone is scrollable (rarely needed)
    this.scrollableTop = false,
  });

  final Widget topContent;
  final int pinLength;
  final Animation<double> shakeAnimation;
  final void Function(String) onKey;
  final VoidCallback onDelete;
  final Widget? bottomExtra;
  final bool scrollableTop;

  @override
  State<PinScaffold> createState() => _PinScaffoldState();
}

class _PinScaffoldState extends State<PinScaffold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _orbCtrl =
  AnimationController(vsync: this, duration: const Duration(seconds: 3))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _orbCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final rs = Rs.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF00023A),
              Color(0xFF0500A0),
              Color(0xFF0033FF),
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // ── Animated orbs ─────────────────────────────
            _OrbLayer(ctrl: _orbCtrl, size: size),

            // ── Main content ──────────────────────────────
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return _PinLayout(
                    constraints: constraints,
                    rs: rs,
                    topContent: widget.topContent,
                    pinLength: widget.pinLength,
                    shakeAnimation: widget.shakeAnimation,
                    onKey: widget.onKey,
                    onDelete: widget.onDelete,
                    bottomExtra: widget.bottomExtra,
                    scrollableTop: widget.scrollableTop,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Internal layout — all sizing derived from LayoutBuilder
// ─────────────────────────────────────────────────────────────
class _PinLayout extends StatelessWidget {
  const _PinLayout({
    required this.constraints,
    required this.rs,
    required this.topContent,
    required this.pinLength,
    required this.shakeAnimation,
    required this.onKey,
    required this.onDelete,
    this.bottomExtra,
    this.scrollableTop = false,
  });

  final BoxConstraints constraints;
  final Rs rs;
  final Widget topContent;
  final int pinLength;
  final Animation<double> shakeAnimation;
  final void Function(String) onKey;
  final VoidCallback onDelete;
  final Widget? bottomExtra;
  final bool scrollableTop;

  // ── Compute adaptive sizes from actual available height ──
  // Available height after SafeArea
  double get _avH => constraints.maxHeight;
  double get _avW => constraints.maxWidth;

  // Horizontal padding for numpad area
  // Larger side padding on wide screens keeps keys from growing too big
  double get _hPad => (_avW * 0.09).clamp(20.0, 56.0);

  // Key size: fit 3 keys + 2 gaps into (avW - 2*hPad)
  // Gap is 4% of avW; key = (remaining) / 3
  double get _gap => (_avW * 0.038).clamp(8.0, 18.0);
  double get _rawKeyW => (_avW - 2 * _hPad - 2 * _gap) / 3;
  // Aspect ratio ~0.95 (more square — comfortable touch targets without eating height)
  double get _keyH => _rawKeyW * 0.95;
  // Clamp so it never overflows on tiny or huge screens
  double get _keySize => _rawKeyW.clamp(56.0, 88.0);
  double get _keyHeight => _keyH.clamp(48.0, 80.0);

  // Row vertical padding — proportional to available height, clamped
  double get _rowVPad => (_avH * 0.008).clamp(4.0, 10.0);

  // Drag handle height
  double get _handleH => 4.0;
  double get _handleW => _avW * 0.09;
  double get _handleTopPad => (_avH * 0.012).clamp(8.0, 18.0);
  double get _handleBotPad => (_avH * 0.016).clamp(10.0, 22.0);

  // Dots row vertical spacing
  double get _dotsTopPad => (_avH * 0.014).clamp(8.0, 20.0);
  double get _dotsBotPad => (_avH * 0.015).clamp(8.0, 22.0);

  // Glass card inner horizontal padding
  double get _cardHPad => _avW * 0.05;
  double get _cardVPad => (_avH * 0.018).clamp(12.0, 24.0);

  // Bottom extra spacing
  double get _extraTopPad => (_avH * 0.012).clamp(6.0, 16.0);
  double get _extraBotPad => (_avH * 0.012).clamp(6.0, 18.0);

  // NumPad: 4 rows, each row has vertical padding above AND below via EdgeInsets.symmetric
  // so total vertical padding = 2 * rowVPad * 4 rows
  double get _numpadH =>
      4 * _keyHeight + 8 * _rowVPad;

  double get _glassCardH =>
      _handleTopPad +
          _handleH +
          _handleBotPad +
          _dotsTopPad +
          rs.sp(16) + // dot size
          _dotsBotPad +
          _numpadH +
          (bottomExtra != null ? _extraTopPad + 48 + _extraBotPad : _extraBotPad);

  // Gap between top content and glass card
  double get _topGap => (_avH * 0.018).clamp(8.0, 24.0);

  // Top zone gets whatever remains after card + gap, minimum 80px
  double get _topZoneH => math.max(_avH - _glassCardH - _topGap, 80);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Top zone ────────────────────────────────────
        SizedBox(
          height: _topZoneH,
          child: ClipRect(
            child: scrollableTop
                ? SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: _topZoneH),
                child: Center(child: topContent),
              ),
            )
                : Center(child: topContent),
          ),
        ),

        // ── Gap between top zone and glass card ─────────
        SizedBox(height: _topGap),

        // ── Glass card ───────────────────────────────────
        _GlassCard(
          cardHPad: _cardHPad,
          cardVPad: _cardVPad,
          handleH: _handleH,
          handleW: _handleW,
          handleTopPad: _handleTopPad,
          handleBotPad: _handleBotPad,
          dotsTopPad: _dotsTopPad,
          dotsBotPad: _dotsBotPad,
          extraTopPad: _extraTopPad,
          extraBotPad: _extraBotPad,
          pinLength: pinLength,
          shakeAnimation: shakeAnimation,
          onKey: onKey,
          onDelete: onDelete,
          bottomExtra: bottomExtra,
          keySize: _keySize,
          keyHeight: _keyHeight,
          gap: _gap,
          rowVPad: _rowVPad,
          hPad: _hPad,
          rs: rs,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Glass card
// ─────────────────────────────────────────────────────────────
class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.cardHPad,
    required this.cardVPad,
    required this.handleH,
    required this.handleW,
    required this.handleTopPad,
    required this.handleBotPad,
    required this.dotsTopPad,
    required this.dotsBotPad,
    required this.extraTopPad,
    required this.extraBotPad,
    required this.pinLength,
    required this.shakeAnimation,
    required this.onKey,
    required this.onDelete,
    required this.bottomExtra,
    required this.keySize,
    required this.keyHeight,
    required this.gap,
    required this.rowVPad,
    required this.hPad,
    required this.rs,
  });

  final double cardHPad, cardVPad;
  final double handleH, handleW, handleTopPad, handleBotPad;
  final double dotsTopPad, dotsBotPad;
  final double extraTopPad, extraBotPad;
  final int pinLength;
  final Animation<double> shakeAnimation;
  final void Function(String) onKey;
  final VoidCallback onDelete;
  final Widget? bottomExtra;
  final double keySize, keyHeight, gap, rowVPad, hPad;
  final Rs rs;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        border: Border.all(color: Colors.white.withOpacity(0.13), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          SizedBox(height: handleTopPad),
          Container(
            width: handleW,
            height: handleH,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: handleBotPad),

          // PIN dots with shake
          SizedBox(height: dotsTopPad),
          AnimatedBuilder(
            animation: shakeAnimation,
            builder: (_, child) => Transform.translate(
              offset: Offset(shakeAnimation.value, 0),
              child: child,
            ),
            child: PinDots(filled: pinLength, rs: rs, dark: true),
          ),
          SizedBox(height: dotsBotPad),

          // Numpad
          AdaptiveNumPad(
            onKey: onKey,
            onDelete: onDelete,
            keySize: keySize,
            keyHeight: keyHeight,
            gap: gap,
            rowVPad: rowVPad,
            hPad: hPad,
            dark: true,
            rs: rs,
          ),

          // Optional bottom extras
          if (bottomExtra != null) ...[
            SizedBox(height: extraTopPad),
            bottomExtra!,
            SizedBox(height: extraBotPad),
          ] else
            SizedBox(height: extraBotPad),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Orb layer (decorative background)
// ─────────────────────────────────────────────────────────────
class _OrbLayer extends StatelessWidget {
  const _OrbLayer({required this.ctrl, required this.size});
  final AnimationController ctrl;
  final Size size;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        final t = ctrl.value;
        return Stack(children: [
          Positioned(
            top: -size.height * 0.05 + t * 18,
            left: -size.width * 0.18,
            child: _Orb(size.width * 0.7, 0.09),
          ),
          Positioned(
            top: size.height * 0.08 + t * -14,
            right: -size.width * 0.22,
            child: _Orb(size.width * 0.55, 0.06),
          ),
          Positioned(
            bottom: size.height * 0.3 + t * 16,
            left: size.width * 0.1,
            child: _Orb(size.width * 0.3, 0.05),
          ),
          Positioned(
            top: size.height * 0.22,
            left: size.width * 0.08,
            child: _StarDot(opacity: 0.4 + t * 0.3),
          ),
          Positioned(
            top: size.height * 0.35,
            right: size.width * 0.12,
            child: _StarDot(opacity: 0.3 + t * 0.4, size: 5),
          ),
        ]);
      },
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb(this.size, this.opacity);
  final double size, opacity;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withOpacity(opacity),
    ),
  );
}

class _StarDot extends StatelessWidget {
  const _StarDot({required this.opacity, this.size = 6});
  final double opacity, size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withOpacity(opacity),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
//  AdaptiveNumPad — sizes driven by explicit parameters,
//  NOT by rs.sp(), so nothing overflows regardless of DPI.
// ─────────────────────────────────────────────────────────────
class AdaptiveNumPad extends StatelessWidget {
  const AdaptiveNumPad({
    super.key,
    required this.onKey,
    required this.onDelete,
    required this.keySize,
    required this.keyHeight,
    required this.gap,
    required this.rowVPad,
    required this.hPad,
    required this.rs,
    this.dark = false,
  });

  final void Function(String) onKey;
  final VoidCallback onDelete;
  final double keySize, keyHeight, gap, rowVPad, hPad;
  final Rs rs;
  final bool dark;

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['', '0', 'del'],
  ];

  static const _sub = {
    '2': 'ABC',
    '3': 'DEF',
    '4': 'JKL',
    '5': 'MNO',
    '6': 'PQRS',
    '7': 'TUV',
    '8': 'WXYZ',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _rows.map((row) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: rowVPad),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: row.map((key) {
                if (key.isEmpty) {
                  return SizedBox(width: keySize, height: keyHeight);
                }
                if (key == 'del') {
                  return _AdaptiveDeleteKey(
                    onDelete: onDelete,
                    w: keySize,
                    h: keyHeight,
                    dark: dark,
                    rs: rs,
                  );
                }
                return _AdaptiveNumKey(
                  digit: key,
                  sub: _sub[key] ?? '',
                  onTap: () => onKey(key),
                  w: keySize,
                  h: keyHeight,
                  dark: dark,
                  rs: rs,
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Adaptive number key ──────────────────────────────────────
class _AdaptiveNumKey extends StatefulWidget {
  const _AdaptiveNumKey({
    required this.digit,
    required this.sub,
    required this.onTap,
    required this.w,
    required this.h,
    required this.rs,
    this.dark = false,
  });
  final String digit, sub;
  final VoidCallback onTap;
  final double w, h;
  final Rs rs;
  final bool dark;

  @override
  State<_AdaptiveNumKey> createState() => _AdaptiveNumKeyState();
}

class _AdaptiveNumKeyState extends State<_AdaptiveNumKey>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 90));
  late final Animation<double> _scale =
  Tween(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    HapticFeedback.lightImpact();
    await _ctrl.forward();
    await _ctrl.reverse();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    // Font sizes proportional to key size, not rs.sp()
    final digitFs = (widget.w * 0.30).clamp(18.0, 28.0);
    final subFs = (widget.w * 0.105).clamp(8.0, 11.0);
    final radius = (widget.w * 0.24).clamp(14.0, 22.0);

    return GestureDetector(
      onTap: _onTap,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: widget.w,
          height: widget.h,
          decoration: BoxDecoration(
            color: widget.dark
                ? Colors.white.withOpacity(0.12)
                : Colors.white,
            borderRadius: BorderRadius.circular(radius),
            border: widget.dark
                ? Border.all(
                color: Colors.white.withOpacity(0.15), width: 1)
                : null,
            boxShadow: [
              BoxShadow(
                color: widget.dark
                    ? Colors.black.withOpacity(0.18)
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
                  fontSize: digitFs,
                  fontWeight: FontWeight.w700,
                  color: widget.dark
                      ? Colors.white
                      : const Color(0xFF0A0A2E),
                ),
              ),
              if (widget.sub.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  widget.sub,
                  style: GoogleFonts.dmSans(
                    fontSize: subFs,
                    fontWeight: FontWeight.w600,
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

// ── Adaptive delete key ──────────────────────────────────────
class _AdaptiveDeleteKey extends StatelessWidget {
  const _AdaptiveDeleteKey({
    required this.onDelete,
    required this.w,
    required this.h,
    required this.rs,
    this.dark = false,
  });
  final VoidCallback onDelete;
  final double w, h;
  final Rs rs;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final iconSize = (w * 0.28).clamp(18.0, 26.0);
    final radius = (w * 0.24).clamp(14.0, 22.0);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onDelete();
      },
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: dark
              ? Colors.white.withOpacity(0.10)
              : const Color(0xFFE8E6F3),
          borderRadius: BorderRadius.circular(radius),
          border: dark
              ? Border.all(
              color: Colors.white.withOpacity(0.12), width: 1)
              : null,
        ),
        child: Icon(
          Icons.backspace_outlined,
          color: dark
              ? Colors.white.withOpacity(0.7)
              : const Color(0xFF3D3B6E),
          size: iconSize,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  PinTopContent — reusable top-zone widget used by all screens
//  Handles: icon, title, subtitle badge, step indicator.
// ─────────────────────────────────────────────────────────────
class PinTopContent extends StatelessWidget {
  const PinTopContent({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.subtitleIcon,
    this.stepIndicator,
    required this.rs,
    // Available height of the top zone so we can scale text down
    required this.topZoneH,
  });

  final Widget icon;
  final String title, subtitle;
  final IconData subtitleIcon;
  final Widget? stepIndicator;
  final Rs rs;
  final double topZoneH;

  @override
  Widget build(BuildContext context) {
    // Scale text if top zone is tight
    final tight = topZoneH < 200;
    final titleFs = tight
        ? (topZoneH * 0.13).clamp(18.0, 28.0)
        : rs.sp(28).clamp(20.0, 32.0);
    final subFs = tight
        ? (topZoneH * 0.065).clamp(11.0, 14.0)
        : rs.sp(12).clamp(11.0, 15.0);
    final iconGap = tight
        ? (topZoneH * 0.06).clamp(8.0, 20.0)
        : rs.sp(20).clamp(10.0, 28.0);
    final stepGap = tight
        ? (topZoneH * 0.05).clamp(6.0, 16.0)
        : rs.sp(16).clamp(8.0, 24.0);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: rs.sp(24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (stepIndicator != null) ...[
            stepIndicator!,
            SizedBox(height: stepGap),
          ],
          icon,
          SizedBox(height: iconGap),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.sora(
              color: Colors.white,
              fontSize: titleFs,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          SizedBox(height: rs.sp(8).clamp(5.0, 12.0)),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: rs.sp(14).clamp(10.0, 18.0),
              vertical: rs.sp(6).clamp(4.0, 8.0),
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border:
              Border.all(color: Colors.white.withOpacity(0.18)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(subtitleIcon,
                    color: Colors.white.withOpacity(0.7),
                    size: subFs + 1),
                SizedBox(width: rs.sp(6).clamp(4.0, 8.0)),
                Flexible(
                  child: Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: subFs,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Glowing icon — shared by lock/setup screens
// ─────────────────────────────────────────────────────────────
class PinGlowIcon extends StatefulWidget {
  const PinGlowIcon({
    super.key,
    required this.icon,
    required this.rs,
    required this.topZoneH,
    this.switchKey,
  });
  final IconData icon;
  final Rs rs;
  final double topZoneH;
  final ValueKey? switchKey;

  @override
  State<PinGlowIcon> createState() => _PinGlowIconState();
}

class _PinGlowIconState extends State<PinGlowIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Icon container size proportional to top zone height
    final iconD =
    (widget.topZoneH * 0.28).clamp(48.0, 80.0);
    final outerD1 = iconD * 1.66;
    final outerD2 = iconD * 1.35;
    final iconFs = (iconD * 0.46).clamp(22.0, 38.0);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        return Stack(alignment: Alignment.center, children: [
          Opacity(
            opacity: 0.06 + t * 0.08,
            child: Container(
              width: outerD1,
              height: outerD1,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
            ),
          ),
          Opacity(
            opacity: 0.10 + t * 0.08,
            child: Container(
              width: outerD2,
              height: outerD2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
                border: Border.all(color: Colors.white, width: 1),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: CurvedAnimation(
                  parent: anim, curve: Curves.elasticOut),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Container(
              key: widget.switchKey,
              width: iconD,
              height: iconD,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.28),
                    Colors.white.withOpacity(0.10),
                  ],
                ),
                border: Border.all(
                    color: Colors.white.withOpacity(0.4), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3366FF).withOpacity(0.6),
                    blurRadius: 32,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Icon(widget.icon,
                  color: Colors.white, size: iconFs),
            ),
          ),
        ]);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Entrance animation helper — wraps any child with a
//  fade + slide driven by an external AnimationController.
// ─────────────────────────────────────────────────────────────
class PinEntrance extends StatelessWidget {
  const PinEntrance({
    super.key,
    required this.controller,
    required this.interval,
    required this.child,
    this.slideStart = 24.0,
  });

  final AnimationController controller;
  final Interval interval;
  final Widget child;
  final double slideStart;

  @override
  Widget build(BuildContext context) {
    final opacity = CurvedAnimation(
      parent: controller,
      curve: Interval(interval.begin, interval.end,
          curve: Curves.easeOut),
    );
    final slide = Tween(begin: slideStart, end: 0.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(interval.begin, interval.end,
            curve: Curves.easeOutCubic),
      ),
    );
    return AnimatedBuilder(
      animation: controller,
      builder: (_, c) => Transform.translate(
        offset: Offset(0, slide.value),
        child: Opacity(opacity: opacity.value, child: c),
      ),
      child: child,
    );
  }
}