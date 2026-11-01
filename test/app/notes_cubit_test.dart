import 'package:anythink_flutter_sample/app/notes/notes_cubit.dart';
import 'package:anythink_flutter_sample/app/notes/notes_state.dart';
import 'package:anythink_flutter_sample/src/anythink/anythink.dart';
import 'package:anythink_flutter_sample/app/domain/notes_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads, appends a page, and puts a new note first', () async {
    final repository = _FakeNotes();
    final cubit = NotesCubit(repository);
    addTearDown(cubit.close);

    await cubit.load();
    final ready = cubit.state as NotesReady;
    expect(ready.notes.map((note) => note.title), ['Later']);
    expect(ready.hasNextPage, isTrue);

    await cubit.loadMore();
    final paged = cubit.state as NotesReady;
    expect(paged.notes.map((note) => note.title), ['Later', 'Earlier']);
    expect(paged.hasNextPage, isFalse);

    await cubit.create(title: 'Newest', body: 'Just written');
    final created = cubit.state as NotesReady;
    expect(created.notes.first.title, 'Newest');
    expect(created.totalItems, 3);
    expect(created.saving, isFalse);
  });

  test('keeps the list when a refresh fails', () async {
    final repository = _FakeNotes();
    final cubit = NotesCubit(repository);
    addTearDown(cubit.close);

    await cubit.load();
    repository.failNext = const AnythinkForbiddenException(
      message: 'You do not have permission to do that.',
    );
    await cubit.refresh();

    final ready = cubit.state as NotesReady;
    expect(ready.notes, isNotEmpty);
    expect(ready.refreshing, isFalse);
    expect(ready.actionError, 'You do not have permission to do that.');
  });
}

class _FakeNotes implements NotesRepository {
  AnythinkException? failNext;

  @override
  Future<Note> create({required String title, required String body}) async {
    return Note(id: 11, title: title, body: body);
  }

  @override
  Future<EntityPage<Note>> list({int page = 1, int pageSize = 20}) async {
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
    if (page == 1) {
      return const EntityPage(
        items: [Note(id: 2, title: 'Later', body: 'second')],
        page: 1,
        pageSize: 20,
        totalItems: 2,
        totalPages: 2,
        hasNextPage: true,
        hasPreviousPage: false,
      );
    }
    return const EntityPage(
      items: [Note(id: 1, title: 'Earlier', body: 'first')],
      page: 2,
      pageSize: 20,
      totalItems: 2,
      totalPages: 2,
      hasNextPage: false,
      hasPreviousPage: true,
    );
  }
}
