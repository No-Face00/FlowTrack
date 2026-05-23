// lib/features/pin/presentation/pin_setup_screen.dart
//
// FLOW: /pin-setup → PIN set + confirmed → /welcome → /home
// Refactored to use PinScaffold — fully responsive on all devices.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/router/appRouter.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/widgets/premium_snackbar.dart';
import '../cubit/pin_cubit.dart';
import '../widgets/pin_layout.dart';
import '../widgets/pin_widgets.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen>
    with TickerProviderStateMixin {
  final List<String> _pin = [];
  List<String> _firstPin = [];
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
      vsync: this, duration: const Duration(milliseconds: 900))
    ..forward();

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _entranceCtrl.dispose();
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
      setState(() {
        _firstPin = List.from(_pin);
        _confirming = true;
        _pin.clear();
      });
    } else {
      if (_pin.join() == _firstPin.join()) {
        final userId =
            FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
        if (!mounted) return;
        context
            .read<PinCubit>()
            .savePin(pin: _pin.join(), userId: userId);
      } else {
        _shakeCtrl.forward(from: 0);
        HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 440));
        if (!mounted) return;
        setState(() {
          _pin.clear();
          _confirming = false;
          _firstPin.clear();
        });
        _showSnack(context.tr(S.pinMismatch));
      }
    }
  }

  void _showSnack(String msg) =>
      AppSnack.show(context, message: msg, type: SnackType.error);

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);

    return BlocListener<PinCubit, PinState>(
      listener: (ctx, state) {
        if (state is PinSetSuccess) {
          AppRouter.markPinJustSet();
          ctx.go(AppRoutes.welcome);
        }
        if (state is PinError) _showSnack(state.message);
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
        final handleBotPad = (avH * 0.016).clamp(10.0, 22.0);
        final handleTopPad = (avH * 0.012).clamp(8.0, 18.0);
        final dotsBotPad = (avH * 0.015).clamp(8.0, 22.0);
        final dotsTopPad = (avH * 0.014).clamp(8.0, 20.0);
        final extraBotPad = (avH * 0.012).clamp(6.0, 18.0);
        final topGap = (avH * 0.018).clamp(8.0, 24.0);
        final glassCardH = handleTopPad +
            4.0 +
            handleBotPad +
            dotsTopPad +
            rs.sp(16) +
            dotsBotPad +
            numpadH +
            extraBotPad;
        final topZoneH =
        (avH - glassCardH - topGap).clamp(80.0, avH * 0.45);

        return PinScaffold(
          pinLength: _pin.length,
          shakeAnimation: _shakeAnim,
          onKey: _onKey,
          onDelete: _onDelete,
          bottomExtra: _SetupHint(rs: rs),
          topContent: PinEntrance(
            controller: _entranceCtrl,
            interval: const Interval(0.0, 0.8),
            child: _SetupTopContent(
              confirming: _confirming,
              topZoneH: topZoneH,
              rs: rs,
            ),
          ),
        );
      }),
    );
  }
}

// ── Top content for setup ─────────────────────────────────────
class _SetupTopContent extends StatelessWidget {
  const _SetupTopContent({
    required this.confirming,
    required this.topZoneH,
    required this.rs,
  });
  final bool confirming;
  final double topZoneH;
  final Rs rs;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
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
      child: Column(
        key: ValueKey(confirming),
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepIndicator(confirming: confirming, rs: rs),
          SizedBox(height: (topZoneH * 0.06).clamp(8.0, 20.0)),
          PinTopContent(
            icon: PinGlowIcon(
              icon: confirming
                  ? Icons.check_circle_outline_rounded
                  : Icons.pin_outlined,
              rs: rs,
              topZoneH: topZoneH,
              switchKey: ValueKey(confirming),
            ),
            title: confirming
                ? context.tr(S.pinConfirmTitle)
                : context.tr(S.pinCreateTitle),
            subtitle: confirming
                ? context.tr(S.pinReenterConfirm)
                : context.tr(S.pinChooseSecure),
            subtitleIcon: confirming
                ? Icons.repeat_rounded
                : Icons.security_rounded,
            rs: rs,
            topZoneH: topZoneH,
          ),
        ],
      ),
    );
  }
}

// ── Hint below numpad ─────────────────────────────────────────
class _SetupHint extends StatelessWidget {
  const _SetupHint({required this.rs});
  final Rs rs;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.fingerprint,
            color: Colors.white.withOpacity(0.35),
            size: rs.sp(16).clamp(12.0, 20.0)),
        SizedBox(width: rs.sp(6).clamp(4.0, 8.0)),
        Text(
          context.tr(S.pinUpdateHint),
          style: GoogleFonts.dmSans(
            color: Colors.white.withOpacity(0.35),
            fontSize: rs.sp(11).clamp(10.0, 13.0),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── Step indicator chips ──────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  const _StepIndicator(
      {required this.confirming, required this.rs});
  final bool confirming;
  final Rs rs;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Chip(
            label: context.tr(S.pinStepSet),
            active: !confirming,
            done: confirming,
            rs: rs),
        Padding(
          padding: EdgeInsets.symmetric(
              horizontal: rs.sp(8).clamp(4.0, 12.0)),
          child: Container(
            width: rs.sp(20).clamp(12.0, 24.0),
            height: 1,
            color: Colors.white.withOpacity(0.3),
          ),
        ),
        _Chip(
            label: context.tr(S.pinStepConfirm),
            active: confirming,
            done: false,
            rs: rs),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.active,
    required this.done,
    required this.rs,
  });
  final String label;
  final bool active, done;
  final Rs rs;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.symmetric(
        horizontal: rs.sp(14).clamp(8.0, 18.0),
        vertical: rs.sp(6).clamp(4.0, 9.0),
      ),
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
                color: const Color(0xFF00E096),
                size: rs.sp(13).clamp(10.0, 16.0)),
            SizedBox(width: rs.sp(4).clamp(2.0, 6.0)),
          ],
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: active
                  ? Colors.white
                  : done
                  ? const Color(0xFF00E096)
                  : Colors.white.withOpacity(0.4),
              fontSize: rs.sp(12).clamp(10.0, 14.0),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}