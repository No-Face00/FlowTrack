// lib/features/auth/presentation/auth_screen.dart
// Redesigned: no emojis, properly-spaced header, non-overlapping tab pill

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/appRouter.dart';
import '../../../core/utils/responsive_helper.dart';
import '../cubit/auth_cubit.dart';
import '../widgets/auth_widgets.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthCubit(),
      child: const _AuthView(),
    );
  }
}

class _AuthView extends StatefulWidget {
  const _AuthView();
  @override
  State<_AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<_AuthView>
    with SingleTickerProviderStateMixin {

  late final TabController _tab = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);

    return BlocListener<AuthCubit, AuthState>(
      listener: (ctx, state) {
        // First-time user → set up PIN
        if (state is AuthNeedsPinSetup) ctx.go(AppRoutes.pinSetup);
        // Returning user → enter existing PIN
        if (state is AuthNeedsPinLock)  ctx.go(AppRoutes.pinLock);
        if (state is AuthError) {
          AuthWidgets.showErrorSnackbar(ctx, state.message);
        }
        if (state is AuthPasswordResetSent) {
          AuthWidgets.showSuccessSnackbar(
              ctx, 'Reset link sent! Check your inbox.');
          _tab.animateTo(0);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.bgLavender,
        body: Column(
          children: [
            _AuthHeader(tab: _tab, rs: rs),
            Expanded(
              child: TabBarView(
                controller: _tab,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  SignInForm(rs: rs),
                  SignUpForm(rs: rs),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Header — gradient background + tab pill anchored at the
//  bottom edge of the blue section with NO overlap into content
// ══════════════════════════════════════════════════════════════
class _AuthHeader extends StatelessWidget {
  const _AuthHeader({required this.tab, required this.rs});
  final TabController tab;
  final Rs rs;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: tab,
      builder: (_, __) {
        final isLogin  = tab.index == 0;
        final pillH    = rs.sp(52);
        // The pill is rendered INSIDE the stack, flush to the bottom.
        // We add bottom padding equal to pillH + spacing so content
        // never overlaps the pill.
        final bottomPad = pillH + rs.sp(-15);

        return Stack(
          clipBehavior: Clip.none,
          children: [

            // ── Blue gradient header ──────────────────────
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin:  Alignment.topLeft,
                  end:    Alignment.bottomRight,
                  colors: [
                    AppColors.midnight,
                    AppColors.deepBlue,
                    AppColors.royalBlue,
                  ],
                  stops: [0.0, 0.50, 1.0],
                ),
              ),
              // Extra bottom padding to make room for the pill
              padding: EdgeInsets.only(bottom: bottomPad),
              child: Stack(
                children: [

                  // Decorative orbs
                  Positioned(
                    top:  -rs.sp(50),
                    left: -rs.sp(40),
                    child: _Orb(rs.sp(180), 0.06),
                  ),
                  Positioned(
                    top:   rs.sp(5),
                    right: -rs.sp(55),
                    child: _Orb(rs.sp(200), 0.05),
                  ),
                  Positioned(
                    bottom: rs.sp(40),
                    right:  rs.sp(20),
                    child:  _Orb(rs.sp(110), 0.07),
                  ),

                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        rs.sp(24),
                        rs.sp(14),
                        rs.sp(24),
                        rs.sp(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          // ── Logo row ─────────────────────
                          Row(
                            children: [
                              Container(
                                width:  rs.sp(42),
                                height: rs.sp(42),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(rs.sp(12)),
                                  color: Colors.white.withOpacity(0.15),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.25),
                                    width: 1.2,
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.trending_up_rounded,
                                    color: Colors.white,
                                    size:  rs.sp(20),
                                  ),
                                ),
                              ),
                              SizedBox(width: rs.sp(12)),
                              Text(
                                'FlowTrack',
                                style: GoogleFonts.sora(
                                  color:         Colors.white,
                                  fontSize:      rs.sp(20),
                                  fontWeight:    FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: rs.sp(22)),

                          // ── Animated title + subtitle ─────
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, anim) =>
                                FadeTransition(
                                  opacity: anim,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 0.12),
                                      end:   Offset.zero,
                                    ).animate(anim),
                                    child: child,
                                  ),
                                ),
                            child: Column(
                              key: ValueKey(isLogin),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isLogin
                                      ? 'Welcome Back  '
                                      : 'Create Account',
                                  style: GoogleFonts.sora(
                                    color:      Colors.white,
                                    fontSize:   rs.sp(28),
                                    fontWeight: FontWeight.w800,
                                    height:     1.2,
                                  ),
                                ),
                                SizedBox(height: rs.sp(6)),
                                Text(
                                  isLogin
                                      ? 'Sign in to continue to FlowTrack'
                                      : 'Start tracking your finances today',
                                  style: GoogleFonts.dmSans(
                                    color:      Colors.white.withOpacity(0.65),
                                    fontSize:   rs.sp(13),
                                    fontWeight: FontWeight.w400,
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

            // ── Tab Pill — anchored at bottom of header ───
            // Positioned so that pill sits HALF inside blue, HALF in white:
            // bottom: -(pillH/2) makes exactly 50/50 split between sections
            Positioned(
              bottom: -(pillH / 2),
              left:   rs.sp(20),
              right:  rs.sp(20),
              child: _TabPill(
                tab:    tab,
                rs:     rs,
                height: pillH,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Segmented Tab Pill ─────────────────────────────────────────
class _TabPill extends StatelessWidget {
  const _TabPill({required this.tab, required this.rs, required double height});
  final TabController tab;
  final Rs rs;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: rs.sp(60),
      decoration: BoxDecoration(
        color:        AppColors.white,
        borderRadius: BorderRadius.circular(rs.sp(28)),
        boxShadow: [
          BoxShadow(
            color:      AppColors.royalBlue.withOpacity(0.14),
            blurRadius: rs.sp(28),
            offset:     const Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(rs.sp(6), rs.sp(6), rs.sp(6), rs.sp(8)),
      child: TabBar(
        controller:     tab,
        dividerColor:   Colors.transparent,
        indicatorColor: Colors.transparent,
        labelPadding:   EdgeInsets.zero,
        splashFactory:  NoSplash.splashFactory,
        indicator: BoxDecoration(
          shape:        BoxShape.rectangle,
          borderRadius: BorderRadius.circular(rs.sp(20)),
          gradient:     AppColors.buttonGradient,
          boxShadow: [
            BoxShadow(
              color:      AppColors.royalBlue.withOpacity(0.35),
              blurRadius: rs.sp(12),
              offset:     const Offset(0, 3),
            ),
          ],
        ),
        labelStyle: GoogleFonts.dmSans(
          fontSize:      rs.sp(15),
          fontWeight:    FontWeight.w700,
          letterSpacing: 0.3,
        ),
        unselectedLabelStyle: GoogleFonts.dmSans(
          fontSize:      rs.sp(14),
          fontWeight:    FontWeight.w600,
        ),
        labelColor:           AppColors.white,
        unselectedLabelColor: const Color(0xFF8B92A9),
        tabs: [
          Tab(
            height: rs.sp(50),
            child: Align(
              alignment: Alignment.center,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: rs.sp(24)),
                child: const Text('Sign In'),
              ),
            ),
          ),
          Tab(
            height: rs.sp(50),
            child: Align(
              alignment: Alignment.center,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: rs.sp(24)),
                child: const Text('Sign Up'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Decorative orb ─────────────────────────────────────────────
class _Orb extends StatelessWidget {
  const _Orb(this.size, this.opacity, {super.key});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
    width:  size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withOpacity(opacity),
    ),
  );
}