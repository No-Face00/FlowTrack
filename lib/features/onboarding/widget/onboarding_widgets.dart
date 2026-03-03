import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive_helper.dart';
import '../presentation/onboarding_models.dart';


// ═══════════════════════════════════════════════════════════════
//  SlidePage
// ═══════════════════════════════════════════════════════════════
class SlidePage extends StatelessWidget {
  const SlidePage({
    super.key,
    required this.slide,
    required this.rs,
    required this.emojiScale,
    required this.emojiFade,
    required this.textSlide,
    required this.textFade,
    required this.particleCtrl,
    required this.isActive,
  });

  final OnboardingSlide      slide;
  final Rs                   rs;
  final Animation<double>    emojiScale;
  final Animation<double>    emojiFade;
  final Animation<Offset>    textSlide;
  final Animation<double>    textFade;
  final AnimationController  particleCtrl;
  final bool                 isActive;

  static const _pPos = [
    [0.06, 0.13], [0.78, 0.09], [0.11, 0.51], [0.85, 0.39],
    [0.32, 0.06], [0.66, 0.60], [0.04, 0.70], [0.89, 0.23],
  ];
  static const _pPosL = [
    [0.04, 0.12], [0.88, 0.08], [0.10, 0.65], [0.90, 0.52],
    [0.28, 0.04], [0.72, 0.80], [0.02, 0.82], [0.94, 0.28],
  ];

  @override
  Widget build(BuildContext context) {
    final positions = rs.isLandscape ? _pPosL : _pPos;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: slide.gradientColors,
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Background orbs
          BgOrbs(rs: rs),

          // Floating particles
          if (isActive)
            Stack(
              children: List.generate(
                positions.length,
                    (i) => Positioned(
                  left: rs.pw(positions[i][0]),
                  top:  rs.ph(positions[i][1]),
                  child: ParticleWidget(
                    emoji: slide.particles[i % slide.particles.length],
                    ctrl:  particleCtrl,
                    delay: (i * 0.38) % 2.5,
                    size:  rs.sp(i % 3 == 0 ? 26 : i % 3 == 1 ? 20 : 16),
                  ),
                ),
              ),
            ),

          // Layout: landscape phone → Row, everything else → Column
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: rs.maxContentW),
                child: rs.isLandscape && rs.isPhone
                    ? LandscapeBody(
                  slide: slide, rs: rs,
                  emojiScale: emojiScale, emojiOpacity: emojiFade,
                  textSlide: textSlide, textFade: textFade,
                )
                    : PortraitBody(
                  slide: slide, rs: rs,
                  emojiScale: emojiScale, emojiOpacity: emojiFade,
                  textSlide: textSlide, textFade: textFade,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PortraitBody
// ═══════════════════════════════════════════════════════════════
class PortraitBody extends StatelessWidget {
  const PortraitBody({
    super.key,
    required this.slide,
    required this.rs,
    required this.emojiScale,
    required this.emojiOpacity,
    required this.textSlide,
    required this.textFade,
  });

  final OnboardingSlide   slide;
  final Rs                rs;
  final Animation<double> emojiScale;
  final Animation<double> emojiOpacity;
  final Animation<Offset> textSlide;
  final Animation<double> textFade;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: rs.ph(0.08)),
        EmojiCircle(
          emoji:     slide.emoji,
          diameter:  rs.emojiCircleDiameter,
          scaleAnim: emojiScale,
          fadeAnim:  emojiOpacity,
        ),
        SizedBox(height: rs.ph(0.05)),
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: rs.hPad),
            child: TextBlock(
              slide:     slide,
              rs:        rs,
              textSlide: textSlide,
              textFade:  textFade,
              textAlign: TextAlign.center,
              crossAxis: CrossAxisAlignment.center,
            ),
          ),
        ),
        SizedBox(height: rs.controlsReserve),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  LandscapeBody  (phone rotated — side by side)
// ═══════════════════════════════════════════════════════════════
class LandscapeBody extends StatelessWidget {
  const LandscapeBody({
    super.key,
    required this.slide,
    required this.rs,
    required this.emojiScale,
    required this.emojiOpacity,
    required this.textSlide,
    required this.textFade,
  });

  final OnboardingSlide   slide;
  final Rs                rs;
  final Animation<double> emojiScale;
  final Animation<double> emojiOpacity;
  final Animation<Offset> textSlide;
  final Animation<double> textFade;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left: emoji
        Expanded(
          flex: 4,
          child: Center(
            child: EmojiCircle(
              emoji:     slide.emoji,
              diameter:  rs.emojiCircleDiameter,
              scaleAnim: emojiScale,
              fadeAnim:  emojiOpacity,
            ),
          ),
        ),
        // Right: text
        Expanded(
          flex: 5,
          child: Padding(
            padding: EdgeInsets.only(
              right:  rs.sp(24),
              bottom: rs.controlsReserve * 0.5,
            ),
            child: TextBlock(
              slide:     slide,
              rs:        rs,
              textSlide: textSlide,
              textFade:  textFade,
              textAlign: TextAlign.left,
              crossAxis: CrossAxisAlignment.start,
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  TextBlock
// ═══════════════════════════════════════════════════════════════
class TextBlock extends StatelessWidget {
  const TextBlock({
    super.key,
    required this.slide,
    required this.rs,
    required this.textSlide,
    required this.textFade,
    required this.textAlign,
    required this.crossAxis,
  });

  final OnboardingSlide    slide;
  final Rs                 rs;
  final Animation<Offset>  textSlide;
  final Animation<double>  textFade;
  final TextAlign          textAlign;
  final CrossAxisAlignment crossAxis;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: textFade,
      child: SlideTransition(
        position: textSlide,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: crossAxis,
          children: [
            Text(
              slide.title,
              textAlign: textAlign,
              style: GoogleFonts.sora(
                fontSize:     rs.titleFontSize,
                fontWeight:   FontWeight.w800,
                color:        Colors.white,
                height:       1.15,
                letterSpacing: -1.2,
              ),
            ),
            SizedBox(height: rs.sp(16)),
            Text(
              slide.subtitle,
              textAlign: textAlign,
              style: GoogleFonts.dmSans(
                fontSize:   rs.subtitleFontSize,
                fontWeight: FontWeight.w400,
                color:      Colors.white.withOpacity(0.72),
                height:     1.65,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  EmojiCircle
// ═══════════════════════════════════════════════════════════════
class EmojiCircle extends StatefulWidget {
  const EmojiCircle({
    super.key,
    required this.emoji,
    required this.diameter,
    required this.scaleAnim,
    required this.fadeAnim,
  });

  final String            emoji;
  final double            diameter;
  final Animation<double> scaleAnim;
  final Animation<double> fadeAnim;

  @override
  State<EmojiCircle> createState() => _EmojiCircleState();
}

class _EmojiCircleState extends State<EmojiCircle>
    with SingleTickerProviderStateMixin {
  late final _orbit = AnimationController(
    vsync: this, duration: const Duration(seconds: 7),
  )..repeat();

  @override
  void dispose() {
    _orbit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d    = widget.diameter;
    final ring = d + 44;

    return FadeTransition(
      opacity: widget.fadeAnim,
      child: ScaleTransition(
        scale: widget.scaleAnim,
        child: SizedBox(
          width: ring, height: ring,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer ring
              Container(
                width: ring, height: ring,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.10),
                    width: 1.2,
                  ),
                ),
              ),

              // Orbiting dot
              AnimatedBuilder(
                animation: _orbit,
                builder: (_, __) {
                  final a       = _orbit.value * 2 * math.pi;
                  final r       = ring / 2;
                  final dotSize = math.max(d * 0.062, 8.0);
                  return Transform.translate(
                    offset: Offset(r * math.cos(a), r * math.sin(a)),
                    child: Container(
                      width: dotSize, height: dotSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color:       Colors.white.withOpacity(0.65),
                            blurRadius:  dotSize * 1.5,
                            spreadRadius: dotSize * 0.2,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // Main frosted-glass circle
              Container(
                width: d, height: d,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.11),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.22),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:      Colors.black.withOpacity(0.28),
                      blurRadius: d * 0.25,
                      offset:     Offset(0, d * 0.11),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    widget.emoji,
                    style: TextStyle(fontSize: d * 0.42),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  ParticleWidget
// ═══════════════════════════════════════════════════════════════
class ParticleWidget extends StatelessWidget {
  const ParticleWidget({
    super.key,
    required this.emoji,
    required this.ctrl,
    required this.delay,
    required this.size,
  });

  final String              emoji;
  final AnimationController ctrl;
  final double              delay;
  final double              size;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        final t = ((ctrl.value + delay / 3.0) % 1.0);
        final double opacity = t < 0.15
            ? t / 0.15
            : t > 0.75
            ? 1 - ((t - 0.75) / 0.25)
            : 0.55;
        return Transform.translate(
          offset: Offset(0, -t * 55),
          child: Transform.rotate(
            angle: (t - 0.5) * 0.28,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Text(emoji, style: TextStyle(fontSize: size)),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  BgOrbs
// ═══════════════════════════════════════════════════════════════
class BgOrbs extends StatelessWidget {
  const BgOrbs({super.key, required this.rs});
  final Rs rs;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(top: -rs.sp(70),   left: -rs.sp(50),
            child: _Orb(size: rs.sp(200), opacity: 0.07)),
        Positioned(top: rs.ph(0.32),  right: -rs.sp(40),
            child: _Orb(size: rs.sp(155), opacity: 0.05)),
        Positioned(bottom: rs.sp(90), left: -rs.sp(28),
            child: _Orb(size: rs.sp(115), opacity: 0.06)),
        Positioned(top: rs.ph(0.14),  right: rs.sp(30),
            child: _Orb(size: rs.sp(65),  opacity: 0.09)),
        if (!rs.isPhone)
          Positioned(top: rs.ph(0.55), left: rs.pw(0.38),
              child: _Orb(size: rs.sp(180), opacity: 0.04)),
      ],
    );
  }
}

// Internal — stays private, only used inside this file
class _Orb extends StatelessWidget {
  const _Orb({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withOpacity(opacity),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════
//  SkipBtn
// ═══════════════════════════════════════════════════════════════
class SkipBtn extends StatelessWidget {
  const SkipBtn({super.key, required this.rs, required this.onTap});
  final Rs           rs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: rs.skipHPad,
          vertical:   rs.skipVPad,
        ),
        decoration: BoxDecoration(
          color:        Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(rs.skipRadius),
          border:       Border.all(color: Colors.white.withOpacity(0.22)),
        ),
        child: Text(
          'Skip',
          style: GoogleFonts.dmSans(
            color:      Colors.white.withOpacity(0.88),
            fontSize:   rs.skipFontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  BottomControls
// ═══════════════════════════════════════════════════════════════
class BottomControls extends StatelessWidget {
  const BottomControls({
    super.key,
    required this.rs,
    required this.page,
    required this.total,
    required this.pulse,
    required this.onNext,
  });

  final Rs                rs;
  final int               page;
  final int               total;
  final Animation<double> pulse;
  final VoidCallback      onNext;

  @override
  Widget build(BuildContext context) {
    final isLast = page == total - 1;

    return Container(
      padding: EdgeInsets.fromLTRB(
        rs.hPad,
        rs.sp(18),
        rs.hPad,
        rs.pad.bottom + rs.sp(28),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end:   Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.22),
          ],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: rs.maxContentW),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              // ── Progress dots ──────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(total, (i) {
                  final active = i == page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 380),
                    curve:    Curves.easeInOutCubic,
                    margin:   EdgeInsets.symmetric(horizontal: rs.sp(4)),
                    width:    active ? rs.dotActiveWidth : rs.dotSize,
                    height:   rs.dotSize,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(rs.dotCorner),
                      color: active
                          ? Colors.white
                          : Colors.white.withOpacity(0.30),
                    ),
                  );
                }),
              ),

              SizedBox(height: rs.sp(22)),

              // ── CTA button ─────────────────────
              ScaleTransition(
                scale: isLast ? pulse : const AlwaysStoppedAnimation(1.0),
                child: GestureDetector(
                  onTap: onNext,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 380),
                    width:    double.infinity,
                    padding:  EdgeInsets.symmetric(vertical: rs.buttonVPad),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(rs.buttonRadius),
                      gradient: isLast
                          ? const LinearGradient(
                        begin:  Alignment.topLeft,
                        end:    Alignment.bottomRight,
                        colors: [AppColors.royalBlue, AppColors.violet],
                      )
                          : null,
                      color: isLast ? null : Colors.white.withOpacity(0.14),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.24),
                        width: 1.5,
                      ),
                      boxShadow: isLast
                          ? [
                        BoxShadow(
                          color:      AppColors.royalBlue.withOpacity(0.46),
                          blurRadius: 28,
                          offset:     const Offset(0, 10),
                        ),
                      ]
                          : [],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isLast ? 'Get Started' : 'Continue',
                          style: GoogleFonts.sora(
                            color:        Colors.white,
                            fontSize:     rs.buttonFontSize,
                            fontWeight:   FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                        SizedBox(width: rs.sp(8)),
                        Text(
                          isLast ? '🚀' : '→',
                          style: TextStyle(
                            color:    Colors.white,
                            fontSize: rs.sp(16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}