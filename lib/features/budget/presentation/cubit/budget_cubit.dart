// lib/features/budget/presentation/cubit/budget_cubit.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../data/local/budget_local_ds.dart';
import '../../data/remote/budget_remote_ds.dart';
import '../../domain/entities/budget_entity.dart';
import '../../../../core/services/connectivity_service.dart';
import 'budget_state.dart';

class BudgetCubit extends Cubit<BudgetState> {
  BudgetCubit({
    required BudgetLocalDS    local,
    required BudgetRemoteDS   remote,
    required ConnectivityService network,
  })  : _local   = local,
        _remote  = remote,
        _network = network,
        super(BudgetInitial());

  final BudgetLocalDS       _local;
  final BudgetRemoteDS      _remote;
  final ConnectivityService _network;

  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Load budgets for a specific month ─────────────────────
  Future<void> loadForMonth(int month, int year) async {
    emit(BudgetLoading());
    try {
      // Load from Hive first (instant)
      final local = _local.getForMonth(month, year);
      emit(BudgetLoaded(local));

      // Then sync from Firestore if online
      if (await _network.isConnected) {
        final remote = await _remote.getForMonth(_userId, month, year);
        for (final b in remote) {
          await _local.save(b);
        }
        final merged = _local.getForMonth(month, year);
        emit(BudgetLoaded(merged));
      }
    } catch (e) {
      emit(const BudgetError('Failed to load budgets.'));
    }
  }

  // ── Save (create or update) ────────────────────────────────
  Future<void> saveBudget({
    String?  existingId,
    required String category,
    required String label,
    required String emoji,
    required double limitAmount,
    required String currency,
    required int    month,
    required int    year,
  }) async {
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

      await _local.save(budget);

      if (await _network.isConnected) {
        await _remote.setBudget(budget, _userId);
      }

      final updated = _local.getForMonth(month, year);
      emit(BudgetLoaded(updated));
    } catch (e) {
      emit(const BudgetError('Failed to save budget.'));
    }
  }

  // ── Delete ─────────────────────────────────────────────────
  Future<void> deleteBudget(BudgetEntity budget) async {
    try {
      await _local.delete(budget.id);

      if (await _network.isConnected) {
        await _remote.deleteBudget(budget.id, _userId);
      }

      final updated = _local.getForMonth(budget.month, budget.year);
      emit(BudgetLoaded(updated));
    } catch (e) {
      emit(const BudgetError('Failed to delete budget.'));
    }
  }
}