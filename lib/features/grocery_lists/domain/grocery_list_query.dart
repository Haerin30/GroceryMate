import 'grocery_category.dart';
import 'grocery_list.dart';

/// Status filters shown under the screen title.
enum GroceryListFilter { all, active, completed, archived }

/// Sorting options for the list overview.
enum GroceryListSort { recentlyUpdated, name, budget, estimatedTotal }

extension GroceryListFilterX on GroceryListFilter {
  String get label => switch (this) {
    GroceryListFilter.all => 'All',
    GroceryListFilter.active => 'Active',
    GroceryListFilter.completed => 'Completed',
    GroceryListFilter.archived => 'Archived',
  };
}

extension GroceryListSortX on GroceryListSort {
  String get label => switch (this) {
    GroceryListSort.recentlyUpdated => 'Recently updated',
    GroceryListSort.name => 'Name (A–Z)',
    GroceryListSort.budget => 'Budget (highest first)',
    GroceryListSort.estimatedTotal => 'Estimated total (highest first)',
  };
}

/// Value used by the "All categories" chip.
const String allCategoriesFilter = '__all_categories__';

/// Applies status and category filters together, then sorts the result.
///
/// Pure function so the filtering/sorting rules can be tested without a widget.
/// Lists without a budget sort last for "Budget" instead of pretending to have
/// a zero budget.
List<GroceryList> queryGroceryLists(
  Iterable<GroceryList> lists, {
  GroceryListFilter status = GroceryListFilter.all,
  String categoryId = allCategoriesFilter,
  GroceryListSort sort = GroceryListSort.recentlyUpdated,
}) {
  final List<GroceryList> result = lists.where((GroceryList list) {
    final bool matchesStatus = switch (status) {
      GroceryListFilter.all => true,
      GroceryListFilter.active => list.status == GroceryListStatus.active,
      GroceryListFilter.completed => list.status == GroceryListStatus.completed,
      GroceryListFilter.archived => list.status == GroceryListStatus.archived,
    };

    late final bool matchesCategory;
    if (categoryId == allCategoriesFilter) {
      matchesCategory = true;
    } else if (categoryId == GroceryCategory.noneId) {
      matchesCategory = list.category == null;
    } else {
      matchesCategory = list.category?.id == categoryId;
    }

    return matchesStatus && matchesCategory;
  }).toList();

  switch (sort) {
    case GroceryListSort.recentlyUpdated:
      result.sort((GroceryList a, GroceryList b) {
        final int byDate = b.updatedAt.compareTo(a.updatedAt);
        return byDate != 0 ? byDate : _byTitle(a, b);
      });
    case GroceryListSort.name:
      result.sort(_byTitle);
    case GroceryListSort.budget:
      result.sort((GroceryList a, GroceryList b) {
        final int byBudget = _descendingNullable(a.budget, b.budget);
        return byBudget != 0 ? byBudget : _byTitle(a, b);
      });
    case GroceryListSort.estimatedTotal:
      result.sort((GroceryList a, GroceryList b) {
        final int byTotal = b.estimatedTotal.compareTo(a.estimatedTotal);
        return byTotal != 0 ? byTotal : _byTitle(a, b);
      });
  }

  return result;
}

int _byTitle(GroceryList a, GroceryList b) =>
    a.title.toLowerCase().compareTo(b.title.toLowerCase());

/// Higher values first; `null` always goes last.
int _descendingNullable(double? a, double? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return b.compareTo(a);
}
