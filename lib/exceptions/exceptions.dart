class ConnectionException implements Exception {
  final String message;

  ConnectionException({
    this.message =
        'No Internet connection. Make sure Wifi or Cellular Data is turned on, then try again.',
  });

  String toString() => "FormatException: $message";
}

class ManuallyException implements Exception {
  final int? code;
  final String message;

  ManuallyException(this.message, {this.code});

  String toString() => "FormatException: $message";
}

class TokenExpiredException implements Exception {
  TokenExpiredException();
}

class ServerException implements Exception {
  final dynamic error;
  final int? code;

  ServerException(this.error, {this.code});
}

class HaveNoPermissionException implements Exception {
  HaveNoPermissionException();
}
