import 'package:flutter_bloc/flutter_bloc.dart';

import '../../src/anythink/anythink.dart';
import '../domain/auth_repository.dart';
import 'auth_state.dart';

/// Drives registration, sign-in and sign-out.
class AuthCubit extends Cubit<AuthState> {
  /// Creates a cubit that starts in [AuthRestoring].
  AuthCubit(this._auth) : super(const AuthRestoring());

  final AuthRepository _auth;

  /// Loads a stored session, if there is one.
  Future<void> restore() async {
    emit(const AuthRestoring());
    try {
      final user = await _auth.restore();
      if (isClosed) {
        return;
      }
      emit(user == null ? const AuthSignedOut() : AuthSignedIn(user));
    } catch (error) {
      if (isClosed) {
        return;
      }
      emit(AuthSignedOut(message: _message(error)));
    }
  }

  /// Registers, then leaves the user on the sign-in form.
  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    emit(const AuthSignedOut(submitting: true));
    try {
      await _auth.register(
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
      );
      if (isClosed) {
        return;
      }
      emit(
        const AuthSignedOut(
          notice: 'Account created. Sign in with that email and password.',
        ),
      );
    } catch (error) {
      if (isClosed) {
        return;
      }
      emit(AuthSignedOut(message: _message(error)));
    }
  }

  /// Signs in and moves to the notes list.
  Future<void> signIn({required String email, required String password}) async {
    emit(const AuthSignedOut(submitting: true));
    try {
      final user = await _auth.signIn(email: email, password: password);
      if (isClosed) {
        return;
      }
      emit(AuthSignedIn(user));
    } catch (error) {
      if (isClosed) {
        return;
      }
      emit(AuthSignedOut(message: _message(error)));
    }
  }

  /// Signs out and returns to the form.
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (_) {
      // The repository drops local tokens even when revoke fails.
    }
    if (isClosed) {
      return;
    }
    emit(const AuthSignedOut());
  }
}

String _message(Object error) {
  if (error is AnythinkException) {
    return describeAnythinkError(error);
  }
  return 'Something went wrong. Try again.';
}

/// Turns an API error into the text the form shows.
String describeAnythinkError(AnythinkException error) {
  final trace = error.traceId;
  if (trace == null || trace.isEmpty) {
    return error.message;
  }
  return '${error.message}\nTrace $trace';
}
