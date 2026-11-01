import '../../src/anythink/anythink.dart';

/// Sign-in operations the UI is allowed to call.
abstract interface class AuthRepository {
  /// Restores a stored session, or returns `null` when there is none.
  Future<AnythinkUser?> restore();

  /// Registers a user. Does not sign them in.
  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  });

  /// Signs in and returns the current user.
  Future<AnythinkUser> signIn({
    required String email,
    required String password,
  });

  /// Revokes the refresh token and clears the local session.
  Future<void> signOut();
}
