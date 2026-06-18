abstract class ConnectivityHelper {
  Future<bool> hasConnection();
  Stream<bool> get connectionStream;
}
