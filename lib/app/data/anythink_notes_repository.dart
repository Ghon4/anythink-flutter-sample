import '../../src/anythink/anythink.dart';
import '../domain/notes_repository.dart';

/// [NotesRepository] for the `notes` entity.
class AnythinkNotesRepository implements NotesRepository {
  /// Creates a repository for [client].
  AnythinkNotesRepository(AnythinkClient client)
    : _notes = client.entity('notes', fromJson: Note.fromJson);

  final EntityRepository<Note> _notes;

  @override
  Future<EntityPage<Note>> list({int page = 1, int pageSize = 20}) {
    return _notes.list(
      page: page,
      pageSize: pageSize,
      sortBy: 'id',
      sortDirection: 'desc',
    );
  }

  @override
  Future<Note> create({required String title, required String body}) {
    return _notes.create(Note(title: title, body: body).toJson());
  }
}
