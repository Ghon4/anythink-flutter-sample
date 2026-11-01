import 'anythink_session.dart';

/// Persistence for the current [AnythinkSession].
///
/// The refresh token is single-use. [write] must complete before it returns,
/// so a later refresh cannot read the token that was just revoked.
abstract interface class TokenStore {
  /// Reads the stored session, or `null` when nothing is stored.
  Future<AnythinkSession?> read();

  /// Replaces the stored session.
  Future<void> write(AnythinkSession session);

  /// Deletes the stored session.
  Future<void> clear();
}
