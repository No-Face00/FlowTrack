// lib/features/account/presentation/account_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/appRouter.dart';
import '../../../core/services/hive_service.dart';
import '../../../core/utils/responsive_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../transactions/domain/entities/transaction_entity.dart';
import '../../transactions/presentation/cubit/balance_cubit.dart';
import '../../transactions/presentation/cubit/balance_state.dart';
import '../../transactions/presentation/cubit/transaction_cubit.dart';
import '../../transactions/presentation/cubit/transaction_state.dart';
import '../../../core/cubit/app_cubit.dart';
import '../../../core/di/service_locator.dart';
import '../Widgets/account_widgets.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthCubit(),
      child: const _AccountView(),
    );
  }
}

class _AccountView extends StatefulWidget {
  const _AccountView();
  @override
  State<_AccountView> createState() => _AccountViewState();
}

class _AccountViewState extends State<_AccountView> {
  bool   _biometric     = true;
  bool   _budgetAlerts  = true;
  bool   _weeklySummary = true;
  bool   _aiTips        = true;
  bool   _aiInsights    = true;
  bool   _autoCateg     = true;

  // ── Scroll / fade state (mirrors Home & Analytics) ─────────
  final _scrollCtrl    = ScrollController();
  double _scrollOffset = 0;

  static const _supportedCurrencies = [
    ('BDT', '৳', 'Bangladeshi Taka'),
    ('USD', '\$', 'US Dollar'),
    ('EUR', '€', 'Euro'),
    ('GBP', '£', 'British Pound'),
    ('INR', '₹', 'Indian Rupee'),
    ('JPY', '¥', 'Japanese Yen'),
    ('CAD', 'CA\$', 'Canadian Dollar'),
    ('AUD', 'A\$', 'Australian Dollar'),
  ];

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(
            () => setState(() => _scrollOffset = _scrollCtrl.offset));
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  // Currency and theme are now managed by AppCubit (single source of truth).
  // _saveCurrency / _loadCurrency removed.

  void _showCurrencyPicker() {
    final rs = Rs.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => Container(
        margin: EdgeInsets.fromLTRB(rs.sp(12), 0, rs.sp(12),
            rs.sp(12) + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(rs.sp(28)),
          boxShadow: [BoxShadow(
              color: AppColors.midnight.withOpacity(0.12),
              blurRadius: 40, offset: const Offset(0, -4))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Center(child: Container(
            width: rs.sp(36), height: rs.sp(4),
            margin: EdgeInsets.symmetric(vertical: rs.sp(14)),
            decoration: BoxDecoration(
                gradient: AppColors.buttonGradient,
                borderRadius: BorderRadius.circular(2)),
          )),
          Padding(
            padding: EdgeInsets.fromLTRB(rs.sp(22), 0, rs.sp(22), rs.sp(6)),
            child: Row(children: [
              Container(
                width: rs.sp(38), height: rs.sp(38),
                decoration: BoxDecoration(
                  gradient: AppColors.buttonGradient,
                  borderRadius: BorderRadius.circular(rs.sp(12)),
                ),
                child: Icon(Icons.attach_money_rounded,
                    color: Colors.white, size: rs.sp(20)),
              ),
              SizedBox(width: rs.sp(12)),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Select Currency', style: TextStyle(
                    fontSize: rs.sp(17), fontWeight: FontWeight.w800,
                    color: AppColors.textDark, fontFamily: 'Sora')),
                Text('Changes apply everywhere in the app',
                    style: TextStyle(fontSize: rs.sp(11),
                        color: AppColors.textMuted)),
              ]),
            ]),
          ),
          SizedBox(height: rs.sp(10)),
          Container(
            margin: EdgeInsets.symmetric(horizontal: rs.sp(20)),
            decoration: BoxDecoration(
              color: AppColors.bgLavender,
              borderRadius: BorderRadius.circular(rs.sp(20)),
            ),
            child: Column(
              children: _supportedCurrencies.asMap().entries.map((e) {
                final idx       = e.key;
                final (code, symbol, name) = e.value;
                final isSelected = code == getIt<AppCubit>().state.currency;
                final isLast     = idx == _supportedCurrencies.length - 1;
                return Column(children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      Navigator.pop(context);
                      final appCubit = getIt<AppCubit>();
                      appCubit.setCurrency(code);
                      // Refresh BalanceCubit so amounts update immediately
                      getIt<BalanceCubit>().refreshCurrency();
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: rs.sp(16), vertical: rs.sp(14)),
                      child: Row(children: [
                        Container(
                          width: rs.sp(40), height: rs.sp(40),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.royalBlue.withOpacity(0.10)
                                : AppColors.bgLavender,
                            borderRadius: BorderRadius.circular(rs.sp(12)),
                            border: isSelected
                                ? Border.all(
                                color: AppColors.royalBlue.withOpacity(0.30),
                                width: 1.5)
                                : null,
                          ),
                          child: Center(child: Text(symbol,
                              style: TextStyle(
                                  fontSize: rs.sp(16),
                                  fontWeight: FontWeight.w800,
                                  color: isSelected
                                      ? AppColors.royalBlue
                                      : AppColors.textDark))),
                        ),
                        SizedBox(width: rs.sp(14)),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(code, style: TextStyle(
                                fontSize: rs.sp(14),
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? AppColors.royalBlue
                                    : AppColors.textDark)),
                            Text(name, style: TextStyle(
                                fontSize: rs.sp(11),
                                color: AppColors.textMuted)),
                          ],
                        )),
                        if (isSelected)
                          Container(
                            width: rs.sp(22), height: rs.sp(22),
                            decoration: BoxDecoration(
                              gradient: AppColors.buttonGradient,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.check_rounded,
                                color: Colors.white, size: rs.sp(13)),
                          ),
                      ]),
                    ),
                  ),
                  if (!isLast) Container(
                      height: 1,
                      color: Colors.white.withOpacity(0.80),
                      margin: EdgeInsets.symmetric(horizontal: rs.sp(16))),
                ]);
              }).toList(),
            ),
          ),
          SizedBox(height: rs.sp(20)),
        ]),
      ),
    );
  }

  void _showThemePicker() {
    final rs      = Rs.of(context);
    final current = getIt<AppCubit>().state.themeMode;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => Container(
          margin: EdgeInsets.fromLTRB(rs.sp(12), 0, rs.sp(12),
              rs.sp(12) + MediaQuery.of(context).padding.bottom),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(rs.sp(28)),
            boxShadow: [BoxShadow(
                color: AppColors.midnight.withOpacity(0.12),
                blurRadius: 40, offset: const Offset(0, -4))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Handle
            Center(child: Container(
              width: rs.sp(36), height: rs.sp(4),
              margin: EdgeInsets.symmetric(vertical: rs.sp(14)),
              decoration: BoxDecoration(
                  gradient: AppColors.buttonGradient,
                  borderRadius: BorderRadius.circular(2)),
            )),
            Padding(
              padding: EdgeInsets.fromLTRB(rs.sp(22), 0, rs.sp(22), rs.sp(6)),
              child: Row(children: [
                Container(
                  width: rs.sp(38), height: rs.sp(38),
                  decoration: BoxDecoration(
                    gradient: AppColors.buttonGradient,
                    borderRadius: BorderRadius.circular(rs.sp(12)),
                  ),
                  child: Icon(Icons.palette_outlined,
                      color: Colors.white, size: rs.sp(20)),
                ),
                SizedBox(width: rs.sp(12)),
                Text('Choose Theme', style: TextStyle(
                    fontSize: rs.sp(17), fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontFamily: 'Sora')),
              ]),
            ),
            SizedBox(height: rs.sp(10)),
            ...[
              (ThemeMode.light,  Icons.light_mode_rounded,   'Light',  'Clean white interface'),
              (ThemeMode.dark,   Icons.dark_mode_rounded,    'Dark',   'Easy on the eyes'),
              (ThemeMode.system, Icons.settings_brightness_rounded, 'System', 'Follow device setting'),
            ].map((entry) {
              final (mode, icon, label, sub) = entry;
              final isSelected = current == mode;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.pop(context);
                  getIt<AppCubit>().setTheme(mode);
                  setState(() {});
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: rs.sp(20), vertical: rs.sp(14)),
                  child: Row(children: [
                    Container(
                      width: rs.sp(44), height: rs.sp(44),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.royalBlue.withOpacity(0.12)
                            : Theme.of(context).colorScheme.surfaceContainerHighest
                            .withOpacity(0.5),
                        borderRadius: BorderRadius.circular(rs.sp(14)),
                        border: isSelected
                            ? Border.all(
                            color: AppColors.royalBlue.withOpacity(0.35),
                            width: 1.5)
                            : null,
                      ),
                      child: Icon(icon,
                          color: isSelected
                              ? AppColors.royalBlue
                              : Theme.of(context).colorScheme.onSurface
                              .withOpacity(0.6),
                          size: rs.sp(22)),
                    ),
                    SizedBox(width: rs.sp(14)),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: TextStyle(
                            fontSize: rs.sp(14), fontWeight: FontWeight.w700,
                            color: isSelected
                                ? AppColors.royalBlue
                                : Theme.of(context).colorScheme.onSurface)),
                        Text(sub, style: TextStyle(
                            fontSize: rs.sp(11),
                            color: Theme.of(context).colorScheme.onSurface
                                .withOpacity(0.45))),
                      ],
                    )),
                    if (isSelected)
                      Container(
                        width: rs.sp(22), height: rs.sp(22),
                        decoration: BoxDecoration(
                          gradient: AppColors.buttonGradient,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check_rounded,
                            color: Colors.white, size: rs.sp(13)),
                      ),
                  ]),
                ),
              );
            }),
            SizedBox(height: rs.sp(20)),
          ]),
        ),
      ),
    );
  }

  void _confirmSignOut() {
    final rs = Rs.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(rs.sp(22))),
        title: Text('Sign Out',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontFamily: 'Sora',
                fontSize: rs.sp(18))),
        content: Text('Are you sure you want to sign out?',
            style: TextStyle(
                fontSize: rs.sp(14), color: AppColors.textMid)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(
                    color: AppColors.textMuted, fontSize: rs.sp(14))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseAuth.instance.signOut();
              if (mounted) context.go(AppRoutes.login);
            },
            child: Text('Sign Out',
                style: TextStyle(
                    color: AppColors.expense,
                    fontSize: rs.sp(14),
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _confirmClear() {
    final rs = Rs.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(rs.sp(22))),
        title: Text('Clear All Data',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontFamily: 'Sora',
                fontSize: rs.sp(18))),
        content: Text(
            'This will permanently delete all local transactions.\n'
                'Cloud data remains intact.\n\nThis cannot be undone.',
            style: TextStyle(
                fontSize: rs.sp(14), color: AppColors.textMid)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(
                    color: AppColors.textMuted, fontSize: rs.sp(14))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await HiveService.clearAll();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('All local data cleared'),
                  backgroundColor: AppColors.textMid,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ));
              }
            },
            child: Text('Delete',
                style: TextStyle(
                    color: AppColors.expense,
                    fontSize: rs.sp(14),
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Coming in Phase 3 🚀'),
      backgroundColor: AppColors.deepBlue,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final rs   = Rs.of(context);
    final user = FirebaseAuth.instance.currentUser;

    final name    = (user?.displayName?.isNotEmpty == true)
        ? user!.displayName!
        : user?.email?.split('@').first ?? 'User';
    final email   = user?.email ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    // Header fades: starts at 60 px scroll, complete at 200 px
    // (matches the Home screen fade range)
    final headerOpacity = (1.0 -
        ((_scrollOffset - 60.0) / 140.0).clamp(0.0, 1.0));

    // Height of the transparent spacer that sits behind the header
    // (profile hero height — avatar + stats + padding)
    const double _headerHeight = 300.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor:          Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.bgLavender,
        extendBodyBehindAppBar: true,
        body: Stack(children: [

          // ── Layer 1 : gradient header — fades as card scrolls over it ──
          Positioned.fill(
            child: BlocBuilder<TransactionCubit, TransactionState>(
              builder: (_, txState) {
                // ── Transaction count ─────────────────────────────
                final txns     = txState is TransactionLoaded
                    ? txState.transactions : <TransactionEntity>[];
                final txnCount = txns.length;

                // ── This-month expense total ───────────────────────
                final now      = DateTime.now();
                final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
                final monthExpense = txns
                    .where((t) => t.type == 'expense' && t.month == monthKey)
                    .fold<double>(0.0, (sum, t) => sum + t.amount);

                return BlocBuilder<BalanceCubit, BalanceState>(
                  builder: (_, balState) {
                    // ── Savings rate (all-time income vs expense) ──
                    final income  = balState is BalanceLoaded ? balState.income  : 0.0;
                    final expense = balState is BalanceLoaded ? balState.expense : 0.0;
                    final symbol  = balState is BalanceLoaded ? balState.symbol  : '৳';
                    final savingsRate = (income > 0)
                        ? ((income - expense) / income * 100).clamp(0.0, 100.0).round()
                        : 0;

                    return AccountHeader(
                      name:        name,
                      email:       email,
                      initial:     initial,
                      bgOpacity:   headerOpacity,
                      txnCount:    txnCount,
                      monthSpend:  monthExpense,
                      savingsRate: savingsRate,
                      symbol:      symbol,
                    );
                  },
                );
              },
            ),
          ),

          // ── Layer 2 : scrollable content card ──────────────────────────
          Positioned.fill(
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              physics: const BouncingScrollPhysics(),
              child: Column(children: [

                // Transparent spacer — same height as the gradient header
                // so the card starts below it on first render.
                SizedBox(height: rs.sp(_headerHeight)),

                // Content card slides over the gradient header
                Container(
                  decoration: BoxDecoration(
                    color:        AppColors.bgLavender,
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(rs.sp(28))),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    rs.sp(20),
                    rs.sp(20),
                    rs.sp(20),
                    MediaQuery.of(context).padding.bottom + rs.sp(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      AccountSection(title: 'Account', rows: [
                        AccountSettingRow(
                          icon:      Icons.person_outline_rounded,
                          label:     'Edit Profile',
                          trailing:  const AccountChevron(),
                          onTap:     () {},
                        ),
                        AccountSettingRow(
                          icon:      Icons.lock_outline_rounded,
                          label:     'Change PIN',
                          trailing:  const AccountChevron(),
                          onTap:     () => context.push(AppRoutes.pinSetup),
                        ),
                        AccountSettingRow(
                          icon:      Icons.fingerprint_rounded,
                          label:     'Biometric Lock',
                          trailing:  AccountToggle(
                            value:     _biometric,
                            onChanged: (v) => setState(() => _biometric = v),
                          ),
                        ),
                      ]),

                      AccountSection(title: 'Preferences', rows: [
                        AccountSettingRow(
                          icon:      Icons.attach_money_rounded,
                          label:     'Currency',
                          trailing:  AccountTrailingLabel('${getIt<AppCubit>().state.currency} ›'),
                          onTap:     _showCurrencyPicker,
                        ),
                        AccountSettingRow(
                          icon:      Icons.palette_outlined,
                          label:     'Theme',
                          trailing:  AccountTrailingLabel(
                            getIt<AppCubit>().state.themeMode == ThemeMode.dark
                                ? 'Dark ›' : 'Light ›',
                          ),
                          onTap:     _showThemePicker,
                        ),
                        AccountSettingRow(
                          icon:      Icons.language_rounded,
                          label:     'Language',
                          trailing:  const AccountTrailingLabel('EN ›'),
                          onTap:     () {},
                        ),
                      ]),

                      AccountSection(title: 'Notifications', rows: [
                        AccountSettingRow(
                          icon:      Icons.notifications_outlined,
                          label:     'Budget Alerts',
                          trailing:  AccountToggle(
                            value:     _budgetAlerts,
                            onChanged: (v) => setState(() => _budgetAlerts = v),
                          ),
                        ),
                        AccountSettingRow(
                          icon:      Icons.bar_chart_rounded,
                          label:     'Weekly Summary',
                          trailing:  AccountToggle(
                            value:     _weeklySummary,
                            onChanged: (v) => setState(() => _weeklySummary = v),
                          ),
                        ),
                        AccountSettingRow(
                          icon:      Icons.lightbulb_outline_rounded,
                          label:     'AI Tips',
                          trailing:  AccountToggle(
                            value:     _aiTips,
                            onChanged: (v) => setState(() => _aiTips = v),
                          ),
                        ),
                      ]),

                      AccountSection(title: 'AI Settings', rows: [
                        AccountSettingRow(
                          icon:      Icons.auto_awesome_rounded,
                          label:     'AI Insights',
                          trailing:  AccountToggle(
                            value:     _aiInsights,
                            onChanged: (v) => setState(() => _aiInsights = v),
                          ),
                        ),
                        AccountSettingRow(
                          icon:      Icons.label_outline_rounded,
                          label:     'Auto-Categorize',
                          trailing:  AccountToggle(
                            value:     _autoCateg,
                            onChanged: (v) => setState(() => _autoCateg = v),
                          ),
                        ),
                      ]),

                      AccountSection(title: 'Data & Privacy', rows: [
                        AccountSettingRow(
                          icon:      Icons.picture_as_pdf_outlined,
                          label:     'Export PDF Report',
                          trailing:  const AccountChevron(),
                          onTap:     _showComingSoon,
                        ),
                        AccountSettingRow(
                          icon:      Icons.table_chart_outlined,
                          label:     'Export CSV',
                          trailing:  const AccountChevron(),
                          onTap:     _showComingSoon,
                        ),
                        AccountSettingRow(
                          icon:      Icons.cloud_upload_outlined,
                          label:     'Cloud Backup',
                          trailing:  const AccountChevron(),
                          onTap:     () {},
                        ),
                        AccountSettingRow(
                          icon:      Icons.delete_outline_rounded,
                          label:     'Clear All Local Data',
                          trailing:  Text(
                            'Delete ›',
                            style: TextStyle(
                              color:      AppColors.expense,
                              fontSize:   rs.sp(13),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onTap: _confirmClear,
                        ),
                      ]),

                      AccountSignOutBtn(onTap: _confirmSignOut),
                      SizedBox(height: rs.sp(8)),

                      Center(
                        child: Text(
                          'FlowTrack v2.0.0',
                          style: TextStyle(
                              color:    AppColors.textMuted,
                              fontSize: rs.sp(11)),
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),

        ]),
      ),
    );
  }
}