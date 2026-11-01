import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth/anythink_session.dart';
import 'auth/anythink_user.dart';
import 'auth/memory_token_store.dart';
import 'auth/token_store.dart';
import 'entities/entity_page.dart';
import 'errors/anythink_exception.dart';
import 'errors/error_mapper.dart';
import 'parsing.dart';

part 'auth/anythink_auth.dart';
part 'auth/session_controller.dart';
part 'entities/entity_repository.dart';

/// Client for one Anythink project.
///
/// [baseUrl] is the API origin, such as
/// `https://api.uk01-lon.anythink.cloud`. [projectId] is the organisation id
/// in `/org/{project_id}`. The client keeps a single in-flight refresh so a
/// single-use refresh token is not presented twice.
class AnythinkClient {
  /// Creates a client.
  ///
  /// [refreshLeeway] is how early to renew the access token. The API reports
  /// a 30 minute lifetime via `expires_in`; the leeway is a client choice.
  /// When [tokenStore] is omitted the session lives only in memory.
  AnythinkClient({
    required String baseUrl,
    required String projectId,
    http.Client? httpClient,
    TokenStore? tokenStore,
    DateTime Function()? clock,
    this.refreshLeeway = const Duration(seconds: 60),
  }) : baseUrl = _normalizeBaseUrl(baseUrl),
       projectId = projectId.trim(),
       _http = httpClient ?? http.Client(),
       _ownsHttp = httpClient == null,
       _clock = clock ?? DateTime.now,
       _sessions = _SessionController(
         store: tokenStore ?? MemoryTokenStore(),
         clock: clock ?? DateTime.now,
       ) {
    if (this.baseUrl.isEmpty) {
      throw ArgumentError.value(baseUrl, 'baseUrl', 'Must not be empty.');
    }
    if (this.projectId.isEmpty) {
      throw ArgumentError.value(projectId, 'projectId', 'Must not be empty.');
    }
    auth = AnythinkAuth._(this);
  }

  /// API origin, without a trailing slash.
  final String baseUrl;

  /// Organisation id used in every path.
  final String projectId;

  /// How long before access-token expiry a call refreshes first.
  final Duration refreshLeeway;

  /// Sign-in, registration, refresh and sign-out.
  late final AnythinkAuth auth;

  final http.Client _http;
  final bool _ownsHttp;
  final DateTime Function() _clock;
  final _SessionController _sessions;

  /// Closes the underlying HTTP client when this object created it.
  void close() {
    if (_ownsHttp) {
      _http.close();
    }
  }

  /// Builds `/org/{projectId}` plus [path].
  ///
  /// [path] is relative to the project, for example `/entities/notes/items`.
  Uri uri(String path, [Map<String, String>? query]) {
    final suffix = path.startsWith('/') ? path : '/$path';
    return Uri.parse(
      '$baseUrl/org/$projectId$suffix',
    ).replace(queryParameters: query == null || query.isEmpty ? null : query);
  }

  /// A typed repository for [name], the lower-case entity name.
  EntityRepository<T> entity<T>(
    String name, {
    required T Function(Map<String, dynamic> json) fromJson,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Must not be empty.');
    }
    return EntityRepository._(
      client: this,
      entity: trimmed,
      fromJson: fromJson,
    );
  }

  /// Sends one request.
  ///
  /// Authenticated calls attach the bearer token, refresh it when it is
  /// inside [refreshLeeway] of expiry, and retry once after a `401`.
  Future<http.Response> send({
    required String method,
    required String path,
    Map<String, String>? query,
    Object? jsonBody,
    bool authenticated = true,
    Set<int> successStatuses = const {200, 201, 204},
  }) async {
    try {
      final response = authenticated
          ? await _sendAuthenticated(
              method: method,
              path: path,
              query: query,
              jsonBody: jsonBody,
            )
          : await _dispatch(
              method: method,
              path: path,
              query: query,
              jsonBody: jsonBody,
            );
      throwIfUnsuccessful(
        statusCode: response.statusCode,
        body: response.body,
        success: successStatuses,
      );
      return response;
    } on http.ClientException catch (error) {
      throw AnythinkNetworkException(
        message: describeTransportFailure(error.message),
      );
    }
  }

  Future<http.Response> _sendAuthenticated({
    required String method,
    required String path,
    Map<String, String>? query,
    Object? jsonBody,
  }) async {
    final generation = _sessions.generation;
    final session = await _sessions.ensureFresh(
      leeway: refreshLeeway,
      refresh: _refresh,
    );
    final first = await _dispatch(
      method: method,
      path: path,
      query: query,
      jsonBody: jsonBody,
      session: session,
    );
    if (first.statusCode != 401) {
      return first;
    }

    // A refresh that already landed, or one still in flight, consumed the
    // single-use refresh token. Retry with that result instead of rotating
    // again. Otherwise refresh once, then retry the original call once.
    final AnythinkSession refreshed;
    if (_sessions.generation == generation && !_sessions.refreshInFlight) {
      refreshed = await _sessions.ensureFresh(
        leeway: refreshLeeway,
        force: true,
        refresh: _refresh,
      );
    } else {
      refreshed = await _sessions.ensureFresh(
        leeway: refreshLeeway,
        refresh: _refresh,
      );
    }
    return _dispatch(
      method: method,
      path: path,
      query: query,
      jsonBody: jsonBody,
      session: refreshed,
    );
  }

  Future<AnythinkSession> _refresh(AnythinkSession current) async {
    final response = await _dispatch(
      method: 'POST',
      path: '/auth/v1/refresh',
      jsonBody: {'token': current.refreshToken},
    );
    if (response.statusCode == 401) {
      await _sessions.clear();
      throw mapAnythinkError(statusCode: 401, body: response.body);
    }
    throwIfUnsuccessful(
      statusCode: response.statusCode,
      body: response.body,
      success: const {200},
    );
    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const AnythinkFormatException(
        message: 'Refresh response was not JSON.',
      );
    }
    return AnythinkSession.fromTokenResponse(
      json: asJsonMap(decoded, 'Refresh response'),
      now: _clock(),
      email: current.email,
    );
  }

  Future<http.Response> _dispatch({
    required String method,
    required String path,
    Map<String, String>? query,
    Object? jsonBody,
    AnythinkSession? session,
  }) {
    final headers = <String, String>{
      // Asking only for JSON turns some plain-text errors into JSON strings.
      // Accept both, and let the error mapper handle either shape.
      'Accept': 'application/json, text/plain, */*',
      if (jsonBody != null) 'Content-Type': 'application/json; charset=UTF-8',
      if (session != null) 'Authorization': 'Bearer ${session.accessToken}',
    };
    final uri = this.uri(path, query);
    final body = jsonBody == null ? null : jsonEncode(jsonBody);
    return switch (method) {
      'GET' => _http.get(uri, headers: headers),
      'POST' => _http.post(uri, headers: headers, body: body),
      'PUT' => _http.put(uri, headers: headers, body: body),
      'DELETE' => _http.delete(uri, headers: headers, body: body),
      _ => throw ArgumentError.value(method, 'method', 'Unsupported method.'),
    };
  }
}

String _normalizeBaseUrl(String baseUrl) {
  var value = baseUrl.trim();
  while (value.endsWith('/')) {
    value = value.substring(0, value.length - 1);
  }
  return value;
}
