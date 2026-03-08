// lib/features/transaction/domain/entities/transaction_entity.dart
//
// ─────────────────────────────────────────────────────────────────────
// WHY THIS FILE EXISTS:
//   This is the PURE BUSINESS OBJECT for a transaction.
//   It has zero Flutter, zero Firebase, zero Hive dependencies.
//   This is the "truth" of what a transaction IS in your app.
//
// CLEAN ARCHITECTURE RULE:
//   Domain layer knows nothing about databases, APIs, or UI.
//   If you ever switch from Firestore → Supabase, this file never changes.
//
// WHY Equatable?
//   Without it, two TransactionEntity objects with identical fields
//   are NOT equal in Dart (reference equality). With Equatable,
//   BlocBuilder can compare old vs new state by VALUE and skip
//   unnecessary rebuilds. Critical for performance.
// ─────────────────────────────────────────────────────────────────────

import 'package:equatable/equatable.dart';

class TransactionEntity extends Equatable {
  final String   id;          // UUID v4 — never Firestore auto-ID (see WHY below)
  final double   amount;      // Always positive. type determines +/-
  final String   type;        // 'income' | 'expense' | 'transfer'
  final String   category;    // 'food' | 'salary' | 'transport' | etc.
  final String   title;       // Max 50 chars
  final String?  note;        // Optional. Max 200 chars
  final String   currency;    // 'BDT' | 'USD' | 'EUR'
  final String   month;       // '2026-03' — pre-computed for fast monthly queries
  final DateTime date;        // User-selected local date
  final DateTime createdAt;
  final bool     isSynced;    // false = saved in Hive, not yet in Firestore
  final bool     isDeleted;   // SOFT DELETE — never call Firestore .delete()

  const TransactionEntity({
    required this.id,
    required this.amount,
    required this.type,
    required this.category,
    required this.title,
    this.note,
    required this.currency,
    required this.month,
    required this.date,
    required this.createdAt,
    this.isSynced  = false,
    this.isDeleted = false,
  });

  // ── WHY UUID v4 and NOT Firestore auto-ID? ────────────────────
  // 1. You save to Hive FIRST (offline-first). Hive needs an ID.
  //    Firestore auto-ID requires a network round-trip to generate.
  // 2. When you later sync to Firestore, you use set(id, data).
  //    set() with the same UUID is IDEMPOTENT — calling it twice
  //    from two devices creates ONE document, not two duplicates.
  // 3. UUID is generated locally in < 1ms. No network needed.
  // ──────────────────────────────────────────────────────────────

  // ── WHY 'month' field? ────────────────────────────────────────
  // Firestore cannot do date range queries AND filter by category
  // AND sort — it hits index limits. Storing '2026-03' as a string
  // lets you do: .where('month', isEqualTo: '2026-03') which is
  // a simple equality check — blazing fast, no compound index needed.
  // ──────────────────────────────────────────────────────────────

  // ── WHY isSynced: bool? ───────────────────────────────────────
  // When offline, transaction is saved to Hive with isSynced=false.
  // When internet returns, TransactionCubit.syncPending() finds all
  // isSynced=false records and pushes them to Firestore.
  // After sync, marks isSynced=true in Hive.
  // UI can show a "⏳ Pending sync" indicator on unsynced items.
  // ──────────────────────────────────────────────────────────────

  // ── WHY isDeleted: bool (soft delete)? ───────────────────────
  // If you call Firestore .delete(), the data is gone forever.
  // Soft delete (isDeleted=true) enables:
  //   - Undo button (5 second window to recover)
  //   - Audit trail
  //   - Balance stays correct (filter isDeleted==false)
  //   - Cloud Function can clean up after 30 days
  // ──────────────────────────────────────────────────────────────

  /// Required by TransactionCubit to update single fields
  /// without mutating (Dart objects are immutable with const).
  TransactionEntity copyWith({
    String?   id,
    double?   amount,
    String?   type,
    String?   category,
    String?   title,
    String?   note,
    String?   currency,
    String?   month,
    DateTime? date,
    DateTime? createdAt,
    bool?     isSynced,
    bool?     isDeleted,
  }) {
    return TransactionEntity(
      id:        id        ?? this.id,
      amount:    amount    ?? this.amount,
      type:      type      ?? this.type,
      category:  category  ?? this.category,
      title:     title     ?? this.title,
      note:      note      ?? this.note,
      currency:  currency  ?? this.currency,
      month:     month     ?? this.month,
      date:      date      ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      isSynced:  isSynced  ?? this.isSynced,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  /// Equatable uses this list to compare two entities by VALUE.
  /// BlocBuilder calls == on states — without this, every emit()
  /// triggers a rebuild even if data is identical.
  @override
  List<Object?> get props => [
    id, amount, type, category, title,
    note, currency, month, date, createdAt,
    isSynced, isDeleted,
  ];
}