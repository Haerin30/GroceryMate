/// Lifecycle of a grocery list.
///
/// Archived lists are kept for reference but stay out of the active flow.
enum GroceryListStatus { active, completed, archived }

extension GroceryListStatusX on GroceryListStatus {
  String get label => switch (this) {
        GroceryListStatus.active => 'Active',
        GroceryListStatus.completed => 'Completed',
        GroceryListStatus.archived => 'Archived',
      };
}

/// A lightweight domain object for the first screen.
///
/// It will be mapped from a Drift table later, so the UI does not depend on
/// database code.
class GroceryList {
  const GroceryList({
    required this.id,
    required this.title,
    required this.category,
    required this.status,
    required this.itemCount,
    required this.estimatedTotal,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String category;
  final GroceryListStatus status;
  final int itemCount;
  final double estimatedTotal;
  final DateTime updatedAt;
}
