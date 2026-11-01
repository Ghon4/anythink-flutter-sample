/// A failure from the Anythink API, or from a response the client cannot use.
sealed class AnythinkException implements Exception {
  /// Creates an exception with a user-readable [message].
  const AnythinkException({
    required this.message,
    this.statusCode,
    this.traceId,
    this.fieldErrors = const {},
  });

  /// Text a UI can show directly.
  final String message;

  /// HTTP status, when the failure came from a response.
  final int? statusCode;

  /// Problem-details `traceId`, when the body included one.
  final String? traceId;

  /// Validation messages keyed by the API's field name.
  ///
  /// Those names are PascalCase (`Password`, `Email`), unlike record JSON.
  final Map<String, List<String>> fieldErrors;

  @override
  String toString() => message;
}

/// The body failed a validation rule, or the project rejected the call.
final class AnythinkValidationException extends AnythinkException {
  /// Creates a validation failure.
  const AnythinkValidationException({
    required super.message,
    super.statusCode,
    super.traceId,
    super.fieldErrors,
  });
}

/// The access token or refresh token was missing, rejected, or revoked.
final class AnythinkUnauthorizedException extends AnythinkException {
  /// Creates an authentication failure.
  const AnythinkUnauthorizedException({
    required super.message,
    super.statusCode = 401,
    super.traceId,
    super.fieldErrors,
  });
}

/// The caller is signed in and is not allowed to do this.
final class AnythinkForbiddenException extends AnythinkException {
  /// Creates a permission failure.
  const AnythinkForbiddenException({
    required super.message,
    super.statusCode = 403,
    super.traceId,
    super.fieldErrors,
  });
}

/// The record, entity, or route was not found for this caller.
final class AnythinkNotFoundException extends AnythinkException {
  /// Creates a not-found failure.
  const AnythinkNotFoundException({
    required super.message,
    super.statusCode = 404,
    super.traceId,
    super.fieldErrors,
  });
}

/// The HTTP method is not supported on this route.
final class AnythinkMethodNotAllowedException extends AnythinkException {
  /// Creates a method failure.
  const AnythinkMethodNotAllowedException({
    required super.message,
    super.statusCode = 405,
    super.traceId,
    super.fieldErrors,
  });
}

/// The project or client IP exceeded the request limit.
final class AnythinkRateLimitException extends AnythinkException {
  /// Creates a rate-limit failure.
  const AnythinkRateLimitException({
    required super.message,
    super.statusCode = 429,
    super.traceId,
    this.retryAfter,
  });

  /// Seconds to wait, from `retry_after`, when the body included it.
  final int? retryAfter;
}

/// Anythink returned a 5xx response.
final class AnythinkServerException extends AnythinkException {
  /// Creates a server failure.
  const AnythinkServerException({
    required super.message,
    super.statusCode,
    super.traceId,
    super.fieldErrors,
  });
}

/// The request never produced an HTTP response.
final class AnythinkNetworkException extends AnythinkException {
  /// Creates a transport failure.
  const AnythinkNetworkException({required super.message});
}

/// A success response was not in the shape the client expects.
final class AnythinkFormatException extends AnythinkException {
  /// Creates a decode failure.
  const AnythinkFormatException({required super.message, super.statusCode});
}

/// An HTTP error that does not fit a more specific type.
final class AnythinkRequestException extends AnythinkException {
  /// Creates a request failure.
  const AnythinkRequestException({
    required super.message,
    super.statusCode,
    super.traceId,
    super.fieldErrors,
  });
}
