import 'grocery_category.dart';

/// Lifecycle of a grocery list.
///
/// Archived lists are kept for reference but stay out of the active flow.
/// A completed list is NOT a purchase record; shopping history is a separate
/// future feature.
enum GroceryListStatus { active, completed, archived }

extension GroceryListStatusX on GroceryListStatus {
  String get label => switch (this) {
    GroceryListStatus.active => 'Active',
    GroceryListStatus.completed => 'Completed',
    GroceryListStatus.archived => 'Archived',
  };
}

/// A lightweight domain object for the grocery lists screen.
///
/// It will be mapped from a Drift table later, so the UI does not depend on
/// database code. [itemCount] and [estimatedTotal] stay at zero until grocery
/// items are implemented in a later milestone.
class GroceryList {
  const GroceryList({
    required this.id,
    required this.title,
    this.category,
    this.status = GroceryListStatus.active,
    this.itemCount = 0,
    this.estimatedTotal = 0,
    this.budget,
    required this.updatedAt,
  });

  /// Stable id that never changes when the list is edited.
  final String id;
  final String title;
  final GroceryCategory? category;
  final GroceryListStatus status;
  final int itemCount;
  final double estimatedTotal;

  /// Optional spending limit. `null` means no budget was configured.
  final double? budget;
  final DateTime updatedAt;
}
