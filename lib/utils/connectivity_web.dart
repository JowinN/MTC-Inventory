// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'connectivity_helper.dart';

class ConnectivityHelperImpl implements ConnectivityHelper {
  final _controller = StreamController<bool>.broadcast();

  ConnectivityHelperImpl() {
    html.window.onOnline.listen((_) => _controller.add(true));
    html.window.onOffline.listen((_) => _controller.add(false));
    
    // Periodically verify network connectivity status
    Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_controller.hasListener) {
        _controller.add(html.window.navigator.onLine ?? false);
      }
    });
  }

  @override
  Future<bool> hasConnection() async {
    return html.window.navigator.onLine ?? false;
  }

  @override
  Stream<bool> get connectionStream => _controller.stream;
}

ConnectivityHelper getHelper() => ConnectivityHelperImpl();
