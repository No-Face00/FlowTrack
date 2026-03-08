// lib/features/transaction/presentation/cubit/balance_state.dart

import 'package:equatable/equatable.dart';

abstract class BalanceState extends Equatable {
  const BalanceState();
  @override
  List<Object?> get props => [];
}

class BalanceInitial extends BalanceState {}
class BalanceLoading extends BalanceState {}

/// Real-time computed balance.
/// income, expense, balance are always computed from transactions —
/// NEVER stored as a field in Firestore (would go out of sync).
class BalanceLoaded extends BalanceState {
  final double income;
  final double expense;
  final double balance; // = income - expense

  const BalanceLoaded({
    required this.income,
    required this.expense,
    required this.balance,
  });

  @override
  List<Object?> get props => [income, expense, balance];
}

class BalanceError extends BalanceState {
  final String message;
  const BalanceError(this.message);
  @override
  List<Object?> get props => [message];
}