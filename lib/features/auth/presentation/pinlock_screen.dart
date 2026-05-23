// lib/features/auth/presentation/pinlock_screen.dart
//
// Refactored to use PinScaffold — fully responsive on all devices.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/router/appRouter.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/widgets/premium_snackbar.dart';
import '../cubit/pin_cubit.dart';
import '../widgets/pin_layout.dart';
import '../widgets/pin_widgets.dart';

class PinLockScreen extends StatefulWidget {
  const PinLockScreen({super.key});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen>
    with TickerProviderStateMixin {
  final List<String> _pin = [];
  bool _bioAvailable = false;

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
      vsync: this, duration: const Duration(milliseconds: 900))
    ..forward();

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    final enabled =
    await context.read<PinCubit>().isBiometricsEnabled();
    if (!mounted) return;
    setState(() => _bioAvailable = enabled);
    if (enabled) {
      Future.delayed(
          const Duration(milliseconds: 600), _doBiometrics);
    }
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
    final userId =
        FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    context
        .read<PinCubit>()
        .verifyPin(pin: _pin.join(), userId: userId);
  }

  void _showSnack(String msg) =>
      AppSnack.show(context, message: msg, type: SnackType.error);

  void _forgotPin() => context.push(AppRoutes.pinReset);

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);

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
            context
                .tr(S.pinWrongAttempt)
                .replaceAll('{n}', '${state.attemptsLeft}')
                .replaceAll(
                '{s}', state.attemptsLeft == 1 ? '' : 's'),
          );
        } else if (state is PinError) {
          setState(() => _pin.clear());
          state.message.contains('Too many')
              ? ctx.go(AppRoutes.login)
              : _showSnack(state.message);
        }
      },
      child: LayoutBuilder(builder: (context, constraints) {
        final avH = constraints.maxHeight;
        final avW = constraints.maxWidth;
        final hPad = (avW * 0.09).clamp(20.0, 56.0);
        final gap = (avW * 0.038).clamp(8.0, 18.0);
        final keyW = ((avW - 2 * hPad - 2 * gap) / 3).clamp(56.0, 88.0);
        final keyH = (keyW * 0.95).clamp(48.0, 80.0);
        final rowVPad = (avH * 0.008).clamp(4.0, 10.0);
        final numpadH = 4 * keyH + 8 * rowVPad;
        final handleTopPad = (avH * 0.012).clamp(8.0, 18.0);
        final handleBotPad = (avH * 0.016).clamp(10.0, 22.0);
        final dotsBotPad = (avH * 0.015).clamp(8.0, 22.0);
        final dotsTopPad = (avH * 0.014).clamp(8.0, 20.0);
        final extraTopPad = (avH * 0.012).clamp(6.0, 16.0);
        final extraBotPad = (avH * 0.012).clamp(6.0, 18.0);
        final topGap = (avH * 0.018).clamp(8.0, 24.0);
        final glassCardH = handleTopPad +
            4.0 +
            handleBotPad +
            dotsTopPad +
            rs.sp(16) +
            dotsBotPad +
            numpadH +
            extraTopPad +
            48.0 +
            extraBotPad;
        final topZoneH =
        (avH - glassCardH - topGap).clamp(80.0, avH * 0.45);

        return PinScaffold(
          pinLength: _pin.length,
          shakeAnimation: _shakeAnim,
          onKey: _onKey,
          onDelete: _onDelete,
          bottomExtra: _LockBottomExtras(
            bioAvailable: _bioAvailable,
            onBiometrics: _doBiometrics,
            onForgotPin: _forgotPin,
            rs: rs,
          ),
          topContent: PinEntrance(
            controller: _entranceCtrl,
            interval: const Interval(0.0, 0.7),
            child: _LockTopContent(
              topZoneH: topZoneH,
              rs: rs,
            ),
          ),
        );
      }),
    );
  }
}

// ── Top content ──────────────────────────────────────────────
class _LockTopContent extends StatelessWidget {
  const _LockTopContent({
    required this.topZoneH,
    required this.rs,
  });
  final double topZoneH;
  final Rs rs;

  @override
  Widget build(BuildContext context) {
    return PinTopContent(
      icon: PinGlowIcon(
        icon: Icons.lock_rounded,
        rs: rs,
        topZoneH: topZoneH,
      ),
      title: context.tr(S.pinWelcomeBack),
      subtitle: context.tr(S.pinEnterHint),
      subtitleIcon: Icons.shield_rounded,
      rs: rs,
      topZoneH: topZoneH,
    );
  }
}

// ── Bottom extras (biometrics + forgot PIN) ──────────────────
class _LockBottomExtras extends StatelessWidget {
  const _LockBottomExtras({
    required this.bioAvailable,
    required this.onBiometrics,
    required this.onForgotPin,
    required this.rs,
  });
  final bool bioAvailable;
  final VoidCallback onBiometrics, onForgotPin;
  final Rs rs;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (bioAvailable) ...[
          _BiometricButton(onTap: onBiometrics, rs: rs),
          SizedBox(height: rs.sp(12).clamp(8.0, 18.0)),
        ],
        GestureDetector(
          onTap: onForgotPin,
          child: Text(
            context.tr(S.pinForgot),
            style: GoogleFonts.dmSans(
              color: Colors.white.withOpacity(0.55),
              fontSize: rs.sp(13).clamp(11.0, 15.0),
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
              decorationColor: Colors.white.withOpacity(0.3),
            ),
          ),
        ),
      ],
    );
  }
}

class _BiometricButton extends StatelessWidget {
  const _BiometricButton(
      {required this.onTap, required this.rs});
  final VoidCallback onTap;
  final Rs rs;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: rs.sp(52).clamp(40.0, 60.0),
          height: rs.sp(52).clamp(40.0, 60.0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.12),
            border: Border.all(
                color: Colors.white.withOpacity(0.3), width: 1.5),
          ),
          child: Icon(Icons.fingerprint,
              color: Colors.white.withOpacity(0.85),
              size: rs.sp(26).clamp(20.0, 30.0)),
        ),
        SizedBox(height: rs.sp(6).clamp(4.0, 8.0)),
        Text(
          context.tr(S.pinUseBiometrics),
          style: GoogleFonts.dmSans(
            color: Colors.white.withOpacity(0.5),
            fontSize: rs.sp(12).clamp(10.0, 14.0),
            fontWeight: FontWeight.w500,
          ),
        ),
      ]),
    );
  }
}