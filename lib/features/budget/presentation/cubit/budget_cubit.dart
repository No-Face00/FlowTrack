// lib/features/budget/presentation/cubit/budget_cubit.dart
//
// ARCHITECTURE: Presentation Layer — Business Logic.
//
// Offline-first flow (identical pattern to TransactionCubit):
//
//   loadForMonth():
//     1. emit(BudgetLoading)
//     2. Read Hive → emit(BudgetLoaded) immediately if data exists
//        User sees stale-but-fast data instantly, no blank screen.
//     3. Check connectivity → fetch Firestore → cache to Hive
//        → emit(BudgetLoaded) again with fresh data
//
//   saveBudget():
//     1. emit(BudgetSaving)
//     2. Write to Hive first → user sees change immediately
//     3. If online → push to Firestore (same UUID, idempotent)
//     4. Reload for current month → emit(BudgetLoaded)
//
// WHY generate UUID locally (not let Firestore auto-ID)?
//   We need the ID before the network call to:
//   a) Save to Hive immediately with a stable key
//   b) Use set(docId) instead of add() — makes upsert idempotent
//   c) Reference the budget from other features in the future
//
// WHY existingId parameter in saveBudget()?
//   Edit vs Create reuse the same method.
//   existingId != null → update existing record (same Hive key,
//     same Firestore doc — set+merge replaces the fields)
//   existingId == null → create new record (fresh UUID)

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/connectivity_service.dart';
import '../../data/local/budget_local_ds.dart';
import '../../data/remote/budget_remote_ds.dart';
import '../../domain/entities/budget_entity.dart';
import 'budget_state.dart';

class BudgetCubit extends Cubit<BudgetState> {

  BudgetCubit({
    required BudgetLocalDS       local,
    required BudgetRemoteDS      remote,
    required ConnectivityService network,
  })  : _local   = local,
        _remote  = remote,
        _network = network,
        super(BudgetInitial());

  final BudgetLocalDS       _local;
  final BudgetRemoteDS      _remote;
  final ConnectivityService _network;

  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Load budgets for a month ──────────────────────────────
  Future<void> loadForMonth(int month, int year) async {
    emit(BudgetLoading());

    // Step 1: Hive — instant, works offline
    final cached = _local.getForMonth(month, year);
    if (cached.isNotEmpty) {
      emit(BudgetLoaded(budgets: cached));
    }

    // Step 2: Firestore — fresh data if online
    if (await _network.isConnected) {
      try {
        final remote = await _remote.getForMonth(_userId, month, year);
        for (final b in remote) {
          await _local.save(b); // refresh Hive cache
        }
        emit(BudgetLoaded(budgets: remote));
      } catch (_) {
        if (cached.isEmpty) {
          emit(const BudgetError('Could not load budgets.'));
        }
        // If cached data exists, keep it visible — silent fail
      }
    } else if (cached.isEmpty) {
      emit(const BudgetLoaded(budgets: [])); // offline + no cache
    }
  }

  // ── Save / update a budget ────────────────────────────────
  Future<void> saveBudget({
    String?  existingId,   // null = create, non-null = update
    required String category,
    required String label,
    required String emoji,
    required double limitAmount,
    required String currency,
    required int    month,
    required int    year,
  }) async {
    emit(BudgetSaving());

    try {
      final budget = BudgetEntity(
        id:          existingId ?? const Uuid().v4(),
        category:    category,
        label:       label,
        emoji:       emoji,
        limitAmount: limitAmount,
        currency:    currency,
        month:       month,
        year:        year,
      );

      await _local.save(budget);                         // Hive first

      if (await _network.isConnected) {
        await _remote.setBudget(budget, _userId);        // then Firestore
      }

      await loadForMonth(month, year);                   // refresh UI
    } catch (_) {
      emit(const BudgetError('Could not save budget. Please try again.'));
    }
  }

  // ── Delete a budget ───────────────────────────────────────
  Future<void> deleteBudget(String id, int month, int year) async {
    try {
      await _local.delete(id);

      if (await _network.isConnected) {
        await _remote.delete(id, _userId);
      }

      await loadForMonth(month, year);
    } catch (_) {
      emit(const BudgetError('Could not delete budget.'));
    }
  }
}