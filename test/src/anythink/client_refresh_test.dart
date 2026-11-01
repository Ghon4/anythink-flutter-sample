import 'dart:async';
import 'dart:convert';

import 'package:anythink_flutter_sample/src/anythink/anythink.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('token refresh', () {
    test('does not refresh a session that is outside the leeway', () async {
      final harness = _Harness();
      addTearDown(harness.client.close);

      await harness.signIn();
      harness.clock.advance(const Duration(seconds: 1700));
      await harness.notes.list();

      expect(harness.refreshTokens, isEmpty);
      expect(harness.noteBearers, ['Bearer access-1']);
    });

    test('refreshes once before expiry and stores the rotated token', () async {
      final harness = _Harness(
        onRefresh: (token) {
          expect(token, 'refresh-1');
          return _tokens(access: 'access-2', refresh: 'refresh-2');
        },
      );
      addTearDown(harness.client.close);

      await harness.signIn();
      harness.clock.advance(const Duration(seconds: 1750));
      final page = await harness.notes.list(page: 2, pageSize: 2);

      expect(harness.refreshTokens, ['refresh-1']);
      expect(harness.noteBearers, ['Bearer access-2']);
      expect(page.items.single.title, 'Field');
      final saved = await harness.store.read();
      expect(saved?.refreshToken, 'refresh-2');
      expect(saved?.email, 'ada@example.com');
      expect(harness.lastNotesQuery['page'], '2');
      expect(harness.lastNotesQuery['pageSize'], '2');
    });

    test(
      'a second refresh presents the rotated token, not the spent one',
      () async {
        final harness = _Harness(
          onRefresh: (token) {
            if (token == 'refresh-1') {
              return _tokens(
                access: 'access-2',
                refresh: 'refresh-2',
                expiresIn: 30,
              );
            }
            return _tokens(access: 'access-3', refresh: 'refresh-3');
          },
        );
        addTearDown(harness.client.close);

        await harness.signIn();
        harness.clock.advance(const Duration(seconds: 1800));
        await harness.notes.list();
        await harness.notes.list();

        expect(harness.refreshTokens, ['refresh-1', 'refresh-2']);
        expect(harness.noteBearers, ['Bearer access-2', 'Bearer access-3']);
      },
    );

    test('concurrent callers share one refresh', () async {
      final gate = Completer<void>();
      final harness = _Harness(
        onRefresh: (token) async {
          await gate.future;
          expect(token, 'refresh-1');
          return _tokens(access: 'access-2', refresh: 'refresh-2');
        },
      );
      addTearDown(harness.client.close);

      await harness.signIn();
      harness.clock.advance(const Duration(seconds: 1750));
      final first = harness.notes.list();
      final second = harness.notes.list();

      await _until(() => harness.refreshTokens.length == 1);
      await Future<void>.delayed(Duration.zero);
      expect(harness.refreshTokens, ['refresh-1']);

      gate.complete();
      final pages = await Future.wait([first, second]);

      expect(harness.refreshTokens, ['refresh-1']);
      expect(harness.noteBearers, ['Bearer access-2', 'Bearer access-2']);
      expect(pages.first.items.single.id, 9);
      expect((await harness.store.read())?.refreshToken, 'refresh-2');
    });

    test('retries a 401 once after a single refresh', () async {
      final harness = _Harness(
        onNotes: (call, bearer) {
          if (call == 1) {
            expect(bearer, 'Bearer access-1');
            return _unauthorized();
          }
          return _notesPage();
        },
        onRefresh: (token) {
          expect(token, 'refresh-1');
          return _tokens(access: 'access-2', refresh: 'refresh-2');
        },
      );
      addTearDown(harness.client.close);

      await harness.signIn();
      final page = await harness.notes.list();

      expect(harness.refreshTokens, ['refresh-1']);
      expect(harness.noteBearers, ['Bearer access-1', 'Bearer access-2']);
      expect(page.totalItems, 1);
    });

    test('does not refresh again when the retried call is still 401', () async {
      final harness = _Harness(onNotes: (call, bearer) => _unauthorized());
      addTearDown(harness.client.close);

      await harness.signIn();

      await expectLater(
        harness.notes.list(),
        throwsA(isA<AnythinkUnauthorizedException>()),
      );
      expect(harness.refreshTokens, ['refresh-1']);
      expect(harness.noteBearers, hasLength(2));
      expect(await harness.store.read(), isNotNull);
    });

    test('a rejected refresh clears the session and is not retried', () async {
      final harness = _Harness(
        onNotes: (call, bearer) => _unauthorized(),
        onRefresh: (token) => http.Response('Invalid refresh token', 401),
      );
      addTearDown(harness.client.close);

      await harness.signIn();

      await expectLater(
        harness.notes.list(),
        throwsA(
          isA<AnythinkUnauthorizedException>().having(
            (error) => error.message,
            'message',
            'Invalid refresh token',
          ),
        ),
      );
      expect(harness.refreshTokens, ['refresh-1']);
      expect(harness.noteBearers, ['Bearer access-1']);
      expect(await harness.store.read(), isNull);
    });

    test('concurrent 401s share the refresh', () async {
      final release = Completer<void>();
      var notesEntered = 0;
      final harness = _Harness(
        onNotes: (call, bearer) async {
          notesEntered++;
          await release.future;
          if (bearer == 'Bearer access-1') {
            return _unauthorized();
          }
          return _notesPage();
        },
      );
      addTearDown(harness.client.close);

      await harness.signIn();
      final first = harness.notes.list();
      final second = harness.notes.list();
      await _until(() => notesEntered == 2);
      release.complete();
      await Future.wait([first, second]);

      expect(harness.refreshTokens, ['refresh-1']);
      expect(
        harness.noteBearers.where((bearer) => bearer == 'Bearer access-2'),
        hasLength(2),
      );
    });
  });

  group('auth and records', () {
    test('register surfaces the plain-text rejection', () async {
      final harness = _Harness(
        onRegister: () =>
            http.Response('Organisation does not allow registrations', 400),
      );
      addTearDown(harness.client.close);

      await expectLater(
        harness.client.auth.register(
          firstName: 'Probe',
          lastName: 'Sample',
          email: 'anythink-flutter-probe@example.com',
          password: 'Probe!pass1',
        ),
        throwsA(
          isA<AnythinkValidationException>().having(
            (error) => error.message,
            'message',
            'Organisation does not allow registrations',
          ),
        ),
      );
    });

    test('sign-in maps a JSON-string 401 without keeping a session', () async {
      final harness = _Harness(
        onToken: () => http.Response(
          '"Invalid email or password"',
          401,
          headers: {'content-type': 'application/json'},
        ),
      );
      addTearDown(harness.client.close);

      await expectLater(
        harness.signIn(),
        throwsA(
          isA<AnythinkUnauthorizedException>().having(
            (error) => error.message,
            'message',
            'Invalid email or password',
          ),
        ),
      );
      expect(await harness.store.read(), isNull);
    });

    test('create posts title and body and parses the record', () async {
      Map<String, dynamic>? sent;
      final harness = _Harness(
        onCreate: (body) {
          sent = jsonDecode(body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'locked': false,
              'id': 9,
              'created_at': '2026-10-04T13:42:54.807588Z',
              'updated_at': '2026-10-04T13:42:54.807588Z',
              'title': 'Field',
              'body': 'A note',
              '__name': 'Field',
            }),
            201,
          );
        },
      );
      addTearDown(harness.client.close);

      await harness.signIn();
      final note = await harness.notes.create(
        const Note(title: 'Field', body: 'A note').toJson(),
      );

      expect(sent, {'title': 'Field', 'body': 'A note'});
      expect(note.id, 9);
      expect(note.name, 'Field');
    });

    test('sign-out posts the refresh token and clears the store', () async {
      String? revoked;
      final harness = _Harness(
        onLogout: (token) {
          revoked = token;
          return http.Response('', 200);
        },
      );
      addTearDown(harness.client.close);

      await harness.signIn();
      await harness.client.auth.signOut();

      expect(revoked, 'refresh-1');
      expect(await harness.store.read(), isNull);
    });
  });
}

class _Clock {
  _Clock(this.now);

  DateTime now;

  void advance(Duration by) {
    now = now.add(by);
  }
}

class _Harness {
  _Harness({
    this.onRefresh,
    this.onNotes,
    this.onRegister,
    this.onToken,
    this.onCreate,
    this.onLogout,
  }) {
    client = AnythinkClient(
      baseUrl: 'https://example.test/',
      projectId: '19515783',
      tokenStore: store,
      clock: () => clock.now,
      httpClient: MockClient(_handle),
    );
    notes = client.entity('notes', fromJson: Note.fromJson);
  }

  final clock = _Clock(DateTime.utc(2026, 11, 1, 9));
  final store = MemoryTokenStore();
  final refreshTokens = <String>[];
  final noteBearers = <String?>[];
  var lastNotesQuery = const <String, String>{};
  var _noteCalls = 0;

  final FutureOr<http.Response> Function(String token)? onRefresh;
  final FutureOr<http.Response> Function(int call, String? bearer)? onNotes;
  final http.Response Function()? onRegister;
  final http.Response Function()? onToken;
  final http.Response Function(String body)? onCreate;
  final http.Response Function(String token)? onLogout;

  late final AnythinkClient client;
  late final EntityRepository<Note> notes;

  Future<AnythinkUser> signIn() {
    return client.auth.signIn(
      email: 'ada@example.com',
      password: 'Sup3r-secret!',
    );
  }

  Future<http.Response> _handle(http.Request request) async {
    final path = request.url.path;
    if (path.endsWith('/auth/v1/token')) {
      return onToken?.call() ?? _tokens();
    }
    if (path.endsWith('/users/me')) {
      return _user();
    }
    if (path.endsWith('/auth/v1/refresh')) {
      final token = _field(request, 'token');
      refreshTokens.add(token);
      final custom = onRefresh?.call(token);
      return custom == null
          ? _tokens(access: 'access-2', refresh: 'refresh-2')
          : await custom;
    }
    if (path.endsWith('/auth/v1/logout')) {
      final token = _field(request, 'token');
      return onLogout?.call(token) ?? http.Response('', 200);
    }
    if (path.endsWith('/auth/v1/register')) {
      return onRegister?.call() ??
          http.Response('Registration successful', 200);
    }
    if (path.endsWith('/entities/notes/items') && request.method == 'POST') {
      return onCreate?.call(request.body) ?? http.Response('{}', 201);
    }
    if (path.endsWith('/entities/notes/items')) {
      _noteCalls++;
      lastNotesQuery = request.url.queryParameters;
      noteBearers.add(request.headers['authorization']);
      final custom = onNotes?.call(
        _noteCalls,
        request.headers['authorization'],
      );
      return custom == null ? _notesPage() : await custom;
    }
    return http.Response('unhandled ${request.method} $path', 404);
  }
}

String _field(http.Request request, String name) {
  final decoded = jsonDecode(request.body);
  if (decoded is! Map) {
    throw StateError('expected a JSON object');
  }
  final value = decoded[name];
  if (value is! String) {
    throw StateError('expected $name');
  }
  return value;
}

http.Response _tokens({
  String access = 'access-1',
  String refresh = 'refresh-1',
  int expiresIn = 1800,
}) {
  return http.Response(
    jsonEncode({
      'access_token': access,
      'refresh_token': refresh,
      'expires_in': expiresIn,
    }),
    200,
    headers: {'content-type': 'application/json'},
  );
}

http.Response _user() {
  return http.Response(
    jsonEncode({
      'id': 42,
      'first_name': 'Ada',
      'last_name': 'Lovelace',
      'email': 'ada@example.com',
      'role_name': 'Standard User',
    }),
    200,
  );
}

http.Response _notesPage() {
  return http.Response(
    jsonEncode({
      'items': [
        {
          'id': 9,
          'title': 'Field',
          'body': 'A note',
          'locked': false,
          '__name': 'Field',
        },
      ],
      'page': 1,
      'page_size': 20,
      'total_items': 1,
      'total_pages': 1,
      'has_next_page': false,
      'has_previous_page': false,
      'retrieval_time': 4,
    }),
    200,
  );
}

http.Response _unauthorized() {
  return http.Response(
    jsonEncode({
      'type': 'https://tools.ietf.org/html/rfc9110#section-15.5.2',
      'title': 'Unauthorized',
      'status': 401,
      'traceId': 'trace-1',
    }),
    401,
    headers: {'content-type': 'application/problem+json'},
  );
}

Future<void> _until(bool Function() ready) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    if (ready()) {
      return;
    }
    await Future<void>.delayed(Duration.zero);
  }
  fail('condition was not met');
}
