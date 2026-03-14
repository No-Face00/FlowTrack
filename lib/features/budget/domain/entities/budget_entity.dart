// lib/features/budget/domain/entities/budget_entity.dart
//
// ARCHITECTURE: Domain Layer — Pure Dart, zero dependencies.
//
// WHY a separate BudgetEntity?
//   Transactions = facts (what happened).
//   Budgets      = goals (what the user wants to limit).
//   Mixing them violates Single Responsibility Principle.
//   The domain layer knows nothing about Hive or Firestore —
//   that knowledge lives exclusively in the data layer.
//
// WHY month + year as separate ints (not DateTime)?
//   1. Firestore queries: .where('month', isEqualTo: 3) is fast.
//   2. Hive filtering: simple int comparison, no date parsing.
//   3. Users set budgets per-month — "spend less on food in March"
//      creates a new budget for month:3 only, not all months.
//   4. DateTime would carry time/timezone noise we don't need.

import 'package:equatable/equatable.dart';

class BudgetEntity extends Equatable {
  final String id;           // UUID v4 — same ID in Hive and Firestore
  final String category;     // matches TransactionEntity.category exactly
  final String label;        // display name e.g. "Food & Dining"
  final String emoji;        // display emoji e.g. "🍔"
  final double limitAmount;  // monthly spending limit in user's currency
  final String currency;     // 'BDT' | 'USD' | 'EUR' etc.
  final int    month;        // 1–12
  final int    year;         // e.g. 2026

  const BudgetEntity({
    required this.id,
    required this.category,
    required this.label,
    required this.emoji,
    required this.limitAmount,
    required this.currency,
    required this.month,
    required this.year,
  });

  BudgetEntity copyWith({
    String? id,
    String? category,
    String? label,
    String? emoji,
    double? limitAmount,
    String? currency,
    int?    month,
    int?    year,
  }) {
    return BudgetEntity(
      id:          id          ?? this.id,
      category:    category    ?? this.category,
      label:       label       ?? this.label,
      emoji:       emoji       ?? this.emoji,
      limitAmount: limitAmount ?? this.limitAmount,
      currency:    currency    ?? this.currency,
      month:       month       ?? this.month,
      year:        year        ?? this.year,
    );
  }

  @override
  List<Object?> get props =>
      [id, category, label, emoji, limitAmount, currency, month, year];
}