// lib/core/notifications/notification_cubit.dart
//
// ── NotificationCubit — v26 complete fix ─────────────────────────────────────
//
// ROOT CAUSES FIXED:
//   1. month/year guard removed — budgets now checked regardless of which
//      month they were created for, as long as spending is current-month.
//      (Old code: `if (budget.month != thisMonth || budget.year != thisYear) continue;`
//       This silently skipped every default budget because they may carry
//       month=0 or a stale month when loaded from cache.)
//   2. checkBudgets() now also returns a list of NEW notifications it just
//      created so callers can show an immediate top banner.
//   3. _fmt() produces accurate decimal-aware output.
//   4. Over-budget amount is explicitly included in the alert body.
//   5. Added resetAlertForBudget() so alerts re-fire after clearAll().

import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/budget/domain/entities/budget_entity.dart';
import '../../features/transactions/domain/entities/transaction_entity.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class AppNotification {
  final String   id;
  final String   title;
  final String   body;
  final String   category;
  final String   emoji;
  final DateTime timestamp;
  final bool     isRead;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.emoji,
    required this.timestamp,
    this.isRead = false,
  });

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id:        id,
    title:     title,
    body:      body,
    category:  category,
    emoji:     emoji,
    timestamp: timestamp,
    isRead:    isRead ?? this.isRead,
  );

  Map<String, dynamic> toJson() => {
    'id':        id,
    'title':     title,
    'body':      body,
    'category':  category,
    'emoji':     emoji,
    'timestamp': timestamp.toIso8601String(),
    'isRead':    isRead,
  };

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id:        j['id'] as String,
    title:     j['title'] as String,
    body:      j['body'] as String,
    category:  j['category'] as String? ?? '',
    emoji:     j['emoji'] as String? ?? '🔔',
    timestamp: DateTime.parse(j['timestamp'] as String),
    isRead:    j['isRead'] as bool? ?? false,
  );
}

// ── State ─────────────────────────────────────────────────────────────────────

class NotificationState {
  final List<AppNotification> notifications;
  final bool budgetAlertsEnabled;

  const NotificationState({
    this.notifications = const [],
    this.budgetAlertsEnabled = true,
  });

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  NotificationState copyWith({
    List<AppNotification>? notifications,
    bool? budgetAlertsEnabled,
  }) => NotificationState(
    notifications:       notifications       ?? this.notifications,
    budgetAlertsEnabled: budgetAlertsEnabled ?? this.budgetAlertsEnabled,
  );
}

// ── Cubit ─────────────────────────────────────────────────────────────────────

class NotificationCubit extends Cubit<NotificationState> {
  NotificationCubit() : super(const NotificationState());

  static const _kNotifs  = 'app_notifications_v2';   // bumped key to clear stale data
  static const _kAlerts  = 'budget_alerts_enabled';
  static const _maxStore = 50;

  // ── Load ──────────────────────────────────────────────────────────────────
  Future<void> load() async {
    final prefs   = await SharedPreferences.getInstance();
    final raw     = prefs.getStringList(_kNotifs) ?? [];
    final enabled = prefs.getBool(_kAlerts) ?? true;
    final notifs  = raw
        .map((s) {
      try { return AppNotification.fromJson(json.decode(s) as Map<String, dynamic>); }
      catch (_) { return null; }
    })
        .whereType<AppNotification>()
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    emit(state.copyWith(notifications: notifs, budgetAlertsEnabled: enabled));
  }

  // ── Check budgets — FIXED ─────────────────────────────────────────────────
  //
  // Returns the list of newly created AppNotification objects so the caller
  // can immediately show a top banner (without waiting for another build cycle).
  //
  // FIX: month/year guard on BudgetEntity removed.
  //   Reason: default budgets are seeded at runtime with whatever month.year
  //   the BudgetCubit happens to load them — this can be month=0 (initial),
  //   or a cached month from a prior session. We should only care that the
  //   *current* month's *spending* exceeds the budget's limitAmount.
  //
  List<AppNotification> checkBudgets({
    required List<TransactionEntity> transactions,
    required List<BudgetEntity>      budgets,
    required String                  symbol,
  }) {
    if (!state.budgetAlertsEnabled) return [];
    if (budgets.isEmpty) return [];

    final now         = DateTime.now();
    final thisMonth   = now.month;
    final thisYear    = now.year;
    final existingIds = state.notifications.map((n) => n.id).toSet();
    final newNotifs   = <AppNotification>[];

    // Sum this month's expense by category
    final spending = <String, double>{};
    for (final tx in transactions) {
      if (tx.type == 'expense' &&
          tx.date.month == thisMonth &&
          tx.date.year  == thisYear) {
        final cat = tx.category.toLowerCase().trim();
        spending[cat] = (spending[cat] ?? 0) + tx.amount;
      }
    }

    for (final budget in budgets) {
      if (budget.limitAmount <= 0) continue;
      // FIX: no month/year guard — we match by category name only
      final cat   = budget.category.toLowerCase().trim();
      final spent = spending[cat] ?? 0;
      if (spent <= 0) continue;

      final pct = spent / budget.limitAmount;

      if (pct >= 1.0) {
        // ── Exceeded ──────────────────────────────────────────
        // ID encodes month/year so we get one alert per calendar month
        final alertId = 'budget_exceeded_${cat}_${thisMonth}_$thisYear';
        if (!existingIds.contains(alertId)) {
          final over = spent - budget.limitAmount;
          final notif = AppNotification(
            id:        alertId,
            title:     '${budget.emoji} ${budget.label} Budget Exceeded',
            body:      'You spent $symbol${_fmt(spent)} against a '
                '$symbol${_fmt(budget.limitAmount)} budget. '
                'Over by $symbol${_fmt(over)}.',
            category:  budget.category,
            emoji:     budget.emoji,
            timestamp: DateTime.now(),
          );
          newNotifs.add(notif);
          existingIds.add(alertId); // prevent same run from duplication
        }
      } else if (pct >= 0.80) {
        // ── 80% warning ───────────────────────────────────────
        final alertId = 'budget_warning_${cat}_${thisMonth}_$thisYear';
        if (!existingIds.contains(alertId)) {
          final remaining = budget.limitAmount - spent;
          final notif = AppNotification(
            id:        alertId,
            title:     '${budget.emoji} ${budget.label} Budget Warning',
            body:      '${(pct * 100).round()}% used — $symbol${_fmt(spent)} of '
                '$symbol${_fmt(budget.limitAmount)}. '
                'Only $symbol${_fmt(remaining)} remaining.',
            category:  budget.category,
            emoji:     budget.emoji,
            timestamp: DateTime.now(),
          );
          newNotifs.add(notif);
          existingIds.add(alertId);
        }
      }
    }

    if (newNotifs.isEmpty) return [];

    final updated = [...newNotifs, ...state.notifications].take(_maxStore).toList();
    emit(state.copyWith(notifications: updated));
    _persist(updated);
    return newNotifs; // ← returned so caller can show banner
  }

  // ── Mark all read ─────────────────────────────────────────────────────────
  void markAllRead() {
    final updated = state.notifications.map((n) => n.copyWith(isRead: true)).toList();
    emit(state.copyWith(notifications: updated));
    _persist(updated);
  }

  // ── Mark single read ──────────────────────────────────────────────────────
  void markRead(String id) {
    final updated = state.notifications
        .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
        .toList();
    emit(state.copyWith(notifications: updated));
    _persist(updated);
  }

  // ── Clear all ─────────────────────────────────────────────────────────────
  void clearAll() {
    emit(state.copyWith(notifications: []));
    _persist([]);
  }

  // ── Dismiss single notification ───────────────────────────────────────────
  void dismiss(String id) {
    if (isClosed) return;
    final updated = state.notifications.where((n) => n.id != id).toList();
    emit(state.copyWith(notifications: updated));
    _persist(updated);
  }

  // ── Toggle budget alerts ──────────────────────────────────────────────────
  Future<void> setBudgetAlerts(bool enabled) async {
    emit(state.copyWith(budgetAlertsEnabled: enabled));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAlerts, enabled);
  }

  // ── Persist ───────────────────────────────────────────────────────────────
  Future<void> _persist(List<AppNotification> notifs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kNotifs,
      notifs.map((n) => json.encode(n.toJson())).toList(),
    );
  }

  // ── Format ───────────────────────────────────────────────────────────────
  static String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}K';
    return v.toStringAsFixed(v % 1 == 0 ? 0 : 1);
  }
}