import 'package:connectivity_plus/connectivity_plus.dart';

abstract class NetworkStatus {
  Future<bool> get isOnline;

  Stream<bool> get onStatusChanged;
}

class PluginNetworkStatus implements NetworkStatus {
  PluginNetworkStatus({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> get isOnline async {
    return _isOnline(await _connectivity.checkConnectivity());
  }

  @override
  Stream<bool> get onStatusChanged {
    return _connectivity.onConnectivityChanged.map(_isOnline);
  }

  bool _isOnline(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }
}
