abstract class ApiListener {
  void onTokenExpired();

  Future<bool> onRequestCall();
}
