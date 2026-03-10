// lib/features/transactions/presentation/cubit/balance_cubit.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/remote/transaction_remote_ds.dart';
import 'balance_state.dart';

class BalanceCubit extends Cubit<BalanceState> {

  BalanceCubit({required TransactionRemoteDS remote})
      : _remote = remote,
        super(BalanceInitial());

  final TransactionRemoteDS _remote;
  final _db = FirebaseFirestore.instance;
  StreamSubscription? _sub;

  void watchBalance(String userId) {
    emit(BalanceLoading());
    _sub?.cancel();

    _sub = _remote.watchAll(userId).listen(
          (transactions) async {
        double income  = 0;
        double expense = 0;

        for (final tx in transactions) {
          if (tx.type == 'income')  income  += tx.amount;
          if (tx.type == 'expense') expense += tx.amount;
        }

        // Read currency from user's Firestore doc
        String currency = 'USD';
        try {
          final doc = await _db.collection('users').doc(userId).get();
          currency = doc.data()?['currency'] as String? ?? 'USD';
        } catch (_) {}

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

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}