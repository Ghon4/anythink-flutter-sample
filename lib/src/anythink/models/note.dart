import '../parsing.dart';

/// A row of the `notes` entity.
///
/// `title` is small text and `body` is large text. [toJson] sends only those
/// two fields, which is what create accepts. System fields are read-only.
class Note {
  /// Creates a note.
  const Note({
    required this.title,
    required this.body,
    this.id,
    this.locked,
    this.name,
    this.createdAt,
    this.updatedAt,
  });

  /// Record id, once the API has assigned one.
  final int? id;

  /// Small-text title.
  final String title;

  /// Large-text body.
  final String body;

  /// Whether the record is locked, when the payload included `locked`.
  final bool? locked;

  /// The entity name field, from `__name`.
  final String? name;

  /// `created_at`, when it was returned.
  final DateTime? createdAt;

  /// `updated_at`, when it was returned.
  final DateTime? updatedAt;

  /// Parses a note record.
  factory Note.fromJson(Map<String, dynamic> json) {
    final title = json['title'];
    final body = json['body'];
    final name = json['__name'];
    final locked = json['locked'];
    return Note(
      id: asInt(json['id']),
      title: title is String ? title : '',
      body: body is String ? body : '',
      locked: locked is bool ? locked : null,
      name: name is String ? name : null,
      createdAt: asDateTime(json['created_at']),
      updatedAt: asDateTime(json['updated_at']),
    );
  }

  /// The create payload: `title` and `body` only.
  Map<String, dynamic> toJson() {
    return {'title': title, 'body': body};
  }
}
