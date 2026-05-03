// lib/features/transactions/presentation/cubit/transaction_cubit.dart

import 'dart:async';

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
  StreamSubscription<List<TransactionEntity>>? _streamSub;

  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── REAL-TIME STREAM (replaces one-shot loadTransactions) ─────────────
  /// Subscribes to Firestore snapshots so the Home screen updates instantly
  /// whenever any transaction is added, edited, or deleted — no navigation needed.
  void watchTransactions() {
    if (_streamSub != null) return; // already watching, don't double-subscribe

    // Seed from local cache immediately so the UI isn't blank while connecting
    final localList = _local.getAll()
        .map((model) => model.toEntity())
        .toList();
    if (localList.isNotEmpty) {
      emit(TransactionLoaded(transactions: localList, hasMore: false));
    } else {
      emit(TransactionLoading());
    }

    // Subscribe to Firestore real-time stream
    _streamSub = _remote.watchAll(_userId).listen(
          (transactions) async {
        // Persist to local cache for offline access
        for (final tx in transactions) {
          await _local.save(tx.copyWith(isSynced: true));
        }
        // Sort by date descending (Firestore stream doesn't guarantee order)
        final sorted = List<TransactionEntity>.from(transactions)
          ..sort((a, b) => b.date.compareTo(a.date));
        emit(TransactionLoaded(
          transactions: sorted,
          hasMore: false,
        ));
      },
      onError: (_) {
        // On error fall back to local cache silently
        final fallback = _local.getAll()
            .map((m) => m.toEntity())
            .toList();
        emit(TransactionLoaded(transactions: fallback, hasMore: false));
      },
    );
  }

  /// One-shot fetch (kept for backward compat with any screen that still calls it).
  Future<void> loadTransactions() async {
    // If the stream is already active, the UI is already up-to-date — no-op.
    if (_streamSub != null) return;
    watchTransactions();
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

      // ── Emit TransactionSaved as a one-time pop signal.
      // The Firestore stream will automatically push the new transaction
      // to the Home screen within ~1 second. We do NOT emit
      // TransactionLoaded here because the BlocConsumer on the Add screen
      // would immediately pop due to the already-active stream state.
      emit(TransactionSaved());

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
      // 1. Emit TransactionDeleted first so BlocListener catches it for the snackbar.
      // 2. Then emit a refreshed TransactionLoaded so BlocBuilder re-renders the list
      //    without the deleted item. BlocBuilders are set to ignore TransactionDeleted,
      //    so step 1 never causes a blank-list flash.
      emit(TransactionDeleted(id));
      await _refreshFromLocal();
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
      // Always refresh from local immediately so the restored item appears right away.
      await _refreshFromLocal();
    } catch (e) {
      emit(const TransactionError('Could not restore transaction.'));
    }
  }

  /// Refreshes UI from local Hive cache (used as fallback when offline).
  Future<void> _refreshFromLocal() async {
    final list = _local.getAll()
        .map((m) => m.toEntity())
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    emit(TransactionLoaded(transactions: list, hasMore: false));
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
    if (pending.isNotEmpty && _streamSub == null) await _refreshFromLocal();
  }

  @override
  Future<void> close() {
    _streamSub?.cancel();
    return super.close();
  }

  String _toMonthString(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';
}