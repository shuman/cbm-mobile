/// Custom exceptions for the app

class AppException implements Exception {
  final String message;
  AppException(this.message);

  @override
  String toString() => message;
}

class PermissionException extends AppException {
  PermissionException([String message = 'Insufficient permissions. You do not have access to this module.'])
      : super(message);
}

class NetworkException extends AppException {
  NetworkException([String message = 'Network error. Please check your connection.'])
      : super(message);
}

class ServerException extends AppException {
  ServerException([String message = 'Server error. Please try again later.'])
      : super(message);
}
