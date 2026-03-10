// lib/features/transactions/presentation/cubit/transaction_cubit.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/transaction_entity.dart';
import '../../data/local/transaction_local_ds.dart';
import '../../data/remote/transaction_remote_ds.dart';
import '../../../../core/services/connectivity_service.dart';
import 'transaction_state.dart';

class TransactionCubit extends Cubit<TransactionState> {

  TransactionCubit({
    required TransactionLocalDS  local,
    required TransactionRemoteDS remote,
    required ConnectivityService network,
  })  : _local   = local,
        _remote  = remote,
        _network = network,
        super(TransactionInitial());

  final TransactionLocalDS  _local;
  final TransactionRemoteDS _remote;
  final ConnectivityService _network;

  bool _isSubmitting = false;

  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<void> loadTransactions() async {
    emit(TransactionLoading());

    // ── FIX: _local.getAll() returns List<TransactionModel>.
    // TransactionLoaded expects List<TransactionEntity>.
    // Call .toEntity() on each item to convert.
    final localList = _local.getAll()
        .map((model) => model.toEntity())
        .toList();

    emit(TransactionLoaded(transactions: localList, hasMore: false));

    if (await _network.isConnected) {
      try {
        final result = await _remote.getPaginated(_userId, limit: 20);
        for (final tx in result.data) {
          await _local.save(tx.copyWith(isSynced: true));
        }
        emit(TransactionLoaded(
          transactions: result.data,
          lastDoc:      result.lastDoc,
          hasMore:      result.hasMore,
        ));
      } catch (e) {
        // keep Hive data visible on network error
      }
    }
  }

  Future<void> addTransaction({
    required double   amount,
    required String   type,
    required String   category,
    required String   title,
    String?           note,
    required String   currency,
    required DateTime date,
  }) async {
    if (_isSubmitting) return;
    _isSubmitting = true;
    emit(TransactionSubmitting());

    try {
      final tx = TransactionEntity(
        id:        const Uuid().v4(),
        amount:    amount,
        type:      type,
        category:  category,
        title:     title,
        note:      note,
        currency:  currency,
        month:     _toMonthString(date),
        date:      date,
        createdAt: DateTime.now(),
        isSynced:  false,
        isDeleted: false,
      );

      await _local.save(tx);

      if (await _network.isConnected) {
        await _remote.setTransaction(tx, _userId);
        await _local.markSynced(tx.id);
      }

      await loadTransactions();

    } catch (e) {
      emit(const TransactionError('Failed to save transaction. Please try again.'));
    } finally {
      _isSubmitting = false;
    }
  }

  Future<void> softDelete(String id) async {
    try {
      await _local.softDelete(id);
      if (await _network.isConnected) {
        await _remote.softDelete(id, _userId);
      }
      emit(TransactionDeleted(id));
      await loadTransactions();
    } catch (e) {
      emit(const TransactionError('Could not delete transaction.'));
    }
  }

  Future<void> undoDelete(String id) async {
    try {
      await _local.undoDelete(id);
      if (await _network.isConnected) {
        await _remote.undoDelete(id, _userId);
      }
      await loadTransactions();
    } catch (e) {
      emit(const TransactionError('Could not restore transaction.'));
    }
  }

  Future<void> loadMore() async {
    if (state is! TransactionLoaded) return;
    final current = state as TransactionLoaded;
    if (!current.hasMore) return;

    try {
      final result = await _remote.getPaginated(
        _userId,
        lastDoc: current.lastDoc,
        limit:   20,
      );
      emit(TransactionLoaded(
        transactions: [...current.transactions, ...result.data],
        lastDoc:      result.lastDoc,
        hasMore:      result.hasMore,
      ));
    } catch (e) {
      // keep current list
    }
  }

  Future<void> syncPending() async {
    final pending = _local.getUnsynced(); // already returns List<TransactionEntity>

    for (final tx in pending) {
      try {
        await _remote.setTransaction(tx, _userId);
        await _local.markSynced(tx.id);
      } catch (_) {}
    }
    if (pending.isNotEmpty) await loadTransactions();
  }

  String _toMonthString(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';
}