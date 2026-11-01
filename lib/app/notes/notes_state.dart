import 'package:equatable/equatable.dart';

import '../../src/anythink/anythink.dart';

/// Notes list state.
sealed class NotesState extends Equatable {
  /// Creates a state.
  const NotesState();

  @override
  List<Object?> get props => [];
}

/// The first page is loading and there is nothing to show yet.
final class NotesLoading extends NotesState {
  /// Creates the loading state.
  const NotesLoading();
}

/// The first page failed.
final class NotesFailure extends NotesState {
  /// Creates a failure state.
  const NotesFailure(this.message);

  /// Text for the error panel.
  final String message;

  @override
  List<Object?> get props => [message];
}

/// A page of notes is on screen.
final class NotesReady extends NotesState {
  /// Creates a ready state.
  const NotesReady({
    required this.notes,
    required this.page,
    required this.totalItems,
    required this.hasNextPage,
    this.refreshing = false,
    this.loadingMore = false,
    this.saving = false,
    this.actionError,
  });

  /// Notes loaded so far, newest first.
  final List<Note> notes;

  /// Last page that was fetched.
  final int page;

  /// Total reported by the API.
  final int totalItems;

  /// Whether [page] is not the last page.
  final bool hasNextPage;

  /// Whether a pull-to-refresh is in flight.
  final bool refreshing;

  /// Whether the next page is in flight.
  final bool loadingMore;

  /// Whether a create call is in flight.
  final bool saving;

  /// An error from refresh, paging or create that should keep the list up.
  final String? actionError;

  /// Returns a copy with the given fields replaced.
  NotesReady copyWith({
    List<Note>? notes,
    int? page,
    int? totalItems,
    bool? hasNextPage,
    bool? refreshing,
    bool? loadingMore,
    bool? saving,
    Object? actionError = _keep,
  }) {
    return NotesReady(
      notes: notes ?? this.notes,
      page: page ?? this.page,
      totalItems: totalItems ?? this.totalItems,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      refreshing: refreshing ?? this.refreshing,
      loadingMore: loadingMore ?? this.loadingMore,
      saving: saving ?? this.saving,
      actionError: identical(actionError, _keep)
          ? this.actionError
          : actionError as String?,
    );
  }

  @override
  List<Object?> get props => [
    notes,
    page,
    totalItems,
    hasNextPage,
    refreshing,
    loadingMore,
    saving,
    actionError,
  ];
}

const _keep = Object();
