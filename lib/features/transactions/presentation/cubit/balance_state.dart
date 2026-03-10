// lib/features/transactions/presentation/cubit/balance_state.dart

import 'package:equatable/equatable.dart';

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

  /// Maps currency code → display symbol
  String get symbol {
    const map = {
      'BDT': '৳',
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'INR': '₹',
      'JPY': '¥',
      'CAD': 'CA\$',
      'AUD': 'A\$',
    };
    return map[currency] ?? currency;
  }

  @override
  List<Object?> get props => [income, expense, balance, currency];
}

class BalanceError extends BalanceState {
  final String message;
  const BalanceError(this.message);
  @override
  List<Object?> get props => [message];
}