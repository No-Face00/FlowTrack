// lib/features/pin/presentation/welcome_screen.dart
//
// Shown ONCE after PIN saved. Auto-navigates to /home after 2.8s.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/appRouter.dart';
import '../../../core/utils/responsive_helper.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {

  // Ripple burst
  late AnimationController _rippleCtrl;
  // Check mark
  late AnimationController _checkCtrl;
  late Animation<double>   _checkScale;
  late Animation<double>   _checkOpacity;
  // Text reveal
  late AnimationController _textCtrl;
  late Animation<double>   _textOpacity;
  late Animation<double>   _textSlide;
  // Confetti particles
  late AnimationController _confettiCtrl;
  // Floating orb pulse
  late AnimationController _orbCtrl;
  // Stats cards slide-in
  late AnimationController _cardsCtrl;

  final List<_Particle> _particles = [];

  @override
  void initState() {
    super.initState();

    // Generate confetti particles
    final rng = math.Random(42);
    for (int i = 0; i < 18; i++) {
      _particles.add(_Particle(
        x:     rng.nextDouble(),
        delay: rng.nextDouble() * 0.4,
        size:  4 + rng.nextDouble() * 6,
        color: _confettiColors[i % _confettiColors.length],
        angle: rng.nextDouble() * math.pi * 2,
        speed: 0.6 + rng.nextDouble() * 0.4,
      ));
    }

    _rippleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..forward();

    _checkCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _checkScale = CurvedAnimation(
        parent: _checkCtrl, curve: Curves.elasticOut);
    _checkOpacity = CurvedAnimation(
        parent: _checkCtrl,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn));

    _textCtrl    = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 520));
    _textOpacity = CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut);
    _textSlide   = Tween(begin: 30.0, end: 0.0).animate(
        CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic));

    _confettiCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800));

    _orbCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);

    _cardsCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));

    // Sequence
    _rippleCtrl.forward().then((_) {
      _checkCtrl.forward().then((_) async {
        _confettiCtrl.forward();
        await Future.delayed(const Duration(milliseconds: 80));
        if (mounted) _textCtrl.forward();
        await Future.delayed(const Duration(milliseconds: 200));
        if (mounted) _cardsCtrl.forward();
      });
    });

    Future.delayed(const Duration(milliseconds: 4000), () {
      if (mounted) context.go(AppRoutes.home);
    });
  }

  @override
  void dispose() {
    _rippleCtrl.dispose();
    _checkCtrl.dispose();
    _textCtrl.dispose();
    _confettiCtrl.dispose();
    _orbCtrl.dispose();
    _cardsCtrl.dispose();
    super.dispose();
  }

  static const _confettiColors = [
    Color(0xFF00E096), Color(0xFFFFD60A), Color(0xFF3366FF),
    Color(0xFFFF6B9D), Color(0xFF00BFFF), Color(0xFFFF8C42),
  ];

  @override
  Widget build(BuildContext context) {
    final rs   = Rs.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
            colors: [Color(0xFF00023A), Color(0xFF0500A0), Color(0xFF0033FF)],
            stops:  [0.0, 0.55, 1.0],
          ),
        ),
        child: Stack(children: [

          // ── Orbs ──────────────────────────────────────
          AnimatedBuilder(
            animation: _orbCtrl,
            builder: (_, __) {
              final t = _orbCtrl.value;
              return Stack(children: [
                Positioned(
                  top:  -size.height * 0.08 + t * 20,
                  left: -size.width  * 0.2,
                  child: _GradOrb(size.width * 0.75, 0.10),
                ),
                Positioned(
                  top:   size.height * 0.1 + t * -16,
                  right: -size.width * 0.25,
                  child: _GradOrb(size.width * 0.6, 0.07),
                ),
                Positioned(
                  bottom: size.height * 0.15 + t * 14,
                  left:   size.width  * 0.05,
                  child:  _GradOrb(size.width * 0.4, 0.05),
                ),
              ]);
            },
          ),

          // ── Confetti ───────────────────────────────────
          AnimatedBuilder(
            animation: _confettiCtrl,
            builder: (_, __) {
              return Stack(
                children: _particles.map((p) {
                  final progress = ((_confettiCtrl.value - p.delay) / p.speed)
                      .clamp(0.0, 1.0);
                  if (progress <= 0) return const SizedBox.shrink();
                  final x = p.x * size.width +
                      math.cos(p.angle) * progress * 80;
                  final y = size.height * 0.45 -
                      progress * size.height * 0.35 +
                      progress * progress * size.height * 0.2;
                  final opacity = progress < 0.7
                      ? progress / 0.7
                      : (1 - progress) / 0.3;
                  return Positioned(
                    left: x,
                    top:  y,
                    child: Opacity(
                      opacity: opacity.clamp(0.0, 1.0),
                      child: Transform.rotate(
                        angle: p.angle + progress * math.pi * 3,
                        child: Container(
                          width:  p.size,
                          height: p.size * 0.5,
                          decoration: BoxDecoration(
                            color: p.color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          // ── Main content ───────────────────────────────
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                const Spacer(flex: 2),

                // ── Ripple + check circle ────────────────
                AnimatedBuilder(
                  animation: Listenable.merge([_rippleCtrl, _checkCtrl]),
                  builder: (_, __) {
                    final rT = _rippleCtrl.value;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Ripple ring 3 (outermost)
                        Opacity(
                          opacity: ((1 - rT) * 0.15).clamp(0.0, 1.0),
                          child: Container(
                            width:  rs.sp(180) * rT,
                            height: rs.sp(180) * rT,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFF00E096), width: 1),
                            ),
                          ),
                        ),
                        // Ripple ring 2
                        Opacity(
                          opacity: ((1 - rT) * 0.25).clamp(0.0, 1.0),
                          child: Container(
                            width:  rs.sp(148) * rT,
                            height: rs.sp(148) * rT,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFF00E096), width: 1.5),
                            ),
                          ),
                        ),
                        // Check circle
                        ScaleTransition(
                          scale: _checkScale,
                          child: FadeTransition(
                            opacity: _checkOpacity,
                            child: Container(
                              width:  rs.sp(110),
                              height: rs.sp(110),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF00E096),
                                boxShadow: [
                                  BoxShadow(
                                    color:        const Color(0xFF00E096).withOpacity(0.5),
                                    blurRadius:   50,
                                    spreadRadius: 8,
                                  ),
                                  BoxShadow(
                                    color:        const Color(0xFF00E096).withOpacity(0.25),
                                    blurRadius:   80,
                                    spreadRadius: 20,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.check_rounded,
                                color: const Color(0xFF00023A),
                                size:  rs.sp(54),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                SizedBox(height: rs.sp(44)),

                // ── Text ─────────────────────────────────
                AnimatedBuilder(
                  animation: _textCtrl,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(0, _textSlide.value),
                    child: Opacity(opacity: _textOpacity.value, child: child),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "You're all set!",
                        style: GoogleFonts.sora(
                          color:      Colors.white,
                          fontSize:   rs.sp(36),
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),
                      SizedBox(height: rs.sp(12)),
                      Text(
                        'Your PIN is saved. FlowTrack is\nsecured and ready to go.',
                        style: GoogleFonts.dmSans(
                          color:    Colors.white.withOpacity(0.6),
                          fontSize: rs.sp(15),
                          height:   1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: rs.sp(48)),

                // ── Feature pills ────────────────────────
                AnimatedBuilder(
                  animation: _cardsCtrl,
                  builder: (_, __) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _FeaturePill(
                          icon:     Icons.track_changes_rounded,
                          label:    'Smart Expense Tracking',
                          delay:    0.0,
                          ctrl:     _cardsCtrl,
                          rs:       rs,
                        ),
                        SizedBox(height: rs.sp(10)),
                        _FeaturePill(
                          icon:     Icons.insights_rounded,
                          label:    'AI-Powered Insights',
                          delay:    0.15,
                          ctrl:     _cardsCtrl,
                          rs:       rs,
                        ),
                        SizedBox(height: rs.sp(10)),
                        _FeaturePill(
                          icon:     Icons.lock_rounded,
                          label:    'PIN & Biometric Security',
                          delay:    0.3,
                          ctrl:     _cardsCtrl,
                          rs:       rs,
                        ),
                      ],
                    );
                  },
                ),

                const Spacer(flex: 3),

                // ── Loading dots ─────────────────────────
                AnimatedBuilder(
                  animation: _textCtrl,
                  builder: (_, child) => Opacity(
                    opacity: _textOpacity.value,
                    child: child,
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(bottom: rs.sp(32)),
                    child: _LoadingDots(rs: rs),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Feature pill ───────────────────────────────────────────────
class _FeaturePill extends StatelessWidget {
  const _FeaturePill({
    required this.icon, required this.label,
    required this.delay, required this.ctrl, required this.rs,
  });
  final IconData icon;
  final String   label;
  final double   delay;
  final AnimationController ctrl;
  final Rs       rs;

  @override
  Widget build(BuildContext context) {
    final t = ((ctrl.value - delay) / (1 - delay)).clamp(0.0, 1.0);
    final curve = Curves.easeOutCubic.transform(t);
    return Transform.translate(
      offset: Offset(40 * (1 - curve), 0),
      child: Opacity(
        opacity: curve,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: rs.sp(32)),
          padding: EdgeInsets.symmetric(
              horizontal: rs.sp(20), vertical: rs.sp(14)),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Row(
            children: [
              Container(
                width:  rs.sp(36),
                height: rs.sp(36),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00E096).withOpacity(0.15),
                ),
                child: Icon(icon,
                    color: const Color(0xFF00E096), size: rs.sp(18)),
              ),
              SizedBox(width: rs.sp(14)),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  color:      Colors.white.withOpacity(0.85),
                  fontSize:   rs.sp(14),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Icon(Icons.check_circle_rounded,
                  color: const Color(0xFF00E096).withOpacity(0.7),
                  size: rs.sp(18)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Animated loading dots ──────────────────────────────────────
class _LoadingDots extends StatefulWidget {
  const _LoadingDots({required this.rs});
  final Rs rs;
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final rs = widget.rs;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i / 3.0;
            final t = ((_ctrl.value - delay + 1) % 1.0);
            final scale = t < 0.5
                ? 0.6 + t * 2 * 0.4
                : 1.0 - (t - 0.5) * 2 * 0.4;
            return Container(
              margin: EdgeInsets.symmetric(horizontal: rs.sp(3)),
              width:  rs.sp(6 * scale),
              height: rs.sp(6 * scale),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.3 + scale * 0.4),
              ),
            );
          }),
        );
      },
    );
  }
}

class _GradOrb extends StatelessWidget {
  const _GradOrb(this.size, this.opacity);
  final double size, opacity;
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withOpacity(opacity),
    ),
  );
}

class _Particle {
  const _Particle({
    required this.x, required this.delay, required this.size,
    required this.color, required this.angle, required this.speed,
  });
  final double x, delay, size, angle, speed;
  final Color  color;
}