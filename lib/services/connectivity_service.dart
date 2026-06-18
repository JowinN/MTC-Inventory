import 'dart:async';
import '../utils/connectivity_helper.dart';
import '../utils/connectivity_stub.dart'
    if (dart.library.html) '../utils/connectivity_web.dart'
    if (dart.library.io) '../utils/connectivity_mobile.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;

  late final ConnectivityHelper _helper;

  ConnectivityService._internal() {
    _helper = getHelper();
  }

  Future<bool> get isConnected => _helper.hasConnection();
  Stream<bool> get connectionStream => _helper.connectionStream;
}
