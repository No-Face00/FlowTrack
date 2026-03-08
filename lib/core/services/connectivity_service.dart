// lib/core/services/connectivity_service.dart
//
// ─────────────────────────────────────────────────────────────────────
// WHY THIS FILE EXISTS:
//   TransactionCubit needs to know: "Am I online right now?"
//   before deciding whether to sync to Firestore.
//
// WHY a separate service and not inline in the cubit?
//   1. TESTABILITY: In unit tests you mock ConnectivityService to
//      simulate offline/online without needing a real device.
//   2. REUSE: BalanceCubit, ExportService, etc. all need the same check.
//   3. SINGLE RESPONSIBILITY: Cubit handles state. Service handles I/O.
//
// HOW IT'S USED:
//   // In TransactionCubit.addTransaction():
//   if (await _network.isConnected) {
//     await _remoteDs.setTransaction(tx);  // online path
//   }
//   // offline path: Hive already saved it, sync later
// ─────────────────────────────────────────────────────────────────────

import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {

  final _connectivity = Connectivity();

  /// Returns true if the device has any active network connection.
  ///
  /// WHY check multiple results?
  /// connectivity_plus returns a LIST on some platforms (iOS 16+
  /// can have WiFi + cellular simultaneously). We check if ANY
  /// result is not 'none'.
  ///
  /// NOTE: A connected result does NOT guarantee internet access —
  /// the user could be on a WiFi network with no internet.
  /// For 99% of cases this is fine. For critical sync operations
  /// the Firestore call itself will fail and be retried later.
  Future<bool> get isConnected async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// Stream that emits whenever connectivity changes.
  /// Used in main.dart to trigger syncPending() automatically
  /// when the device comes back online.
  ///
  /// Usage in main.dart (after runApp):
  ///   ConnectivityService().onConnectivityChanged.listen((isOnline) {
  ///     if (isOnline) getIt<TransactionCubit>().syncPending();
  ///   });
  Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.map(
          (results) => results.any((r) => r != ConnectivityResult.none),
    );
  }
}