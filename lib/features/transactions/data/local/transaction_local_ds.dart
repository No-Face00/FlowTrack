

import 'package:hive/hive.dart';

import '../../domain/entities/transaction_entity.dart';
import '../models/transaction_model.dart';
import '../../../../core/services/hive_service.dart';

class TransactionLocalDS {

  // Get the already-open box (HiveService.init() opened it in main.dart)
  Box<TransactionModel> get _box => HiveService.transactionBox;

  // ── SAVE ──────────────────────────────────────────────────────
  /// Saves or updates a transaction in Hive using its UUID as key.
  ///
  /// WHY use tx.id as the key?
  /// Hive boxes are key-value stores. Using the UUID means:
  ///   box.put(tx.id, model) — if key exists, it UPDATES (no duplicate)
  /// This matches Firestore's set() behavior — idempotent on both ends.
  Future<void> save(TransactionEntity tx) async {
    await _box.put(tx.id, TransactionModel.fromEntity(tx));
  }

  // ── GET ALL ───────────────────────────────────────────────────
  /// Returns all non-deleted transactions, newest first.
  /// Called by home screen for instant load — zero network latency.
  List<TransactionModel> getAll() {
    return _box.values
        .where((m) => !m.isDeleted)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date)); // newest first
  }

  // ── GET BY MONTH ──────────────────────────────────────────────
  /// Returns transactions for a specific month string ('2026-03').
  /// Used by analytics screen without hitting Firestore.
  List<TransactionEntity> getByMonth(String month) {
    return _box.values
        .where((m) => m.month == month && !m.isDeleted)
        .map((m) => m.toEntity())
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  // ── GET UNSYNCED ──────────────────────────────────────────────
  /// Returns all transactions where isSynced=false.
  /// Called by TransactionCubit.syncPending() when internet returns.
  List<TransactionEntity> getUnsynced() {
    return _box.values
        .where((m) => !m.isSynced)
        .map((m) => m.toEntity())
        .toList();
  }

  // ── MARK SYNCED ───────────────────────────────────────────────
  /// Updates isSynced=true after Firestore confirms the transaction.
  /// Uses box.put() to update in-place — same key, updated model.
  Future<void> markSynced(String id) async {
    final existing = _box.get(id);
    if (existing == null) return;
    // Rebuild model with isSynced=true, all other fields unchanged
    await _box.put(id, TransactionModel(
      id:        existing.id,
      amount:    existing.amount,
      type:      existing.type,
      category:  existing.category,
      title:     existing.title,
      note:      existing.note,
      currency:  existing.currency,
      month:     existing.month,
      date:      existing.date,
      createdAt: existing.createdAt,
      isSynced:  true,           // ← updated
      isDeleted: existing.isDeleted,
    ));
  }

  // ── SOFT DELETE ───────────────────────────────────────────────
  /// Sets isDeleted=true. NEVER removes from Hive.
  /// WHY? Same reason as Firestore — undo support + data integrity.
  Future<void> softDelete(String id) async {
    final existing = _box.get(id);
    if (existing == null) return;
    await _box.put(id, TransactionModel(
      id:        existing.id,
      amount:    existing.amount,
      type:      existing.type,
      category:  existing.category,
      title:     existing.title,
      note:      existing.note,
      currency:  existing.currency,
      month:     existing.month,
      date:      existing.date,
      createdAt: existing.createdAt,
      isSynced:  existing.isSynced,
      isDeleted: true,           // ← soft delete
    ));
  }

  // ── UNDO DELETE ───────────────────────────────────────────────
  Future<void> undoDelete(String id) async {
    final existing = _box.get(id);
    if (existing == null) return;
    await _box.put(id, TransactionModel(
      id:        existing.id,
      amount:    existing.amount,
      type:      existing.type,
      category:  existing.category,
      title:     existing.title,
      note:      existing.note,
      currency:  existing.currency,
      month:     existing.month,
      date:      existing.date,
      createdAt: existing.createdAt,
      isSynced:  existing.isSynced,
      isDeleted: false,          // ← restored
    ));
  }

  // ── GET SINGLE ────────────────────────────────────────────────
  TransactionEntity? getById(String id) {
    return _box.get(id)?.toEntity();
  }
}