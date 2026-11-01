import 'anythink_session.dart';
import 'token_store.dart';

/// An in-memory [TokenStore] for tests and short-lived processes.
class MemoryTokenStore implements TokenStore {
  AnythinkSession? _session;

  @override
  Future<AnythinkSession?> read() async => _session;

  @override
  Future<void> write(AnythinkSession session) async {
    _session = session;
  }

  @override
  Future<void> clear() async {
    _session = null;
  }
}
