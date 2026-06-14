
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

import '../../domain/entities/transaction_entity.dart';

part 'transaction_model.g.dart'; // ← THIS LINE was missing — connects the adapter

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
      'isSynced':  true,
      'isDeleted': isDeleted,
      'serverTime': FieldValue.serverTimestamp(),
    };
  }

  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      id:        d['id']       as String,
      amount:    (d['amount']  as num).toDouble(),
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