import '../errors/anythink_exception.dart';
import '../parsing.dart';

/// One page of entity records.
class EntityPage<T> {
  /// Creates a page.
  const EntityPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalItems,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPreviousPage,
    this.retrievalTime,
  });

  /// Records on this page.
  final List<T> items;

  /// Page number, starting at 1.
  final int page;

  /// Requested page size.
  final int pageSize;

  /// Records matching the query, across pages.
  final int totalItems;

  /// Page count.
  final int totalPages;

  /// Whether another page exists after this one.
  final bool hasNextPage;

  /// Whether a page exists before this one.
  final bool hasPreviousPage;

  /// Server query time in milliseconds, when `retrieval_time` was present.
  final int? retrievalTime;

  /// Parses a list response and maps each item with [fromJson].
  static EntityPage<T> fromJson<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    final rawItems = json['items'];
    if (rawItems is! List) {
      throw const AnythinkFormatException(
        message: 'List response has no items array.',
      );
    }
    final items = <T>[];
    for (final raw in rawItems) {
      if (raw is! Map) {
        throw const AnythinkFormatException(
          message: 'List response contained an item that was not an object.',
        );
      }
      items.add(fromJson(Map<String, dynamic>.from(raw)));
    }
    return EntityPage(
      items: items,
      page: asInt(json['page']) ?? 1,
      pageSize: asInt(json['page_size']) ?? items.length,
      totalItems: asInt(json['total_items']) ?? items.length,
      totalPages: asInt(json['total_pages']) ?? 1,
      hasNextPage: json['has_next_page'] == true,
      hasPreviousPage: json['has_previous_page'] == true,
      retrievalTime: asInt(json['retrieval_time']),
    );
  }
}
