part of '../anythink_client.dart';

/// Registration and session calls for one [AnythinkClient].
class AnythinkAuth {
  AnythinkAuth._(this._client);

  final AnythinkClient _client;

  /// Creates a user and does not sign them in.
  ///
  /// A successful body is plain text (`Registration successful` in the
  /// guide). This project currently answers `400` with
  /// `Organisation does not allow registrations` for a valid payload.
  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    await _client.send(
      method: 'POST',
      path: '/auth/v1/register',
      authenticated: false,
      jsonBody: {
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'password': password,
      },
      successStatuses: const {200, 201},
    );
  }

  /// Exchanges an email and password for a stored session.
  ///
  /// Loads `GET /users/me` afterwards. When that call fails for a reason
  /// other than `401`, the returned user carries the email that was signed
  /// in and the session is kept.
  Future<AnythinkUser> signIn({
    required String email,
    required String password,
  }) async {
    final trimmed = email.trim();
    final response = await _client.send(
      method: 'POST',
      path: '/auth/v1/token',
      authenticated: false,
      jsonBody: {'email': trimmed, 'password': password},
      successStatuses: const {200},
    );
    final session = _sessionFrom(response.body, email: trimmed);
    await _client._sessions.adopt(session);
    return _loadUser(fallbackEmail: trimmed);
  }

  /// Restores a stored session, refreshing it when the access token is due.
  ///
  /// Returns `null` when nothing is stored, or when refresh is rejected.
  Future<AnythinkUser?> restore() async {
    final existing = await _client._sessions.read();
    if (existing == null) {
      return null;
    }
    try {
      if (existing.expiresWithin(_client.refreshLeeway, _client._clock())) {
        await _client._sessions.ensureFresh(
          leeway: _client.refreshLeeway,
          force: true,
          refresh: _client._refresh,
        );
      }
      final current = await _client._sessions.read();
      return await _loadUser(
        fallbackEmail: current?.email ?? existing.email ?? '',
      );
    } on AnythinkUnauthorizedException {
      await _client._sessions.clear();
      return null;
    }
  }

  /// Revokes the refresh token, then deletes the local session.
  ///
  /// Local tokens are removed even when the revoke call fails. A failed
  /// revoke can leave the refresh token valid until it expires.
  Future<void> signOut() async {
    final session = await _client._sessions.read();
    try {
      if (session != null && session.refreshToken.isNotEmpty) {
        await _client.send(
          method: 'POST',
          path: '/auth/v1/logout',
          authenticated: false,
          jsonBody: {'token': session.refreshToken},
          successStatuses: const {200, 204},
        );
      }
    } on AnythinkException {
      // The local session is cleared in the finally block.
    } finally {
      await _client._sessions.clear();
    }
  }

  Future<AnythinkUser> _loadUser({required String fallbackEmail}) async {
    try {
      final response = await _client.send(
        method: 'GET',
        path: '/users/me',
        successStatuses: const {200},
      );
      Object? decoded;
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        throw const AnythinkFormatException(
          message: 'User response was not JSON.',
        );
      }
      final user = AnythinkUser.fromJson(asJsonMap(decoded, 'User'));
      final current = _client._sessions.current;
      if (current != null && current.email != user.email) {
        await _client._sessions.adopt(current.copyWith(email: user.email));
      }
      return user;
    } on AnythinkUnauthorizedException {
      await _client._sessions.clear();
      rethrow;
    } on AnythinkException {
      return AnythinkUser(email: fallbackEmail);
    }
  }

  AnythinkSession _sessionFrom(String body, {required String email}) {
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const AnythinkFormatException(
        message: 'Sign-in response was not JSON.',
      );
    }
    return AnythinkSession.fromTokenResponse(
      json: asJsonMap(decoded, 'Sign-in response'),
      now: _client._clock(),
      email: email,
    );
  }
}
