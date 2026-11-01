import '../errors/anythink_exception.dart';
import '../parsing.dart';

/// The signed-in user returned by `GET /users/me`.
///
/// The parser keeps the fields this sample shows and ignores the rest.
/// The live success payload was not exercised: registrations are off on the
/// project this sample targets, so there was no end-user token to call with.
class AnythinkUser {
  /// Creates a user.
  const AnythinkUser({
    required this.email,
    this.id,
    this.firstName,
    this.lastName,
    this.roleName,
  });

  /// Numeric user id, when the payload included one.
  final int? id;

  /// Email address.
  final String email;

  /// Given name.
  final String? firstName;

  /// Family name.
  final String? lastName;

  /// Role name, such as `Standard User`.
  final String? roleName;

  /// A short label for the app bar.
  String get label {
    final name = [
      firstName,
      lastName,
    ].whereType<String>().where((part) => part.isNotEmpty).join(' ');
    if (name.isNotEmpty) {
      return name;
    }
    if (email.isNotEmpty) {
      return email;
    }
    return 'Signed in';
  }

  /// Parses a `GET /users/me` body.
  factory AnythinkUser.fromJson(Map<String, dynamic> json) {
    final email = json['email'];
    if (email is! String || email.isEmpty) {
      throw const AnythinkFormatException(
        message: 'User payload did not include an email.',
      );
    }
    final firstName = json['first_name'];
    final lastName = json['last_name'];
    final roleName = json['role_name'];
    return AnythinkUser(
      id: asInt(json['id']),
      email: email,
      firstName: firstName is String ? firstName : null,
      lastName: lastName is String ? lastName : null,
      roleName: roleName is String ? roleName : null,
    );
  }
}
