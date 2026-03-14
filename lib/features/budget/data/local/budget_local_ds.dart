// lib/features/budget/data/local/budget_local_ds.dart
//
// ARCHITECTURE: Data Layer — Local Data Source.
//
// This is the ONLY class in the app that reads/writes Hive for
// budgets. Nobody else touches HiveService.budgetBox directly.
// This boundary means if we ever swap Hive for SQLite, only this
// file changes — nothing in the cubit or UI knows or cares.
//
// WHY use budget.id as the Hive key?
//   box.put(key, value) is idempotent — calling it twice with the
//   same key updates in-place, never duplicates. This is the same
//   pattern used by TransactionLocalDS.
//
// WHY no async on getForMonth / getAll?
//   Hive boxes are fully in-memory after openBox(). Reads are
//   synchronous — no I/O, no await needed. Only writes are async
//   because they flush to disk.

import 'package:hive/hive.dart';

import '../../../../core/services/hive_service.dart';
import '../../domain/entities/budget_entity.dart';
import '../models/budget_model.dart';

class BudgetLocalDS {

  Box<BudgetModel> get _box => HiveService.budgetBox;

  // ── Save / Update (idempotent) ─────────────────────────────
  Future<void> save(BudgetEntity budget) async {
    await _box.put(budget.id, BudgetModel.fromEntity(budget));
  }

  // ── Get all budgets for a specific month ───────────────────
  List<BudgetEntity> getForMonth(int month, int year) {
    return _box.values
        .where((m) => m.month == month && m.year == year)
        .map((m) => m.toEntity())
        .toList();
  }

  // ── Get all budgets across all months ─────────────────────
  List<BudgetEntity> getAll() {
    return _box.values.map((m) => m.toEntity()).toList();
  }

  // ── Hard delete by ID ──────────────────────────────────────
  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  // ── Get single budget by ID ────────────────────────────────
  BudgetEntity? getById(String id) {
    return _box.get(id)?.toEntity();
  }
}