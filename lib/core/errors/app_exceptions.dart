/// Base exception class for all application exceptions
sealed class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const AppException(this.message, {this.code, this.originalError});

  @override
  String toString() {
    if (code != null) {
      return '$runtimeType($code): $message';
    }
    return '$runtimeType: $message';
  }
}

/// Authentication-related exceptions
class AuthException extends AppException {
  const AuthException(super.message, {super.code, super.originalError});

  /// Create from Firebase Auth error code
  factory AuthException.fromFirebaseCode(String code) {
    switch (code) {
      case 'wrong-password':
        return const AuthException(
          'Incorrect password',
          code: 'wrong-password',
        );
      case 'user-not-found':
        return const AuthException(
          'No account found with this email',
          code: 'user-not-found',
        );
      case 'email-already-in-use':
        return const AuthException(
          'An account already exists with this email',
          code: 'email-already-in-use',
        );
      case 'invalid-email':
        return const AuthException(
          'Invalid email address',
          code: 'invalid-email',
        );
      case 'weak-password':
        return const AuthException(
          'Password is too weak',
          code: 'weak-password',
        );
      case 'too-many-requests':
        return const AuthException(
          'Too many failed attempts. Please try again later',
          code: 'too-many-requests',
        );
      case 'network-request-failed':
        return const AuthException(
          'Network error. Please check your connection',
          code: 'network-request-failed',
        );
      default:
        return AuthException(
          'Authentication failed: $code',
          code: code,
        );
    }
  }
}

/// Network-related exceptions
class NetworkException extends AppException {
  const NetworkException(super.message, {super.code, super.originalError});

  factory NetworkException.timeout() {
    return const NetworkException(
      'Request timed out. Please check your connection',
      code: 'timeout',
    );
  }

  factory NetworkException.noConnection() {
    return const NetworkException(
      'No internet connection',
      code: 'no-connection',
    );
  }
}

/// Permission-related exceptions
class PermissionException extends AppException {
  const PermissionException(super.message, {super.code, super.originalError});

  factory PermissionException.denied(String resource) {
    return PermissionException(
      'Permission denied: $resource',
      code: 'permission-denied',
    );
  }

  factory PermissionException.notGranted(String permission) {
    return PermissionException(
      'Permission not granted: $permission',
      code: 'not-granted',
    );
  }
}

/// Firestore-related exceptions
class FirestoreException extends AppException {
  const FirestoreException(super.message, {super.code, super.originalError});

  factory FirestoreException.fromCode(String code) {
    switch (code) {
      case 'permission-denied':
        return const FirestoreException(
          'Permission denied. You may not have access to this data',
          code: 'permission-denied',
        );
      case 'unavailable':
        return const FirestoreException(
          'Service temporarily unavailable. Please try again',
          code: 'unavailable',
        );
      case 'not-found':
        return const FirestoreException(
          'Document not found',
          code: 'not-found',
        );
      default:
        return FirestoreException(
          'Firestore error: $code',
          code: code,
        );
    }
  }
}

/// Storage-related exceptions
class StorageException extends AppException {
  const StorageException(super.message, {super.code, super.originalError});

  factory StorageException.fromCode(String code) {
    switch (code) {
      case 'unauthorized':
        return const StorageException(
          'You do not have permission to access this file',
          code: 'unauthorized',
        );
      case 'object-not-found':
        return const StorageException(
          'File not found',
          code: 'object-not-found',
        );
      default:
        return StorageException(
          'Storage error: $code',
          code: code,
        );
    }
  }
}

/// Validation exceptions
class ValidationException extends AppException {
  const ValidationException(super.message, {super.code, super.originalError});
}

/// Generic application exception for unexpected errors
class UnknownException extends AppException {
  const UnknownException(super.message, {super.code, super.originalError});
}

/// Subscription-related exceptions
class SubscriptionException extends AppException {
  const SubscriptionException(super.message, {super.code, super.originalError});
}

/// Resource not found exceptions
class NotFoundException extends AppException {
  const NotFoundException(super.message, {super.code, super.originalError});
}

