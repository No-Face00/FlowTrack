import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/budget/domain/entities/budget_entity.dart';
import '../../features/transactions/domain/entities/transaction_entity.dart';
import '../cubit/app_cubit.dart';
import '../di/service_locator.dart';
import '../l10n/l10n_extension.dart';
import 'budget_notification_formatter.dart';

// ── Budget payload (raw amounts — formatted at display time) ────────────────

class BudgetAlertPayload {
  /// [BudgetAlertLevelKey.warning] | critical | exceeded
  final String level;
  final double spent;
  final double limit;
  final String categoryLabel;

  const BudgetAlertPayload({
    required this.level,
    required this.spent,
    required this.limit,
    required this.categoryLabel,
  });

  double get overAmount => spent - limit;
  double get remainingAmount => (limit - spent).clamp(0, double.infinity);
  double get pctUsed => limit > 0 ? (spent / limit) * 100 : 0;

  Map<String, dynamic> toJson() => {
    'level':          level,
    'spent':          spent,
    'limit':          limit,
    'categoryLabel':  categoryLabel,
    // legacy field for older persisted rows
    if (level == BudgetAlertLevelKey.exceeded) 'variant': 'exceeded',
  };

  factory BudgetAlertPayload.fromJson(Map<String, dynamic> j) {
    final legacy = j['variant'] as String?;
    final level = (j['level'] as String?) ??
        (legacy == 'exceeded'
            ? BudgetAlertLevelKey.exceeded
            : BudgetAlertLevelKey.warning);
    return BudgetAlertPayload(
      level:          level,
      spent:          (j['spent'] as num).toDouble(),
      limit:          (j['limit'] as num).toDouble(),
      categoryLabel:  j['categoryLabel'] as String? ?? '',
    );
  }
}

/// Picks the highest-severity budget alert for top banners (exceeded > critical > warning).
AppNotification mostSevereBudgetAlert(List<AppNotification> alerts) {
  int rank(AppNotification n) {
    if (n.id.contains('budget_exceeded')) return 3;
    if (n.id.contains('budget_critical')) return 2;
    if (n.id.contains('budget_warning')) return 1;
    return 0;
  }

  return alerts.reduce(
    (best, n) => rank(n) > rank(best) ? n : best,
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

  /// Full notification text — localized templates + locale-aware amounts.
  String displayBody(String currencyCode, {String? langCode}) {
    final p = budgetPayload;
    if (p == null) return body;
    final lang = langCode ?? getIt<AppCubit>().state.languageCode;
    final now  = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysLeft    = daysInMonth - now.day;
    return BudgetNotificationFormatter.formatBody(
      languageCode:    lang,
      currencyCode:    currencyCode,
      categoryLabel:   p.categoryLabel,
      spent:           p.spent,
      limit:           p.limit,
      levelKey:        p.level,
      daysLeftInMonth: daysLeft.clamp(0, 31),
    );
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


  List<AppNotification> checkBudgets({
    required List<TransactionEntity> transactions,
    required List<BudgetEntity>      budgets,
  }) {
    if (!state.budgetAlertsEnabled) return [];
    if (budgets.isEmpty) return [];

    final now           = DateTime.now();
    final thisMonth     = now.month;
    final thisYear      = now.year;
    final daysInMonth   = DateTime(now.year, now.month + 1, 0).day;
    final daysLeft      = (daysInMonth - now.day).clamp(0, 31);

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

      final warnId     = 'budget_warning_${cat}_${thisMonth}_$thisYear';
      final critId     = 'budget_critical_${cat}_${thisMonth}_$thisYear';
      final exceedId   = 'budget_exceeded_${cat}_${thisMonth}_$thisYear';
      final allIds     = [warnId, critId, exceedId];

      final level = BudgetNotificationFormatter.levelForRatio(pct);

      if (level == BudgetAlertLevel.none) {
        current.removeWhere((n) => allIds.contains(n.id));
        continue;
      }

      final levelKey = BudgetNotificationFormatter.levelKey(level);
      final activeId = switch (level) {
        BudgetAlertLevel.exceeded => exceedId,
        BudgetAlertLevel.critical => critId,
        _                         => warnId,
      };

      // Drop lower-severity rows when upgrading (e.g. 70% → 90% → 100%).
      current.removeWhere((n) => allIds.contains(n.id) && n.id != activeId);

      final lang = getIt<AppCubit>().state.languageCode;
      final currency = getIt<AppCubit>().state.currency;

      if (!current.any((n) => n.id == activeId)) {
        final payload = BudgetAlertPayload(
          level:         levelKey,
          spent:         spent,
          limit:         budget.limitAmount,
          categoryLabel: budget.label,
        );
        final notif = AppNotification(
          id:        activeId,
          title:     BudgetNotificationFormatter.formatTitle(
            languageCode: lang,
            categoryLabel: budget.label,
            emoji:        budget.emoji,
            levelKey:     levelKey,
          ),
          body:      BudgetNotificationFormatter.formatBody(
            languageCode:    lang,
            currencyCode:    currency,
            categoryLabel:   budget.label,
            spent:           spent,
            limit:           budget.limitAmount,
            levelKey:        levelKey,
            daysLeftInMonth: daysLeft,
          ),
          category:  budget.category,
          emoji:     budget.emoji,
          timestamp: DateTime.now(),
          budgetPayload: payload,
        );
        current = [notif, ...current];
        newBannerAlerts.add(notif);
      } else {
        // Update existing row amounts in place (same id, fresh payload).
        current = current.map((n) {
          if (n.id != activeId) return n;
          final payload = BudgetAlertPayload(
            level:         levelKey,
            spent:         spent,
            limit:         budget.limitAmount,
            categoryLabel: budget.label,
          );
          return AppNotification(
            id:            n.id,
            title:         BudgetNotificationFormatter.formatTitle(
              languageCode: lang,
              categoryLabel: budget.label,
              emoji:        budget.emoji,
              levelKey:     levelKey,
            ),
            body:          '',
            category:      n.category,
            emoji:         n.emoji,
            timestamp:     DateTime.now(),
            isRead:        n.isRead,
            budgetPayload: payload,
          );
        }).toList();
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