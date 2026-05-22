// lib/features/auth/presentation/pin_reset_screen.dart
//
// Step 1 — Verify identity
//   • Email users  : enter account password
//   • Google users : tap "Verify with Google" button
//
// Step 2 — Set new 4-digit PIN (same UI as pin_setup_screen)

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

  // Step 0 — password field (email users only)
  final _passCtrl    = TextEditingController();
  bool  _passVisible = false;

  // Step 1 — PIN entry
  final List<String> _newPin     = [];
  final List<String> _confirmPin = [];
  bool               _confirming = false;

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
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _orbCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _passCtrl.dispose();
    _shakeCtrl.dispose();
    _entranceCtrl.dispose();
    _orbCtrl.dispose();
    super.dispose();
  }

  // ── PIN numpad (Step 1) ────────────────────────────────────────
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
          pin:        _newPin.join(),
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
    AppSnack.show(
      context,
      message: msg,
      type: isError ? SnackType.error : SnackType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final rs   = Rs.of(context);
    final size = MediaQuery.of(context).size;

    return BlocListener<PinResetCubit, PinResetState>(
      listener: (ctx, state) {
        if (state is PinResetVerified) {
          // Identity confirmed → move to new PIN step
          setState(() {
            _step       = 1;
            _confirming = false;
            _newPin.clear();
            _confirmPin.clear();
          });
        }
        if (state is PinResetComplete) {
          AppRouter.markPinJustSet();
          ctx.go(AppRoutes.home);
        }
        if (state is PinResetError) {
          _showSnack(state.message);
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

            // ── Orbs ──────────────────────────────────────────
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
                ]);
              },
            ),

            SafeArea(
              child: Column(children: [

                // ── Top bar: back + step bar ───────────────────
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: rs.sp(8), vertical: rs.sp(4)),
                  child: Row(children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 20),
                      onPressed: () {
                        if (_step == 0) {
                          context.pop();
                        } else {
                          setState(() {
                            _step       = 0;
                            _confirming = false;
                            _newPin.clear();
                            _confirmPin.clear();
                          });
                        }
                      },
                    ),
                    Expanded(
                      child: Row(
                        children: List.generate(2, (i) => Expanded(
                          child: Container(
                            height: rs.sp(4),
                            margin: EdgeInsets.symmetric(
                                horizontal: rs.sp(3)),
                            decoration: BoxDecoration(
                              color: i <= _step
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        )),
                      ),
                    ),
                    SizedBox(width: rs.sp(48)),
                  ]),
                ),

                // ── Content ────────────────────────────────────
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.06, 0),
                          end:   Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: _step == 0
                        ? KeyedSubtree(
                      key: const ValueKey('verify'),
                      child: _VerifyStep(
                        passCtrl:    _passCtrl,
                        passVisible: _passVisible,
                        rs:          rs,
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
                      child: _NewPinStep(
                        newPin:     _newPin,
                        confirmPin: _confirmPin,
                        confirming: _confirming,
                        shakeAnim:  _shakeAnim,
                        onKey:      _onKey,
                        onDelete:   _onDelete,
                        rs:         rs,
                      ),
                    ),
                  ),
                ),

              ]),
            ),

            // ── Loading overlay ────────────────────────────────
            BlocBuilder<PinResetCubit, PinResetState>(
              builder: (_, state) {
                if (state is! PinResetLoading) {
                  return const SizedBox.shrink();
                }
                return Container(
                  color: Colors.black.withOpacity(0.45),
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
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

// ══════════════════════════════════════════════════════════════
//  Step 1 — Verify identity
//  Automatically shows password field OR Google button
//  depending on how the user signed up
// ══════════════════════════════════════════════════════════════
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
  final bool        passVisible;
  final Rs          rs;
  final VoidCallback onTogglePass;
  final VoidCallback onEmailSubmit;
  final VoidCallback onGoogleSubmit;

  @override
  Widget build(BuildContext context) {
    // Detect provider to show correct UI
    final cubit      = context.read<PinResetCubit>();
    final isGoogle   = cubit.isGoogleUser;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
          horizontal: rs.sp(24), vertical: rs.sp(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          SizedBox(height: rs.sp(16)),

          // Icon
          Container(
            width:  rs.sp(64),
            height: rs.sp(64),
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
              color: Colors.white, size: rs.sp(28),
            ),
          ),

          SizedBox(height: rs.sp(24)),

          Text(context.tr(S.pinVerifyTitle),
            style: GoogleFonts.sora(
              color: Colors.white, fontSize: rs.sp(26),
              fontWeight: FontWeight.w800,
            ),
          ),

          SizedBox(height: rs.sp(8)),

          Text(
            isGoogle
                ? context.tr(S.pinVerifyGoogleSub)
                : context.tr(S.pinVerifyPasswordSub),
            style: GoogleFonts.dmSans(
              color:    Colors.white.withOpacity(0.65),
              fontSize: rs.sp(13),
              height:   1.6,
            ),
          ),

          SizedBox(height: rs.sp(32)),

          if (isGoogle) ...[
            // ── Google re-auth button ──────────────────────
            _GoogleVerifyButton(rs: rs, onTap: onGoogleSubmit),
          ] else ...[
            // ── Password field ─────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(rs.sp(14)),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: TextField(
                controller:     passCtrl,
                obscureText:    !passVisible,
                style: GoogleFonts.dmSans(
                    color: Colors.white, fontSize: rs.sp(15)),
                decoration: InputDecoration(
                  hintText:  context.tr(S.pinAccountPassword),
                  hintStyle: GoogleFonts.dmSans(
                      color: Colors.white.withOpacity(0.35)),
                  prefixIcon: Icon(Icons.lock_outline_rounded,
                      color: Colors.white.withOpacity(0.5),
                      size: rs.sp(20)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      passVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.white.withOpacity(0.5),
                      size: rs.sp(20),
                    ),
                    onPressed: onTogglePass,
                  ),
                  border:         InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: rs.sp(16), vertical: rs.sp(16)),
                ),
              ),
            ),

            SizedBox(height: rs.sp(20)),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0033FF),
                  padding: EdgeInsets.symmetric(vertical: rs.sp(16)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(rs.sp(14))),
                  elevation: 0,
                ),
                onPressed: onEmailSubmit,
                child: Text(context.tr(S.pinVerifyContinue),
                    style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        fontSize:   rs.sp(15))),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Google verify button ───────────────────────────────────────
class _GoogleVerifyButton extends StatelessWidget {
  const _GoogleVerifyButton({required this.rs, required this.onTap});
  final Rs rs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:   double.infinity,
        padding: EdgeInsets.symmetric(
            vertical: rs.sp(16), horizontal: rs.sp(20)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(rs.sp(14)),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset:     const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Google G logo (coloured)
            _GoogleLogo(size: rs.sp(22)),
            SizedBox(width: rs.sp(12)),
            Text(context.tr(S.pinVerifyGoogle),
              style: GoogleFonts.dmSans(
                color:      const Color(0xFF1A1A2E),
                fontSize:   rs.sp(15),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Minimal coloured Google "G" drawn with a RichText
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size, height: size,
      child: CustomPaint(painter: _GLogoPainter()),
    );
  }
}

class _GLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;
    final r  = size.width  / 2;

    // Draw coloured arcs (simplified Google G)
    final colors = [
      const Color(0xFF4285F4), // blue
      const Color(0xFF34A853), // green
      const Color(0xFFFBBC05), // yellow
      const Color(0xFFEA4335), // red
    ];
    final sweeps = [1.6, 1.6, 1.0, 2.1];
    double start = -0.3;

    for (int i = 0; i < 4; i++) {
      final paint = Paint()
        ..color       = colors[i]
        ..style       = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.18
        ..strokeCap   = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.72),
        start, sweeps[i], false, paint,
      );
      start += sweeps[i];
    }

    // White bar for the horizontal part of G
    final barPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = size.width * 0.18
      ..strokeCap   = StrokeCap.round;
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + r * 0.68, cy),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// ══════════════════════════════════════════════════════════════
//  Step 2 — Set new PIN
// ══════════════════════════════════════════════════════════════
class _NewPinStep extends StatelessWidget {
  const _NewPinStep({
    required this.newPin,
    required this.confirmPin,
    required this.confirming,
    required this.shakeAnim,
    required this.onKey,
    required this.onDelete,
    required this.rs,
  });

  final List<String>      newPin, confirmPin;
  final bool              confirming;
  final Animation<double> shakeAnim;
  final void Function(String) onKey;
  final VoidCallback      onDelete;
  final Rs                rs;

  @override
  Widget build(BuildContext context) {
    final current = confirming ? confirmPin : newPin;

    return Column(children: [

      SizedBox(height: rs.sp(16)),

      Padding(
        padding: EdgeInsets.symmetric(horizontal: rs.sp(24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [

            Container(
              width: rs.sp(64), height: rs.sp(64),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.12),
                border: Border.all(
                    color: Colors.white.withOpacity(0.3), width: 1.5),
              ),
              child: Icon(
                confirming
                    ? Icons.check_circle_outline_rounded
                    : Icons.pin_outlined,
                color: Colors.white, size: rs.sp(28),
              ),
            ),

            SizedBox(height: rs.sp(24)),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              child: Column(
                key: ValueKey(confirming),
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    confirming
                        ? context.tr(S.pinConfirmNewTitle)
                        : context.tr(S.pinSetNewTitle),
                    style: GoogleFonts.sora(
                      color:      Colors.white,
                      fontSize:   rs.sp(26),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: rs.sp(6)),
                  Text(
                    confirming
                        ? context.tr(S.pinReenterNew)
                        : context.tr(S.pinChooseNew),
                    style: GoogleFonts.dmSans(
                      color:    Colors.white.withOpacity(0.6),
                      fontSize: rs.sp(13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      const Spacer(),

      // Glass card with PIN dots + numpad
      Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(36)),
          border: Border.all(
              color: Colors.white.withOpacity(0.13), width: 1),
        ),
        padding: EdgeInsets.fromLTRB(
            rs.sp(20), rs.sp(20), rs.sp(20), rs.sp(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            Container(
              width:  rs.sp(36),
              height: rs.sp(4),
              margin: EdgeInsets.only(bottom: rs.sp(24)),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            AnimatedBuilder(
              animation: shakeAnim,
              builder: (_, child) => Transform.translate(
                offset: Offset(shakeAnim.value, 0), child: child,
              ),
              child: PinDots(
                  filled: current.length, rs: rs, dark: true),
            ),

            SizedBox(height: rs.sp(28)),

            NumPad(
                onKey:    onKey,
                onDelete: onDelete,
                rs:       rs,
                dark:     true),

            SizedBox(height: rs.sp(12)),
          ],
        ),
      ),
    ]);
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