// lib/features/transactions/presentation/cubit/balance_cubit.dart
//
// Computes income / expense / balance totals from the transaction stream.
// Currency is read from AppCubit (single source of truth) — no separate
// Firestore round-trip per transaction update.

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/remote/transaction_remote_ds.dart';
import '../../../../core/cubit/app_cubit.dart';
import '../../../../core/di/service_locator.dart';
import 'balance_state.dart';

class BalanceCubit extends Cubit<BalanceState> {

  BalanceCubit({required TransactionRemoteDS remote})
      : _remote = remote,
        super(BalanceInitial());

  final TransactionRemoteDS _remote;
  StreamSubscription? _sub;

  void watchBalance(String userId) {
    emit(BalanceLoading());
    _sub?.cancel();

    _sub = _remote.watchAll(userId).listen(
          (transactions) {
        double income  = 0;
        double expense = 0;
        for (final tx in transactions) {
          if (tx.type == 'income')  income  += tx.amount;
          if (tx.type == 'expense') expense += tx.amount;
        }

        // Currency comes from AppCubit — the single source of truth.
        // No extra Firestore fetch needed; AppCubit already loaded it.
        final currency = getIt<AppCubit>().state.currency;

        emit(BalanceLoaded(
          income:   income,
          expense:  expense,
          balance:  income - expense,
          currency: currency,
        ));
      },
      onError: (_) {
        emit(const BalanceError('Could not load balance. Please check your connection.'));
      },
    );
  }

  /// Call after currency change so the header updates instantly
  /// without waiting for the next Firestore snapshot.
  void refreshCurrency() {
    final current = state;
    if (current is! BalanceLoaded) return;
    if (isClosed) return;
    emit(current.copyWith(currency: getIt<AppCubit>().state.currency));
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}