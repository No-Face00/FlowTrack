// lib/features/auth/presentation/pinlock_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/appRouter.dart';
import '../../../core/utils/responsive_helper.dart';
import '../cubit/pin_cubit.dart';
import '../widgets/pin_widgets.dart';

class PinLockScreen extends StatefulWidget {
  const PinLockScreen({super.key});
  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen>
    with TickerProviderStateMixin {

  final List<String> _pin          = [];
  bool               _bioAvailable = false;

  late AnimationController _shakeCtrl;
  late Animation<double>   _shakeAnim;
  late AnimationController _entranceCtrl;
  late AnimationController _orbCtrl;

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
    _checkBiometrics();
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _entranceCtrl.dispose();
    _orbCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    final enabled = await context.read<PinCubit>().isBiometricsEnabled();
    if (!mounted) return;
    setState(() => _bioAvailable = enabled);
    if (enabled) Future.delayed(const Duration(milliseconds: 600), _doBiometrics);
  }

  void _doBiometrics() {
    if (!mounted) return;
    context.read<PinCubit>().authenticateWithBiometrics();
  }

  void _onKey(String digit) {
    if (_pin.length >= 4) return;
    setState(() => _pin.add(digit));
    if (_pin.length == 4) _verify();
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() => _pin.removeLast());
  }

  void _verify() {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    context.read<PinCubit>().verifyPin(pin: _pin.join(), userId: userId);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(msg,
              style: GoogleFonts.dmSans(
                  color: Colors.white, fontWeight: FontWeight.w600))),
        ]),
        backgroundColor: const Color(0xFFFF4757),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(14),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final rs   = Rs.of(context);
    final size = MediaQuery.of(context).size;

    return BlocListener<PinCubit, PinState>(
      listener: (ctx, state) {
        if (state is PinVerifySuccess) {
          AppRouter.markPinJustSet();
          ctx.go(AppRoutes.home);
        } else if (state is PinWrongAttempt) {
          _shakeCtrl.forward(from: 0);
          HapticFeedback.heavyImpact();
          setState(() => _pin.clear());
          _showSnack(
            'Wrong PIN · ${state.attemptsLeft} attempt${state.attemptsLeft == 1 ? '' : 's'} left',
          );
        } else if (state is PinError) {
          setState(() => _pin.clear());
          state.message.contains('Too many')
              ? ctx.go(AppRoutes.login)
              : _showSnack(state.message);
        }
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
                    child: _Orb(size.width * 0.6, 0.06),
                  ),
                  Positioned(
                    bottom: size.height * 0.3 + t * 16,
                    left:   size.width  * 0.1,
                    child:  _Orb(size.width * 0.3, 0.05),
                  ),
                  Positioned(
                    top:   size.height * 0.22,
                    left:  size.width  * 0.08,
                    child: _StarDot(opacity: 0.4 + t * 0.3),
                  ),
                  Positioned(
                    top:   size.height * 0.35,
                    right: size.width  * 0.12,
                    child: _StarDot(opacity: 0.3 + t * 0.4, size: 5),
                  ),
                ]);
              },
            ),

            SafeArea(
              child: Column(children: [

                Expanded(
                  flex: 5,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildEntranceAnim(
                        interval: const Interval(0.0, 0.55),
                        slideStart: 0,
                        child: _GlowLockIcon(rs: rs),
                      ),
                      SizedBox(height: rs.sp(26)),
                      _buildEntranceAnim(
                        interval: const Interval(0.2, 0.7),
                        child: Column(
                          children: [
                            Text('Welcome Back',
                              style: GoogleFonts.sora(
                                color: Colors.white, fontSize: rs.sp(30),
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5, height: 1.15,
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
                                  Icon(Icons.shield_rounded,
                                      color: Colors.white.withOpacity(0.7),
                                      size: rs.sp(13)),
                                  SizedBox(width: rs.sp(6)),
                                  Text('Enter your 4-digit PIN to continue',
                                    style: GoogleFonts.dmSans(
                                      color: Colors.white.withOpacity(0.7),
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
                    ],
                  ),
                ),

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
                            child: PinDots(
                                filled: _pin.length, rs: rs, dark: true),
                          ),
                          SizedBox(height: rs.sp(28)),
                          NumPad(
                              onKey: _onKey, onDelete: _onDelete,
                              rs: rs, dark: true),
                          if (_bioAvailable) ...[
                            SizedBox(height: rs.sp(18)),
                            _BiometricButton(onTap: _doBiometrics, rs: rs),
                          ],
                          SizedBox(height: rs.sp(16)),

                          // ── Forgot PIN → opens /pin-reset ────
                          GestureDetector(
                            onTap: () => context.push(AppRoutes.pinReset),
                            child: Text(
                              'Forgot PIN?',
                              style: GoogleFonts.dmSans(
                                color:      Colors.white.withOpacity(0.55),
                                fontSize:   rs.sp(13),
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                                decorationColor:
                                Colors.white.withOpacity(0.3),
                              ),
                            ),
                          ),
                          SizedBox(height: rs.sp(8)),
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
            curve: Interval(interval.begin, interval.end,
                curve: Curves.easeOutCubic)));
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

class _GlowLockIcon extends StatefulWidget {
  const _GlowLockIcon({required this.rs});
  final Rs rs;
  @override
  State<_GlowLockIcon> createState() => _GlowLockIconState();
}

class _GlowLockIconState extends State<_GlowLockIcon>
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
        return Stack(alignment: Alignment.center, children: [
          Opacity(opacity: 0.06 + t * 0.08,
            child: Container(width: rs.sp(120), height: rs.sp(120),
              decoration: BoxDecoration(shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1)),
            ),
          ),
          Opacity(opacity: 0.10 + t * 0.08,
            child: Container(width: rs.sp(96), height: rs.sp(96),
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                  border: Border.all(color: Colors.white, width: 1)),
            ),
          ),
          Container(
            width: rs.sp(72), height: rs.sp(72),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white.withOpacity(0.28),
                    Colors.white.withOpacity(0.10)]),
              border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
              boxShadow: [BoxShadow(color: const Color(0xFF3366FF).withOpacity(0.6),
                  blurRadius: 32, spreadRadius: 4)],
            ),
            child: Icon(Icons.lock_rounded, color: Colors.white, size: rs.sp(32)),
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
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacity)),
  );
}

class _StarDot extends StatelessWidget {
  const _StarDot({required this.opacity, this.size = 6});
  final double opacity, size;
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacity)),
  );
}

class _BiometricButton extends StatelessWidget {
  const _BiometricButton({required this.onTap, required this.rs});
  final VoidCallback onTap;
  final Rs rs;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: rs.sp(52), height: rs.sp(52),
          decoration: BoxDecoration(shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.12),
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5)),
          child: Icon(Icons.fingerprint, color: Colors.white.withOpacity(0.85),
              size: rs.sp(26)),
        ),
        SizedBox(height: rs.sp(6)),
        Text('Use biometrics',
            style: GoogleFonts.dmSans(color: Colors.white.withOpacity(0.5),
                fontSize: rs.sp(12), fontWeight: FontWeight.w500)),
      ]),
    );
  }
}