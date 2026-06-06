// lib/features/account/presentation/account_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/appRouter.dart';
import '../../../core/services/hive_service.dart';
import '../../../core/services/profile_image_service.dart';
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
import '../../ai/data/finance_assistant_prefs.dart';
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
              ProfileImageService.instance.clear();
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

  /// Safe translation helper for use inside event handlers / async callbacks.
  ///
  /// WHY this exists:
  ///   context.tr(key) internally calls context.watch<AppCubit>() which maps
  ///   to Provider.of(context, listen: true). Provider enforces that listen:true
  ///   is only called during a build() phase. Calling it from a tap handler
  ///   (GestureRecognizer, onTap, onPressed, etc.) throws:
  ///     "Tried to listen to a value exposed with provider, from outside of
  ///      the widget tree."
  ///   even on the very first synchronous line — no async gap required.
  ///
  /// THE FIX:
  ///   context.read<AppCubit>() is the listen:false equivalent and is
  ///   explicitly designed for use in event handlers. We then call .tr(key)
  ///   on the cubit's own state/method rather than through the watch extension.
  ///   Since AppCubit IS in the widget tree (just not watched), we can use
  ///   Provider.of(context, listen: false) which has no restriction.
  // No trGlobal() helper needed — l10n_extension.dart already exposes trGlobal(key),
  // a top-level function that reads AppCubit via getIt (no BuildContext, no
  // Provider.of, no watch). It is explicitly safe in event handlers, async
  // callbacks, and anywhere else outside build().

  void _confirmClear() {
    final rs = Rs.of(context);

    // Use trGlobal() — NOT context.tr() — because this is a tap handler.
    // context.tr() calls Provider.of(listen:true) which is only legal
    // inside build(). trGlobal() uses getIt which is always safe.
    final strTitle        = trGlobal('clear_data_title');
    final strWarning      = trGlobal(S.clearWarning);
    final strTransactions = trGlobal(S.clearItemTransactions);
    final strBudgets      = trGlobal(S.clearItemBudgets);
    final strAnalytics    = trGlobal(S.clearItemAnalytics);
    final strNotifs       = trGlobal(S.clearItemNotifications);
    final strLocal        = trGlobal(S.clearItemLocal);
    final strFirebase     = trGlobal(S.clearItemFirebase);
    final strCannotUndo   = trGlobal(S.cannotUndo);
    final strCancel       = trGlobal('cancel');
    final strDeleteAll    = trGlobal('delete_all_data');
    final strDeleting     = trGlobal(S.deletingData);
    final strDeletingSub  = trGlobal(S.deletingDataSub);
    final strCleared      = trGlobal(S.dataCleared);
    final strClearedSub   = trGlobal(S.dataClearedSub);
    final strFailed       = trGlobal(S.clearFailed);
    final onSurface       = Theme.of(context).colorScheme.onSurface;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(rs.sp(22))),
        title: Text(strTitle,
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontFamily: 'Sora',
                fontSize: rs.sp(18))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                strWarning,
                style: TextStyle(
                    fontSize: rs.sp(14),
                    color: onSurface,
                    fontWeight: FontWeight.w600)),
            SizedBox(height: rs.sp(12)),
            ...[
              strTransactions,
              strBudgets,
              strAnalytics,
              strNotifs,
              strLocal,
              strFirebase,
            ].map((item) => Padding(
              padding: EdgeInsets.only(bottom: rs.sp(4)),
              child: Text(
                item,
                style: TextStyle(
                  fontSize: rs.sp(13),
                  color: onSurface.withOpacity(0.7),
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
                  Icon(Icons.warning_rounded,
                      color: AppColors.expense, size: rs.sp(20)),
                  SizedBox(width: rs.sp(8)),
                  Expanded(
                    child: Text(
                      strCannotUndo,
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
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(strCancel,
                style: TextStyle(
                    color: onSurface.withOpacity(0.45),
                    fontSize: rs.sp(14))),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              // All strings pre-captured — safe to call from here.
              _performFullDataClear(
                rs:             rs,
                labelDeleting:  strDeleting,
                labelDeletingSub: strDeletingSub,
                labelCleared:   strCleared,
                labelClearedSub: strClearedSub,
                labelFailed:    strFailed,
              );
            },
            child: Text(strDeleteAll,
                style: TextStyle(
                    color: AppColors.expense,
                    fontSize: rs.sp(14),
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  /// All l10n strings are passed in as parameters — this method must NEVER
  /// call context.tr() directly because it runs after async gaps and after
  /// dialogs have been popped, at which point the BuildContext is no longer
  /// in the widget tree and Provider.of throws an assertion error.
  Future<void> _performFullDataClear({
    required Rs     rs,
    required String labelDeleting,
    required String labelDeletingSub,
    required String labelCleared,
    required String labelClearedSub,
    required String labelFailed,
  }) async {
    // ── Show loading dialog ──────────────────────────────────────────────────
    // Use rootNavigator so it renders above the account-screen route and can
    // be reliably dismissed with the root navigator later.
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(rs.sp(22))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.royalBlue),
            ),
            SizedBox(height: rs.sp(16)),
            Text(labelDeleting,
                style: TextStyle(
                    fontSize: rs.sp(14), fontWeight: FontWeight.w600)),
            SizedBox(height: rs.sp(8)),
            Text(labelDeletingSub,
                style: TextStyle(fontSize: rs.sp(12))),
          ],
        ),
      ),
    );

    // Track whether the Firestore delete succeeded (offline = skip remote).
    bool firestoreCleared = false;
    String? remoteError;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        return;
      }

      // ── Refresh ID token so Firestore security rules accept the request ──
      await user.getIdToken(true);

      // ── Helper: batch-delete every doc in a Firestore collection ─────────
      // Fetches in pages of 500 (Firestore WriteBatch limit) until empty.
      Future<void> deleteCollection(String path) async {
        const int batchLimit = 500;
        while (true) {
          final snap = await FirebaseFirestore.instance
              .collection(path)
              .limit(batchLimit)
              .get(const GetOptions(source: Source.server)); // force server

          if (snap.docs.isEmpty) break;

          final batch = FirebaseFirestore.instance.batch();
          for (final doc in snap.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();

          if (snap.docs.length < batchLimit) break;
        }
      }

      // 1. Delete Firestore transactions
      await deleteCollection('transactions/${user.uid}/userTransactions');

      // 2. Delete Firestore budgets
      await deleteCollection('budgets/${user.uid}/userBudgets');

      firestoreCleared = true;
    } on FirebaseException catch (e) {
      debugPrint('[AccountScreen] Firestore clear error: ${e.code} ${e.message}');
      remoteError = switch (e.code) {
        'unavailable'       => 'Offline — local data cleared. Cloud will sync on reconnect.',
        'permission-denied' => 'Cloud delete blocked by Security Rules — local data cleared.',
        'unauthenticated'   => 'Session expired — please sign in again.',
        _                   => '${e.code}: ${e.message}',
      };
    } catch (e) {
      debugPrint('[AccountScreen] Unexpected clear error: $e');
      remoteError = e.toString();
    }

    // ── Always clear local data regardless of network state ─────────────────
    try {
      // 3. Clear all Hive boxes
      await HiveService.clearAll();

      // 4. Reset in-memory BLoC / Cubit state — UI goes blank immediately
      getIt<NotificationCubit>().clearAll();
      getIt<TransactionCubit>().clearAll();
      getIt<BudgetCubit>().clearAll();
      getIt<BalanceCubit>().clearAll();
    } catch (e) {
      debugPrint('[AccountScreen] Local clear error: $e');
    }

    // ── Dismiss loading dialog ───────────────────────────────────────────────
    if (mounted) Navigator.of(context, rootNavigator: true).pop();

    // ── Show result snackbar ─────────────────────────────────────────────────
    if (!mounted) return;

    if (remoteError == null) {
      // Full success
      showPremiumSnackBar(
        context,
        message:  labelCleared,
        subtitle: labelClearedSub,
        icon:     Icons.check_circle_rounded,
      );
    } else if (firestoreCleared == false &&
        remoteError!.contains('Offline')) {
      // Offline — local cleared, remote pending
      showPremiumSnackBar(
        context,
        message:  'Local data cleared',
        subtitle: remoteError,
        icon:     Icons.cloud_off_rounded,
        isError:  false,
      );
    } else {
      // Hard error
      showPremiumSnackBar(
        context,
        message:  labelFailed,
        subtitle: remoteError,
        icon:     Icons.error_outline,
        isError:  true,
      );
    }
  }

  void _showPdfExportModal() {
    // FIX: Resolve BLoC data HERE in the parent context, before the modal
    // opens.  The modal's builder receives a new BuildContext that is NOT
    // inside the TransactionCubit / AppCubit widget tree, so calling
    // context.read<...>() inside the modal would throw / hang forever.
    final txState = context.read<TransactionCubit>().state;
    final transactions = txState is TransactionLoaded
        ? List<TransactionEntity>.from(txState.transactions)
        : <TransactionEntity>[];

    final appState  = getIt<AppCubit>().state;
    final symbol    = appState.symbol;
    final langCode  = appState.languageCode;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => PdfExportModal(
        transactions:   transactions,
        currencySymbol: symbol,
        languageCode:   langCode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, userSnap) {
        final user = userSnap.data ?? FirebaseAuth.instance.currentUser;

        // Reload base64 photo bytes from Firestore into ProfileImageService.
        // This covers app restarts where the in-memory cache is empty.
        ProfileImageService.instance.reloadFromFirestore(user?.uid);

        final name = (user?.displayName?.isNotEmpty == true)
            ? user!.displayName!
            : user?.email?.split('@').first ?? 'User';
        final email = user?.email ?? '';
        final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
        // photoUrl is kept as a fallback only — the avatar widget prefers
        // in-memory bytes from ProfileImageService.bytesNotifier.
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
                    SizedBox(height: rs.sp(330)),

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
                                '${context.tr(S.deleteLabel)} ›',
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
                              'FlowTrack v1.0.0',
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