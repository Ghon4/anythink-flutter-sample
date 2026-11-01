import 'package:anythink_flutter_sample/src/anythink/anythink.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Note', () {
    test('parses a record and writes only title and body', () {
      final note = Note.fromJson({
        'locked': false,
        'id': 9,
        'created_at': '2026-10-04T13:42:54.807588Z',
        'updated_at': '2026-10-04T13:42:54.807588Z',
        'title': 'Field',
        'body': 'A note',
        '__name': 'Field',
      });

      expect(note.id, 9);
      expect(note.title, 'Field');
      expect(note.body, 'A note');
      expect(note.locked, isFalse);
      expect(note.name, 'Field');
      expect(note.createdAt, DateTime.utc(2026, 10, 4, 13, 42, 54, 807, 588));
      expect(note.toJson(), {'title': 'Field', 'body': 'A note'});
    });

    test('tolerates a missing title and a numeric id', () {
      final note = Note.fromJson({'id': 3.0, 'body': 'Only a body'});

      expect(note.id, 3);
      expect(note.title, isEmpty);
      expect(note.body, 'Only a body');
      expect(note.locked, isNull);
    });
  });

  group('EntityPage', () {
    test('parses the documented page shape', () {
      final page = EntityPage.fromJson(<String, dynamic>{
        'items': [
          {
            'id': 3,
            'title': 'Later',
            'body': 'b',
            'locked': false,
            '__name': 'Later',
          },
          {'id': 1, 'title': 'Earlier', 'body': 'a', '__name': 'Earlier'},
        ],
        'page': 1,
        'page_size': 2,
        'total_items': 3,
        'total_pages': 2,
        'has_next_page': true,
        'has_previous_page': false,
        'retrieval_time': 6,
      }, Note.fromJson);

      expect(page.items.map((note) => note.id), [3, 1]);
      expect(page.page, 1);
      expect(page.pageSize, 2);
      expect(page.totalItems, 3);
      expect(page.totalPages, 2);
      expect(page.hasNextPage, isTrue);
      expect(page.hasPreviousPage, isFalse);
      expect(page.retrievalTime, 6);
    });
  });

  group('AnythinkSession', () {
    test('round-trips storage json and keeps the email', () {
      final now = DateTime.utc(2026, 11, 1, 9);
      final session = AnythinkSession.fromTokenResponse(
        json: {
          'access_token': 'access-1',
          'refresh_token': 'refresh-1',
          'expires_in': 1800,
        },
        now: now,
        email: 'ada@example.com',
      );

      final restored = AnythinkSession.fromJson(session.toJson());

      expect(restored.accessToken, 'access-1');
      expect(restored.refreshToken, 'refresh-1');
      expect(restored.email, 'ada@example.com');
      expect(
        restored.accessTokenExpiresAt,
        now.add(const Duration(seconds: 1800)),
      );
      expect(session.expiresWithin(const Duration(seconds: 60), now), isFalse);
      expect(
        session.expiresWithin(
          const Duration(seconds: 60),
          now.add(const Duration(seconds: 1750)),
        ),
        isTrue,
      );
    });
  });

  group('AnythinkUser', () {
    test('parses the documented profile and ignores extra fields', () {
      final user = AnythinkUser.fromJson({
        'id': 42,
        'gid': '368f7b33-940e-4aad-a3d8-5a28215935bd',
        'first_name': 'Alice',
        'last_name': 'Smith',
        'email': 'alice@example.com',
        'role_name': 'Standard User',
        'permissions': [
          {'name': 'notes:read', 'is_active': true},
        ],
      });

      expect(user.id, 42);
      expect(user.label, 'Alice Smith');
      expect(user.roleName, 'Standard User');
    });
  });
}
