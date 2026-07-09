// lib/core/exceptions.dart
class NetworkException implements Exception {
  final String message;
  const NetworkException(this.message);
  @override String toString() => 'NetworkException: $message';
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override String toString() => 'AuthException: $message';
}

class DataException implements Exception {
  final String message;
  const DataException(this.message);
  @override String toString() => 'DataException: $message';
}

class UnexpectedException implements Exception {
  final String message;
  const UnexpectedException(this.message);
  @override String toString() => 'UnexpectedException: $message';
}