import '../../src/anythink/anythink.dart';
import '../domain/auth_repository.dart';

/// [AuthRepository] backed by [AnythinkClient.auth].
class AnythinkAuthRepository implements AuthRepository {
  /// Creates a repository for [client].
  AnythinkAuthRepository(this._client);

  final AnythinkClient _client;

  @override
  Future<AnythinkUser?> restore() => _client.auth.restore();

  @override
  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) {
    return _client.auth.register(
      firstName: firstName,
      lastName: lastName,
      email: email,
      password: password,
    );
  }

  @override
  Future<AnythinkUser> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signIn(email: email, password: password);
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}
