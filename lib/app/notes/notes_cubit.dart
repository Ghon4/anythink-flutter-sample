import 'package:flutter_bloc/flutter_bloc.dart';

import '../../src/anythink/anythink.dart';
import '../auth/auth_cubit.dart';
import '../domain/notes_repository.dart';
import 'notes_state.dart';

/// Loads, pages and creates notes.
class NotesCubit extends Cubit<NotesState> {
  /// Creates a cubit that starts in [NotesLoading].
  NotesCubit(this._notes) : super(const NotesLoading());

  final NotesRepository _notes;

  static const _pageSize = 20;

  /// Loads the first page, replacing anything already shown.
  Future<void> load() => _reload(initial: true);

  /// Reloads the first page and keeps the current list until it returns.
  Future<void> refresh() => _reload(initial: false);

  /// Appends the next page when there is one.
  Future<void> loadMore() async {
    final current = state;
    if (current is! NotesReady ||
        !current.hasNextPage ||
        current.loadingMore ||
        current.refreshing) {
      return;
    }
    emit(current.copyWith(loadingMore: true, actionError: null));
    try {
      final page = await _notes.list(
        page: current.page + 1,
        pageSize: _pageSize,
      );
      if (isClosed) {
        return;
      }
      final latest = state;
      if (latest is! NotesReady) {
        return;
      }
      emit(
        latest.copyWith(
          notes: [...latest.notes, ...page.items],
          page: page.page,
          totalItems: page.totalItems,
          hasNextPage: page.hasNextPage,
          loadingMore: false,
        ),
      );
    } on AnythinkException catch (error) {
      _failAction(error);
    }
  }

  /// Creates a note and puts it at the top of the list.
  Future<void> create({required String title, required String body}) async {
    final current = state;
    if (current is NotesReady) {
      emit(current.copyWith(saving: true, actionError: null));
    }
    try {
      final note = await _notes.create(title: title, body: body);
      if (isClosed) {
        return;
      }
      final latest = state;
      if (latest is NotesReady) {
        emit(
          latest.copyWith(
            notes: [note, ...latest.notes],
            totalItems: latest.totalItems + 1,
            saving: false,
          ),
        );
        return;
      }
      emit(
        NotesReady(notes: [note], page: 1, totalItems: 1, hasNextPage: false),
      );
    } on AnythinkException catch (error) {
      _failAction(error);
      rethrow;
    }
  }

  Future<void> _reload({required bool initial}) async {
    final current = state;
    if (!initial && current is NotesReady) {
      emit(current.copyWith(refreshing: true, actionError: null));
    } else {
      emit(const NotesLoading());
    }
    try {
      final page = await _notes.list(page: 1, pageSize: _pageSize);
      if (isClosed) {
        return;
      }
      emit(
        NotesReady(
          notes: page.items,
          page: page.page,
          totalItems: page.totalItems,
          hasNextPage: page.hasNextPage,
        ),
      );
    } on AnythinkException catch (error) {
      if (isClosed) {
        return;
      }
      final latest = state;
      if (!initial && latest is NotesReady) {
        emit(
          latest.copyWith(
            refreshing: false,
            actionError: describeAnythinkError(error),
          ),
        );
        return;
      }
      emit(NotesFailure(describeAnythinkError(error)));
    }
  }

  void _failAction(AnythinkException error) {
    if (isClosed) {
      return;
    }
    final latest = state;
    if (latest is NotesReady) {
      emit(
        latest.copyWith(
          loadingMore: false,
          saving: false,
          refreshing: false,
          actionError: describeAnythinkError(error),
        ),
      );
      return;
    }
    emit(NotesFailure(describeAnythinkError(error)));
  }
}
