import '../../src/anythink/anythink.dart';

/// Notes the signed-in user can read and create.
abstract interface class NotesRepository {
  /// Lists one page, newest id first.
  Future<EntityPage<Note>> list({int page = 1, int pageSize = 20});

  /// Creates a note and returns the stored record.
  Future<Note> create({required String title, required String body});
}
