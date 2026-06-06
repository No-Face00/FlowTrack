/// Stable localization keys — use with [L10nContext.tr].
abstract class S {
  // App
  static const appName    = 'app_name';
  static const appVersion = 'app_version';

  // Navigation
  static const navHome         = 'nav_home';
  static const navTransactions = 'nav_transactions';
  static const navAnalytics    = 'nav_analytics';
  static const navAccount      = 'nav_account';

  // Account screen
  static const account          = 'account';
  static const preferences      = 'preferences';
  static const notifications    = 'notifications';
  static const dataPrivacy      = 'data_privacy';
  static const flowIntelligence = 'flow_intelligence';
  static const editProfile           = 'edit_profile';
  static const tapToChangePhoto      = 'tap_to_change_photo';
  static const displayName           = 'display_name';
  static const yourNameHint          = 'your_name_hint';
  static const saveChanges           = 'save_changes';
  static const profileUpdated        = 'profile_updated';
  static const profileUpdatedSub     = 'profile_updated_sub';
  static const profileError          = 'profile_error';
  static const nameEnterRequired     = 'name_enter_required';
  static const clearItemTransactions = 'clear_item_transactions';
  static const clearItemBudgets      = 'clear_item_budgets';
  static const clearItemAnalytics    = 'clear_item_analytics';
  static const clearItemNotifications= 'clear_item_notifications';
  static const clearItemLocal        = 'clear_item_local';
  static const clearItemFirebase     = 'clear_item_firebase';
  static const changePin        = 'change_pin';
  static const currency         = 'currency';
  static const theme            = 'theme';
  static const language         = 'language';
  static const budgetAlerts     = 'budget_alerts';
  static const flowAdvisorHome  = 'flow_advisor_home';
  static const exportPdf        = 'export_pdf';
  static const clearData        = 'clear_data';
  static const signOut          = 'sign_out';
  static const signOutConfirm   = 'sign_out_confirm';
  static const cancel           = 'cancel';
  static const delete           = 'delete';
  static const deleteAllData    = 'delete_all_data';
  static const clearDataTitle   = 'clear_data_title';
  static const selectCurrency   = 'select_currency';
  static const chooseTheme      = 'choose_theme';
  static const themeLight       = 'theme_light';
  static const themeDark        = 'theme_dark';
  static const themeSystem      = 'theme_system';
  static const selectLanguage   = 'select_language';
  static const languageSubtitle = 'language_subtitle';
  static const lightSub         = 'light_sub';
  static const darkSub          = 'dark_sub';
  static const systemSub        = 'system_sub';
  static const currencyUpdates  = 'currency_updates';
  static const cannotUndo       = 'cannot_undo';
  static const clearWarning     = 'clear_warning';
  static const premiumMember    = 'premium_member';

  // PDF export
  static const exportPdfTitle         = 'export_pdf_title';
  static const exportPdfSubtitle      = 'export_pdf_subtitle';
  static const monthlyReport          = 'monthly_report';
  static const monthlyReportSub       = 'monthly_report_sub';
  static const annualReport           = 'annual_report';
  static const annualReportSub        = 'annual_report_sub';
  static const completeReport         = 'complete_report';
  static const completeReportSub      = 'complete_report_sub';
  static const selectMonth            = 'select_month';
  static const selectYear             = 'select_year';
  static const exportShare            = 'export_share';
  static const generatingPdf          = 'generating_pdf';
  static const pdfSuccess             = 'pdf_success';
  static const pdfSuccessSub          = 'pdf_success_sub';
  static const pdfError               = 'pdf_error';
  static const selectReportType       = 'select_report_type';
  static const noTransactionsPeriod   = 'no_transactions_period';

  // PDF content labels
  static const pdfFinancialReport     = 'pdf_financial_report';
  static const pdfFinancial           = 'pdf_financial';
  static const pdfExpenseBreakdown    = 'pdf_expense_breakdown';
  static const pdfTransactionHistory  = 'pdf_transaction_history';
  static const pdfAiInsight           = 'pdf_ai_insight';
  static const pdfAmount              = 'pdf_amount';
  static const pdfType                = 'pdf_type';
  static const pdfPercentOfSpend      = 'pdf_percent_of_spend';

  // Auth
  static const authSignIn         = 'auth_sign_in';
  static const authSignInSub      = 'auth_sign_in_sub';
  static const authSignUp         = 'auth_sign_up';
  static const authSignUpSub      = 'auth_sign_up_sub';
  static const authEmail          = 'auth_email';
  static const authPassword       = 'auth_password';
  static const authFullName       = 'auth_full_name';
  static const authForgotPassword = 'auth_forgot_password';
  static const authResetSent      = 'auth_reset_sent';
  static const passwordRequired   = 'password_required';
  static const nameRequired       = 'name_required';
  static const welcomeBack        = 'welcome_back';
  static const createAccount      = 'create_account';
  static const orContinueWith     = 'or_continue_with';
  static const resetPassword      = 'reset_password';
  static const sendLink           = 'send_link';

  // PIN screens — lock
  static const pinWelcomeBack        = 'pin_welcome_back';
  static const pinEnterHint          = 'pin_enter_hint';
  static const pinUseBiometrics      = 'pin_use_biometrics';
  static const pinForgot             = 'pin_forgot';
  static const pinWrongAttempt       = 'pin_wrong_attempt';

  // PIN screens — verify identity
  static const pinVerifyTitle        = 'pin_verify_title';
  static const pinVerifyContinue     = 'pin_verify_continue';
  static const pinVerifyGoogle       = 'pin_verify_google';
  static const pinVerifyGoogleSub    = 'pin_verify_google_sub';
  static const pinVerifyPasswordSub  = 'pin_verify_password_sub';
  static const pinAccountPassword    = 'pin_account_password';

  // PIN screens — setup
  static const pinCreateTitle        = 'pin_create_title';
  static const pinConfirmTitle       = 'pin_confirm_title';
  static const pinChooseSecure       = 'pin_choose_secure';
  static const pinReenterConfirm     = 'pin_reenter_confirm';
  static const pinStepSet            = 'pin_step_set';
  static const pinStepConfirm        = 'pin_step_confirm';
  static const pinMismatch           = 'pin_mismatch';
  static const pinUpdateHint         = 'pin_update_hint';

  // PIN screens — reset
  static const pinSetNewTitle        = 'pin_set_new_title';
  static const pinConfirmNewTitle    = 'pin_confirm_new_title';
  static const pinChooseNew          = 'pin_choose_new';
  static const pinReenterNew         = 'pin_reenter_new';
  static const pinMismatchRetry      = 'pin_mismatch_retry';

  // Welcome screen (post-PIN setup)
  static const welcomeAllSet          = 'welcome_all_set';
  static const welcomeSubtitle        = 'welcome_subtitle';
  static const welcomeFeatureTracking = 'welcome_feature_tracking';
  static const welcomeFeatureInsights = 'welcome_feature_insights';
  static const welcomeFeatureSecurity = 'welcome_feature_security';

  // Misc
  static const comingSoon      = 'coming_soon';
  static const comingSoonSub   = 'coming_soon_sub';
  static const deletingData    = 'deleting_data';
  static const deletingDataSub = 'deleting_data_sub';
  static const dataCleared     = 'data_cleared';
  static const dataClearedSub  = 'data_cleared_sub';
  static const clearFailed     = 'clear_failed';

  // Home
  static const hello              = 'hello';
  static const totalBalance       = 'total_balance';
  static const income             = 'income';
  static const expenses           = 'expenses';
  static const surplus            = 'surplus';
  static const savingsRate        = 'savings_rate';
  static const overBudget         = 'over_budget';
  static const thisMonthSpending  = 'this_month_spending';
  static const noExpensesMonth    = 'no_expenses_month';
  static const spendingBreakdown  = 'spending_breakdown';
  static const close              = 'close';
  static const done               = 'done';
  static const quickActions       = 'quick_actions';
  static const transfer           = 'transfer';
  static const budget             = 'budget';
  static const recentTransactions = 'recent_transactions';
  static const seeAll             = 'see_all';
  static const noTransactionsYet  = 'no_transactions_yet';
  static const addFirstTxn        = 'add_first_txn';
  static const categories         = 'categories';
  static const noExpensesRecorded = 'no_expenses_recorded';
  static const thisMonth          = 'this_month';

  // Transaction detail popup
  static const labelCategory   = 'label_category';
  static const labelDate       = 'label_date';
  static const labelCurrency   = 'label_currency';
  static const labelNote       = 'label_note';
  static const labelSyncStatus = 'label_sync_status';

  // Transactions
  static const transactions       = 'transactions';
  static const txnSubtitle        = 'txn_subtitle';
  static const txnActivitySub     = 'txn_activity_sub';
  static const searchTransactions = 'search_transactions';
  static const filterAll          = 'filter_all';
  static const filterIncome       = 'filter_income';
  static const filterExpense      = 'filter_expense';
  static const filterTransfer     = 'filter_transfer';
  static const filterThisMonth    = 'filter_this_month';
  static const addTransaction     = 'add_transaction';
  static const enterAmount        = 'enter_amount';
  static const category           = 'category';
  static const details            = 'details';
  static const titleHint          = 'title_hint';
  static const noteHint           = 'note_hint';
  static const titleRequired      = 'title_required';
  static const saveTransaction    = 'save_transaction';
  static const selectCategory     = 'select_category';
  static const validAmount        = 'valid_amount';
  static const expense            = 'expense';
  static const noTxnMatch         = 'no_txn_match';
  static const txnDeleted         = 'txn_deleted';
  static const undo               = 'undo';
  static const aiSuggests         = 'ai_suggests';
  static const deleteLabel        = 'delete_label';

  // Empty states
  static const emptyIncomeTitle   = 'empty_income_title';
  static const emptyExpenseTitle  = 'empty_expense_title';
  static const emptyTransferTitle = 'empty_transfer_title';
  static const emptyMonthTitle    = 'empty_month_title';
  static const emptyIncomeSub     = 'empty_income_sub';
  static const emptyExpenseSub    = 'empty_expense_sub';
  static const emptyTransferSub   = 'empty_transfer_sub';
  static const emptyMonthSub      = 'empty_month_sub';
  static const emptyAllSub        = 'empty_all_sub';
  static const addIncome          = 'add_income';
  static const addExpenseBtn      = 'add_expense_btn';
  static const addTransferBtn     = 'add_transfer_btn';

  // Analytics
  static const analytics            = 'analytics';
  static const financialOverview    = 'financial_overview';
  static const netBalance           = 'net_balance';
  static const deficit              = 'deficit';
  static const spent                = 'spent';
  static const saved                = 'saved';
  static const daily                = 'daily';
  static const monthly              = 'monthly';
  static const yearly               = 'yearly';
  static const dailyHistory         = 'daily_history';
  static const yearlyHistory        = 'yearly_history';
  static const viewPeriod           = 'view_period';
  static const selectTimeRange      = 'select_time_range';
  static const last7Days            = 'last_7_days';
  static const last6Months          = 'last_6_months';
  static const last5Years           = 'last_5_years';
  static const budgetOverview       = 'budget_overview';
  static const budgetTapEdit        = 'budget_tap_edit';
  static const monthlyHistory       = 'monthly_history';
  static const incomeExpensesPeriod = 'income_expenses_period';
  static const totalIncome          = 'total_income';
  static const totalExpenses        = 'total_expenses';
  static const cashFlow             = 'cash_flow';
  static const incomeVsExpenses     = 'income_vs_expenses';
  static const add                  = 'add';
  static const periods              = 'periods';
  static const set                  = 'set';
  static const removeBudget         = 'remove_budget';
  static const removeBudgetConfirm  = 'remove_budget_confirm';
  static const saveBudget           = 'save_budget';

  // Onboarding
  static const onboardTitle1 = 'onboard_title_1';
  static const onboardSub1   = 'onboard_sub_1';
  static const onboardTitle2 = 'onboard_title_2';
  static const onboardSub2   = 'onboard_sub_2';
  static const onboardTitle3 = 'onboard_title_3';
  static const onboardSub3   = 'onboard_sub_3';
  static const onboardTitle4 = 'onboard_title_4';
  static const onboardSub4   = 'onboard_sub_4';
  static const skip          = 'skip';
  static const continueBtn   = 'continue_btn';
  static const getStarted    = 'get_started';

  // PDF custom range
  static const customReport     = 'custom_report';
  static const customReportSub  = 'custom_report_sub';
  static const startDate        = 'start_date';
  static const endDate          = 'end_date';
  static const invalidDateRange = 'invalid_date_range';

  // Notifications
  static const notificationsTitle = 'notifications_title';
  static const markAllRead        = 'mark_all_read';
  static const noNotifications    = 'no_notifications';
  static const noNotificationsSub = 'no_notifications_sub';
  static const clearAll           = 'clear_all';
  static const swipeToDismiss     = 'swipe_to_dismiss';
  static const removeNotification = 'remove_notification';
  static const setBudgetsHint     = 'set_budgets_hint';

  // Budget notification templates (use {pct}, {spent}, {limit}, {remaining}, {over}, {days})
  static const budgetNotifTitleWarning  = 'budget_notif_title_warning';
  static const budgetNotifTitleCritical = 'budget_notif_title_critical';
  static const budgetNotifTitleExceeded = 'budget_notif_title_exceeded';
  static const budgetNotifBodyWarning   = 'budget_notif_body_warning';
  static const budgetNotifBodyCritical  = 'budget_notif_body_critical';
  static const budgetNotifBodyExceeded  = 'budget_notif_body_exceeded';
  static const notifChipWarning   = 'notif_chip_warning';
  static const notifChipCritical  = 'notif_chip_critical';
  static const notifChipExceeded  = 'notif_chip_exceeded';
  static const notifView          = 'notif_view';
  static const notifAlertsCount   = 'notif_alerts_count';
  static const notifJustNow       = 'notif_just_now';
  static const notifMinutesAgo    = 'notif_minutes_ago';
  static const notifHoursAgo      = 'notif_hours_ago';
  static const notifDaysAgo       = 'notif_days_ago';
  static const notifEmptyBudgetBody = 'notif_empty_budget_body';

  // Transaction category → title suggestion
  static const txnTapToFillTitle  = 'txn_tap_to_fill_title';

  // Analytics / account extras
  static const legendActive       = 'legend_active';
  static const legendSelected     = 'legend_selected';
  static const legendAvailable    = 'legend_available';
  static const addBudgetTitle     = 'add_budget_title';
  static const addBudgetSheetSub  = 'add_budget_sheet_sub';
  static const monthlyLimitFor    = 'monthly_limit_for';
  static const overAmountPrefix   = 'over_amount_prefix';
  static const savedAmountPrefix  = 'saved_amount_prefix';
  static const setMonthlyLimit    = 'set_monthly_limit';
  static const rtlLabel           = 'rtl_label';
  static const budgetsLabel       = 'budgets_label';
  static const walletsLabel       = 'wallets_label';
  static const removeBudgetNamed  = 'remove_budget_named';

  // Insight chips
  static const insightAlert = 'insight_alert';
  static const insightWin   = 'insight_win';
  static const insightSave  = 'insight_save';
  static const insightSpend = 'insight_spend';
  static const insightTip   = 'insight_tip';

  // Flow Advisor — multi-category brain keys
  static const faBudgetOverflowItem   = 'fa_budget_overflow_item';
  static const faRecoveryTip          = 'fa_recovery_tip';
  static const faIncomeExceeded       = 'fa_income_exceeded';
  static const faOverflowHeadline     = 'fa_overflow_headline';
  static const faRiskItem             = 'fa_risk_item';
  static const faProjectionTip        = 'fa_projection_tip';
  static const faRiskHeadline         = 'fa_risk_headline';
  static const faVelocityItem         = 'fa_velocity_item';
  static const faVelocityFooter       = 'fa_velocity_footer';
  static const faVelocityHeadline     = 'fa_velocity_headline';
  static const faSpikeHeadline        = 'fa_spike_headline';
  static const faSpikeItem            = 'fa_spike_item';
  static const faSpikeWarning         = 'fa_spike_warning';
  static const faIncomeWarnHeadline   = 'fa_income_warn_headline';
  static const faIncomeWarnItem       = 'fa_income_warn_item';
  static const faReviewAllCats        = 'fa_review_all_cats';
  static const faSaveHeadline         = 'fa_save_headline';
  static const faSaveItem             = 'fa_save_item';
  static const faOnTrackCount         = 'fa_on_track_count';
  static const faMomUpHeadline        = 'fa_mom_up_headline';
  static const faMomUpItem            = 'fa_mom_up_item';
  static const faMomDownHeadline      = 'fa_mom_down_headline';
  static const faMomDownItem          = 'fa_mom_down_item';
  static const faSavingsRateNote      = 'fa_savings_rate_note';
  static const faConcentrationHeadline = 'fa_concentration_headline';
  static const faConcentrationItem    = 'fa_concentration_item';
  static const faConcentrationTip     = 'fa_concentration_tip';
  static const faLifetimeLowHeadline  = 'fa_lifetime_low_headline';
  static const faLifetimeLowItem      = 'fa_lifetime_low_item';
  static const faSetBudgetsTip        = 'fa_set_budgets_tip';
  static const faLifetimeHighHeadline = 'fa_lifetime_high_headline';
  static const faLifetimeHighItem     = 'fa_lifetime_high_item';
  static const faKeepBudgetsTip       = 'fa_keep_budgets_tip';
  static const faEmptyHeadline        = 'fa_empty_headline';
  static const faEmptyTip             = 'fa_empty_tip';
  static const faNeutralHeadline      = 'fa_neutral_headline';
  static const faIncomePctNote        = 'fa_income_pct_note';
  static const faKeepLogging          = 'fa_keep_logging';
  static const faSteadyHeadline       = 'fa_steady_headline';
  static const faSteadyItem           = 'fa_steady_item';
  static const faBudgetContext        = 'fa_budget_context';

  // Home widgets
  static const syncedLabel            = 'synced_label';
  static const pendingSyncLabel       = 'pending_sync_label';
  static const flowAdvisor        = 'flow_advisor';
  static const flowAdvisorSub     = 'flow_advisor_sub';
  static const flowAdvisorRefresh = 'flow_advisor_refresh';
  static const flowAdvisorDismiss = 'flow_advisor_dismiss';
  static const flowAdvisorEmpty   = 'flow_advisor_empty';
  static const live               = 'live';

  // Flow Advisor fallback
  static const advisorGood    = 'advisor_good';
  static const advisorCaution = 'advisor_caution';

  // Flow Advisor dynamic patterns (tokenized strings)
  static const faWarn1    = 'fa_warn_1';
  static const faWarn2    = 'fa_warn_2';
  static const faSpike1   = 'fa_spike_1';
  static const faSpike2   = 'fa_spike_2';
  static const faSave1    = 'fa_save_1';
  static const faSave2    = 'fa_save_2';
  static const faMotiv1   = 'fa_motiv_1';
  static const faMotiv2   = 'fa_motiv_2';
  static const faNeutral1 = 'fa_neutral_1';
  static const faNeutral2 = 'fa_neutral_2';

  // Router / 404
  static const pageNotFound = 'page_not_found';
  static const goToLogin    = 'go_to_login';
}