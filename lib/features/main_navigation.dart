// lib/features/home/presentation/main_navigation.dart

import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import '../core/constants/app_colors.dart';
import '../core/l10n/l10n_extension.dart';
import '../core/router/appRouter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/cubit/app_cubit.dart';
import '../core/notifications/notification_cubit.dart';
import '../core/di/service_locator.dart';
import 'home/finance/finance_assistant_cubit.dart';
import 'home/finance/finance_assistant_prefs.dart';
import 'account/presentation/account_screen.dart';
import 'analytics/presentation/analytics_screen.dart';
import 'home/presentation/home_screen.dart';
import 'transactions/presentation/transaction_screen.dart';
import 'transactions/presentation/cubit/transaction_cubit.dart';
import 'transactions/presentation/cubit/balance_cubit.dart';

// ── Tab model ──────────────────────────────────────────────────
class _Tab {
  const _Tab({
    required this.labelKey,
    required this.icon,
    required this.activeIcon,
  });
  final String   labelKey;
  final IconData icon;
  final IconData activeIcon;
}

const _tabs = [
  _Tab(labelKey: 'nav_home',         icon: Icons.home_outlined,          activeIcon: Icons.home_rounded),
  _Tab(labelKey: 'nav_transactions', icon: Icons.receipt_long_outlined,  activeIcon: Icons.receipt_long_rounded),
  _Tab(labelKey: 'nav_analytics',    icon: Icons.bar_chart_outlined,     activeIcon: Icons.bar_chart_rounded),
  _Tab(labelKey: 'nav_account',      icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded),
];

// ══════════════════════════════════════════════════════════════
//  MainNavigation
// ══════════════════════════════════════════════════════════════
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => MainNavigationState();
}

class MainNavigationState extends State<MainNavigation>
    with TickerProviderStateMixin {
  int _current = 0;
  late final PageController _pageCtrl = PageController();

  late final AnimationController _fabCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
  );
  late final Animation<double> _fabScale = Tween(begin: 1.0, end: 0.88)
      .animate(CurvedAnimation(parent: _fabCtrl, curve: Curves.easeOut));

  final _screens = const [
    HomeScreen(),
    TransactionScreen(),
    AnalyticsScreen(),
    AccountScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FinanceAssistantPrefs.syncFromDisk();
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _fabCtrl.dispose();
    super.dispose();
  }

  void onTabTap(int index) {
    if (index == _current) return;
    HapticFeedback.selectionClick();
    setState(() => _current = index);
    _pageCtrl.animateToPage(index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOutCubic);
  }

  void _onFabTap() async {
    HapticFeedback.mediumImpact();
    await _fabCtrl.forward();
    await _fabCtrl.reverse();
    if (mounted) context.push(AppRoutes.addTransaction);
  }

  @override
  Widget build(BuildContext context) {
    // ── IMPORTANT: use BlocProvider.value(), NOT BlocProvider(create:) ──
    // BlocProvider(create:) takes ownership of the cubit and calls close()
    // when the widget is disposed. Since TransactionCubit and BalanceCubit
    // are lazySingletons in getIt, closing them breaks all future emit()
    // calls with "Bad state: Cannot emit new states after calling close".
    // BlocProvider.value() makes the cubit available in the tree WITHOUT
    // taking ownership — getIt remains the sole owner of the lifecycle.
    final txnCubit     = getIt<TransactionCubit>()..watchTransactions();
    final balanceCubit = getIt<BalanceCubit>();
    final appCubit     = getIt<AppCubit>()..load(); // load settings after login
    final notifCubit   = getIt<NotificationCubit>()..load();

    return MultiBlocProvider(
      providers: [
        BlocProvider<TransactionCubit>.value(value: txnCubit),
        BlocProvider<BalanceCubit>.value(value: balanceCubit),
        BlocProvider<AppCubit>.value(value: appCubit),
        BlocProvider<NotificationCubit>.value(value: notifCubit),
        BlocProvider<FinanceAssistantCubit>.value(
            value: getIt<FinanceAssistantCubit>()),
      ],
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        extendBody: true,
        body: PageView(
          controller:    _pageCtrl,
          physics:       const NeverScrollableScrollPhysics(),
          onPageChanged: (i) => setState(() => _current = i),
          children:      _screens,
        ),
        bottomNavigationBar: _BottomBar(
          current:  _current,
          onTap:    onTabTap,
          onFabTap: _onFabTap,
          fabScale: _fabScale,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  CustomClipper — notched pill shape
// ══════════════════════════════════════════════════════════════
class _NotchClipper extends CustomClipper<Path> {
  const _NotchClipper({required this.notchR, required this.cornerR});

  final double notchR;
  final double cornerR;

  @override
  Path getClip(Size size) => _buildNotchPath(size, notchR, cornerR);

  @override
  bool shouldReclip(_NotchClipper old) =>
      old.notchR != notchR || old.cornerR != cornerR;
}

Path _buildNotchPath(Size size, double notchR, double cornerR) {
  final cx = size.width / 2;
  final r  = notchR;
  final br = cornerR;
  final path = Path();
  path.moveTo(br, 0);
  path.lineTo(cx - r - 12, 0);
  path.quadraticBezierTo(cx - r, 0, cx - r, r * 0.3);
  path.arcToPoint(Offset(cx + r, r * 0.3),
      radius: Radius.circular(r), clockwise: false);
  path.quadraticBezierTo(cx + r, 0, cx + r + 12, 0);
  path.lineTo(size.width - br, 0);
  path.arcToPoint(Offset(size.width, br),
      radius: Radius.circular(br), clockwise: true);
  path.lineTo(size.width, size.height - br);
  path.arcToPoint(Offset(size.width - br, size.height),
      radius: Radius.circular(br), clockwise: true);
  path.lineTo(br, size.height);
  path.arcToPoint(Offset(0, size.height - br),
      radius: Radius.circular(br), clockwise: true);
  path.lineTo(0, br);
  path.arcToPoint(Offset(br, 0),
      radius: Radius.circular(br), clockwise: true);
  path.close();
  return path;
}

// ══════════════════════════════════════════════════════════════
//  Painter — 4-layer premium glass  (light + dark aware)
//
//  Layer A — translucent base fill
//            Low enough opacity that BackdropFilter blur bleeds
//            through in BOTH modes → real glassmorphism.
//
//  Layer B — top-edge inner highlight
//            Thin white shimmer at the top rim — the signature
//            "glass edge catches light" look.
//
//  Layer C — depth gradient
//            Radial falloff from center → gives curvature / warmth.
//
//  Layer D — crisp border stroke
//            Defines the glass edge cleanly without harshness.
// ══════════════════════════════════════════════════════════════
class _GlassBarPainter extends CustomPainter {
  const _GlassBarPainter({
    required this.notchR,
    required this.cornerR,
    required this.isDark,
  });

  final double notchR;
  final double cornerR;
  final bool   isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final path = _buildNotchPath(size, notchR, cornerR);

    if (isDark) {
      _paintDark(canvas, size, rect, path);
    } else {
      _paintLight(canvas, size, rect, path);
    }
  }

  // ── LIGHT MODE — original design, never modified ────────────
  void _paintLight(Canvas canvas, Size size, Rect rect, Path path) {
    // Layer A: white-blue glass fill
    canvas.drawPath(path, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end:   Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.30),
          const Color(0xFFB8CAFF).withOpacity(0.16),
        ],
      ).createShader(rect));

    // Layer B: top highlight shimmer
    canvas.drawPath(path, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end:   Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity(0.44),
          Colors.white.withOpacity(0.00),
        ],
        stops: const [0.0, 0.30],
      ).createShader(rect));

    // Layer C: border stroke
    canvas.drawPath(path, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end:   Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.65),
          Colors.white.withOpacity(0.28),
        ],
      ).createShader(rect)
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 1.0);
  }

  // ── DARK MODE — tuned dark version of the same glass identity ─
  // Design principles:
  //   • Same frosted-glass look as light, just with indigo tint
  //   • Fill opacity low (0.25–0.35) so blur bleeds through
  //   • Highlight STRONGER than light (no bright bg to fall back on)
  //   • Border gradient: bright top-left, dim bottom-right (angled light)
  //   • Faint inner indigo glow for app-hue warmth
  void _paintDark(Canvas canvas, Size size, Rect rect, Path path) {
    // Layer A: indigo-navy glass fill — genuinely translucent
    canvas.drawPath(path, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end:   Alignment.bottomRight,
        colors: [
          const Color(0xFF2E3B8A).withOpacity(0.32),  // indigo tint, low opacity
          const Color(0xFF141830).withOpacity(0.42),  // deep navy edge
        ],
      ).createShader(rect));

    // Layer B: top-edge highlight — stronger than light to define glass edge
    canvas.drawPath(path, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end:   Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity(0.18),  // glass surface catch
          Colors.white.withOpacity(0.00),
        ],
        stops: const [0.0, 0.28],
      ).createShader(rect));

    // Layer C: faint radial indigo glow (glass picks up dominant app hue)
    canvas.drawPath(path, Paint()
      ..shader = RadialGradient(
        center: Alignment.topCenter,
        radius: 1.1,
        colors: [
          const Color(0xFF4466EE).withOpacity(0.10),
          Colors.transparent,
        ],
      ).createShader(rect));

    // Layer D: angled border — bright where light hits, dim in shadow
    canvas.drawPath(path, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end:   Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.28),
          const Color(0xFF5566BB).withOpacity(0.12),
        ],
      ).createShader(rect)
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 1.0);
  }

  @override
  bool shouldRepaint(_GlassBarPainter old) => old.isDark != isDark;
}

// ══════════════════════════════════════════════════════════════
//  Bottom Bar
// ══════════════════════════════════════════════════════════════
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.current,
    required this.onTap,
    required this.onFabTap,
    required this.fabScale,
  });

  final int                current;
  final void Function(int) onTap;
  final VoidCallback       onFabTap;
  final Animation<double>  fabScale;

  static const double _barHeight   = 68.0;
  static const double _notchR      = 34.0;
  static const double _cornerR     = 38.0;
  static const double _fabDiameter = 56.0;
  static const double _fabLift     = 12.0;

  @override
  Widget build(BuildContext context) {
    final sysPad      = MediaQuery.of(context).padding.bottom;
    final bottomInset = sysPad > 0 ? sysPad + 8 : 16.0;
    final totalHeight = _barHeight + _fabLift + bottomInset + 4;

    return SizedBox(
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Glassmorphism bar ────────────────────────────
          Positioned(
            left:   16,
            right:  16,
            bottom: bottomInset,
            height: _barHeight,
            child: Builder(builder: (context) {
              final isDarkMode = Theme.of(context).brightness == Brightness.dark;
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_cornerR),
                  boxShadow: isDarkMode ? [
                    // ── DARK MODE shadows ──────────────────────
                    // Outer indigo glow (softer than light to avoid harshness)
                    BoxShadow(
                      color:        const Color(0xFF3355EE).withOpacity(0.30),
                      blurRadius:   28,
                      spreadRadius: 0,
                      offset:       const Offset(0, 8),
                    ),
                    // Ambient ground shadow
                    BoxShadow(
                      color:      Colors.black.withOpacity(0.22),
                      blurRadius: 14,
                      offset:     const Offset(0, 4),
                    ),
                    // Upward indigo lift — floating glass feel
                    BoxShadow(
                      color:        const Color(0xFF4466FF).withOpacity(0.14),
                      blurRadius:   12,
                      spreadRadius: 0,
                      offset:       const Offset(0, -3),
                    ),
                  ] : [
                    // ── LIGHT MODE shadows — original, unchanged ─
                    BoxShadow(
                      color:      const Color(0xFF2244EE).withOpacity(0.43),
                      blurRadius: 28,
                      offset:     const Offset(0, 8),
                    ),
                    BoxShadow(
                      color:      Colors.black.withOpacity(0.07),
                      blurRadius: 12,
                      offset:     const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipPath(
                  clipper: _NotchClipper(notchR: _notchR, cornerR: _cornerR),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      // Original light mode sigma = 24 (unchanged).
                      // Dark mode: 36 — stronger blur visible through
                      // the lower-opacity dark fill.
                      sigmaX: isDarkMode ? 36 : 24,
                      sigmaY: isDarkMode ? 36 : 24,
                    ),
                    child: CustomPaint(
                      painter: _GlassBarPainter(
                        notchR:  _notchR,
                        cornerR: _cornerR,
                        isDark:  Theme.of(context).brightness == Brightness.dark,
                      ),
                      child: SizedBox(
                        height: _barHeight,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _NavItem(tab: _tabs[0], index: 0, current: current, onTap: onTap),
                            _NavItem(tab: _tabs[1], index: 1, current: current, onTap: onTap),
                            SizedBox(width: _notchR * 2 + 8),
                            _NavItem(tab: _tabs[2], index: 2, current: current, onTap: onTap),
                            _NavItem(tab: _tabs[3], index: 3, current: current, onTap: onTap),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );}),
          ),

          // ── Elevated FAB ─────────────────────────────────
          Positioned(
            left:   0,
            right:  0,
            bottom: bottomInset + _barHeight - _fabDiameter / 2 - _fabLift,
            child:  Center(
              child: _FabButton(onTap: onFabTap, scale: fabScale),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Individual nav tab item
//
//  ✅ DUPLICATE KEY FIX:
//  The old code used AnimatedSwitcher which keeps BOTH the old
//  and new child alive in its internal Stack during the crossfade.
//  When two tabs are both inactive they each produce an Icon with
//  the same ValueKey string (e.g. 'icon_1_false') → Flutter finds
//  two identical keys in the same Stack → crash.
//
//  Fix: remove AnimatedSwitcher entirely. Instead, overlay the
//  active and inactive icons with two AnimatedOpacity widgets in
//  a plain Stack. Each icon lives in its own separate subtree,
//  no shared parent Stack, no key collisions — ever.
// ══════════════════════════════════════════════════════════════
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.index,
    required this.current,
    required this.onTap,
  });

  final _Tab               tab;
  final int                index;
  final int                current;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final isActive = index == current;

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width:  62,
        height: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize:      MainAxisSize.min,
          children: [
            // Active pill highlight
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve:    Curves.easeOutCubic,
              width:    isActive ? 46 : 36,
              height:   30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                // ── Light mode pill: original design ─────────────
                // ── Dark mode pill: same structure, dark-tuned ───
                gradient: isActive
                    ? (Theme.of(context).brightness == Brightness.dark
                    ? LinearGradient(
                  begin: Alignment.topCenter,
                  end:   Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.16),        // glass top shimmer
                    AppColors.royalBlue.withOpacity(0.18), // indigo body
                  ],
                )
                    : null)   // light mode uses solid color below, not gradient
                    : null,
                color: isActive && Theme.of(context).brightness != Brightness.dark
                    ? AppColors.royalBlue.withOpacity(0.13)  // ORIGINAL light value
                    : Colors.transparent,
                border: isActive
                    ? Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withOpacity(0.20)           // subtle glass rim
                      : AppColors.royalBlue.withOpacity(0.25),   // ORIGINAL light value
                  width: 1.0,
                )
                    : null,
                boxShadow: isActive
                    ? (Theme.of(context).brightness == Brightness.dark
                    ? [
                  BoxShadow(
                    color:      AppColors.royalBlue.withOpacity(0.35),
                    blurRadius: 14,
                    spreadRadius: 0,
                  ),
                ]
                    : [
                  BoxShadow(       // ORIGINAL light value
                    color:      AppColors.royalBlue.withOpacity(0.18),
                    blurRadius: 10,
                  ),
                ])
                    : null,
              ),
              // ── Two overlapping icons, each in its own AnimatedOpacity ──
              // No AnimatedSwitcher = no shared Stack = zero key conflicts.
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Inactive icon — fades out when active
                  AnimatedOpacity(
                    opacity:  isActive ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      tab.icon,
                      size:  20,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFAAABD4)   // soft indigo-grey, readable on dark glass
                          : Colors.black.withOpacity(0.75),  // ORIGINAL light value
                    ),
                  ),
                  // Active icon — fades in when active
                  AnimatedOpacity(
                    opacity:  isActive ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      tab.activeIcon,
                      size:  20,
                      color: AppColors.royalBlue,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 3),

            // Label
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: GoogleFonts.dmSans(
                fontSize:   9.5,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive
                    ? AppColors.royalBlue
                    : Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFAAABD4)   // soft indigo-grey, readable on dark glass
                    : Colors.black.withOpacity(0.75),  // ORIGINAL light value
              ),
              child: Text(context.tr(tab.labelKey)),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  FAB — glowing elevated orb
// ══════════════════════════════════════════════════════════════
class _FabButton extends StatelessWidget {
  const _FabButton({required this.onTap, required this.scale});

  final VoidCallback      onTap;
  final Animation<double> scale;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ScaleTransition(
        scale: scale,
        child: Container(
          width:  56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end:   Alignment.bottomRight,
              colors: [
                Color(0xFF6B85FF),
                Color(0xFF2244F0),
                Color(0xFF0011CC),
              ],
              stops: [0.0, 0.5, 1.0],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.42),
              width: 1.8,
            ),
            boxShadow: [
              BoxShadow(
                color:        const Color(0xFF2244FF).withOpacity(0.55),
                blurRadius:   24,
                spreadRadius: 2,
                offset:       const Offset(0, 6),
              ),
              BoxShadow(
                color:        Colors.black.withOpacity(0.12),
                blurRadius:   8,
                offset:       const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  ✨ SHIMMER WIDGETS
//  Add shimmer: ^3.0.0 to pubspec.yaml
//
//  Use NavShimmerLoader for transaction list loading states.
//  Use BalanceCardShimmer in place of BalanceCard while loading.
// ══════════════════════════════════════════════════════════════

/// Drop-in shimmer skeleton for the transaction list.
/// Usage: isLoading ? const NavShimmerLoader() : YourList()
class NavShimmerLoader extends StatelessWidget {
  const NavShimmerLoader({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor:      const Color(0xFFE8EAF6),
      highlightColor: const Color(0xFFFFFFFF),
      child: Column(
        children: List.generate(
          itemCount,
              (i) => const _ShimmerTransactionRow(),
        ),
      ),
    );
  }
}

class _ShimmerTransactionRow extends StatelessWidget {
  const _ShimmerTransactionRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          // Icon tile
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(width: 14),
          // Title + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 13,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 7),
                Container(
                  height: 10, width: 110,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Amount
          Container(
            height: 13, width: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      ),
    );
  }
}

/// Drop-in shimmer skeleton for the BalanceCard.
/// Usage: isLoading ? const BalanceCardShimmer() : const BalanceCard()
class BalanceCardShimmer extends StatelessWidget {
  const BalanceCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor:      const Color(0xFF1A2A8A),
      highlightColor: const Color(0xFF5566FF),
      child: Container(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // "This Month Spend" label
            Container(
              height: 12, width: 130,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 16),
            // Balance number
            Container(
              height: 52, width: 200,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            const SizedBox(height: 14),
            // Badge
            Container(
              height: 28, width: 155,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 22),
            // Income / Expense chips
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}