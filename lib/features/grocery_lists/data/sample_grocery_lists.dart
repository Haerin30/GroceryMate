import '../domain/grocery_category.dart';
import '../domain/grocery_list.dart';

/// Starter lists for the in-memory store.
///
/// Item data is not part of this milestone, so counts and estimated totals stay
/// at zero. Replace this seed with a repository when local persistence lands.
final List<GroceryList> sampleGroceryLists = <GroceryList>[
  GroceryList(
    id: '1',
    title: 'Weekly groceries',
    category: GroceryCategory.weekly,
    status: GroceryListStatus.active,
    budget: 1500,
    updatedAt: DateTime(2026, 11, 20),
  ),
  GroceryList(
    id: '2',
    title: 'Meal prep ingredients',
    category: GroceryCategory.personal,
    status: GroceryListStatus.active,
    updatedAt: DateTime(2026, 11, 18),
  ),
  GroceryList(
    id: '3',
    title: 'Household restock',
    category: GroceryCategory.monthly,
    status: GroceryListStatus.active,
    budget: 2500,
    updatedAt: DateTime(2026, 11, 15),
  ),
  GroceryList(
    id: '4',
    title: 'Weekend BBQ',
    category: GroceryCategory.party,
    status: GroceryListStatus.completed,
    budget: 3000,
    updatedAt: DateTime(2026, 11, 10),
  ),
  GroceryList(
    id: '5',
    title: "Last month's essentials",
    category: GroceryCategory.other,
    status: GroceryListStatus.archived,
    updatedAt: DateTime(2026, 10, 28),
  ),
];
