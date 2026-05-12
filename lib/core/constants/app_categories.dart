// lib/core/constants/app_categories.dart
//
// ── Centralized Category System ────────────────────────────────────────────────
//
// SINGLE SOURCE OF TRUTH for all categories across:
//   • Add Transaction screen
//   • Transaction Screen (filter chips, list display)
//   • Analytics → Category totals
//   • Budget Overview → category picker & progress tracking
//   • Budget Notifications → category matching
//
// HOW IT WORKS:
//   • `AppCategory.value` is the stable key stored in Firestore/Hive
//   • The same key is used in TransactionEntity.category AND BudgetEntity.category
//   • Budget progress = sum of expenses where tx.category == budget.category
//
// ADDING A NEW CATEGORY:
//   1. Add it to `expenseCategories` list below
//   2. It automatically appears in Add Transaction + Budget picker
//   3. No other changes needed

import 'package:flutter/material.dart';

// ── Category model ─────────────────────────────────────────────────────────────

class AppCategory {
  /// Stable key stored in Firestore/Hive — never change after release
  final String value;

  /// Human-readable label shown in UI
  final String label;

  /// Emoji used in Budget Overview cards and notifications
  final String emoji;

  /// Material icon used in Add Transaction picker
  final IconData icon;

  /// Accent color for the category icon tile
  final Color color;

  const AppCategory({
    required this.value,
    required this.label,
    required this.emoji,
    required this.icon,
    required this.color,
  });
}

// ── Expense categories — THE master list ───────────────────────────────────────
//
// `value` MUST match what is stored in TransactionEntity.category exactly.
// Budget tracking breaks if these values drift from transaction values.

const List<AppCategory> expenseCategories = [
  AppCategory(
    value: 'food',
    label: 'Food & Dining',
    emoji: '🍔',
    icon:  Icons.restaurant_rounded,
    color: Color(0xFFFF6B6B),
  ),
  AppCategory(
    value: 'transport',
    label: 'Transport',
    emoji: '🚗',
    icon:  Icons.directions_car_rounded,
    color: Color(0xFF4ECDC4),
  ),
  AppCategory(
    value: 'shopping',
    label: 'Shopping',
    emoji: '🛍️',
    icon:  Icons.shopping_bag_rounded,
    color: Color(0xFFFF9FF3),
  ),
  AppCategory(
    value: 'health',
    label: 'Health & Medical',
    emoji: '💊',
    icon:  Icons.favorite_rounded,
    color: Color(0xFF48DBFB),
  ),
  AppCategory(
    value: 'entertainment',
    label: 'Entertainment',
    emoji: '🎮',
    icon:  Icons.sports_esports_rounded,
    color: Color(0xFFA29BFE),
  ),
  AppCategory(
    value: 'bills',
    label: 'Bills & Utilities',
    emoji: '⚡',
    icon:  Icons.bolt_rounded,
    color: Color(0xFFFDCB6E),
  ),
  AppCategory(
    value: 'education',
    label: 'Education',
    emoji: '🎓',
    icon:  Icons.school_rounded,
    color: Color(0xFF6C5CE7),
  ),
  AppCategory(
    value: 'rent',
    label: 'Rent & Housing',
    emoji: '🏠',
    icon:  Icons.home_rounded,
    color: Color(0xFF00B894),
  ),
  AppCategory(
    value: 'other',
    label: 'Other',
    emoji: '📦',
    icon:  Icons.more_horiz_rounded,
    color: Color(0xFFB2BEC3),
  ),
];

// ── Income categories ──────────────────────────────────────────────────────────

const List<AppCategory> incomeCategories = [
  AppCategory(
    value: 'salary',
    label: 'Salary',
    emoji: '💼',
    icon:  Icons.work_rounded,
    color: Color(0xFF00B894),
  ),
  AppCategory(
    value: 'freelance',
    label: 'Freelance',
    emoji: '💻',
    icon:  Icons.laptop_rounded,
    color: Color(0xFF6C5CE7),
  ),
  AppCategory(
    value: 'investment',
    label: 'Investment',
    emoji: '📈',
    icon:  Icons.trending_up_rounded,
    color: Color(0xFF00CEC9),
  ),
  AppCategory(
    value: 'business',
    label: 'Business',
    emoji: '🏪',
    icon:  Icons.store_rounded,
    color: Color(0xFFFDCB6E),
  ),
  AppCategory(
    value: 'gift',
    label: 'Gift',
    emoji: '🎁',
    icon:  Icons.card_giftcard_rounded,
    color: Color(0xFFFF7675),
  ),
  AppCategory(
    value: 'other',
    label: 'Other',
    emoji: '📦',
    icon:  Icons.more_horiz_rounded,
    color: Color(0xFFB2BEC3),
  ),
];

// ── Transfer ───────────────────────────────────────────────────────────────────

const List<AppCategory> transferCategories = [
  AppCategory(
    value: 'transfer',
    label: 'Transfer',
    emoji: '🔄',
    icon:  Icons.swap_horiz_rounded,
    color: Color(0xFF74B9FF),
  ),
];

// ── Lookup helpers ─────────────────────────────────────────────────────────────

/// Returns the AppCategory for a given value key.
/// Falls back to 'other' if not found.
AppCategory categoryFromValue(String value) {
  return expenseCategories.firstWhere(
        (c) => c.value == value,
    orElse: () => incomeCategories.firstWhere(
          (c) => c.value == value,
      orElse: () => transferCategories.firstWhere(
            (c) => c.value == value,
        orElse: () => expenseCategories.last, // 'other'
      ),
    ),
  );
}

/// Returns the emoji for a given category value.
String categoryEmoji(String value) => categoryFromValue(value).emoji;

/// Returns the human label for a given category value.
String categoryLabel(String value) => categoryFromValue(value).label;