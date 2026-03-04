// lib/features/onboarding/presentation/onboarding_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/router/appRouter.dart';

import '../../../core/utils/responsive_helper.dart';
import '../widget/onboarding_widgets.dart';
import 'onboarding_models.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {

  // ── Page ──────────────────────────────────────────────────
  final _pageCtrl = PageController();
  int _page = 0;

  // ── Animation controllers ─────────────────────────────────
  late final _emojiCtrl = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 650),
  );
  late final _textCtrl = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 520),
  );
  late final _particleCtrl = AnimationController(
    vsync: this, duration: const Duration(seconds: 3),
  )..repeat();
  late final _pulseCtrl = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  // ── Animations ────────────────────────────────────────────
  late final _emojiScale =
  CurvedAnimation(parent: _emojiCtrl, curve: Curves.elasticOut);

  late final _emojiFade = Tween<double>(begin: 0, end: 1).animate(
    CurvedAnimation(
      parent: _emojiCtrl,
      curve: const Interval(0, 0.4, curve: Curves.easeIn),
    ),
  );

  late final _textSlide =
  Tween<Offset>(begin: const Offset(0, 0.28), end: Offset.zero).animate(
      CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic));

  late final _textFade =
  CurvedAnimation(parent: _textCtrl, curve: Curves.easeIn);

  late final _btnPulse = Tween<double>(begin: 1.0, end: 1.035).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

  // ─────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:           Colors.transparent,
      statusBarIconBrightness:  Brightness.light,
      systemNavigationBarColor: Colors.transparent,
    ));
    _playEntrance();
  }

  void _playEntrance() {
    _emojiCtrl.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _textCtrl.forward(from: 0);
    });
  }

  void _onPageChanged(int p) {
    setState(() => _page = p);
    _playEntrance();
  }

  void _next() {
    if (_page < kSlides.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 460),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _goToAuth();
    }
  }

  // ── Navigate to login + mark onboarding done ──────────────
  // Safe: wrapped in try/catch so a prefs failure never blocks
  // the user from moving forward.
  Future<void> _goToAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('seen_onboarding', true);
    } catch (e) {
      // Prefs failed — not critical, user can still proceed.
      // On next launch onboarding will show again, which is fine.
      debugPrint('⚠️ Could not save onboarding flag: $e');
    }

    // Navigate — context.go replaces the full stack so the user
    // cannot go back to onboarding by pressing the back button.
    if (mounted) context.go(AppRoutes.login);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _emojiCtrl.dispose();
    _textCtrl.dispose();
    _particleCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);

    return Scaffold(
      body: Stack(
        children: [

          // ── 1. PageView ──────────────────────
          PageView.builder(
            controller:    _pageCtrl,
            onPageChanged: _onPageChanged,
            itemCount:     kSlides.length,
            itemBuilder: (_, i) => SlidePage(
              slide:        kSlides[i],
              rs:           rs,
              emojiScale:   _emojiScale,
              emojiFade:    _emojiFade,
              textSlide:    _textSlide,
              textFade:     _textFade,
              particleCtrl: _particleCtrl,
              isActive:     i == _page,
            ),
          ),

          // ── 2. Bottom controls ───────────────
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: BottomControls(
              rs:     rs,
              page:   _page,
              total:  kSlides.length,
              pulse:  _btnPulse,
              onNext: _next,
            ),
          ),

          // ── 3. Skip button ───────────────────
          if (_page < kSlides.length - 1)
            Positioned(
              top:   rs.pad.top + rs.sp(12),
              right: rs.sp(20),
              child: SkipBtn(rs: rs, onTap: _goToAuth),
            ),

        ],
      ),
    );
  }
}