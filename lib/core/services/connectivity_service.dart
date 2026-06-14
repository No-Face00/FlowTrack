

import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {

  final _connectivity = Connectivity();

  Future<bool> get isConnected async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }


  Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.map(
          (results) => results.any((r) => r != ConnectivityResult.none),
    );
  }
}