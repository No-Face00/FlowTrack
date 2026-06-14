

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/router/appRouter.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/widgets/premium_snackbar.dart';
import '../cubit/pin_reset_cubit.dart';
import '../widgets/pin_layout.dart';
import '../widgets/pin_widgets.dart';

class PinResetScreen extends StatelessWidget {
  const PinResetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PinResetCubit(),
      child: const _PinResetView(),
    );
  }
}

class _PinResetView extends StatefulWidget {
  const _PinResetView();

  @override
  State<_PinResetView> createState() => _PinResetViewState();
}

class _PinResetViewState extends State<_PinResetView>
    with TickerProviderStateMixin {
  // Step 0 = verify identity, Step 1 = set new PIN
  int _step = 0;

  // Step 0
  final _passCtrl = TextEditingController();
  bool _passVisible = false;

  // Step 1
  final List<String> _newPin = [];
  final List<String> _confirmPin = [];
  bool _confirming = false;

  late final AnimationController _shakeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420));
  late final Animation<double> _shakeAnim =
  TweenSequence<double>([
    TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -14.0), weight: 1),
    TweenSequenceItem(
        tween: Tween(begin: -14.0, end: 14.0), weight: 2),
    TweenSequenceItem(
        tween: Tween(begin: 14.0, end: -10.0), weight: 2),
    TweenSequenceItem(
        tween: Tween(begin: -10.0, end: 10.0), weight: 2),
    TweenSequenceItem(
        tween: Tween(begin: 10.0, end: 0.0), weight: 1),
  ]).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));

  late final AnimationController _entranceCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700))
    ..forward();

  late final AnimationController _orbCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 3))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _passCtrl.dispose();
    _shakeCtrl.dispose();
    _entranceCtrl.dispose();
    _orbCtrl.dispose();
    super.dispose();
  }

  void _onKey(String digit) {
    final current = _confirming ? _confirmPin : _newPin;
    if (current.length >= 4) return;
    setState(() => current.add(digit));
    if (current.length == 4) _onPinComplete();
  }

  void _onDelete() {
    final current = _confirming ? _confirmPin : _newPin;
    if (current.isEmpty) return;
    setState(() => current.removeLast());
  }

  Future<void> _onPinComplete() async {
    await Future.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    if (!_confirming) {
      setState(() => _confirming = true);
    } else {
      if (_newPin.join() == _confirmPin.join()) {
        context.read<PinResetCubit>().setNewPin(
          pin: _newPin.join(),
          confirmPin: _confirmPin.join(),
        );
      } else {
        _shakeCtrl.forward(from: 0);
        HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 440));
        if (!mounted) return;
        setState(() {
          _newPin.clear();
          _confirmPin.clear();
          _confirming = false;
        });
        _showSnack(context.tr(S.pinMismatchRetry));
      }
    }
  }

  void _showSnack(String msg, {bool isError = true}) {
    AppSnack.show(context,
        message: msg,
        type: isError ? SnackType.error : SnackType.success);
  }

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    final size = MediaQuery.of(context).size;

    return BlocListener<PinResetCubit, PinResetState>(
      listener: (ctx, state) {
        if (state is PinResetVerified) {
          setState(() {
            _step = 1;
            _confirming = false;
            _newPin.clear();
            _confirmPin.clear();
          });
          _entranceCtrl
            ..reset()
            ..forward();
        }
        if (state is PinResetComplete) {
          AppRouter.markPinJustSet();
          ctx.go(AppRoutes.home);
        }
        if (state is PinResetError) _showSnack(state.message);
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF00023A),
                Color(0xFF0500A0),
                Color(0xFF0033FF)
              ],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
          child: Stack(children: [
            // Orbs
            AnimatedBuilder(
              animation: _orbCtrl,
              builder: (_, __) {
                final t = _orbCtrl.value;
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
                ]);
              },
            ),

            // Main content
            SafeArea(
              child: Column(children: [
                // Top bar: back + progress pills
                _TopBar(
                  step: _step,
                  rs: rs,
                  onBack: () {
                    if (_step == 0) {
                      context.pop();
                    } else {
                      setState(() {
                        _step = 0;
                        _confirming = false;
                        _newPin.clear();
                        _confirmPin.clear();
                      });
                    }
                  },
                ),

                // Content area
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.06, 0),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: _step == 0
                        ? KeyedSubtree(
                      key: const ValueKey('verify'),
                      child: _VerifyStep(
                        passCtrl: _passCtrl,
                        passVisible: _passVisible,
                        rs: rs,
                        onTogglePass: () => setState(
                                () => _passVisible = !_passVisible),
                        onEmailSubmit: () => context
                            .read<PinResetCubit>()
                            .reAuthWithPassword(_passCtrl.text),
                        onGoogleSubmit: () => context
                            .read<PinResetCubit>()
                            .reAuthWithGoogle(),
                      ),
                    )
                        : KeyedSubtree(
                      key: const ValueKey('newpin'),
                      child: _NewPinContent(
                        newPin: _newPin,
                        confirmPin: _confirmPin,
                        confirming: _confirming,
                        shakeAnim: _shakeAnim,
                        entranceCtrl: _entranceCtrl,
                        onKey: _onKey,
                        onDelete: _onDelete,
                        rs: rs,
                      ),
                    ),
                  ),
                ),
              ]),
            ),

            // Loading overlay
            BlocBuilder<PinResetCubit, PinResetState>(
              builder: (_, state) {
                if (state is! PinResetLoading) {
                  return const SizedBox.shrink();
                }
                return Container(
                  color: Colors.black.withOpacity(0.45),
                  child: const Center(
                    child: CircularProgressIndicator(
                        color: Colors.white),
                  ),
                );
              },
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Top navigation bar ────────────────────────────────────────
class _TopBar extends StatelessWidget {
  const _TopBar(
      {required this.step, required this.rs, required this.onBack});
  final int step;
  final Rs rs;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: rs.sp(8).clamp(4.0, 12.0),
          vertical: rs.sp(4).clamp(2.0, 8.0)),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: onBack,
        ),
        Expanded(
          child: Row(
            children: List.generate(
              2,
                  (i) => Expanded(
                child: Container(
                  height: rs.sp(4).clamp(3.0, 5.0),
                  margin: EdgeInsets.symmetric(
                      horizontal: rs.sp(3).clamp(2.0, 5.0)),
                  decoration: BoxDecoration(
                    color: i <= step
                        ? Colors.white
                        : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: rs.sp(48).clamp(36.0, 56.0)),
      ]),
    );
  }
}

// ──  2: New PIN using PinScaffold logic inline ────────────
// We can't use PinScaffold directly here because Step 2 lives
// inside an Expanded+AnimatedSwitcher. Instead we replicate the
// two-zone layout using LayoutBuilder.
class _NewPinContent extends StatelessWidget {
  const _NewPinContent({
    required this.newPin,
    required this.confirmPin,
    required this.confirming,
    required this.shakeAnim,
    required this.entranceCtrl,
    required this.onKey,
    required this.onDelete,
    required this.rs,
  });

  final List<String> newPin, confirmPin;
  final bool confirming;
  final Animation<double> shakeAnim;
  final AnimationController entranceCtrl;
  final void Function(String) onKey;
  final VoidCallback onDelete;
  final Rs rs;

  @override
  Widget build(BuildContext context) {
    final current = confirming ? confirmPin : newPin;

    return LayoutBuilder(builder: (context, constraints) {
      final avH = constraints.maxHeight;
      final avW = constraints.maxWidth;
      final gap = avW * 0.038;
      final hPad = avW * 0.06;
      final keyW =
      ((avW - 2 * hPad - 2 * gap) / 3).clamp(64.0, 110.0);
      final keyH = (keyW * 1.13).clamp(56.0, 100.0);
      final rowVPad = (avH * 0.008).clamp(4.0, 10.0);
      final numpadH = 4 * keyH + 8 * rowVPad;
      final handleBotPad = (avH * 0.025).clamp(16.0, 32.0);
      final dotsBotPad = (avH * 0.022).clamp(14.0, 30.0);
      final dotsTopPad = (avH * 0.02).clamp(12.0, 28.0);
      final extraBotPad = (avH * 0.01).clamp(4.0, 14.0);
      final glassCardH = (avH * 0.025).clamp(16.0, 32.0) +
          4.0 +
          handleBotPad +
          dotsTopPad +
          16.0 +
          dotsBotPad +
          numpadH +
          extraBotPad;
      final topZoneH =
      (avH - glassCardH).clamp(80.0, avH * 0.45);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top zone
          SizedBox(
            height: topZoneH,
            child: Center(
              child: PinEntrance(
                controller: entranceCtrl,
                interval: const Interval(0.0, 0.75),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.12),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: PinTopContent(
                    key: ValueKey(confirming),
                    icon: PinGlowIcon(
                      icon: confirming
                          ? Icons.check_circle_outline_rounded
                          : Icons.pin_outlined,
                      rs: rs,
                      topZoneH: topZoneH,
                      switchKey: ValueKey(confirming),
                    ),
                    title: confirming
                        ? context.tr(S.pinConfirmNewTitle)
                        : context.tr(S.pinSetNewTitle),
                    subtitle: confirming
                        ? context.tr(S.pinReenterNew)
                        : context.tr(S.pinChooseNew),
                    subtitleIcon: confirming
                        ? Icons.repeat_rounded
                        : Icons.security_rounded,
                    rs: rs,
                    topZoneH: topZoneH,
                  ),
                ),
              ),
            ),
          ),

          // Glass card
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(36)),
              border: Border.all(
                  color: Colors.white.withOpacity(0.13), width: 1),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(height: (avH * 0.025).clamp(16.0, 32.0)),
              Container(
                width: avW * 0.09,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: handleBotPad),
              SizedBox(height: dotsTopPad),
              AnimatedBuilder(
                animation: shakeAnim,
                builder: (_, child) => Transform.translate(
                  offset: Offset(shakeAnim.value, 0),
                  child: child,
                ),
                child: PinDots(
                    filled: current.length, rs: rs, dark: true),
              ),
              SizedBox(height: dotsBotPad),
              AdaptiveNumPad(
                onKey: onKey,
                onDelete: onDelete,
                keySize: keyW,
                keyHeight: keyH,
                gap: gap,
                rowVPad: rowVPad,
                hPad: hPad,
                dark: true,
                rs: rs,
              ),
              SizedBox(height: extraBotPad + 4),
            ]),
          ),
        ],
      );
    });
  }
}

// ── Step 1: Verify identity (unchanged, uses form fields) ─────
class _VerifyStep extends StatelessWidget {
  const _VerifyStep({
    required this.passCtrl,
    required this.passVisible,
    required this.rs,
    required this.onTogglePass,
    required this.onEmailSubmit,
    required this.onGoogleSubmit,
  });

  final TextEditingController passCtrl;
  final bool passVisible;
  final Rs rs;
  final VoidCallback onTogglePass, onEmailSubmit, onGoogleSubmit;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PinResetCubit>();
    final isGoogle = cubit.isGoogleUser;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
          horizontal: rs.sp(24).clamp(16.0, 32.0),
          vertical: rs.sp(8).clamp(4.0, 16.0)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: rs.sp(16).clamp(8.0, 24.0)),

          Container(
            width: rs.sp(64).clamp(48.0, 72.0),
            height: rs.sp(64).clamp(48.0, 72.0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.12),
              border: Border.all(
                  color: Colors.white.withOpacity(0.3), width: 1.5),
            ),
            child: Icon(
              isGoogle
                  ? Icons.verified_user_outlined
                  : Icons.lock_open_outlined,
              color: Colors.white,
              size: rs.sp(28).clamp(20.0, 34.0),
            ),
          ),

          SizedBox(height: rs.sp(24).clamp(14.0, 32.0)),

          Text(
            context.tr(S.pinVerifyTitle),
            style: GoogleFonts.sora(
              color: Colors.white,
              fontSize: rs.sp(26).clamp(18.0, 30.0),
              fontWeight: FontWeight.w800,
            ),
          ),

          SizedBox(height: rs.sp(8).clamp(5.0, 12.0)),

          Text(
            isGoogle
                ? context.tr(S.pinVerifyGoogleSub)
                : context.tr(S.pinVerifyPasswordSub),
            style: GoogleFonts.dmSans(
              color: Colors.white.withOpacity(0.65),
              fontSize: rs.sp(13).clamp(11.0, 15.0),
              height: 1.6,
            ),
          ),

          SizedBox(height: rs.sp(32).clamp(18.0, 40.0)),

          if (isGoogle) ...[
            _GoogleVerifyButton(rs: rs, onTap: onGoogleSubmit),
          ] else ...[
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius:
                BorderRadius.circular(rs.sp(14).clamp(10.0, 18.0)),
                border: Border.all(
                    color: Colors.white.withOpacity(0.2)),
              ),
              child: TextField(
                controller: passCtrl,
                obscureText: !passVisible,
                style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: rs.sp(15).clamp(13.0, 17.0)),
                decoration: InputDecoration(
                  hintText: context.tr(S.pinAccountPassword),
                  hintStyle: GoogleFonts.dmSans(
                      color: Colors.white.withOpacity(0.35)),
                  prefixIcon: Icon(Icons.lock_outline_rounded,
                      color: Colors.white.withOpacity(0.5),
                      size: rs.sp(20).clamp(16.0, 24.0)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      passVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.white.withOpacity(0.5),
                      size: rs.sp(20).clamp(16.0, 24.0),
                    ),
                    onPressed: onTogglePass,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: rs.sp(16).clamp(12.0, 20.0),
                    vertical: rs.sp(16).clamp(12.0, 20.0),
                  ),
                ),
              ),
            ),

            SizedBox(height: rs.sp(20).clamp(12.0, 28.0)),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0033FF),
                  padding: EdgeInsets.symmetric(
                      vertical: rs.sp(16).clamp(12.0, 20.0)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                          rs.sp(14).clamp(10.0, 18.0))),
                  elevation: 0,
                ),
                onPressed: onEmailSubmit,
                child: Text(
                  context.tr(S.pinVerifyContinue),
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: rs.sp(15).clamp(13.0, 17.0),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Google verify button ──────────────────────────────────────
class _GoogleVerifyButton extends StatelessWidget {
  const _GoogleVerifyButton(
      {required this.rs, required this.onTap});
  final Rs rs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          vertical: rs.sp(16).clamp(12.0, 20.0),
          horizontal: rs.sp(20).clamp(14.0, 26.0),
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.circular(rs.sp(14).clamp(10.0, 18.0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _GoogleLogo(size: rs.sp(22).clamp(18.0, 26.0)),
            SizedBox(width: rs.sp(12).clamp(8.0, 16.0)),
            Text(
              context.tr(S.pinVerifyGoogle),
              style: GoogleFonts.dmSans(
                color: const Color(0xFF1A1A2E),
                fontSize: rs.sp(15).clamp(13.0, 17.0),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GLogoPainter()),
    );
  }
}

class _GLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    final colors = [
      const Color(0xFF4285F4),
      const Color(0xFF34A853),
      const Color(0xFFFBBC05),
      const Color(0xFFEA4335),
    ];
    final sweeps = [1.6, 1.6, 1.0, 2.1];
    double start = -0.3;
    for (int i = 0; i < 4; i++) {
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.18
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.72),
        start,
        sweeps[i],
        false,
        paint,
      );
      start += sweeps[i];
    }
    final barPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = size.width * 0.18
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(cx, cy), Offset(cx + r * 0.68, cy), barPaint);
  }

  @override
  bool shouldRepaint(_) => false;
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