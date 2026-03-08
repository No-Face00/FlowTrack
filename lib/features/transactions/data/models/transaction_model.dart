// lib/features/transaction/data/models/transaction_model.dart
//
// ─────────────────────────────────────────────────────────────────────
// WHY THIS FILE EXISTS:
//   The entity (transaction_entity.dart) is your BUSINESS object.
//   The model is your DATA object — it knows HOW to serialize/
//   deserialize to/from Hive (local) and Firestore (remote).
//
// TWO JOBS IN ONE FILE:
//   1. @HiveType — stores transactions in Hive (local, offline)
//   2. toFirestoreMap / fromFirestore — talks to Firestore (cloud)
//
// WHY NOT TWO SEPARATE FILES?
//   TransactionModel IS the bridge. Splitting it adds complexity
//   with zero benefit. One file, two serialization jobs.
//
// AFTER WRITING THIS FILE:
//   Run: flutter pub run build_runner build --delete-conflicting-outputs
//   This generates transaction_model.g.dart (Hive adapter).
//   NEVER edit .g.dart files manually.
// ─────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

import '../../domain/entities/transaction_entity.dart';



// ── WHY @HiveType(typeId: 0)? ─────────────────────────────────
// Hive uses numeric typeIds to identify object types in its binary
// format. typeId: 0 = TransactionModel. If you add more Hive models
// later (e.g., BudgetModel), use typeId: 1, 2, 3, etc.
// NEVER reuse or change a typeId once data is stored — it will corrupt
// existing data on users' devices.
// ──────────────────────────────────────────────────────────────

@HiveType(typeId: 0)
class TransactionModel extends HiveObject {

  @HiveField(0)  final String   id;
  @HiveField(1)  final double   amount;
  @HiveField(2)  final String   type;
  @HiveField(3)  final String   category;
  @HiveField(4)  final String   title;
  @HiveField(5)  final String?  note;
  @HiveField(6)  final String   currency;
  @HiveField(7)  final String   month;
  @HiveField(8)  final DateTime date;
  @HiveField(9)  final DateTime createdAt;
  @HiveField(10) final bool     isSynced;
  @HiveField(11) final bool     isDeleted;

  // ── WHY HiveField numbers must be sequential & never reused? ──
  // Hive stores field numbers (not names) in binary. If you delete
  // field 5 and add a new field 5, Hive reads the old data into the
  // wrong field. Always add NEW fields at the end with the next number.
  // ──────────────────────────────────────────────────────────────

  TransactionModel({
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

  // ── Convert entity → model (for saving) ───────────────────────
  factory TransactionModel.fromEntity(TransactionEntity e) {
    return TransactionModel(
      id:        e.id,
      amount:    e.amount,
      type:      e.type,
      category:  e.category,
      title:     e.title,
      note:      e.note,
      currency:  e.currency,
      month:     e.month,
      date:      e.date,
      createdAt: e.createdAt,
      isSynced:  e.isSynced,
      isDeleted: e.isDeleted,
    );
  }

  // ── Convert model → entity (for business logic) ───────────────
  TransactionEntity toEntity() {
    return TransactionEntity(
      id:        id,
      amount:    amount,
      type:      type,
      category:  category,
      title:     title,
      note:      note,
      currency:  currency,
      month:     month,
      date:      date,
      createdAt: createdAt,
      isSynced:  isSynced,
      isDeleted: isDeleted,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HIVE SERIALIZATION
  // Hive uses its own binary format. HiveObject with @HiveType
  // and @HiveField handles this automatically via the generated
  // .g.dart adapter. The fields above ARE the Hive schema.
  // You DON'T need manual toHiveMap/fromHiveMap — Hive generates
  // the binary read/write code in transaction_model.g.dart.
  // ─────────────────────────────────────────────────────────────

  // ─────────────────────────────────────────────────────────────
  // FIRESTORE SERIALIZATION
  // ─────────────────────────────────────────────────────────────

  /// Converts model to Map for Firestore.
  /// WHY Timestamp? Firestore stores dates as Timestamps (UTC).
  /// DateTime → Timestamp.fromDate() handles the conversion.
  /// WHY serverTimestamp()? It uses Firestore's server clock —
  /// immune to wrong device clocks and timezone differences.
  Map<String, dynamic> toFirestoreMap() {
    return {
      'id':        id,
      'amount':    amount,
      'type':      type,
      'category':  category,
      'title':     title,
      'note':      note,
      'currency':  currency,
      'month':     month,
      'date':      Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(createdAt),
      'isSynced':  true,   // always true when sending to Firestore
      'isDeleted': isDeleted,
      'serverTime': FieldValue.serverTimestamp(), // conflict resolution
    };
  }

  /// Reads a Firestore DocumentSnapshot back into a TransactionModel.
  /// WHY static factory? It matches Firestore's API:
  ///   final model = TransactionModel.fromFirestore(doc);
  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      id:        d['id']       as String,
      amount:    (d['amount'] as num).toDouble(),
      type:      d['type']     as String,
      category:  d['category'] as String,
      title:     d['title']    as String,
      note:      d['note']     as String?,
      currency:  d['currency'] as String,
      month:     d['month']    as String,
      date:      (d['date']      as Timestamp).toDate(),
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      isSynced:  d['isSynced']  as bool? ?? true,
      isDeleted: d['isDeleted'] as bool? ?? false,
    );
  }
}