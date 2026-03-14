// lib/core/services/hive_service.dart
//
// ARCHITECTURE: Core / Infrastructure Layer.
//
// PHASE 3 CHANGES:
//   1. BudgetModel adapter registered
//   2. budgetBox opened alongside transactionBox
//   3. AES-256 encryption added to BOTH boxes
//
// WHY encrypt Hive at all?
//   Hive stores data as binary files in the app's documents
//   directory. On a rooted Android device or via iTunes backup,
//   those files are readable without a password. AES-256
//   encryption makes the files unreadable without the key,
//   even with physical device access.
//
// HOW the key lifecycle works:
//   App first launch:
//     Hive.generateSecureKey() → 32 random bytes (256 bits)
//     base64url encode → store in FlutterSecureStorage
//     FlutterSecureStorage uses Android Keystore / iOS Keychain
//     (hardware-backed on modern devices)
//
//   Every subsequent launch:
//     Read key from FlutterSecureStorage
//     Decode base64url → 32 bytes
//     Wrap in HiveAesCipher → pass to openBox()
//
// WHY base64url encode the key before storing?
//   FlutterSecureStorage stores strings, not bytes.
//   base64url is URL-safe, no padding issues.
//
// IMPORTANT: If the user uninstalls the app or clears app data,
//   FlutterSecureStorage is wiped → key is gone → Hive data is
//   permanently unreadable. This is expected and safe — all
//   data is recoverable from Firestore after re-login.
//
// WHY one cipher shared by both boxes?
//   The same 32-byte key encrypts both boxes. If you ever need
//   separate keys per box, call _getCipher() twice with different
//   key names. For now, shared key simplifies key management.

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../features/budget/data/models/budget_model.dart';
import '../../features/transactions/data/models/transaction_model.dart';

class HiveService {
  HiveService._();

  static const String _txBoxName     = 'transactions';
  static const String _budgetBoxName = 'budgets';
  static const String _encKeyName    = 'hive_enc_key';

  static final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<void> init() async {
    await Hive.initFlutter();

    // ── Register type adapters ────────────────────────────────
    if (!Hive.isAdapterRegistered(TransactionModelAdapter().typeId)) {
      Hive.registerAdapter(TransactionModelAdapter());
    }
    if (!Hive.isAdapterRegistered(BudgetModelAdapter().typeId)) {
      Hive.registerAdapter(BudgetModelAdapter());
    }

    // ── Build AES-256 cipher from stored / new key ────────────
    final cipher = await _getCipher();

    // ── Open both encrypted boxes ─────────────────────────────
    await Hive.openBox<TransactionModel>(_txBoxName,     encryptionCipher: cipher);
    await Hive.openBox<BudgetModel>     (_budgetBoxName, encryptionCipher: cipher);
  }

  static Future<HiveAesCipher> _getCipher() async {
    String? keyString = await _secureStorage.read(key: _encKeyName);

    if (keyString == null) {
      // First launch — generate and persist a 256-bit key
      final key = Hive.generateSecureKey();
      keyString = base64UrlEncode(key);
      await _secureStorage.write(key: _encKeyName, value: keyString);
    }

    return HiveAesCipher(base64Url.decode(keyString));
  }

  // ── Box accessors ─────────────────────────────────────────
  static Box<TransactionModel> get transactionBox =>
      Hive.box<TransactionModel>(_txBoxName);

  static Box<BudgetModel> get budgetBox =>
      Hive.box<BudgetModel>(_budgetBoxName);

  // ── Clear all local data (used by Account screen) ─────────
  // Clears box contents but keeps the encryption key in
  // FlutterSecureStorage. Firestore data is NOT affected.
  static Future<void> clearAll() async {
    await transactionBox.clear();
    await budgetBox.clear();
  }
}