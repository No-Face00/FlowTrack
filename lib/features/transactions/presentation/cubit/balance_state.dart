// lib/features/transactions/presentation/cubit/balance_state.dart

import 'package:equatable/equatable.dart';

import '../../../../core/cubit/app_cubit.dart';

abstract class BalanceState extends Equatable {
  const BalanceState();
  @override
  List<Object?> get props => [];
}

class BalanceInitial extends BalanceState {}
class BalanceLoading extends BalanceState {}

class BalanceLoaded extends BalanceState {
  final double income;
  final double expense;
  final double balance; // = income - expense
  final String currency; // e.g. 'BDT', 'USD' — read from Firestore user doc

  const BalanceLoaded({
    required this.income,
    required this.expense,
    required this.balance,
    this.currency = 'USD',
  });

  /// Maps currency code → display symbol.
  /// Delegates to CurrencyHelper which is the single source of truth
  /// so this never gets out of sync with AppCubit.
  String get symbol => CurrencyHelper.symbol(currency);

  BalanceLoaded copyWith({String? currency}) => BalanceLoaded(
    income:   income,
    expense:  expense,
    balance:  balance,
    currency: currency ?? this.currency,
  );

  @override
  List<Object?> get props => [income, expense, balance, currency];
}

class BalanceError extends BalanceState {
  final String message;
  const BalanceError(this.message);
  @override
  List<Object?> get props => [message];
}