import 'package:connectivity/connectivity.dart';

class ConnectivityService {

  Future<bool> hasConnection() async {
    return await _checkConnection();
  }

  Future<bool> _checkConnection() async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.mobile) {
      return true;
    }
    if (connectivityResult == ConnectivityResult.wifi) {
      return true;
    }
    return false;
  }
}