import 'dart:convert';

import 'anythink_exception.dart';

/// Maps an HTTP error body to a typed [AnythinkException].
///
/// Anythink does not use one error shape. Observed on project `19515783`:
///
/// * Problem details (`application/problem+json`) for model validation and
///   for a missing credential on a record route.
/// * A JSON string (`application/json`, body `"Invalid email or password"`)
///   when the request asks for `Accept: application/json` on sign-in,
///   refresh, or the registrations-disabled response.
/// * Plain text for those same calls when `Accept` is `*/*` or includes
///   `text/plain`.
/// * `{error, message, tenant_id}` for an inactive organisation.
/// * An empty body for `405`.
AnythinkException mapAnythinkError({
  required int statusCode,
  required String body,
}) {
  final inspected = _inspect(body, statusCode);
  return switch (statusCode) {
    400 => AnythinkValidationException(
      message: inspected.message,
      statusCode: statusCode,
      traceId: inspected.traceId,
      fieldErrors: inspected.fieldErrors,
    ),
    401 => AnythinkUnauthorizedException(
      message: inspected.message,
      statusCode: statusCode,
      traceId: inspected.traceId,
      fieldErrors: inspected.fieldErrors,
    ),
    403 => AnythinkForbiddenException(
      message: inspected.message,
      statusCode: statusCode,
      traceId: inspected.traceId,
      fieldErrors: inspected.fieldErrors,
    ),
    404 => AnythinkNotFoundException(
      message: inspected.message,
      statusCode: statusCode,
      traceId: inspected.traceId,
      fieldErrors: inspected.fieldErrors,
    ),
    405 => AnythinkMethodNotAllowedException(
      message: inspected.message,
      statusCode: statusCode,
      traceId: inspected.traceId,
    ),
    429 => AnythinkRateLimitException(
      message: inspected.message,
      statusCode: statusCode,
      traceId: inspected.traceId,
      retryAfter: inspected.retryAfter,
    ),
    >= 500 => AnythinkServerException(
      message: inspected.message,
      statusCode: statusCode,
      traceId: inspected.traceId,
      fieldErrors: inspected.fieldErrors,
    ),
    _ => AnythinkRequestException(
      message: inspected.message,
      statusCode: statusCode,
      traceId: inspected.traceId,
      fieldErrors: inspected.fieldErrors,
    ),
  };
}

/// Turns a transport failure into text a UI can show.
///
/// A browser reports a blocked cross-origin response as `Failed to fetch`
/// and does not expose the status or body. Anythink's preflight echoes the
/// origin, but the live token and record responses omit
/// `Access-Control-Allow-Origin`, which is what produces that message.
String describeTransportFailure(String raw) {
  final trimmed = raw.trim();
  if (trimmed == 'Failed to fetch' ||
      trimmed.contains('XMLHttpRequest error')) {
    return 'The browser blocked the Anythink response. '
        'The preflight allows this origin, but the response itself has no '
        'Access-Control-Allow-Origin header, so the app never sees the status '
        'or body. iOS, Android and desktop are not affected.';
  }
  if (trimmed.isEmpty) {
    return 'The network request failed.';
  }
  return trimmed;
}

/// Throws [mapAnythinkError] when [statusCode] is outside [success].
void throwIfUnsuccessful({
  required int statusCode,
  required String body,
  Set<int> success = const {200, 201, 204},
}) {
  if (success.contains(statusCode)) {
    return;
  }
  throw mapAnythinkError(statusCode: statusCode, body: body);
}

class _Inspected {
  const _Inspected({
    required this.message,
    this.traceId,
    this.fieldErrors = const {},
    this.retryAfter,
  });

  final String message;
  final String? traceId;
  final Map<String, List<String>> fieldErrors;
  final int? retryAfter;
}

_Inspected _inspect(String body, int statusCode) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) {
    return _Inspected(message: _fallback(statusCode));
  }

  Object? decoded;
  try {
    decoded = jsonDecode(trimmed);
  } on FormatException {
    decoded = null;
  }

  if (decoded is String) {
    final message = decoded.trim();
    return _Inspected(
      message: message.isEmpty ? _fallback(statusCode) : message,
    );
  }

  if (decoded is Map) {
    final map = Map<String, dynamic>.from(decoded);
    final fieldErrors = _fieldErrors(map['errors']);
    final traceId = map['traceId'] is String ? map['traceId'] as String : null;
    final retryAfter = _asInt(map['retry_after']);
    final message = _messageFromMap(map, fieldErrors, statusCode);
    return _Inspected(
      message: message,
      traceId: traceId,
      fieldErrors: fieldErrors,
      retryAfter: retryAfter,
    );
  }

  return _Inspected(message: trimmed);
}

String _messageFromMap(
  Map<String, dynamic> map,
  Map<String, List<String>> fieldErrors,
  int statusCode,
) {
  if (fieldErrors.isNotEmpty) {
    return fieldErrors.values.expand((lines) => lines).join('\n');
  }
  final message = map['message'];
  if (message is String && message.trim().isNotEmpty) {
    return message.trim();
  }
  final title = map['title'];
  if (title is String && title.trim().isNotEmpty) {
    return title.trim();
  }
  final error = map['error'];
  if (error is String && error.trim().isNotEmpty) {
    return error.trim();
  }
  return _fallback(statusCode);
}

Map<String, List<String>> _fieldErrors(Object? errors) {
  if (errors is! Map) {
    return const {};
  }
  final parsed = <String, List<String>>{};
  errors.forEach((key, value) {
    final name = key.toString();
    if (value is List) {
      parsed[name] = [for (final item in value) item.toString()];
    } else if (value != null) {
      parsed[name] = [value.toString()];
    }
  });
  return parsed;
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}

String _fallback(int statusCode) {
  return switch (statusCode) {
    400 => 'The request was rejected.',
    401 => 'Sign in required.',
    403 => 'You do not have permission to do that.',
    404 => 'Not found.',
    405 => 'That method is not supported.',
    429 => 'Too many requests.',
    >= 500 => 'Anythink failed to handle the request.',
    _ => 'Request failed ($statusCode).',
  };
}
