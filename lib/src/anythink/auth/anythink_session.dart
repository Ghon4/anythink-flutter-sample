import '../errors/anythink_exception.dart';

/// An access token, the refresh token that rotates it, and when it expires.
///
/// The access token is treated as opaque. Expiry comes from `expires_in` on
/// the token response, not from JWT claims.
class AnythinkSession {
  /// Creates a session.
  const AnythinkSession({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
    this.email,
  });

  /// Bearer credential sent on authenticated calls.
  final String accessToken;

  /// Single-use token exchanged at `/auth/v1/refresh`.
  final String refreshToken;

  /// Instant after which the access token should be refreshed.
  final DateTime accessTokenExpiresAt;

  /// Email captured at sign-in, so the UI can label the session offline.
  final String? email;

  /// Whether the access token expires within [leeway] of [now].
  bool expiresWithin(Duration leeway, DateTime now) {
    return !accessTokenExpiresAt.isAfter(now.toUtc().add(leeway));
  }

  /// Returns a copy with the given fields replaced.
  AnythinkSession copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? accessTokenExpiresAt,
    String? email,
  }) {
    return AnythinkSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      accessTokenExpiresAt: accessTokenExpiresAt ?? this.accessTokenExpiresAt,
      email: email ?? this.email,
    );
  }

  /// Serialises the session for a token store.
  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'access_token_expires_at': accessTokenExpiresAt.toUtc().toIso8601String(),
      if (email != null) 'email': email,
    };
  }

  /// Restores a session previously written by [toJson].
  factory AnythinkSession.fromJson(Map<String, dynamic> json) {
    final access = json['access_token'];
    final refresh = json['refresh_token'];
    final expiry = json['access_token_expires_at'];
    if (access is! String || refresh is! String || expiry is! String) {
      throw const AnythinkFormatException(
        message: 'Stored session is missing a token or expiry.',
      );
    }
    final parsed = DateTime.tryParse(expiry);
    if (parsed == null) {
      throw const AnythinkFormatException(
        message: 'Stored session expiry is not a timestamp.',
      );
    }
    final email = json['email'];
    return AnythinkSession(
      accessToken: access,
      refreshToken: refresh,
      accessTokenExpiresAt: parsed.toUtc(),
      email: email is String ? email : null,
    );
  }

  /// Builds a session from `access_token`, `refresh_token` and `expires_in`.
  factory AnythinkSession.fromTokenResponse({
    required Map<String, dynamic> json,
    required DateTime now,
    String? email,
  }) {
    final access = json['access_token'];
    final refresh = json['refresh_token'];
    final expiresIn = json['expires_in'];
    if (access is! String ||
        access.isEmpty ||
        refresh is! String ||
        refresh.isEmpty) {
      throw const AnythinkFormatException(
        message:
            'Token response did not include access_token and refresh_token.',
      );
    }
    if (expiresIn is! num) {
      throw const AnythinkFormatException(
        message: 'Token response did not include expires_in.',
      );
    }
    return AnythinkSession(
      accessToken: access,
      refreshToken: refresh,
      accessTokenExpiresAt: now.toUtc().add(
        Duration(seconds: expiresIn.toInt()),
      ),
      email: email,
    );
  }
}
