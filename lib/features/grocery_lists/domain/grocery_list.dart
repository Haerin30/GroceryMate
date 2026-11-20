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

  /// Stable value stored in the `status` TEXT column.
  String get storageValue => switch (this) {
    GroceryListStatus.active => 'active',
    GroceryListStatus.completed => 'completed',
    GroceryListStatus.archived => 'archived',
  };
}

/// User-facing action revealed while swiping a list card.
///
/// `complete` and `markCompleted` share the same target status but keep
/// different labels so the gesture remains understandable from every status.
enum GroceryListSwipeAction { complete, archive, reactivate, markCompleted }

extension GroceryListSwipeActionX on GroceryListSwipeAction {
  GroceryListStatus get targetStatus => switch (this) {
    GroceryListSwipeAction.complete => GroceryListStatus.completed,
    GroceryListSwipeAction.archive => GroceryListStatus.archived,
    GroceryListSwipeAction.reactivate => GroceryListStatus.active,
    GroceryListSwipeAction.markCompleted => GroceryListStatus.completed,
  };

  String get label => switch (this) {
    GroceryListSwipeAction.complete => 'Complete',
    GroceryListSwipeAction.archive => 'Archive',
    GroceryListSwipeAction.reactivate => 'Reactivate',
    GroceryListSwipeAction.markCompleted => 'Mark completed',
  };
}

/// Single source of truth for the swipe table used by grocery list cards.
extension GroceryListStatusSwipeX on GroceryListStatus {
  GroceryListSwipeAction swipeAction({required bool toEnd}) => switch ((
    this,
    toEnd,
  )) {
    (GroceryListStatus.active, true) => GroceryListSwipeAction.complete,
    (GroceryListStatus.active, false) => GroceryListSwipeAction.archive,
    (GroceryListStatus.completed, true) => GroceryListSwipeAction.reactivate,
    (GroceryListStatus.completed, false) => GroceryListSwipeAction.archive,
    (GroceryListStatus.archived, true) => GroceryListSwipeAction.reactivate,
    (GroceryListStatus.archived, false) => GroceryListSwipeAction.markCompleted,
  };
}

/// Domain object rendered by the grocery lists screen.
///
/// Database rows are mapped to this shape so widgets never depend on Drift.
/// [itemCount] and [estimatedTotal] stay at zero until grocery items are
/// implemented in a later milestone.
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
