
import 'dart:math' as math;
import 'package:flutter/material.dart';

class Rs {
  Rs.of(this._ctx);
  final BuildContext _ctx;

  // ── Raw measurements ──────────────────────────────────────
  MediaQueryData get _mq    => MediaQuery.of(_ctx);
  Size           get screen => _mq.size;
  EdgeInsets     get pad    => _mq.padding;
  double         get w      => screen.width;
  double         get h      => screen.height;

  // ── Breakpoints ───────────────────────────────────────────
  bool get isPhone   => w < 600;
  bool get isTablet  => w >= 600 && w < 900;
  bool get isDesktop => w >= 900;
  bool get isPortrait  => h > w;
  bool get isLandscape => w > h;

  // ── Scale factor: phone=1.0  tablet=1.22  desktop=1.45 ───
  double get scale => isPhone ? 1.0 : isTablet ? 1.22 : 1.45;

  // ── Core helpers ──────────────────────────────────────────
  /// Scaled font / dp size
  double sp(double v) => v * scale;

  /// Fraction of screen width
  double pw(double pct) => w * pct;

  /// Fraction of screen height
  double ph(double pct) => h * pct;

  // ── Component sizes ───────────────────────────────────────
  double get emojiCircleDiameter {
    if (isDesktop) return math.min(pw(0.14), 260);
    if (isTablet)  return math.min(pw(0.26), 230);
    return isLandscape
        ? math.min(h * 0.48, 155)
        : math.min(pw(0.52), 185);
  }

  double get titleFontSize {
    if (isDesktop) return sp(50);
    if (isTablet)  return sp(44);
    return isLandscape ? sp(30) : sp(38);
  }

  double get subtitleFontSize {
    if (isDesktop) return sp(17);
    if (isTablet)  return sp(16);
    return sp(14);
  }

  double get buttonFontSize => sp(16);
  double get dotSize        => sp(7);
  double get dotActiveWidth => sp(28);
  double get dotCorner      => sp(4);
  double get buttonRadius   => sp(22);
  double get buttonVPad     => sp(17);
  double get skipFontSize   => sp(13);
  double get skipHPad       => sp(16);
  double get skipVPad       => sp(8);
  double get skipRadius     => sp(20);

  /// Max content width — tablets/desktops centre the card
  double get maxContentW => isPhone ? w : isTablet ? 560 : 680;

  /// Horizontal padding for content
  double get hPad => isPhone ? sp(28) : pw(0.08);

  /// Space reserved at bottom for controls overlay
  double get controlsReserve =>
      isPhone && isLandscape ? sp(110) : sp(170);

  /// Total bottom controls height
  double get controlsHeight =>
      pad.bottom + (isPhone && isLandscape ? sp(100) : sp(160));
}