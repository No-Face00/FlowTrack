// lib/features/budget/data/remote/budget_remote_ds.dart
//
// ARCHITECTURE: Data Layer — Remote Data Source (Firestore).
//
// Firestore schema:
//   budgets/{userId}/userBudgets/{budgetId}
//   └── id, category, label, emoji, limitAmount,
//       currency, month, year, updatedAt
//
// WHY same subcollection-per-user pattern as transactions?
//   One Firestore security rule covers both:
//     match /budgets/{userId}/userBudgets/{doc} {
//       allow read, write: if request.auth.uid == userId;
//     }
//   Zero cross-user data leakage is guaranteed at the DB level.
//
// WHY set() with merge:true instead of add()?
//   We generate UUID locally before saving. set() with a known
//   doc ID is idempotent — safe to retry on network error.
//   add() would create duplicates on retry.
//
// WHY keep watchForMonth() even though BudgetCubit uses get()?
//   Future phases can subscribe to the stream for real-time
//   budget updates across devices without changing the cubit API.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/budget_entity.dart';
import '../models/budget_model.dart';

class BudgetRemoteDS {

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String userId) =>
      _db.collection('budgets/$userId/userBudgets');

  // ── Upsert ─────────────────────────────────────────────────
  Future<void> setBudget(BudgetEntity budget, String userId) async {
    await _col(userId).doc(budget.id).set(
      BudgetModel.fromEntity(budget).toFirestoreMap(),
      SetOptions(merge: true),
    );
  }

  // ── Fetch for a month (one-time) ───────────────────────────
  Future<List<BudgetEntity>> getForMonth(
      String userId, int month, int year,
      ) async {
    final snap = await _col(userId)
        .where('month', isEqualTo: month)
        .where('year',  isEqualTo: year)
        .get();
    return snap.docs
        .map((d) => BudgetModel.fromFirestore(d).toEntity())
        .toList();
  }

  // ── Hard delete ────────────────────────────────────────────
  Future<void> delete(String id, String userId) async {
    await _col(userId).doc(id).delete();
  }

  // ── Real-time stream (reserved for future use) ─────────────
  Stream<List<BudgetEntity>> watchForMonth(
      String userId, int month, int year,
      ) {
    return _col(userId)
        .where('month', isEqualTo: month)
        .where('year',  isEqualTo: year)
        .snapshots()
        .map((snap) => snap.docs
        .map((d) => BudgetModel.fromFirestore(d).toEntity())
        .toList());
  }
}