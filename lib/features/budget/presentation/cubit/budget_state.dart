// lib/features/budget/presentation/cubit/budget_state.dart
//
// ARCHITECTURE: Presentation Layer — State definitions.
//
// State machine:
//
//   BudgetInitial
//       │
//       ▼  loadForMonth() called
//   BudgetLoading
//       │
//       ├──► BudgetLoaded(budgets)   ← success
//       └──► BudgetError(message)    ← network + hive both failed
//
//   BudgetLoaded
//       │
//       ▼  saveBudget() / deleteBudget() called
//   BudgetSaving
//       │
//       └──► BudgetLoaded(budgets)   ← always reloads after save
//
// WHY a separate BudgetSaving state?
//   The UI can show a loading indicator on the Save button
//   without disabling the entire screen. Without this state,
//   you'd have to track loading locally with a StatefulWidget.
//
// WHY limitFor() as a convenience method on BudgetLoaded?
//   Keeps the "find budget limit for category X" logic in one
//   place. Any widget that needs this just calls:
//     context.read<BudgetCubit>().state is BudgetLoaded
//       ? state.limitFor('food')
//       : 0.0

import 'package:equatable/equatable.dart';

import '../../domain/entities/budget_entity.dart';

abstract class BudgetState extends Equatable {
  const BudgetState();
  @override
  List<Object?> get props => [];
}

class BudgetInitial extends BudgetState {}
class BudgetLoading extends BudgetState {}
class BudgetSaving  extends BudgetState {}

class BudgetLoaded extends BudgetState {
  final List<BudgetEntity> budgets;

  const BudgetLoaded({required this.budgets});

  /// Look up monthly limit for a category. Returns 0 if not set.
  double limitFor(String category) {
    final match = budgets.where((b) => b.category == category).firstOrNull;
    return match?.limitAmount ?? 0.0;
  }

  @override
  List<Object?> get props => [budgets];
}

class BudgetError extends BudgetState {
  final String message;
  const BudgetError(this.message);
  @override
  List<Object?> get props => [message];
}