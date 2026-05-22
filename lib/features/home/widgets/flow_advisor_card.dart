// lib/features/home/widgets/flow_advisor_card.dart
//
// The Flow Advisor card shown on the Home screen.
// Displays AI-generated financial insights with:
//   • InsightType-aware colour coding
//   • Shimmer loading state
//   • Dismiss (X) and Refresh buttons
//   • Full localization via context.tr()

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/cubit/app_cubit.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../transactions/presentation/cubit/balance_cubit.dart';
import '../../transactions/presentation/cubit/transaction_cubit.dart';
import '../../budget/presentation/cubit/budget_cubit.dart';
import '../finance/finance_assistant_cubit.dart';
import '../finance/finance_assistant_prefs.dart';
import '../finance/insight_type.dart';

class FlowAdvisorCard extends StatelessWidget {
const FlowAdvisorCard({
super.key,
required this.onDismiss,
required this.onRefresh,
});

final VoidCallback onDismiss;
final VoidCallback onRefresh;

@override
Widget build(BuildContext context) {
final rs = Rs.of(context);

return BlocBuilder<FinanceAssistantCubit, FinanceAssistantState>(
bloc: getIt<FinanceAssistantCubit>(),
builder: (context, state) {
// ── Language change watcher (keeps card in sync) ─────────────────
// Watch AppCubit so the card rebuilds on language change and
// triggers a fresh AI generation.
final langCode = context.watch<AppCubit>().state.languageCode;

final isLoading = state is FinanceAssistantLoading ||
state is FinanceAssistantInitial;

final insight = state is FinanceAssistantLoaded ? state.insight : null;
final type    = state is FinanceAssistantLoaded
? state.type
    : InsightType.neutral;

final colors  = _typeColors(type, context);

return Container(
decoration: BoxDecoration(
gradient: LinearGradient(
begin: Alignment.topLeft,
end:   Alignment.bottomRight,
colors: [
colors.bgStart,
colors.bgEnd,
],
),
borderRadius: BorderRadius.circular(rs.sp(20)),
border: Border.all(color: colors.border, width: 1),
boxShadow: [
BoxShadow(
color:       colors.shadow,
blurRadius:  rs.sp(16),
offset:      Offset(0, rs.sp(4)),
),
],
),
padding: EdgeInsets.all(rs.sp(16)),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [

// ── Header row ──────────────────────────────────────────────
Row(children: [
_AiLottieIcon(colors: colors, size: rs.sp(34)),
SizedBox(width: rs.sp(10)),
Expanded(child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(children: [
Text(context.tr(S.flowAdvisor),
style: TextStyle(
fontSize: rs.sp(11),
fontWeight: FontWeight.w800,
color: colors.label,
letterSpacing: 1.0)),
SizedBox(width: rs.sp(6)),
Container(
padding: EdgeInsets.symmetric(
horizontal: rs.sp(6), vertical: rs.sp(2)),
decoration: BoxDecoration(
color:        colors.liveBg,
borderRadius: BorderRadius.circular(rs.sp(4)),
),
child: Text(context.tr(S.live),
style: TextStyle(
fontSize: rs.sp(8),
fontWeight: FontWeight.w700,
color: colors.liveFg,
letterSpacing: 0.8)),
),
]),
SizedBox(height: rs.sp(1)),
Text(context.tr(S.flowAdvisorSub),
style: TextStyle(
fontSize: rs.sp(10),
color: colors.subtitle,
fontWeight: FontWeight.w500)),
],
)),

// Action buttons
_ActionBtn(
icon:    Icons.refresh_rounded,
color:   colors.actionBtn,
tooltip: context.tr(S.flowAdvisorRefresh),
onTap:   () {
final txState  = context.read<TransactionCubit>().state;
final balState = context.read<BalanceCubit>().state;
final budState = getIt<BudgetCubit>().state;
getIt<FinanceAssistantCubit>().forceRefresh(
tx:           txState,
bal:          balState,
bud:          budState,
currencyCode: getIt<AppCubit>().state.currency,
);
},
),
SizedBox(width: rs.sp(6)),
_ActionBtn(
icon:    Icons.close_rounded,
color:   colors.actionBtn,
tooltip: context.tr(S.flowAdvisorDismiss),
onTap:   () async {
await FinanceAssistantPrefs.setVisible(false);
onDismiss();
},
),
]),

SizedBox(height: rs.sp(12)),
Divider(color: colors.divider, height: 1),
SizedBox(height: rs.sp(12)),

// ── Insight text / shimmer ───────────────────────────────────
if (isLoading)
_InsightShimmer(rs: rs, color: colors.shimmer)
else if (insight != null)
AnimatedSwitcher(
duration: const Duration(milliseconds: 260),
switchInCurve: Curves.easeOutCubic,
switchOutCurve: Curves.easeInCubic,
transitionBuilder: (child, anim) {
final slide = Tween<Offset>(
begin: const Offset(0.0, 0.12),
end: Offset.zero,
).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
return FadeTransition(
opacity: anim,
child: SlideTransition(position: slide, child: child),
);
},
child: Text(
insight,
key: ValueKey(insight),
style: TextStyle(
fontSize: rs.sp(13),
color: colors.text,
height: 1.55,
fontWeight: FontWeight.w500,
),
),
)
else
Text(context.tr(S.flowAdvisorEmpty),
style: TextStyle(
fontSize:   rs.sp(13),
color:      colors.text.withOpacity(0.7),
height:     1.55)),
],
),
);
},
);
}

// ── Color scheme per insight type ───────────────────────────────────────────

_CardColors _typeColors(InsightType type, BuildContext context) {
final isDark = Theme.of(context).brightness == Brightness.dark;
return switch (type) {
InsightType.warning    => _CardColors.warning(isDark),
InsightType.motivation => _CardColors.motivation(isDark),
InsightType.saving     => _CardColors.saving(isDark),
InsightType.spending   => _CardColors.spending(isDark),
InsightType.neutral    => _CardColors.neutral(isDark),
};
}

IconData _typeIcon(InsightType type) => switch (type) {
InsightType.warning    => Icons.warning_amber_rounded,
InsightType.motivation => Icons.emoji_events_rounded,
InsightType.saving     => Icons.savings_rounded,
InsightType.spending   => Icons.trending_up_rounded,
InsightType.neutral    => Icons.auto_awesome_rounded,
};
}

class _AiLottieIcon extends StatefulWidget {
  const _AiLottieIcon({required this.colors, required this.size});
  final _CardColors colors;
  final double size;

  @override
  State<_AiLottieIcon> createState() => _AiLottieIconState();
}

class _AiLottieIconState extends State<_AiLottieIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        final t = Curves.easeInOut.transform(_pulse.value);
        final glow = 0.18 + (t * 0.18);
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.size / 2.6),
            color: c.iconBg,
            boxShadow: [
              BoxShadow(
                color: c.iconFg.withOpacity(glow),
                blurRadius: 18,
                spreadRadius: 1.0,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.size / 2.6),
            child: Lottie.asset(
              'assets/icons/AI_Assist.json',
              fit: BoxFit.contain,
              repeat: true,
              animate: true,
              frameRate: FrameRate.max,
            ),
          ),
        );
      },
    );
  }
}

// ── Action button ────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
const _ActionBtn({
required this.icon,
required this.color,
required this.tooltip,
required this.onTap,
});
final IconData  icon;
final Color     color;
final String    tooltip;
final VoidCallback onTap;

@override
Widget build(BuildContext context) {
final rs = Rs.of(context);
return Tooltip(
message: tooltip,
child: GestureDetector(
onTap: onTap,
child: Container(
padding: EdgeInsets.all(rs.sp(7)),
decoration: BoxDecoration(
color:        color.withOpacity(0.12),
borderRadius: BorderRadius.circular(rs.sp(8)),
),
child: Icon(icon, color: color, size: rs.sp(16)),
),
),
);
}
}

// ── Shimmer loader ───────────────────────────────────────────────────────────

class _InsightShimmer extends StatefulWidget {
const _InsightShimmer({required this.rs, required this.color});
final Rs    rs;
final Color color;

@override
State<_InsightShimmer> createState() => _InsightShimmerState();
}

class _InsightShimmerState extends State<_InsightShimmer>
with SingleTickerProviderStateMixin {
late AnimationController _ctrl;
late Animation<double>   _anim;

@override
void initState() {
super.initState();
_ctrl = AnimationController(
vsync: this, duration: const Duration(milliseconds: 1200))
..repeat(reverse: true);
_anim = Tween<double>(begin: 0.3, end: 0.8).animate(
CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
}

@override
void dispose() {
_ctrl.dispose();
super.dispose();
}

@override
Widget build(BuildContext context) {
final rs = widget.rs;
return AnimatedBuilder(
animation: _anim,
builder: (_, __) => Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
_bar(rs, _anim.value, 0.9),
SizedBox(height: rs.sp(6)),
_bar(rs, _anim.value, 0.75),
SizedBox(height: rs.sp(6)),
_bar(rs, _anim.value, 0.55),
],
),
);
}

Widget _bar(Rs rs, double opacity, double widthFactor) {
return FractionallySizedBox(
widthFactor: widthFactor,
child: Container(
height: rs.sp(12),
decoration: BoxDecoration(
color:        widget.color.withOpacity(opacity),
borderRadius: BorderRadius.circular(rs.sp(6)),
),
),
);
}
}

// ── Color palette ────────────────────────────────────────────────────────────

class _CardColors {
const _CardColors({
required this.bgStart,
required this.bgEnd,
required this.border,
required this.shadow,
required this.iconBg,
required this.iconFg,
required this.label,
required this.subtitle,
required this.text,
required this.liveBg,
required this.liveFg,
required this.actionBtn,
required this.divider,
required this.shimmer,
});

final Color bgStart, bgEnd, border, shadow;
final Color iconBg, iconFg, label, subtitle, text;
final Color liveBg, liveFg, actionBtn, divider, shimmer;

factory _CardColors.warning(bool dark) => _CardColors(
bgStart:   dark ? const Color(0xFF2A1A0E) : const Color(0xFFFFF8F0),
bgEnd:     dark ? const Color(0xFF1E1208) : const Color(0xFFFFF0E0),
border:    const Color(0xFFFF8C42).withOpacity(0.35),
shadow:    const Color(0xFFFF8C42).withOpacity(0.18),
iconBg:    const Color(0xFFFF8C42).withOpacity(0.15),
iconFg:    const Color(0xFFFF8C42),
label:     dark ? const Color(0xFFFFB36B) : const Color(0xFFD4611A),
subtitle:  dark ? const Color(0xFF9A7050) : const Color(0xFFAA7040),
text:      dark ? const Color(0xFFEEDDCC) : const Color(0xFF5A3A1A),
liveBg:    const Color(0xFFFF8C42).withOpacity(0.20),
liveFg:    const Color(0xFFFF8C42),
actionBtn: const Color(0xFFFF8C42),
divider:   const Color(0xFFFF8C42).withOpacity(0.20),
shimmer:   const Color(0xFFFF8C42),
);

factory _CardColors.motivation(bool dark) => _CardColors(
bgStart:   dark ? const Color(0xFF0D2A1A) : const Color(0xFFF0FFF8),
bgEnd:     dark ? const Color(0xFF082010) : const Color(0xFFE0FFF0),
border:    AppColors.income.withOpacity(0.35),
shadow:    AppColors.income.withOpacity(0.18),
iconBg:    AppColors.income.withOpacity(0.15),
iconFg:    AppColors.income,
label:     dark ? const Color(0xFF6BDAA5) : const Color(0xFF0A7A4A),
subtitle:  dark ? const Color(0xFF4A8060) : const Color(0xFF3A7060),
text:      dark ? const Color(0xFFCCEEDD) : const Color(0xFF1A4A30),
liveBg:    AppColors.income.withOpacity(0.20),
liveFg:    AppColors.income,
actionBtn: AppColors.income,
divider:   AppColors.income.withOpacity(0.20),
shimmer:   AppColors.income,
);

factory _CardColors.saving(bool dark) => _CardColors(
bgStart:   dark ? const Color(0xFF0D1A2A) : const Color(0xFFF0F8FF),
bgEnd:     dark ? const Color(0xFF081020) : const Color(0xFFE0F0FF),
border:    AppColors.royalBlue.withOpacity(0.30),
shadow:    AppColors.royalBlue.withOpacity(0.15),
iconBg:    AppColors.royalBlue.withOpacity(0.12),
iconFg:    AppColors.royalBlue,
label:     dark ? const Color(0xFF7799FF) : const Color(0xFF0033CC),
subtitle:  dark ? const Color(0xFF4A6080) : const Color(0xFF3A5080),
text:      dark ? const Color(0xFFCCDDFF) : const Color(0xFF1A2A50),
liveBg:    AppColors.royalBlue.withOpacity(0.18),
liveFg:    AppColors.royalBlue,
actionBtn: AppColors.royalBlue,
divider:   AppColors.royalBlue.withOpacity(0.18),
shimmer:   AppColors.royalBlue,
);

factory _CardColors.spending(bool dark) => _CardColors(
bgStart:   dark ? const Color(0xFF2A0A14) : const Color(0xFFFFF2F4),
bgEnd:     dark ? const Color(0xFF1A060C) : const Color(0xFFFFE8EC),
border:    AppColors.expense.withOpacity(0.35),
shadow:    AppColors.expense.withOpacity(0.18),
iconBg:    AppColors.expense.withOpacity(0.15),
iconFg:    AppColors.expense,
label:     dark ? const Color(0xFFFF9FAF) : const Color(0xFFCC2040),
subtitle:  dark ? const Color(0xFF804050) : const Color(0xFF804050),
text:      dark ? const Color(0xFFFFCCDD) : const Color(0xFF4A1020),
liveBg:    AppColors.expense.withOpacity(0.20),
liveFg:    AppColors.expense,
actionBtn: AppColors.expense,
divider:   AppColors.expense.withOpacity(0.20),
shimmer:   AppColors.expense,
);

factory _CardColors.neutral(bool dark) => _CardColors(
bgStart:   dark ? const Color(0xFF12102A) : const Color(0xFFF5F4FF),
bgEnd:     dark ? const Color(0xFF0C0A1E) : const Color(0xFFECEAFF),
border:    AppColors.violet.withOpacity(0.30),
shadow:    AppColors.violet.withOpacity(0.15),
iconBg:    AppColors.violet.withOpacity(0.15),
iconFg:    AppColors.violet,
label:     dark ? const Color(0xFFAA99FF) : const Color(0xFF4A30CC),
subtitle:  dark ? const Color(0xFF6A5A90) : const Color(0xFF6A5A90),
text:      dark ? const Color(0xFFDDCCFF) : const Color(0xFF2A1A60),
liveBg:    AppColors.violet.withOpacity(0.20),
liveFg:    AppColors.violet,
actionBtn: AppColors.violet,
divider:   AppColors.violet.withOpacity(0.20),
shimmer:   AppColors.violet,
);
}