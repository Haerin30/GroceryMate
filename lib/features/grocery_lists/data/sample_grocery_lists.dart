import '../domain/grocery_list.dart';

/// Temporary preview data so the first screen can be reviewed.
///
/// Replace this with a Drift-backed repository when local persistence lands.
final List<GroceryList> sampleGroceryLists = <GroceryList>[
  GroceryList(
    id: '1',
    title: 'Weekly groceries',
    category: 'Everyday',
    status: GroceryListStatus.active,
    itemCount: 12,
    estimatedTotal: 84.75,
    updatedAt: DateTime(2026, 11, 20),
  ),
  GroceryList(
    id: '2',
    title: 'Meal prep ingredients',
    category: 'Meal prep',
    status: GroceryListStatus.active,
    itemCount: 8,
    estimatedTotal: 52.30,
    updatedAt: DateTime(2026, 11, 18),
  ),
  GroceryList(
    id: '3',
    title: 'Household restock',
    category: 'Household',
    status: GroceryListStatus.active,
    itemCount: 6,
    estimatedTotal: 37.99,
    updatedAt: DateTime(2026, 11, 15),
  ),
  GroceryList(
    id: '4',
    title: 'Weekend BBQ',
    category: 'Occasion',
    status: GroceryListStatus.completed,
    itemCount: 15,
    estimatedTotal: 126.40,
    updatedAt: DateTime(2026, 11, 10),
  ),
  GroceryList(
    id: '5',
    title: "Last month's essentials",
    category: 'Everyday',
    status: GroceryListStatus.archived,
    itemCount: 9,
    estimatedTotal: 61.20,
    updatedAt: DateTime(2026, 10, 28),
  ),
];
