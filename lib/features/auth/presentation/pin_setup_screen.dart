// lib/features/pin/presentation/pin_setup_screen.dart
//
// FLOW: /pin-setup → PIN set + confirmed → /welcome → /home

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/appRouter.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/widgets/premium_snackbar.dart';
import '../cubit/pin_cubit.dart';
import '../widgets/pin_widgets.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});
  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen>
    with TickerProviderStateMixin {

  final List<String> _pin      = [];
  List<String>       _firstPin = [];
  bool               _confirming = false;

  late AnimationController _shakeCtrl;
  late Animation<double>   _shakeAnim;
  late AnimationController _entranceCtrl;
  late AnimationController _orbCtrl;
  late AnimationController _switchCtrl; // for step switch animation

  @override
  void initState() {
    super.initState();

    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0,   end: -14.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -14.0, end:  14.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin:  14.0, end: -10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10.0, end:  10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin:  10.0, end:   0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));

    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();

    _orbCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);

    _switchCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _entranceCtrl.dispose();
    _orbCtrl.dispose();
    _switchCtrl.dispose();
    super.dispose();
  }

  void _onKey(String digit) {
    if (_pin.length >= 4) return;
    setState(() => _pin.add(digit));
    if (_pin.length == 4) _onPinComplete();
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() => _pin.removeLast());
  }

  Future<void> _onPinComplete() async {
    await Future.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;

    if (!_confirming) {
      // Switch to confirm step with animation
      await _switchCtrl.forward();
      if (!mounted) return;
      setState(() {
        _firstPin   = List.from(_pin);
        _confirming = true;
        _pin.clear();
      });
      _switchCtrl.reverse();
    } else {
      if (_pin.join() == _firstPin.join()) {
        final userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
        if (!mounted) return;
        context.read<PinCubit>().savePin(pin: _pin.join(), userId: userId);
      } else {
        _shakeCtrl.forward(from: 0);
        HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 440));
        if (!mounted) return;
        setState(() { _pin.clear(); _confirming = false; _firstPin.clear(); });
        _showSnack('PINs do not match. Please start again.');
      }
    }
  }

  void _showSnack(String msg) {
    AppSnack.show(context, message: msg, type: SnackType.error);
  }

  @override
  Widget build(BuildContext context) {
    final rs   = Rs.of(context);
    final size = MediaQuery.of(context).size;

    return BlocListener<PinCubit, PinState>(
      listener: (ctx, state) {
        if (state is PinSetSuccess) {
          AppRouter.markPinJustSet();
          ctx.go(AppRoutes.welcome);
        }
        if (state is PinError) _showSnack(state.message);
      },
      child: Scaffold(
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
                    top:  -size.height * 0.05 + t * 18,
                    left: -size.width  * 0.18,
                    child: _Orb(size.width * 0.7, 0.09),
                  ),
                  Positioned(
                    top:   size.height * 0.08 + t * -14,
                    right: -size.width * 0.22,
                    child: _Orb(size.width * 0.55, 0.06),
                  ),
                  Positioned(
                    top:   size.height * 0.22,
                    left:  size.width  * 0.08,
                    child: _StarDot(opacity: 0.4 + t * 0.3),
                  ),
                  Positioned(
                    top:   size.height * 0.15,
                    right: size.width  * 0.15,
                    child: _StarDot(opacity: 0.25 + t * 0.35, size: 4),
                  ),
                ]);
              },
            ),

            // ── Content ───────────────────────────────────
            SafeArea(
              child: Column(children: [

                // Top area — step indicator + icon + text
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: rs.sp(24)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [

                        // Step chips
                        _buildEntranceAnim(
                          interval: const Interval(0.0, 0.4),
                          child: _StepIndicator(confirming: _confirming, rs: rs),
                        ),

                        SizedBox(height: rs.sp(28)),

                        // Icon
                        _buildEntranceAnim(
                          interval: const Interval(0.05, 0.55),
                          child: _SetupIcon(confirming: _confirming, rs: rs),
                        ),

                        SizedBox(height: rs.sp(24)),

                        // Title + subtitle
                        _buildEntranceAnim(
                          interval: const Interval(0.25, 0.7),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 320),
                            transitionBuilder: (child, anim) => FadeTransition(
                              opacity: anim,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.15),
                                  end:   Offset.zero,
                                ).animate(anim),
                                child: child,
                              ),
                            ),
                            child: Column(
                              key: ValueKey(_confirming),
                              children: [
                                Text(
                                  _confirming ? 'Confirm Your PIN' : 'Create a PIN',
                                  style: GoogleFonts.sora(
                                    color: Colors.white,
                                    fontSize: rs.sp(28),
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                SizedBox(height: rs.sp(8)),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: rs.sp(16), vertical: rs.sp(6)),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: Colors.white.withOpacity(0.18)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _confirming
                                            ? Icons.repeat_rounded
                                            : Icons.security_rounded,
                                        color: Colors.white.withOpacity(0.7),
                                        size: rs.sp(13),
                                      ),
                                      SizedBox(width: rs.sp(6)),
                                      Text(
                                        _confirming
                                            ? 'Re-enter the same PIN to confirm'
                                            : 'Choose a secure 4-digit PIN',
                                        style: GoogleFonts.dmSans(
                                          color:    Colors.white.withOpacity(0.7),
                                          fontSize: rs.sp(12),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom glass card
                _buildEntranceAnim(
                  interval: const Interval(0.4, 0.9),
                  slideStart: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(36)),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.13), width: 1),
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                          rs.sp(20), rs.sp(20), rs.sp(20), rs.sp(20)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [

                          Container(
                            width: rs.sp(36), height: rs.sp(4),
                            margin: EdgeInsets.only(bottom: rs.sp(24)),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),

                          AnimatedBuilder(
                            animation: _shakeAnim,
                            builder: (_, child) => Transform.translate(
                              offset: Offset(_shakeAnim.value, 0),
                              child: child,
                            ),
                            child: PinDots(filled: _pin.length, rs: rs, dark: true),
                          ),

                          SizedBox(height: rs.sp(28)),

                          NumPad(onKey: _onKey, onDelete: _onDelete, rs: rs, dark: true),

                          SizedBox(height: rs.sp(20)),

                          // Biometrics hint
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.fingerprint,
                                  color: Colors.white.withOpacity(0.35),
                                  size: rs.sp(16)),
                              SizedBox(width: rs.sp(6)),
                              Text(
                                'Update your name and photo anytime from Account.',
                                style: GoogleFonts.dmSans(
                                  color:    Colors.white.withOpacity(0.35),
                                  fontSize: rs.sp(11),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: rs.sp(4)),
                        ],
                      ),
                    ),
                  ),
                ),

              ]),
            ),

          ]),
        ),
      ),
    );
  }

  Widget _buildEntranceAnim({
    required Widget child,
    required Interval interval,
    double slideStart = 24,
  }) {
    final opacity = CurvedAnimation(parent: _entranceCtrl,
        curve: Interval(interval.begin, interval.end, curve: Curves.easeOut));
    final slide = Tween(begin: slideStart, end: 0.0).animate(
        CurvedAnimation(parent: _entranceCtrl,
            curve: Interval(interval.begin, interval.end, curve: Curves.easeOutCubic)));
    return AnimatedBuilder(
      animation: _entranceCtrl,
      builder: (_, c) => Transform.translate(
        offset: Offset(0, slide.value),
        child: Opacity(opacity: opacity.value, child: c),
      ),
      child: child,
    );
  }
}

// ── Step indicator chips ───────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.confirming, required this.rs});
  final bool confirming;
  final Rs   rs;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Chip(label: '1  Set PIN',     active: !confirming, done: confirming, rs: rs),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: rs.sp(8)),
          child: Container(
            width: rs.sp(20), height: 1,
            color: Colors.white.withOpacity(0.3),
          ),
        ),
        _Chip(label: '2  Confirm',     active: confirming, done: false, rs: rs),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label, required this.active,
    required this.done, required this.rs,
  });
  final String label;
  final bool   active, done;
  final Rs     rs;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.symmetric(
          horizontal: rs.sp(14), vertical: rs.sp(6)),
      decoration: BoxDecoration(
        color: active
            ? Colors.white.withOpacity(0.2)
            : done
            ? const Color(0xFF00E096).withOpacity(0.2)
            : Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active
              ? Colors.white.withOpacity(0.35)
              : done
              ? const Color(0xFF00E096).withOpacity(0.5)
              : Colors.white.withOpacity(0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (done) ...[
            Icon(Icons.check_circle_rounded,
                color: const Color(0xFF00E096), size: rs.sp(13)),
            SizedBox(width: rs.sp(4)),
          ],
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: active
                  ? Colors.white
                  : done
                  ? const Color(0xFF00E096)
                  : Colors.white.withOpacity(0.4),
              fontSize:   rs.sp(12),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animated setup icon ────────────────────────────────────────
class _SetupIcon extends StatefulWidget {
  const _SetupIcon({required this.confirming, required this.rs});
  final bool confirming;
  final Rs   rs;
  @override
  State<_SetupIcon> createState() => _SetupIconState();
}

class _SetupIconState extends State<_SetupIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final rs = widget.rs;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: 0.06 + t * 0.08,
              child: Container(
                width:  rs.sp(116),
                height: rs.sp(116),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
              ),
            ),
            Opacity(
              opacity: 0.10 + t * 0.08,
              child: Container(
                width:  rs.sp(94),
                height: rs.sp(94),
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
                scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Container(
                key: ValueKey(widget.confirming),
                width:  rs.sp(70),
                height: rs.sp(70),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end:   Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.28),
                      Colors.white.withOpacity(0.10),
                    ],
                  ),
                  border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color:      const Color(0xFF3366FF).withOpacity(0.6),
                      blurRadius: 32,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Icon(
                  widget.confirming
                      ? Icons.check_circle_outline_rounded
                      : Icons.pin_outlined,
                  color: Colors.white,
                  size:  rs.sp(32),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb(this.size, this.opacity);
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

class _StarDot extends StatelessWidget {
  const _StarDot({required this.opacity, this.size = 6});
  final double opacity, size;
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withOpacity(opacity),
    ),
  );
}