part of '../anythink_client.dart';

/// Holds the session and makes sure only one refresh runs at a time.
final class _SessionController {
  _SessionController({required this._store, required this._clock});

  final TokenStore _store;
  final DateTime Function() _clock;

  AnythinkSession? _session;
  Future<void>? _loading;
  Future<AnythinkSession>? _refreshing;
  bool _loaded = false;
  int _generation = 0;

  /// Changes every time the stored session is replaced or cleared.
  int get generation => _generation;

  /// Whether a refresh call is waiting on the network or on storage.
  bool get refreshInFlight => _refreshing != null;

  /// The session currently in memory. `null` before the first [read] or
  /// [adopt], and after [clear].
  AnythinkSession? get current => _session;

  /// Loads the persisted session once.
  Future<AnythinkSession?> read() async {
    await _ensureLoaded();
    return _session;
  }

  /// Persists [session] and publishes it to later callers.
  Future<void> adopt(AnythinkSession session) async {
    await _store.write(session);
    _session = session;
    _loaded = true;
    _generation++;
  }

  /// Drops the session from memory and from the store.
  Future<void> clear() async {
    await _store.clear();
    _session = null;
    _loaded = true;
    _generation++;
  }

  /// Returns a session whose access token is outside [leeway] of expiry.
  ///
  /// Concurrent callers share one refresh. [refresh] is invoked at most once
  /// for that flight, with the refresh token captured at the start.
  Future<AnythinkSession> ensureFresh({
    required Duration leeway,
    required Future<AnythinkSession> Function(AnythinkSession current) refresh,
    bool force = false,
  }) {
    final inflight = _refreshing;
    if (inflight != null) {
      return inflight;
    }
    if (!_loaded) {
      return _ensureLoaded().then(
        (_) => ensureFresh(leeway: leeway, refresh: refresh, force: force),
      );
    }
    final session = _session;
    if (session == null) {
      return Future<AnythinkSession>.error(
        const AnythinkUnauthorizedException(message: 'Sign in required.'),
      );
    }
    if (!force && !session.expiresWithin(leeway, _clock())) {
      return Future<AnythinkSession>.value(session);
    }
    return _begin(session, refresh);
  }

  Future<AnythinkSession> _begin(
    AnythinkSession session,
    Future<AnythinkSession> Function(AnythinkSession current) refresh,
  ) {
    final inflight = _refreshing;
    if (inflight != null) {
      return inflight;
    }
    final future = _run(session, refresh);
    _refreshing = future;
    return future.whenComplete(() {
      if (identical(_refreshing, future)) {
        _refreshing = null;
      }
    });
  }

  Future<AnythinkSession> _run(
    AnythinkSession session,
    Future<AnythinkSession> Function(AnythinkSession current) refresh,
  ) async {
    final next = await refresh(session);
    await _store.write(next);
    _session = next;
    _generation++;
    return next;
  }

  Future<void> _ensureLoaded() {
    if (_loaded) {
      return Future<void>.value();
    }
    final pending = _loading;
    if (pending != null) {
      return pending;
    }
    final future = _load();
    _loading = future;
    return future.whenComplete(() {
      if (identical(_loading, future)) {
        _loading = null;
      }
    });
  }

  Future<void> _load() async {
    _session = await _store.read();
    _loaded = true;
  }
}
