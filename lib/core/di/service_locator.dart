// lib/core/di/service_locator.dart

import 'package:get_it/get_it.dart';

import '../services/connectivity_service.dart';
import '../../features/transactions/data/local/transaction_local_ds.dart';
import '../../features/transactions/data/remote/transaction_remote_ds.dart';
import '../../features/transactions/presentation/cubit/balance_cubit.dart';
import '../../features/transactions/presentation/cubit/transaction_cubit.dart';

final getIt = GetIt.instance;

Future<void> setupLocator() async {

  getIt.registerLazySingleton<ConnectivityService>(
        () => ConnectivityService(),
  );

  getIt.registerLazySingleton<TransactionLocalDS>(
        () => TransactionLocalDS(),
  );

  getIt.registerLazySingleton<TransactionRemoteDS>(
        () => TransactionRemoteDS(),
  );

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
}