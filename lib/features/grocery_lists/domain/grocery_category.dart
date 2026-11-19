import 'package:flutter/foundation.dart';

/// A category that can be attached to a grocery list.
///
/// Keeping an id alongside the display name means this can be mapped to a
/// SQLite table later without changing the widgets that use it.
@immutable
class GroceryCategory {
  const GroceryCategory({
    required this.id,
    required this.name,
    this.isPredefined = false,
  });

  /// Sentinel used when a list intentionally has no category.
  static const String noneId = '__no_category__';

  static const GroceryCategory weekly = GroceryCategory(
    id: 'predefined-weekly',
    name: 'Weekly',
    isPredefined: true,
  );
  static const GroceryCategory monthly = GroceryCategory(
    id: 'predefined-monthly',
    name: 'Monthly',
    isPredefined: true,
  );
  static const GroceryCategory personal = GroceryCategory(
    id: 'predefined-personal',
    name: 'Personal',
    isPredefined: true,
  );
  static const GroceryCategory family = GroceryCategory(
    id: 'predefined-family',
    name: 'Family',
    isPredefined: true,
  );
  static const GroceryCategory party = GroceryCategory(
    id: 'predefined-party',
    name: 'Party',
    isPredefined: true,
  );
  static const GroceryCategory other = GroceryCategory(
    id: 'predefined-other',
    name: 'Other',
    isPredefined: true,
  );

  static const List<GroceryCategory> predefined = <GroceryCategory>[
    weekly,
    monthly,
    personal,
    family,
    party,
    other,
  ];

  /// Stable identifier, safe to persist as a foreign key later.
  final String id;

  /// User-facing name, already trimmed when created through the controller.
  final String name;
  final bool isPredefined;

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
