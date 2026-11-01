import 'errors/anythink_exception.dart';

/// Reads an int from JSON that may arrive as an [int] or another [num].
int? asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}

/// Parses an ISO-8601 timestamp, or returns `null` when [value] is not one.
DateTime? asDateTime(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value)?.toUtc();
}

/// Copies a decoded JSON object into a `Map<String, dynamic>`.
///
/// Throws [AnythinkFormatException] when [decoded] is not an object.
Map<String, dynamic> asJsonMap(Object? decoded, String what) {
  if (decoded is! Map) {
    throw AnythinkFormatException(message: '$what was not a JSON object.');
  }
  return Map<String, dynamic>.from(decoded);
}
