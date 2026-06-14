
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

import '../../domain/entities/budget_entity.dart';

part 'budget_model.g.dart';

@HiveType(typeId: 1)
class BudgetModel extends HiveObject {

  @HiveField(0) final String id;
  @HiveField(1) final String category;
  @HiveField(2) final String label;
  @HiveField(3) final String emoji;
  @HiveField(4) final double limitAmount;
  @HiveField(5) final String currency;
  @HiveField(6) final int    month;
  @HiveField(7) final int    year;

  BudgetModel({
    required this.id,
    required this.category,
    required this.label,
    required this.emoji,
    required this.limitAmount,
    required this.currency,
    required this.month,
    required this.year,
  });

  // ── Entity → Model ─────────────────────────────────────────
  factory BudgetModel.fromEntity(BudgetEntity e) => BudgetModel(
    id:          e.id,
    category:    e.category,
    label:       e.label,
    emoji:       e.emoji,
    limitAmount: e.limitAmount,
    currency:    e.currency,
    month:       e.month,
    year:        e.year,
  );

  // ── Model → Entity ─────────────────────────────────────────
  BudgetEntity toEntity() => BudgetEntity(
    id:          id,
    category:    category,
    label:       label,
    emoji:       emoji,
    limitAmount: limitAmount,
    currency:    currency,
    month:       month,
    year:        year,
  );

  // ── Model → Firestore map ──────────────────────────────────
  Map<String, dynamic> toFirestoreMap() => {
    'id':          id,
    'category':    category,
    'label':       label,
    'emoji':       emoji,
    'limitAmount': limitAmount,
    'currency':    currency,
    'month':       month,
    'year':        year,
    'updatedAt':   FieldValue.serverTimestamp(),
  };

  // ── Firestore doc → Model ──────────────────────────────────
  factory BudgetModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return BudgetModel(
      id:          d['id']          as String,
      category:    d['category']    as String,
      label:       d['label']       as String,
      emoji:       d['emoji']       as String? ?? '💰',
      limitAmount: (d['limitAmount'] as num).toDouble(),
      currency:    d['currency']    as String? ?? 'USD',
      month:       d['month']       as int,
      year:        d['year']        as int,
    );
  }
}