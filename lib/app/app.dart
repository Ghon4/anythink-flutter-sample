import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'auth/auth_cubit.dart';
import 'auth/auth_state.dart';
import 'auth/sign_in_page.dart';
import 'domain/auth_repository.dart';
import 'domain/notes_repository.dart';
import 'notes/notes_cubit.dart';
import 'notes/notes_page.dart';
import 'theme.dart';

/// Root widget. Repositories are constructed in `main`.
class AnythinkSampleApp extends StatelessWidget {
  /// Creates the app.
  const AnythinkSampleApp({
    required this.authRepository,
    required this.notesRepository,
    this.projectLabel = '',
    super.key,
  });

  /// Sign-in implementation.
  final AuthRepository authRepository;

  /// Notes implementation.
  final NotesRepository notesRepository;

  /// Line under the sign-in form, usually the project id and host.
  final String projectLabel;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<NotesRepository>.value(
      value: notesRepository,
      child: BlocProvider(
        create: (_) => AuthCubit(authRepository)..restore(),
        child: MaterialApp(
          title: 'Anythink Notes',
          theme: buildTheme(),
          home: _Gate(projectLabel: projectLabel),
        ),
      ),
    );
  }
}

class _Gate extends StatelessWidget {
  const _Gate({required this.projectLabel});

  final String projectLabel;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        return switch (state) {
          AuthRestoring() => const _Restoring(),
          AuthSignedOut() => SignInPage(projectLabel: projectLabel),
          AuthSignedIn(:final user) => BlocProvider(
            create: (_) => NotesCubit(context.read<NotesRepository>())..load(),
            child: NotesPage(user: user),
          ),
        };
      },
    );
  }
}

class _Restoring extends StatelessWidget {
  const _Restoring();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Checking the saved session'),
          ],
        ),
      ),
    );
  }
}
