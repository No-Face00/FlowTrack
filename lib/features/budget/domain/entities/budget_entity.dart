// lib/features/budget/domain/entities/budget_entity.dart

import 'package:equatable/equatable.dart';

class BudgetEntity extends Equatable {
  final String id;
  final String category;
  final String label;
  final String emoji;
  final double limitAmount; // -1 = tombstone (hidden default)
  final String currency;
  final int    month;
  final int    year;

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