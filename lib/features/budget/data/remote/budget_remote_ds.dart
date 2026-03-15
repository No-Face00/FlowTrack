// lib/features/budget/data/remote/budget_remote_ds.dart

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/budget_entity.dart';

class BudgetRemoteDS {
  final _db = FirebaseFirestore.instance;

  /// Firestore path: budgets/{userId}/userBudgets/{budgetId}
  CollectionReference<Map<String, dynamic>> _col(String userId) =>
      _db.collection('budgets/$userId/userBudgets');

  // ── SET (create or update) ────────────────────────────────
  Future<void> setBudget(BudgetEntity budget, String userId) async {
    await _col(userId).doc(budget.id).set({
      'id':          budget.id,
      'category':    budget.category,
      'label':       budget.label,
      'emoji':       budget.emoji,
      'limitAmount': budget.limitAmount,
      'currency':    budget.currency,
      'month':       budget.month,
      'year':        budget.year,
      'updatedAt':   FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── GET by month ──────────────────────────────────────────
  Future<List<BudgetEntity>> getForMonth(
      String userId, int month, int year) async {
    final snap = await _col(userId)
        .where('month', isEqualTo: month)
        .where('year',  isEqualTo: year)
        .get();

    return snap.docs.map((doc) {
      final d = doc.data();
      return BudgetEntity(
        id:          d['id']          as String,
        category:    d['category']    as String,
        label:       d['label']       as String,
        emoji:       d['emoji']       as String,
        limitAmount: (d['limitAmount'] as num).toDouble(),
        currency:    d['currency']    as String,
        month:       d['month']       as int,
        year:        d['year']        as int,
      );
    }).toList();
  }

  // ── DELETE ────────────────────────────────────────────────
  Future<void> deleteBudget(String id, String userId) async {
    await _col(userId).doc(id).delete();
  }
}