part of '../anythink_client.dart';

/// List and create for one entity.
///
/// Obtain one from [AnythinkClient.entity]. Update and delete are the same
/// shape of call, and are left out of this sample.
class EntityRepository<T> {
  EntityRepository._({
    required this._client,
    required this._entity,
    required this._fromJson,
  });

  final AnythinkClient _client;
  final String _entity;
  final T Function(Map<String, dynamic> json) _fromJson;

  /// The entity name used in the path.
  String get entity => _entity;

  /// Lists one page.
  ///
  /// Query names `pageSize`, `sortBy` and `sortDirection` are camel case.
  /// The JSON page uses snake case.
  Future<EntityPage<T>> list({
    int page = 1,
    int pageSize = 25,
    String? sortBy,
    String sortDirection = 'asc',
  }) async {
    final response = await _client.send(
      method: 'GET',
      path: '/entities/${Uri.encodeComponent(_entity)}/items',
      query: {
        'page': '$page',
        'pageSize': '$pageSize',
        'sortBy': ?sortBy,
        'sortDirection': ?(sortBy == null ? null : sortDirection),
      },
      successStatuses: const {200},
    );
    return EntityPage.fromJson(
      asJsonMap(_decode(response.body, 'List response'), 'List response'),
      _fromJson,
    );
  }

  /// Creates one record and returns the representation from the `201` body.
  Future<T> create(Map<String, dynamic> fields) async {
    final response = await _client.send(
      method: 'POST',
      path: '/entities/${Uri.encodeComponent(_entity)}/items',
      jsonBody: fields,
      successStatuses: const {200, 201},
    );
    return _fromJson(
      asJsonMap(_decode(response.body, 'Create response'), 'Create response'),
    );
  }

  Object? _decode(String body, String what) {
    try {
      return jsonDecode(body);
    } on FormatException {
      throw AnythinkFormatException(message: '$what was not JSON.');
    }
  }
}
