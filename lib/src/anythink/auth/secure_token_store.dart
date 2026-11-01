import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'anythink_session.dart';
import 'token_store.dart';

/// A [TokenStore] backed by the platform secure store.
///
/// iOS uses the Keychain and Android uses encrypted shared preferences.
/// Web uses the plugin's web backend, which is not equivalent to a keychain;
/// a published package should keep this behind [TokenStore] and document that.
class SecureTokenStore implements TokenStore {
  /// Creates a store. Tests can pass [storage].
  SecureTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  /// Key under which the session JSON is stored.
  static const sessionKey = 'anythink_session';

  final FlutterSecureStorage _storage;

  @override
  Future<AnythinkSession?> read() async {
    final raw = await _storage.read(key: sessionKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      return AnythinkSession.fromJson(Map<String, dynamic>.from(decoded));
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> write(AnythinkSession session) {
    return _storage.write(key: sessionKey, value: jsonEncode(session.toJson()));
  }

  @override
  Future<void> clear() => _storage.delete(key: sessionKey);
}
