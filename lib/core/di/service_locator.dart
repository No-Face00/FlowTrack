// lib/core/di/service_locator.dart

import 'package:get_it/get_it.dart';

import '../cubit/app_cubit.dart';
import '../notifications/notification_cubit.dart';
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

  // ── App-wide settings (theme + currency) ─────────────────
  getIt.registerLazySingleton<AppCubit>(() => AppCubit());

  // ── Notifications ─────────────────────────────────────────
  getIt.registerLazySingleton<NotificationCubit>(() => NotificationCubit());

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

  // ── Cubits ────────────────────────────────────────────────
  // lazySingleton — one instance shared across ALL routes.
  // Both HomeScreen and AddTransactionScreen use the same cubit,
  // so when addTransaction() emits, the Home UI updates instantly.
  getIt.registerLazySingleton<TransactionCubit>(
        () => TransactionCubit(
      local:   getIt<TransactionLocalDS>(),
      remote:  getIt<TransactionRemoteDS>(),
      network: getIt<ConnectivityService>(),
    ),
  );

  // lazySingleton so all screens share ONE BalanceCubit instance.
  // Currency changes propagate instantly across Home, Analytics, etc.
  getIt.registerLazySingleton<BalanceCubit>(
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