import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../src/anythink/anythink.dart';
import '../auth/auth_cubit.dart';
import 'notes_cubit.dart';
import 'notes_state.dart';

/// Notes list, with the composer beside it on a wide window.
class NotesPage extends StatelessWidget {
  /// Creates the notes page for [user].
  const NotesPage({required this.user, super.key});

  /// Signed-in user shown in the header.
  final AnythinkUser user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => _confirmSignOut(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 840;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 3, child: _NotesList(user: user)),
                        const VerticalDivider(width: 1),
                        Expanded(
                          flex: 2,
                          child: _NoteEditor(user: user, popOnSave: false),
                        ),
                      ],
                    )
                  : _NotesList(user: user, showComposerButton: true),
            ),
          );
        },
      ),
    );
  }
}

class _NotesList extends StatelessWidget {
  const _NotesList({required this.user, this.showComposerButton = false});

  final AnythinkUser user;
  final bool showComposerButton;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotesCubit, NotesState>(
      builder: (context, state) {
        return switch (state) {
          NotesLoading() => const Center(child: CircularProgressIndicator()),
          NotesFailure(:final message) => _Failure(message: message),
          NotesReady() => _ReadyList(
            state: state,
            user: user,
            showComposerButton: showComposerButton,
          ),
        };
      },
    );
  }
}

class _ReadyList extends StatelessWidget {
  const _ReadyList({
    required this.state,
    required this.user,
    required this.showComposerButton,
  });

  final NotesReady state;
  final AnythinkUser user;
  final bool showComposerButton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<NotesCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.label, style: theme.textTheme.titleMedium),
              if (user.roleName != null)
                Text(user.roleName!, style: theme.textTheme.bodyMedium),
              Text(
                state.totalItems == 1 ? '1 note' : '${state.totalItems} notes',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        if (state.actionError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              state.actionError!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: cubit.refresh,
            child: state.notes.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [SizedBox(height: 72), _EmptyNotes()],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: state.notes.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      if (index == state.notes.length) {
                        return _ListFooter(state: state);
                      }
                      return _NoteCard(note: state.notes[index]);
                    },
                  ),
          ),
        ),
        if (showComposerButton)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: FilledButton.icon(
                onPressed: () {
                  final notes = context.read<NotesCubit>();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BlocProvider.value(
                        value: notes,
                        child: _ComposerPage(user: user),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('New note'),
              ),
            ),
          ),
      ],
    );
  }
}

class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.state});

  final NotesReady state;

  @override
  Widget build(BuildContext context) {
    if (!state.hasNextPage && !state.loadingMore) {
      return const SizedBox(height: 8);
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: OutlinedButton(
        onPressed: state.loadingMore
            ? null
            : () => context.read<NotesCubit>().loadMore(),
        child: state.loadingMore
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Load more'),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stamp = note.updatedAt ?? note.createdAt;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              note.title.isEmpty ? 'Untitled' : note.title,
              style: theme.textTheme.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (note.body.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                note.body,
                style: theme.textTheme.bodyMedium,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (stamp != null) ...[
              const SizedBox(height: 8),
              Text(_formatStamp(stamp), style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyNotes extends StatelessWidget {
  const _EmptyNotes();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          Icon(
            Icons.sticky_note_2_outlined,
            size: 40,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text('No notes yet', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Create one and it is stored on Anythink. Row-level security is '
            'on, so this list is only the records your user can read.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.read<NotesCubit>().load(),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComposerPage extends StatelessWidget {
  const _ComposerPage({required this.user});

  final AnythinkUser user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New note')),
      body: _NoteEditor(user: user, popOnSave: true),
    );
  }
}

class _NoteEditor extends StatefulWidget {
  const _NoteEditor({required this.user, required this.popOnSave});

  final AnythinkUser user;
  final bool popOnSave;

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<NotesCubit, NotesState>(
      builder: (context, state) {
        final saving = state is NotesReady && state.saving;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Text(widget.user.label, style: theme.textTheme.titleMedium),
            if (widget.user.roleName != null) ...[
              const SizedBox(height: 2),
              Text(widget.user.roleName!, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 4),
            Text(widget.user.email, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 20),
            Text('New note', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _title,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Title'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Give the note a title.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _body,
                    minLines: 6,
                    maxLines: 12,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Body',
                      alignLabelWithHint: true,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: saving ? null : _save,
                    child: saving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save note'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _error = null);
    try {
      await context.read<NotesCubit>().create(
        title: _title.text.trim(),
        body: _body.text.trim(),
      );
      if (!mounted) {
        return;
      }
      _title.clear();
      _body.clear();
      if (widget.popOnSave) {
        Navigator.of(context).pop();
      }
    } on AnythinkException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = describeAnythinkError(error));
    }
  }
}

Future<void> _confirmSignOut(BuildContext context) async {
  final cubit = context.read<AuthCubit>();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'This revokes the refresh token on Anythink and removes it from '
          'this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      );
    },
  );
  if (confirmed ?? false) {
    await cubit.signOut();
  }
}

String _formatStamp(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
