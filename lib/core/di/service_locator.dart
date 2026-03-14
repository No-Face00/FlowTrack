// lib/core/di/service_locator.dart
//
// ARCHITECTURE: Dependency Injection via GetIt.
//
// PHASE 3 ADDITIONS:
//   BudgetLocalDS  → lazySingleton (one Hive box, shared)
//   BudgetRemoteDS → lazySingleton (stateless Firestore wrapper)
//   BudgetCubit    → factory (fresh instance per BlocProvider)
//
// Registration strategy:
//
//   lazySingleton: created once on first getIt<T>() call, reused
//     forever. Use for stateless services and data sources that
//     wrap a shared resource (Hive box, Firestore instance).
//
//   factory: new instance on every getIt<T>() call. Use for
//     Cubits — each screen needs its own cubit with its own
//     state, not a shared global state.
//
// WHY inject ConnectivityService into BudgetCubit?
//   Cubit needs to know if it's online before pushing to
//   Firestore. Injecting it (instead of calling it directly)
//   makes the cubit unit-testable — pass a mock in tests.

import 'package:get_it/get_it.dart';

import '../services/connectivity_service.dart';
import '../../features/transactions/data/local/transaction_local_ds.dart';
import '../../features/transactions/data/remote/transaction_remote_ds.dart';
import '../../features/transactions/presentation/cubit/balance_cubit.dart';
import '../../features/transactions/presentation/cubit/transaction_cubit.dart';
import '../../features/budget/data/local/budget_local_ds.dart';
import '../../features/budget/data/remote/budget_remote_ds.dart';
import '../../features/budget/presentation/cubit/budget_cubit.dart';

final getIt = GetIt.instance;

Future<void> setupLocator() async {

  // ── Core services ─────────────────────────────────────────
  getIt.registerLazySingleton<ConnectivityService>(
        () => ConnectivityService(),
  );

  // ── Transaction layer ─────────────────────────────────────
  getIt.registerLazySingleton<TransactionLocalDS>(
        () => TransactionLocalDS(),
  );
  getIt.registerLazySingleton<TransactionRemoteDS>(
        () => TransactionRemoteDS(),
  );

  // ── Budget layer ──────────────────────────────────────────
  getIt.registerLazySingleton<BudgetLocalDS>(
        () => BudgetLocalDS(),
  );
  getIt.registerLazySingleton<BudgetRemoteDS>(
        () => BudgetRemoteDS(),
  );

  // ── Cubits (factory — new instance per screen) ────────────
  getIt.registerFactory<TransactionCubit>(
        () => TransactionCubit(
      local:   getIt<TransactionLocalDS>(),
      remote:  getIt<TransactionRemoteDS>(),
      network: getIt<ConnectivityService>(),
    ),
  );

  getIt.registerFactory<BalanceCubit>(
        () => BalanceCubit(
      remote: getIt<TransactionRemoteDS>(),
    ),
  );

  getIt.registerFactory<BudgetCubit>(
        () => BudgetCubit(
      local:   getIt<BudgetLocalDS>(),
      remote:  getIt<BudgetRemoteDS>(),
      network: getIt<ConnectivityService>(),
    ),
  );
}