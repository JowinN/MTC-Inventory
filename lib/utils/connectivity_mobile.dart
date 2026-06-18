import 'dart:async';
import 'dart:io';
import 'connectivity_helper.dart';

class ConnectivityHelperImpl implements ConnectivityHelper {
  final _controller = StreamController<bool>.broadcast();
  bool _lastStatus = true;

  ConnectivityHelperImpl() {
    _checkStatus();
    Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkStatus();
    });
  }

  Future<void> _checkStatus() async {
    final status = await hasConnection();
    if (status != _lastStatus) {
      _lastStatus = status;
      _controller.add(status);
    }
  }

  @override
  Future<bool> hasConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<bool> get connectionStream => _controller.stream;
}

ConnectivityHelper getHelper() => ConnectivityHelperImpl();
