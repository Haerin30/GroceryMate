import 'package:flutter/foundation.dart';

/// A category that can be attached to a grocery list.
///
/// The stable id is the primary key of the persisted `categories` row. The six
/// predefined categories use fixed UUIDs so first-run seeding is deterministic.
@immutable
class GroceryCategory {
  const GroceryCategory({
    required this.id,
    required this.name,
    this.isPredefined = false,
    this.sortOrder = 0,
  });

  /// Sentinel used when a list intentionally has no category.
  static const String noneId = '__no_category__';

  static const GroceryCategory weekly = GroceryCategory(
    id: '11111111-1111-4111-8111-111111111111',
    name: 'Weekly',
    isPredefined: true,
    sortOrder: 0,
  );
  static const GroceryCategory monthly = GroceryCategory(
    id: '22222222-2222-4222-8222-222222222222',
    name: 'Monthly',
    isPredefined: true,
    sortOrder: 1,
  );
  static const GroceryCategory personal = GroceryCategory(
    id: '33333333-3333-4333-8333-333333333333',
    name: 'Personal',
    isPredefined: true,
    sortOrder: 2,
  );
  static const GroceryCategory family = GroceryCategory(
    id: '44444444-4444-4444-8444-444444444444',
    name: 'Family',
    isPredefined: true,
    sortOrder: 3,
  );
  static const GroceryCategory party = GroceryCategory(
    id: '55555555-5555-4555-8555-555555555555',
    name: 'Party',
    isPredefined: true,
    sortOrder: 4,
  );
  static const GroceryCategory other = GroceryCategory(
    id: '66666666-6666-4666-8666-666666666666',
    name: 'Other',
    isPredefined: true,
    sortOrder: 5,
  );

  static const List<GroceryCategory> predefined = <GroceryCategory>[
    weekly,
    monthly,
    personal,
    family,
    party,
    other,
  ];

  /// Stable identifier, safe to persist as a foreign key.
  final String id;

  /// User-facing name, already trimmed when created through the controller.
  final String name;

  /// Mirrors the `is_system` database flag.
  final bool isPredefined;

  /// Display order for predefined categories and persisted custom categories.
  final int sortOrder;

  /// Case- and whitespace-insensitive key used to detect duplicates.
  static String normalizeName(String value) => value.trim().toLowerCase();

  /// Returns a trimmed display name, or `null` when [value] is blank.
  static String? cleanName(String value) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is GroceryCategory && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'GroceryCategory($id, $name)';
}
