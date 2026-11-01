import 'package:anythink_flutter_sample/src/anythink/anythink.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mapAnythinkError', () {
    test('reads a JSON-string 401 from sign-in', () {
      final error = mapAnythinkError(
        statusCode: 401,
        body: '"Invalid email or password"',
      );

      expect(error, isA<AnythinkUnauthorizedException>());
      expect(error.message, 'Invalid email or password');
      expect(error.statusCode, 401);
    });

    test('reads the same sign-in failure as plain text', () {
      final error = mapAnythinkError(
        statusCode: 401,
        body: 'Invalid email or password',
      );

      expect(error, isA<AnythinkUnauthorizedException>());
      expect(error.message, 'Invalid email or password');
    });

    test('reads a plain-text refresh rejection', () {
      final error = mapAnythinkError(
        statusCode: 401,
        body: 'Invalid refresh token',
      );

      expect(error.message, 'Invalid refresh token');
    });

    test('reads a JSON-string refresh rejection', () {
      final error = mapAnythinkError(
        statusCode: 401,
        body: '"Invalid refresh token"',
      );

      expect(error.message, 'Invalid refresh token');
    });

    test('flattens problem-details validation errors', () {
      final error = mapAnythinkError(
        statusCode: 400,
        body: '''
{
  "type": "https://tools.ietf.org/html/rfc9110#section-15.5.1",
  "title": "One or more validation errors occurred.",
  "status": 400,
  "errors": {
    "Password": [
      "Password must be at least 8 characters long",
      "Password must contain at least one uppercase letter"
    ]
  },
  "traceId": "00-ba6fb38ac84a9ea5fcb3e0a8470d7055-d337f766e3aa522a-00"
}
''',
      );

      expect(error, isA<AnythinkValidationException>());
      expect(
        error.message,
        'Password must be at least 8 characters long\n'
        'Password must contain at least one uppercase letter',
      );
      expect(
        error.traceId,
        '00-ba6fb38ac84a9ea5fcb3e0a8470d7055-d337f766e3aa522a-00',
      );
      expect(error.fieldErrors['Password'], hasLength(2));
    });

    test('reads an unauthenticated record call', () {
      final error = mapAnythinkError(
        statusCode: 401,
        body:
            '{"type":"https://tools.ietf.org/html/rfc9110#section-15.5.2",'
            '"title":"Unauthorized","status":401,'
            '"traceId":"00-0124c764f8c868fd2c5d2321ef618f7f-07b7527dad729d3b-00"}',
      );

      expect(error, isA<AnythinkUnauthorizedException>());
      expect(error.message, 'Unauthorized');
      expect(
        error.traceId,
        '00-0124c764f8c868fd2c5d2321ef618f7f-07b7527dad729d3b-00',
      );
    });

    test('reads the registrations-disabled body in both shapes', () {
      final plain = mapAnythinkError(
        statusCode: 400,
        body: 'Organisation does not allow registrations',
      );
      final encoded = mapAnythinkError(
        statusCode: 400,
        body: '"Organisation does not allow registrations"',
      );

      expect(plain, isA<AnythinkValidationException>());
      expect(plain.message, 'Organisation does not allow registrations');
      expect(encoded.message, plain.message);
    });

    test('reads an inactive organisation', () {
      final error = mapAnythinkError(
        statusCode: 403,
        body:
            '{"error":"Organisation not active","message":"The requested '
            'organisation is not currently active.","tenant_id":"1"}',
      );

      expect(error, isA<AnythinkForbiddenException>());
      expect(
        error.message,
        'The requested organisation is not currently active.',
      );
    });

    test('reads a missing public entity', () {
      final error = mapAnythinkError(
        statusCode: 404,
        body: "Entity 'notes' not found",
      );

      expect(error, isA<AnythinkNotFoundException>());
      expect(error.message, "Entity 'notes' not found");
    });

    test('uses a fallback for an empty 405', () {
      final error = mapAnythinkError(statusCode: 405, body: '');

      expect(error, isA<AnythinkMethodNotAllowedException>());
      expect(error.message, 'That method is not supported.');
    });

    test('reads a rate-limit body', () {
      final error = mapAnythinkError(
        statusCode: 429,
        body:
            '{"error":"Rate limit exceeded","message":"Too many requests. '
            'Limit: 2000 requests per minute","retry_after":60,'
            '"route_type":"org"}',
      );

      expect(error, isA<AnythinkRateLimitException>());
      expect((error as AnythinkRateLimitException).retryAfter, 60);
      expect(error.message, contains('2000'));
    });

    test('uses a fallback for an empty 403', () {
      final error = mapAnythinkError(statusCode: 403, body: '   ');

      expect(error.message, 'You do not have permission to do that.');
    });
  });

  group('describeTransportFailure', () {
    test('explains the browser message when CORS hides the response', () {
      final message = describeTransportFailure('Failed to fetch');

      expect(message, contains('Access-Control-Allow-Origin'));
      expect(message, contains('iOS, Android and desktop'));
    });

    test('keeps other transport messages', () {
      expect(
        describeTransportFailure('Connection refused'),
        'Connection refused',
      );
    });
  });
}
