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
//   3. Budget amounts use [BudgetAlertPayload] + [CurrencyHelper] so currency
//      symbols always follow [AppCubit] without persisting formatted strings.

import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/budget/domain/entities/budget_entity.dart';
import '../../features/transactions/domain/entities/transaction_entity.dart';
import '../cubit/app_cubit.dart';

// ── Budget payload (raw amounts — symbol applied at render time) ─────────────

class BudgetAlertPayload {
  static const String kExceeded = 'exceeded';
  static const String kWarning  = 'warning';

  final String variant;
  final double spent;
  final double limit;

  const BudgetAlertPayload({
    required this.variant,
    required this.spent,
    required this.limit,
  });

  double get overAmount => spent - limit;
  double get remainingAmount => limit - spent;
  double get pctUsed => limit > 0 ? (spent / limit) * 100 : 0;

  Map<String, dynamic> toJson() => {
    'variant': variant,
    'spent':   spent,
    'limit':   limit,
  };

  factory BudgetAlertPayload.fromJson(Map<String, dynamic> j) =>
      BudgetAlertPayload(
        variant: j['variant'] as String,
        spent:   (j['spent'] as num).toDouble(),
        limit:   (j['limit'] as num).toDouble(),
      );
}

// ── Model ─────────────────────────────────────────────────────────────────────

class AppNotification {
  final String   id;
  final String   title;
  final String   body;
  final String   category;
  final String   emoji;
  final DateTime timestamp;
  final bool     isRead;

  /// When set, [displayBody] formats amounts with the live app currency.
  /// [body] may be empty for these rows — never persist pre-symbolized money.
  final BudgetAlertPayload? budgetPayload;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.emoji,
    required this.timestamp,
    this.isRead = false,
    this.budgetPayload,
  });

  /// Full notification text with amounts for the given currency code.
  String displayBody(String currencyCode) {
    final p = budgetPayload;
    if (p == null) return body;
    final sym = CurrencyHelper.symbol(currencyCode);
    final fmt = CurrencyHelper.formatCompactAmount;
    if (p.variant == BudgetAlertPayload.kExceeded) {
      final over = p.overAmount;
      return 'You spent $sym${fmt(p.spent)} against a '
          '$sym${fmt(p.limit)} limit. '
          'Over by $sym${fmt(over)}.';
    }
    if (p.variant == BudgetAlertPayload.kWarning) {
      final pct = p.pctUsed.round();
      final remaining = p.remainingAmount;
      return '$pct% used — $sym${fmt(p.spent)} of '
          '$sym${fmt(p.limit)}. '
          '$sym${fmt(remaining)} remaining.';
    }
    return body;
  }

  AppNotification copyWith({
    bool? isRead,
    BudgetAlertPayload? budgetPayload,
  }) => AppNotification(
    id:            id,
    title:         title,
    body:          body,
    category:      category,
    emoji:         emoji,
    timestamp:     timestamp,
    isRead:        isRead ?? this.isRead,
    budgetPayload: budgetPayload ?? this.budgetPayload,
  );

  Map<String, dynamic> toJson() => {
    'id':        id,
    'title':     title,
    'body':      body,
    'category':  category,
    'emoji':     emoji,
    'timestamp': timestamp.toIso8601String(),
    'isRead':    isRead,
    if (budgetPayload != null) 'budgetPayload': budgetPayload!.toJson(),
  };

  factory AppNotification.fromJson(Map<String, dynamic> j) {
    BudgetAlertPayload? payload;
    final raw = j['budgetPayload'];
    if (raw is Map) {
      try {
        payload = BudgetAlertPayload.fromJson(Map<String, dynamic>.from(raw));
      } catch (_) {}
    }
    return AppNotification(
      id:            j['id'] as String,
      title:         j['title'] as String,
      body:          j['body'] as String? ?? '',
      category:      j['category'] as String? ?? '',
      emoji:         j['emoji'] as String? ?? '🔔',
      timestamp:     DateTime.parse(j['timestamp'] as String),
      isRead:        j['isRead'] as bool? ?? false,
      budgetPayload: payload,
    );
  }
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

  // v3: budget rows store [BudgetAlertPayload] — bodies format with live currency.
  static const _kNotifs  = 'app_notifications_v3';
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

  // ── Check budgets — fully dynamic, category-agnostic ─────────────────────
  //
  // Works for EVERY active budget category automatically — no hardcoded names.
  // Iterates whatever budgets[] contains, computes spending, reconciles state.
  //
  // KEY BEHAVIORS:
  //   1. Fully dynamic — works for any category name, including custom ones.
  //   2. Warning → Exceeded UPGRADE: spending crosses 100% → warning is
  //      removed and replaced with exceeded notification (not blocked).
  //   3. Exceeded → Warning DOWNGRADE: transaction deleted, spending drops
  //      below 100% → exceeded removed, warning emitted (real-time accuracy).
  //   4. Below 80%: all alerts for that category are cleared automatically.
  //   5. Returns NEW banner-worthy alerts so caller can show top slide-in.
  //
  List<AppNotification> checkBudgets({
    required List<TransactionEntity> transactions,
    required List<BudgetEntity>      budgets,
  }) {
    if (!state.budgetAlertsEnabled) return [];
    if (budgets.isEmpty) return [];

    final now       = DateTime.now();
    final thisMonth = now.month;
    final thisYear  = now.year;

    // ── Step 1: Sum this month's expenses by category ─────────────────────
    final spending = <String, double>{};
    for (final tx in transactions) {
      if (tx.type == 'expense' &&
          tx.date.month == thisMonth &&
          tx.date.year  == thisYear) {
        final cat = tx.category.toLowerCase().trim();
        spending[cat] = (spending[cat] ?? 0) + tx.amount;
      }
    }

    // ── Step 2: Reconcile alerts against current spending ─────────────────
    // We work on a mutable copy so we can add/remove in one pass.
    var current           = List<AppNotification>.from(state.notifications);
    final newBannerAlerts = <AppNotification>[];

    for (final budget in budgets) {
      if (budget.limitAmount <= 0) continue;

      final cat    = budget.category.toLowerCase().trim();
      final spent  = spending[cat] ?? 0;
      final pct    = spent / budget.limitAmount;

      final warnId    = 'budget_warning_${cat}_${thisMonth}_$thisYear';
      final exceedId  = 'budget_exceeded_${cat}_${thisMonth}_$thisYear';
      final hasWarn   = current.any((n) => n.id == warnId);
      final hasExceed = current.any((n) => n.id == exceedId);

      if (pct >= 1.0) {
        // ── EXCEEDED ──────────────────────────────────────────
        // Remove warning (upgrade) then add exceeded if new
        if (hasWarn) current.removeWhere((n) => n.id == warnId);
        if (!hasExceed) {
          final notif = AppNotification(
            id:        exceedId,
            title:     '${budget.emoji} ${budget.label} Budget Exceeded',
            body:      '',
            category:  budget.category,
            emoji:     budget.emoji,
            timestamp: DateTime.now(),
            budgetPayload: BudgetAlertPayload(
              variant: BudgetAlertPayload.kExceeded,
              spent:   spent,
              limit:   budget.limitAmount,
            ),
          );
          current = [notif, ...current];
          newBannerAlerts.add(notif);
        }
      } else if (pct >= 0.80) {
        // ── WARNING ───────────────────────────────────────────
        // Remove exceeded (downgrade) then add warning if new
        if (hasExceed) current.removeWhere((n) => n.id == exceedId);
        if (!hasWarn) {
          final notif = AppNotification(
            id:        warnId,
            title:     '${budget.emoji} ${budget.label} Budget Warning',
            body:      '',
            category:  budget.category,
            emoji:     budget.emoji,
            timestamp: DateTime.now(),
            budgetPayload: BudgetAlertPayload(
              variant: BudgetAlertPayload.kWarning,
              spent:   spent,
              limit:   budget.limitAmount,
            ),
          );
          current = [notif, ...current];
          newBannerAlerts.add(notif);
        }
      } else {
        // ── BELOW THRESHOLD — clear stale alerts ──────────────
        current.removeWhere((n) => n.id == warnId || n.id == exceedId);
      }
    }

    // ── Step 3: Persist and emit ──────────────────────────────────────────
    final trimmed = current.take(_maxStore).toList();
    emit(state.copyWith(notifications: trimmed));
    _persist(trimmed);

    // Return new banner-worthy alerts (caller shows the most severe)
    return newBannerAlerts;
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

  /// General system notification (sync, security, AI).
  void pushSystem({
    required String title,
    required String body,
    String emoji = '🔔',
    String category = 'system',
  }) {
    final id = 'sys_${category}_${DateTime.now().millisecondsSinceEpoch}';
    final notif = AppNotification(
      id: id,
      title: title,
      body: body,
      category: category,
      emoji: emoji,
      timestamp: DateTime.now(),
    );
    final updated = [notif, ...state.notifications].take(_maxStore).toList();
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

}