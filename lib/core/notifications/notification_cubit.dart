// lib/core/notifications/notification_cubit.dart
//
// ── NotificationCubit ─────────────────────────────────────────────────────────
//
// Single source of truth for in-app notifications.
//
// HOW BUDGET ALERTS WORK:
//   1. HomeScreen and AnalyticsScreen call checkBudgets() whenever
//      TransactionCubit or BudgetCubit emits a new state.
//   2. checkBudgets() compares each budget's limitAmount against the
//      current month's spending for that category.
//   3. When spending >= limitAmount: emit an alert (once per budget-month
//      combo — deduplicated by id so it never fires twice).
//   4. Alerts appear in the notification sheet opened from the Home bell.
//
// PERSISTENCE:
//   SharedPreferences — instant load, no network needed.
//   Max 50 notifications stored (oldest pruned automatically).

import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../features/budget/domain/entities/budget_entity.dart';
import '../../features/transactions/domain/entities/transaction_entity.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class AppNotification {
  final String   id;
  final String   title;
  final String   body;
  final String   category;  // e.g. 'food'
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

  static const _kNotifs  = 'app_notifications';
  static const _kAlerts  = 'budget_alerts_enabled';
  static const _maxStore = 50;

  // ── Load from SharedPrefs ─────────────────────────────────────────────────
  Future<void> load() async {
    final prefs    = await SharedPreferences.getInstance();
    final raw      = prefs.getStringList(_kNotifs) ?? [];
    final enabled  = prefs.getBool(_kAlerts) ?? true;
    final notifs   = raw
        .map((s) {
      try { return AppNotification.fromJson(json.decode(s) as Map<String, dynamic>); }
      catch (_) { return null; }
    })
        .whereType<AppNotification>()
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    emit(state.copyWith(notifications: notifs, budgetAlertsEnabled: enabled));
  }

  // ── Check budgets and generate alerts ────────────────────────────────────
  /// Called from HomeScreen / AnalyticsScreen whenever transactions or
  /// budgets update. Compares each budget against current-month spending.
  void checkBudgets({
    required List<TransactionEntity> transactions,
    required List<BudgetEntity>      budgets,
    required String                  symbol,
  }) {
    if (!state.budgetAlertsEnabled) return;
    if (budgets.isEmpty) return;

    final now          = DateTime.now();
    final thisMonth    = now.month;
    final thisYear     = now.year;
    final existingIds  = state.notifications.map((n) => n.id).toSet();
    final newNotifs    = <AppNotification>[];

    // Group this month's spending by category (lowercase)
    final spending = <String, double>{};
    for (final tx in transactions) {
      if (tx.type == 'expense' &&
          tx.date.month == thisMonth &&
          tx.date.year  == thisYear) {
        final cat = tx.category.toLowerCase();
        spending[cat] = (spending[cat] ?? 0) + tx.amount;
      }
    }

    // Compare each active budget
    for (final budget in budgets) {
      if (budget.limitAmount <= 0) continue;
      if (budget.month != thisMonth || budget.year != thisYear) continue;

      final spent    = spending[budget.category.toLowerCase()] ?? 0;
      final pct      = spent / budget.limitAmount;

      // Alert IDs are deterministic so they're never duplicated:
      // one for "100% exceeded", one for "80% warning"
      if (pct >= 1.0) {
        final alertId = 'budget_exceeded_${budget.id}_${thisMonth}_$thisYear';
        if (!existingIds.contains(alertId)) {
          newNotifs.add(AppNotification(
            id:        alertId,
            title:     '${budget.emoji} Budget Exceeded',
            body:      '${budget.label} budget of $symbol${_fmt(budget.limitAmount)} exceeded. '
                'You spent $symbol${_fmt(spent)} this month.',
            category:  budget.category,
            emoji:     budget.emoji,
            timestamp: DateTime.now(),
          ));
        }
      } else if (pct >= 0.80) {
        final alertId = 'budget_warning_${budget.id}_${thisMonth}_$thisYear';
        if (!existingIds.contains(alertId)) {
          newNotifs.add(AppNotification(
            id:        alertId,
            title:     '${budget.emoji} Budget Warning',
            body:      '${budget.label} budget is ${(pct * 100).round()}% used. '
                '$symbol${_fmt(spent)} of $symbol${_fmt(budget.limitAmount)}.',
            category:  budget.category,
            emoji:     budget.emoji,
            timestamp: DateTime.now(),
          ));
        }
      }
    }

    if (newNotifs.isEmpty) return;

    // Prepend new alerts, prune to max
    final updated = [...newNotifs, ...state.notifications]
        .take(_maxStore)
        .toList();
    emit(state.copyWith(notifications: updated));
    _persist(updated);
  }

  // ── Mark all read ─────────────────────────────────────────────────────────
  void markAllRead() {
    final updated = state.notifications
        .map((n) => n.copyWith(isRead: true))
        .toList();
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

  // ── Toggle budget alerts on/off ───────────────────────────────────────────
  Future<void> setBudgetAlerts(bool enabled) async {
    emit(state.copyWith(budgetAlertsEnabled: enabled));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAlerts, enabled);
  }

  // ── Private helpers ───────────────────────────────────────────────────────
  Future<void> _persist(List<AppNotification> notifs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kNotifs,
      notifs.map((n) => json.encode(n.toJson())).toList(),
    );
  }

  static String _fmt(double v) {
    if (v >= 1000) {
      return '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}K';
    }
    return v.toStringAsFixed(0);
  }
}