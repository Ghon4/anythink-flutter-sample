import 'package:equatable/equatable.dart';

import '../../src/anythink/anythink.dart';

/// Where the sample is in the sign-in flow.
sealed class AuthState extends Equatable {
  /// Creates a state.
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// A stored session is being read.
final class AuthRestoring extends AuthState {
  /// Creates the restoring state.
  const AuthRestoring();
}

/// Nobody is signed in.
final class AuthSignedOut extends AuthState {
  /// Creates a signed-out state.
  const AuthSignedOut({this.message, this.notice, this.submitting = false});

  /// Why the last attempt failed, when it did.
  final String? message;

  /// A success note, such as a completed registration.
  final String? notice;

  /// Whether a sign-in or register call is in flight.
  final bool submitting;

  @override
  List<Object?> get props => [message, notice, submitting];
}

/// A user is signed in.
final class AuthSignedIn extends AuthState {
  /// Creates a signed-in state.
  const AuthSignedIn(this.user);

  /// The user the UI should greet.
  final AnythinkUser user;

  @override
  List<Object?> get props => [user.email, user.label, user.roleName];
}
