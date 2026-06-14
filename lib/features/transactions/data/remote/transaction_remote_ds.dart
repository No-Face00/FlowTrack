
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/transaction_entity.dart';
import '../models/transaction_model.dart';

class TransactionRemoteDS {

  final _db = FirebaseFirestore.instance;

  /// Returns the subcollection reference for a specific user.
  CollectionReference<Map<String, dynamic>> _col(String userId) =>
      _db.collection('transactions/$userId/userTransactions');

  // ── SET (create or update) ────────────────────────────────────
  /// Saves transaction to Firestore using UUID as document ID.
  /// set() = upsert: creates if not exists, updates if exists.
  /// Called during online add AND during syncPending() for offline txns.
  Future<void> setTransaction(TransactionEntity tx, String userId) async {
    final model = TransactionModel.fromEntity(tx);
    await _col(userId).doc(tx.id).set(
      model.toFirestoreMap(),
      SetOptions(merge: true), // merge:true = safe concurrent writes
    );
  }

  // ── UPDATE (partial) ──────────────────────────────────────────
  /// Updates specific fields only.
  /// Used for: soft delete, undo delete, mark synced.
  ///
  /// WHY not set() for updates?
  /// set() without merge:true would OVERWRITE the entire document.
  /// update() only changes the specified fields.
  Future<void> update(String id, String userId, Map<String, dynamic> fields) async {
    await _col(userId).doc(id).update(fields);
  }

  // ── GET BY MONTH ──────────────────────────────────────────────
  /// Fetches transactions for a specific month.
  /// WHY .where('month')? The 'month' string field ('2026-03') lets
  /// us do a simple equality query — no date range, no compound index.
  Future<List<TransactionEntity>> getByMonth(String userId, String month) async {
    final snap = await _col(userId)
        .where('month',     isEqualTo: month)
        .where('isDeleted', isEqualTo: false)
        .orderBy('date',    descending: true)
        .get();

    return snap.docs
        .map((doc) => TransactionModel.fromFirestore(doc).toEntity())
        .toList();
  }

  // ── PAGINATED QUERY ───────────────────────────────────────────
  /// Loads 20 transactions at a time.
  /// Pass lastDoc to continue from where you left off (pagination).
  ///
  /// WHY limit(20)?
  /// A user with 5 years of transactions has 1,800+ documents.
  /// Loading all = slow + expensive (Firestore charges per read).
  /// Pagination loads 20 at a time — instant, cheap.
  Future<({List<TransactionEntity> data, DocumentSnapshot? lastDoc, bool hasMore})>
  getPaginated(
      String userId, {
        DocumentSnapshot? lastDoc,
        int limit = 20,
        String? month,
      }) async {
    Query query = _col(userId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('date',    descending: true)
        .limit(limit + 1); // fetch 1 extra to check if there's more

    if (month != null) {
      query = query.where('month', isEqualTo: month);
    }

    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }

    final snap = await query.get();
    final hasMore = snap.docs.length > limit;
    final docs    = hasMore ? snap.docs.sublist(0, limit) : snap.docs;

    return (
    data:    docs.map((d) => TransactionModel.fromFirestore(d).toEntity()).toList(),
    lastDoc: docs.isNotEmpty ? docs.last : null,
    hasMore: hasMore,
    );
  }

  // ── REAL-TIME STREAM (for BalanceCubit) ───────────────────────
  /// Returns a stream of ALL non-deleted transactions for a user.
  /// BalanceCubit listens to this and recomputes balance on every change.
  ///
  /// WHY snapshots() stream and NOT a one-time get()?
  /// When any device adds/edits/deletes a transaction, Firestore pushes
  /// the update to ALL listening devices in ~1 second. This is how your
  /// balance card updates in real-time without refreshing.
  Stream<List<TransactionEntity>> watchAll(String userId) {
    return _col(userId)
        .where('isDeleted', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs
        .map((d) => TransactionModel.fromFirestore(d).toEntity())
        .toList());
  }

  // ── SOFT DELETE ───────────────────────────────────────────────
  Future<void> softDelete(String id, String userId) async {
    await update(id, userId, {
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── UNDO DELETE ───────────────────────────────────────────────
  Future<void> undoDelete(String id, String userId) async {
    await update(id, userId, {
      'isDeleted': false,
      'deletedAt': null,
    });
  }
}