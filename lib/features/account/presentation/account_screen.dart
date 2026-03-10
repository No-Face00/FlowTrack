// lib/features/account/presentation/account_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/appRouter.dart';
import '../../../core/services/hive_service.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../widgets/account_widgets.dart';

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
  bool _biometric     = true;
  bool _budgetAlerts  = true;
  bool _weeklySummary = true;
  bool _aiTips        = true;
  bool _aiInsights    = true;
  bool _autoCateg     = true;

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

    return Scaffold(
      backgroundColor: AppColors.bgLavender,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: AccountProfileHero(
              name:       name,
              email:      email,
              initial:    initial,
              topPadding: MediaQuery.of(context).padding.top,
            ),
          ),

          SliverPadding(
            padding: EdgeInsets.fromLTRB(
                rs.sp(20), rs.sp(20), rs.sp(20), 110),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                AccountSection(title: 'Account', rows: [
                  AccountSettingRow(
                    icon:      Icons.person_outline_rounded,
                    label:     'Edit Profile',
                   // subtitle:  'Update your name and photo',
                   // iconColor: AppColors.royalBlue,
                    //iconBg:    AppColors.iconTile,
                    trailing:  const AccountChevron(),
                    onTap:     () {},
                  ),
                  AccountSettingRow(
                    icon:      Icons.lock_outline_rounded,
                    label:     'Change PIN',
                   // subtitle:  'Update your security PIN',
                    //iconColor: const Color(0xFF7B5CFF),
                    //iconBg:    const Color(0xFFF0EDFF),
                    trailing:  const AccountChevron(),
                    onTap:     () => context.push(AppRoutes.pinSetup),
                  ),
                  AccountSettingRow(
                    icon:      Icons.fingerprint_rounded,
                    label:     'Biometric Lock',
                   // subtitle:  'Use fingerprint to unlock',
                    //iconColor: const Color(0xFF00C48C),
                   // iconBg:    const Color(0xFFE8FBF5),
                   // isLast:    true,
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
                   // subtitle:  'BDT — Bangladeshi Taka',
                   // iconColor: const Color(0xFF00C48C),
                   // iconBg:    const Color(0xFFE8FBF5),
                    trailing:  const AccountTrailingLabel('BDT ›'),
                    onTap:     () {},
                  ),
                  AccountSettingRow(
                    icon:      Icons.palette_outlined,
                    label:     'Theme',
                   // subtitle:  'Light mode',
                   // iconColor: const Color(0xFFFF8C42),
                   // iconBg:    const Color(0xFFFFF3E8),
                    trailing:  const AccountTrailingLabel('Light ›'),
                    onTap:     () {},
                  ),
                  AccountSettingRow(
                    icon:      Icons.language_rounded,
                    label:     'Language',
                    //subtitle:  'English (United States)',
                   // iconColor: AppColors.royalBlue,
                   // iconBg:    AppColors.iconTile,
                   // isLast:    true,
                    trailing:  const AccountTrailingLabel('EN ›'),
                    onTap:     () {},
                  ),
                ]),

                AccountSection(title: 'Notifications', rows: [
                  AccountSettingRow(
                    icon:      Icons.notifications_outlined,
                    label:     'Budget Alerts',
                    //subtitle:  'Get notified when near limit',
                  //  iconColor: AppColors.expense,
                   // iconBg:    const Color(0xFFFFEEF1),
                    trailing:  AccountToggle(
                      value:     _budgetAlerts,
                      onChanged: (v) => setState(() => _budgetAlerts = v),
                    ),
                  ),
                  AccountSettingRow(
                    icon:      Icons.bar_chart_rounded,
                    label:     'Weekly Summary',
                   // subtitle:  'Sunday spending report',
                   // iconColor: AppColors.royalBlue,
                    //iconBg:    AppColors.iconTile,
                    trailing:  AccountToggle(
                      value:     _weeklySummary,
                      onChanged: (v) => setState(() => _weeklySummary = v),
                    ),
                  ),
                  AccountSettingRow(
                    icon:      Icons.lightbulb_outline_rounded,
                    label:     'AI Tips',
                   // subtitle:  'Smart saving suggestions',
                   // iconColor: const Color(0xFFFF8C42),
                   // iconBg:    const Color(0xFFFFF3E8),
                   // isLast:    true,
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
                   // subtitle:  'Smart financial analysis',
                   // iconColor: const Color(0xFF7B5CFF),
                   //iconBg:    const Color(0xFFF0EDFF),
                    trailing:  AccountToggle(
                      value:     _aiInsights,
                      onChanged: (v) => setState(() => _aiInsights = v),
                    ),
                  ),
                  AccountSettingRow(
                    icon:      Icons.label_outline_rounded,
                    label:     'Auto-Categorize',
                  //  subtitle:  'AI assigns categories',
                  //  iconColor: const Color(0xFF00C48C),
                   // iconBg:    const Color(0xFFE8FBF5),
                   // isLast:    true,
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
                  //  subtitle:  'Download monthly statement',
                  //  iconColor: AppColors.expense,
                  //  iconBg:    const Color(0xFFFFEEF1),
                    trailing:  const AccountChevron(),
                    onTap:     _showComingSoon,
                  ),
                  AccountSettingRow(
                    icon:      Icons.table_chart_outlined,
                    label:     'Export CSV',
                  //  subtitle:  'Raw data for spreadsheets',
                  //  iconColor: const Color(0xFF00C48C),
                  //  iconBg:    const Color(0xFFE8FBF5),
                    trailing:  const AccountChevron(),
                    onTap:     _showComingSoon,
                  ),
                  AccountSettingRow(
                    icon:      Icons.cloud_upload_outlined,
                    label:     'Cloud Backup',
                  //  subtitle:  'Sync to Firebase',
                  //  iconColor: AppColors.royalBlue,
                  //  iconBg:    AppColors.iconTile,
                    trailing:  const AccountChevron(),
                    onTap:     () {},
                  ),
                  AccountSettingRow(
                    icon:      Icons.delete_outline_rounded,
                    label:     'Clear All Local Data',
                   // subtitle:  'Remove offline cache',
                   // iconColor: AppColors.expense,
                  //  iconBg:    const Color(0xFFFFEEF1),
                   // isLast:    true,
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
              ]),
            ),
          ),
        ],
      ),
    );
  }
}