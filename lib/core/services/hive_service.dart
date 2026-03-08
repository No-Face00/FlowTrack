// lib/core/services/hive_service.dart

import 'package:hive_flutter/hive_flutter.dart';

import '../../features/transactions/data/models/transaction_model.dart';

class HiveService {
  HiveService._();

  static const String _txBoxName = 'transactions';

  static Future<void> init() async {
    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(TransactionModelAdapter().typeId)) {
      Hive.registerAdapter(TransactionModelAdapter());
    }

    await Hive.openBox<TransactionModel>(_txBoxName);
  }

  static Box<TransactionModel> get transactionBox =>
      Hive.box<TransactionModel>(_txBoxName);

  static Future<void> clearAll() async {
    await transactionBox.clear();
  }
}