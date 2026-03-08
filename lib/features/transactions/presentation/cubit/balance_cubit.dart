// lib/features/transaction/presentation/cubit/balance_cubit.dart
//
// ─────────────────────────────────────────────────────────────────────
// WHY THIS IS A SEPARATE CUBIT (not inside TransactionCubit)?
//
// Balance updates in REAL-TIME via a Firestore .snapshots() stream.
// TransactionCubit does one-time loads and mutations.
// Mixing them would make both cubits complex and hard to test.
//
// HOW REAL-TIME WORKS:
//   1. HomeScreen calls context.read<BalanceCubit>().watchBalance(uid)
//   2. BalanceCubit opens a Firestore stream (snapshots())
//   3. Every time ANY transaction changes, Firestore pushes new data
//   4. BalanceCubit recomputes income/expense/balance and emits
//   5. BlocBuilder<BalanceCubit> rebuilds ONLY the balance card
//
// MULTI-DEVICE MAGIC:
//   Phone A adds "Salary +$5000" → Phone B's balance card updates
//   within ~1 second. No polling, no refresh button needed.
//
// MEMORY LEAK PREVENTION:
//   _sub?.cancel() in close() stops the stream when cubit is disposed.
//   Without this, the stream keeps listening even after HomeScreen
//   is gone — causes memory leaks and phantom state updates.
// ─────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/remote/transaction_remote_ds.dart';
import 'balance_state.dart';

class BalanceCubit extends Cubit<BalanceState> {

  BalanceCubit({required TransactionRemoteDS remote})
      : _remote = remote,
        super(BalanceInitial());

  final TransactionRemoteDS _remote;

  // The active stream subscription.
  // Kept as a field so we can cancel() it in close().
  StreamSubscription? _sub;

  /// Start listening to real-time transaction changes.
  /// Called once when HomeScreen mounts.
  void watchBalance(String userId) {
    emit(BalanceLoading());

    // Cancel any existing subscription before starting a new one.
    // Prevents duplicate listeners if watchBalance is called twice.
    _sub?.cancel();

    _sub = _remote.watchAll(userId).listen(
          (transactions) {
        double income  = 0;
        double expense = 0;

        for (final tx in transactions) {
          if (tx.type == 'income')  income  += tx.amount;
          if (tx.type == 'expense') expense += tx.amount;
          // 'transfer' doesn't affect income/expense totals
        }

        emit(BalanceLoaded(
          income:  income,
          expense: expense,
          balance: income - expense, // COMPUTED, never stored
        ));
      },
      onError: (e) {
        emit(const BalanceError('Could not load balance. Please check your connection.'));
      },
    );
  }

  /// CRITICAL: Cancel the stream subscription when this cubit is closed.
  /// Without this, the Firestore listener keeps running even after the
  /// widget tree disposes this cubit — causing memory leaks.
  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}