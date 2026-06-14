
import 'package:hive_flutter/hive_flutter.dart';

import '../../domain/entities/budget_entity.dart';

class BudgetLocalDS {
  static const String _boxName = 'budgets';

  // HiveService.init() must have opened this box. Add to hive_service.dart:
  //   await Hive.openBox<Map>(_budgetBoxName);
  Box<Map> get _box => Hive.box<Map>(_boxName);

  // ── SAVE ──────────────────────────────────────────────────
  Future<void> save(BudgetEntity budget) async {
    await _box.put(budget.id, _toMap(budget));
  }

  // ── GET by month ──────────────────────────────────────────
  List<BudgetEntity> getForMonth(int month, int year) {
    return _box.values
        .where((m) => m['month'] == month && m['year'] == year)
        .map((m) => _fromMap(Map<String, dynamic>.from(m)))
        .toList();
  }

  // ── DELETE ────────────────────────────────────────────────
  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  // ── CLEAR ALL ─────────────────────────────────────────────
  Future<void> clearAll() async {
    await _box.clear();
  }

  // ── Serialization ─────────────────────────────────────────
  Map<String, dynamic> _toMap(BudgetEntity b) => {
    'id':          b.id,
    'category':    b.category,
    'label':       b.label,
    'emoji':       b.emoji,
    'limitAmount': b.limitAmount,
    'currency':    b.currency,
    'month':       b.month,
    'year':        b.year,
  };

  BudgetEntity _fromMap(Map<String, dynamic> m) => BudgetEntity(
    id:          m['id']          as String,
    category:    m['category']    as String,
    label:       m['label']       as String,
    emoji:       m['emoji']       as String,
    limitAmount: (m['limitAmount'] as num).toDouble(),
    currency:    m['currency']    as String,
    month:       m['month']       as int,
    year:        m['year']        as int,
  );
}