import 'package:anythink_flutter_sample/app/app.dart';
import 'package:anythink_flutter_sample/app/domain/auth_repository.dart';
import 'package:anythink_flutter_sample/app/domain/notes_repository.dart';
import 'package:anythink_flutter_sample/src/anythink/anythink.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('signs in and shows the notes returned for that user', (
    tester,
  ) async {
    await tester.pumpWidget(
      AnythinkSampleApp(
        authRepository: _FakeAuth(),
        notesRepository: _FakeNotes(),
        projectLabel: 'Project 19515783',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Project 19515783'), findsOneWidget);

    await tester.tap(find.text('Register'));
    await tester.pump();
    expect(find.text('First name'), findsOneWidget);

    await tester.tap(find.text('Sign in').first);
    await tester.pump();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'ada@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'Sup3r-secret!',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Market'), findsOneWidget);
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('Standard User'), findsOneWidget);
  });

  testWidgets('shows a validation message before calling the API', (
    tester,
  ) async {
    await tester.pumpWidget(
      AnythinkSampleApp(
        authRepository: _FakeAuth(),
        notesRepository: _FakeNotes(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();

    expect(find.text('Enter an email address.'), findsOneWidget);
  });
}

class _FakeAuth implements AuthRepository {
  @override
  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {}

  @override
  Future<AnythinkUser?> restore() async => null;

  @override
  Future<AnythinkUser> signIn({
    required String email,
    required String password,
  }) async {
    return const AnythinkUser(
      id: 42,
      email: 'ada@example.com',
      firstName: 'Ada',
      lastName: 'Lovelace',
      roleName: 'Standard User',
    );
  }

  @override
  Future<void> signOut() async {}
}

class _FakeNotes implements NotesRepository {
  @override
  Future<Note> create({required String title, required String body}) async {
    return Note(title: title, body: body);
  }

  @override
  Future<EntityPage<Note>> list({int page = 1, int pageSize = 20}) async {
    return const EntityPage(
      items: [Note(id: 1, title: 'Market', body: 'Oranges, and a reminder.')],
      page: 1,
      pageSize: 20,
      totalItems: 1,
      totalPages: 1,
      hasNextPage: false,
      hasPreviousPage: false,
    );
  }
}
