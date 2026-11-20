import '../domain/grocery_category.dart';
import '../domain/grocery_list.dart';

/// Template for the five starter lists inserted on first database creation.
///
/// These objects are only used by the seeder (and by in-memory unit tests).
/// Changing them does not affect an existing installation.
final List<GroceryList> sampleGroceryLists = <GroceryList>[
  GroceryList(
    id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
    title: 'Weekly groceries',
    category: GroceryCategory.weekly,
    status: GroceryListStatus.active,
    budget: 1500,
    updatedAt: DateTime.utc(2026, 11, 20),
  ),
  GroceryList(
    id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2',
    title: 'Meal prep ingredients',
    category: GroceryCategory.personal,
    status: GroceryListStatus.active,
    updatedAt: DateTime.utc(2026, 11, 18),
  ),
  GroceryList(
    id: 'cccccccc-cccc-4ccc-8ccc-ccccccccccc3',
    title: 'Household restock',
    category: GroceryCategory.monthly,
    status: GroceryListStatus.active,
    budget: 2500,
    updatedAt: DateTime.utc(2026, 11, 15),
  ),
  GroceryList(
    id: 'dddddddd-dddd-4ddd-8ddd-ddddddddddd4',
    title: 'Weekend BBQ',
    category: GroceryCategory.party,
    status: GroceryListStatus.completed,
    budget: 3000,
    updatedAt: DateTime.utc(2026, 11, 10),
  ),
  GroceryList(
    id: 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee5',
    title: "Last month's essentials",
    category: GroceryCategory.other,
    status: GroceryListStatus.archived,
    updatedAt: DateTime.utc(2026, 10, 28),
  ),
];
