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
import '../../budget/presentation/cubit/budget_cubit.dart';
import '../../transactions/domain/entities/transaction_entity.dart';
import '../../transactions/presentation/cubit/balance_cubit.dart';
import '../../transactions/presentation/cubit/balance_state.dart';
import '../../transactions/presentation/cubit/transaction_cubit.dart';
import '../../transactions/presentation/cubit/transaction_state.dart';
import '../../../core/cubit/app_cubit.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/notifications/notification_cubit.dart';
import '../../../core/widgets/premium_snackbar.dart';
import '../../home/finance/finance_assistant_prefs.dart';
import '../../../core/l10n/app_locale.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/l10n/app_strings.dart';
import '../Widgets/account_widgets.dart';
import 'language_picker_modal.dart';
import 'pdf_export_modal.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthCubit()),
        BlocProvider<NotificationCubit>.value(
            value: getIt<NotificationCubit>()),
      ],
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
  bool   _budgetAlerts  = true;

  // ── Scroll / fade state (mirrors Home & Analytics) ─────────
  final _scrollCtrl    = ScrollController();
  double _scrollOffset = 0;

  static const _supportedCurrencies = [
    ('BDT', '৳',    'Bangladeshi Taka'),
    ('USD', '\$',   'US Dollar'),
    ('EUR', '€',    'Euro'),
    ('GBP', '£',    'British Pound'),
    ('INR', '₹',    'Indian Rupee'),
    ('JPY', '¥',    'Japanese Yen'),
    ('CAD', 'CA\$', 'Canadian Dollar'),
    ('AUD', 'A\$',  'Australian Dollar'),
    ('SGD', 'S\$',  'Singapore Dollar'),
    ('CHF', 'Fr',   'Swiss Franc'),
    ('MYR', 'RM',   'Malaysian Ringgit'),
    ('AED', 'د.إ',  'UAE Dirham'),
    ('SAR', '﷼',    'Saudi Riyal'),
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
      builder: (sheetCtx) {
        final mq       = MediaQuery.of(context);
        final maxListH = mq.size.height * 0.52;
        final cs       = Theme.of(context).colorScheme;
        final isDark   = Theme.of(context).brightness == Brightness.dark;

        return BlocBuilder<AppCubit, AppSettings>(
          bloc: getIt<AppCubit>(),
          builder: (_, appState) => Container(
            margin: EdgeInsets.fromLTRB(
              rs.sp(12), 0, rs.sp(12),
              rs.sp(12) + mq.padding.bottom,
            ),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(rs.sp(28)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.midnight.withOpacity(isDark ? 0.5 : 0.15),
                  blurRadius: 48,
                  offset: const Offset(0, -6),
                ),
                if (isDark)
                  BoxShadow(
                    color: AppColors.royalBlue.withOpacity(0.12),
                    blurRadius: 32,
                    offset: const Offset(0, -2),
                  ),
              ],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // ── Drag handle ──────────────────────────────────────
              Center(child: Container(
                width: rs.sp(36), height: rs.sp(4),
                margin: EdgeInsets.symmetric(vertical: rs.sp(14)),
                decoration: BoxDecoration(
                  gradient: AppColors.buttonGradient,
                  borderRadius: BorderRadius.circular(2),
                ),
              )),

              // ── Header ───────────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(rs.sp(22), 0, rs.sp(22), rs.sp(14)),
                child: Row(children: [
                  Container(
                    width: rs.sp(42), height: rs.sp(42),
                    decoration: BoxDecoration(
                      gradient: AppColors.buttonGradient,
                      borderRadius: BorderRadius.circular(rs.sp(14)),
                      boxShadow: [BoxShadow(
                        color: AppColors.royalBlue.withOpacity(0.35),
                        blurRadius: 12, offset: const Offset(0, 4),
                      )],
                    ),
                    child: Icon(Icons.currency_exchange_rounded,
                        color: Colors.white, size: rs.sp(20)),
                  ),
                  SizedBox(width: rs.sp(14)),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('select_currency'), style: TextStyle(
                        fontSize: rs.sp(17), fontWeight: FontWeight.w800,
                        color: cs.onSurface, fontFamily: 'Sora',
                      )),
                      SizedBox(height: rs.sp(2)),
                      Text(context.tr(S.currencyUpdates),
                          style: TextStyle(
                            fontSize: rs.sp(11),
                            color: cs.onSurface.withOpacity(0.5),
                          )),
                    ],
                  )),
                  // Currently selected badge
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: rs.sp(10), vertical: rs.sp(5)),
                    decoration: BoxDecoration(
                      gradient: AppColors.buttonGradient,
                      borderRadius: BorderRadius.circular(rs.sp(10)),
                    ),
                    child: Text(
                      CurrencyHelper.symbol(appState.currency),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: rs.sp(14),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ]),
              ),

              // ── Divider ──────────────────────────────────────────
              Container(
                height: 1,
                margin: EdgeInsets.symmetric(horizontal: rs.sp(20)),
                color: cs.onSurface.withOpacity(0.06),
              ),
              SizedBox(height: rs.sp(8)),

              // ── Scrollable currency list ──────────────────────────
              LimitedBox(
                maxHeight: maxListH,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                      rs.sp(16), 0, rs.sp(16), rs.sp(8)),
                  child: Column(
                    children: _supportedCurrencies.asMap().entries.map((e) {
                      final (code, sym, nm) = e.value;
                      final isSel  = code == appState.currency;
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          // 1. Update global state immediately
                          getIt<AppCubit>().setCurrency(code);
                          // 2. Auto-close the sheet
                          Navigator.of(sheetCtx).pop();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          margin: EdgeInsets.only(bottom: rs.sp(6)),
                          padding: EdgeInsets.symmetric(
                              horizontal: rs.sp(14), vertical: rs.sp(11)),
                          decoration: BoxDecoration(
                            gradient: isSel
                                ? LinearGradient(colors: [
                              AppColors.royalBlue.withOpacity(0.12),
                              AppColors.violet.withOpacity(0.08),
                            ])
                                : null,
                            color: isSel
                                ? null
                                : cs.onSurface.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(rs.sp(16)),
                            border: isSel
                                ? Border.all(
                                color: AppColors.royalBlue.withOpacity(0.30),
                                width: 1.5)
                                : Border.all(
                                color: Colors.transparent,
                                width: 1.5),
                          ),
                          child: Row(children: [
                            // Symbol tile
                            Container(
                              width: rs.sp(42), height: rs.sp(42),
                              decoration: BoxDecoration(
                                gradient: isSel
                                    ? AppColors.buttonGradient
                                    : null,
                                color: isSel
                                    ? null
                                    : cs.onSurface.withOpacity(0.07),
                                borderRadius: BorderRadius.circular(rs.sp(12)),
                              ),
                              child: Center(child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(sym, style: TextStyle(
                                  fontSize: rs.sp(16),
                                  fontWeight: FontWeight.w800,
                                  color: isSel
                                      ? Colors.white
                                      : cs.onSurface,
                                )),
                              )),
                            ),
                            SizedBox(width: rs.sp(12)),
                            // Code + name
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(code, style: TextStyle(
                                  fontSize: rs.sp(14),
                                  fontWeight: FontWeight.w700,
                                  color: isSel
                                      ? AppColors.royalBlue
                                      : cs.onSurface,
                                )),
                                SizedBox(height: rs.sp(2)),
                                Text(nm, style: TextStyle(
                                  fontSize: rs.sp(11),
                                  color: cs.onSurface.withOpacity(0.5),
                                )),
                              ],
                            )),
                            // Checkmark
                            AnimatedOpacity(
                              opacity: isSel ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              child: Container(
                                width: rs.sp(24), height: rs.sp(24),
                                decoration: BoxDecoration(
                                  gradient: AppColors.buttonGradient,
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(
                                    color: AppColors.royalBlue.withOpacity(0.4),
                                    blurRadius: 8,
                                  )],
                                ),
                                child: Icon(Icons.check_rounded,
                                    color: Colors.white, size: rs.sp(14)),
                              ),
                            ),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              // ── Bottom breathing room ──────────────────────────────
              SizedBox(height: rs.sp(20)),
            ]),
          ),
        );
      },
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
                Text(context.tr('choose_theme'), style: TextStyle(
                    fontSize: rs.sp(17), fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontFamily: 'Sora')),
              ]),
            ),
            SizedBox(height: rs.sp(10)),
            ...[
              (ThemeMode.light,  Icons.light_mode_rounded,   context.tr('theme_light'),  context.tr('light_sub')),
              (ThemeMode.dark,   Icons.dark_mode_rounded,    context.tr('theme_dark'),   context.tr('dark_sub')),
              (ThemeMode.system, Icons.settings_brightness_rounded, context.tr('theme_system'), context.tr('system_sub')),
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
        title: Text(context.tr('sign_out'),
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontFamily: 'Sora',
                fontSize: rs.sp(18))),
        content: Text(context.tr('sign_out_confirm'),
            style: TextStyle(
                fontSize: rs.sp(14), color: AppColors.textMid)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('cancel'),
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45), fontSize: rs.sp(14))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseAuth.instance.signOut();
              if (mounted) context.go(AppRoutes.login);
            },
            child: Text(context.tr('sign_out'),
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
        title: Text(context.tr('clear_data_title'),
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontFamily: 'Sora',
                fontSize: rs.sp(18))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'This will permanently delete ALL your finance data including:',
                style: TextStyle(
                    fontSize: rs.sp(14),
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600)),
            SizedBox(height: rs.sp(12)),
            ...[
              '• All transactions',
              '• All budgets',
              '• Analytics data',
              '• Notifications',
              '• Cached local storage',
              '• Firebase finance data',
            ].map((item) => Padding(
              padding: EdgeInsets.only(bottom: rs.sp(4)),
              child: Text(
                item,
                style: TextStyle(
                  fontSize: rs.sp(13),
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            )),
            SizedBox(height: rs.sp(16)),
            Container(
              padding: EdgeInsets.all(rs.sp(12)),
              decoration: BoxDecoration(
                color: AppColors.expense.withOpacity(0.1),
                borderRadius: BorderRadius.circular(rs.sp(12)),
                border: Border.all(
                  color: AppColors.expense.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_rounded,
                    color: AppColors.expense,
                    size: rs.sp(20),
                  ),
                  SizedBox(width: rs.sp(8)),
                  Expanded(
                    child: Text(
                      'This action cannot be undone',
                      style: TextStyle(
                        fontSize: rs.sp(12),
                        color: AppColors.expense,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('cancel'),
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45), fontSize: rs.sp(14))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performFullDataClear();
            },
            child: Text(context.tr('delete_all_data'),
                style: TextStyle(
                    color: AppColors.expense,
                    fontSize: rs.sp(14),
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _performFullDataClear() async {
    final rs = Rs.of(context);

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(rs.sp(22))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.royalBlue),
            ),
            SizedBox(height: rs.sp(16)),
            Text(
              'Deleting all data...',
              style: TextStyle(
                fontSize: rs.sp(14),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: rs.sp(8)),
            Text(
              'This may take a moment',
              style: TextStyle(
                fontSize: rs.sp(12),
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) Navigator.pop(context);
        return;
      }

      // 1. Delete all transactions from Firebase
      final transactionCol = FirebaseFirestore.instance
          .collection('transactions/${user.uid}/userTransactions');
      final transactionSnap = await transactionCol.get();
      for (final doc in transactionSnap.docs) {
        await doc.reference.delete();
      }

      // 2. Delete all budgets from Firebase
      final budgetCol = FirebaseFirestore.instance
          .collection('budgets/${user.uid}/userBudgets');
      final budgetSnap = await budgetCol.get();
      for (final doc in budgetSnap.docs) {
        await doc.reference.delete();
      }

      // 3. Clear local Hive storage
      await HiveService.clearAll();

      // 4. Clear notifications
      getIt<NotificationCubit>().clearAll();

      // 5. Reset all finance-related app state
      getIt<TransactionCubit>().clearAll();
      getIt<BudgetCubit>().clearAll();
      getIt<BalanceCubit>().clearAll();

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show success feedback
      if (mounted) {
        showPremiumSnackBar(
          context,
          message: context.tr(S.dataCleared),
          subtitle: context.tr(S.dataClearedSub),
          icon: Icons.check_circle_rounded,
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show error feedback
      if (mounted) {
        showPremiumSnackBar(
          context,
          message: 'Failed to Clear Data',
          subtitle: e.toString(),
          icon: Icons.error_outline,
        );
      }
    }
  }

  void _showPdfExportModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => const PdfExportModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, userSnap) {
        final user = userSnap.data ?? FirebaseAuth.instance.currentUser;

        final name = (user?.displayName?.isNotEmpty == true)
            ? user!.displayName!
            : user?.email?.split('@').first ?? 'User';
        final email = user?.email ?? '';
        final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
        final photoUrl = user?.photoURL;

        // Header fades: starts at 60 px scroll, complete at 200 px
        // (matches the Home screen fade range)
        final headerOpacity = (1.0 -
            ((_scrollOffset - 60.0) / 140.0).clamp(0.0, 1.0));

        // Height of the transparent spacer that sits behind the header
        // (profile hero height — avatar + stats + padding)
        const double headerHeight = 300.0;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor:          Colors.transparent,
            statusBarIconBrightness: Brightness.light,
          ),
          child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                          photoUrl:    photoUrl,
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
                    SizedBox(height: rs.sp(headerHeight)),

                    // Content card slides over the gradient header
                    Container(
                      decoration: BoxDecoration(
                        color:        Theme.of(context).scaffoldBackgroundColor,
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

                          AccountSection(title: context.tr('account'), rows: [
                            AccountSettingRow(
                              icon:      Icons.person_outline_rounded,
                              label:     context.tr('edit_profile'),
                              trailing:  const AccountChevron(),
                              onTap:     () => context.push(AppRoutes.editProfile),
                            ),
                            AccountSettingRow(
                              icon:      Icons.lock_outline_rounded,
                              label:     context.tr('change_pin'),
                              trailing:  const AccountChevron(),
                              onTap:     () => context.push(AppRoutes.pinSetup),
                            ),
                          ]),

                          BlocBuilder<AppCubit, AppSettings>(
                            bloc: getIt<AppCubit>(),
                            builder: (_, appState) => AccountSection(
                                title: context.tr('preferences'),
                                rows: [
                                  AccountSettingRow(
                                    icon:      Icons.attach_money_rounded,
                                    label:     context.tr('currency'),
                                    trailing:  AccountTrailingLabel('${appState.currency} ›'),
                                    onTap:     _showCurrencyPicker,
                                  ),
                                  AccountSettingRow(
                                    icon:      Icons.palette_outlined,
                                    label:     context.tr('theme'),
                                    trailing:  AccountTrailingLabel(switch (appState.themeMode) {
                                      ThemeMode.dark   => '${context.tr('theme_dark')} ›',
                                      ThemeMode.system => '${context.tr('theme_system')} ›',
                                      _                => '${context.tr('theme_light')} ›',
                                    }),
                                    onTap:     _showThemePicker,
                                  ),
                                  AccountSettingRow(
                                    icon:      Icons.language_rounded,
                                    label:     context.tr('language'),
                                    trailing:  AccountTrailingLabel(
                                      '${AppLocales.find(appState.languageCode)?.code.toUpperCase() ?? 'EN'} ›',
                                    ),
                                    onTap:     () => showLanguagePicker(context),
                                  ),
                                ]),
                          ),

                          // ── Notifications — only Budget Alerts ────────
                          // Weekly Summary and AI Tips removed (not functional).
                          // Budget Alerts toggle is wired to NotificationCubit.
                          BlocBuilder<NotificationCubit, NotificationState>(
                            builder: (ctx, notifState) => AccountSection(
                              title: context.tr('notifications'),
                              rows: [
                                AccountSettingRow(
                                  icon:  Icons.notifications_outlined,
                                  label: context.tr('budget_alerts'),
                                  trailing: AccountToggle(
                                    value: notifState.budgetAlertsEnabled,
                                    onChanged: (v) =>
                                        ctx.read<NotificationCubit>()
                                            .setBudgetAlerts(v),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          ValueListenableBuilder<bool>(
                            valueListenable:
                            FinanceAssistantPrefs.visibleListenable,
                            builder: (ctx, v, _) => AccountSection(
                              title: context.tr('flow_intelligence'),
                              rows: [
                                AccountSettingRow(
                                  icon: Icons.auto_awesome_rounded,
                                  label: context.tr('flow_advisor_home'),
                                  trailing: AccountToggle(
                                    value: v,
                                    onChanged: (nv) =>
                                        FinanceAssistantPrefs.setCardVisible(nv),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          AccountSection(title: context.tr('data_privacy'), rows: [
                            AccountSettingRow(
                              icon:      Icons.picture_as_pdf_outlined,
                              label:     context.tr('export_pdf'),
                              trailing:  const AccountChevron(),
                              onTap:     _showPdfExportModal,
                            ),
                            AccountSettingRow(
                              icon:      Icons.delete_outline_rounded,
                              label:     context.tr('clear_data'),
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
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
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
      },
    );
  }
}