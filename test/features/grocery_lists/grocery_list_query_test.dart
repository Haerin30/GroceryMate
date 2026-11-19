import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_scan/features/grocery_lists/domain/grocery_category.dart';
import 'package:grocery_scan/features/grocery_lists/domain/grocery_list.dart';
import 'package:grocery_scan/features/grocery_lists/domain/grocery_list_query.dart';

void main() {
  late List<GroceryList> lists;

  setUp(() {
    lists = <GroceryList>[
      GroceryList(
        id: '1',
        title: 'Zebra weekly',
        category: GroceryCategory.weekly,
        status: GroceryListStatus.active,
        budget: 1500,
        estimatedTotal: 20,
        updatedAt: DateTime(2026, 11, 18),
      ),
      GroceryList(
        id: '2',
        title: 'Alpha personal',
        category: GroceryCategory.personal,
        status: GroceryListStatus.completed,
        estimatedTotal: 40,
        updatedAt: DateTime(2026, 11, 20),
      ),
      GroceryList(
        id: '3',
        title: 'Monthly restock',
        category: GroceryCategory.monthly,
        status: GroceryListStatus.active,
        budget: 3000,
        estimatedTotal: 10,
        updatedAt: DateTime(2026, 11, 10),
      ),
      GroceryList(
        id: '4',
        title: 'Party supplies',
        category: GroceryCategory.party,
        status: GroceryListStatus.completed,
        budget: 2500,
        estimatedTotal: 30,
        updatedAt: DateTime(2026, 11, 12),
      ),
      GroceryList(
        id: '5',
        title: 'Uncategorised ideas',
        status: GroceryListStatus.archived,
        updatedAt: DateTime(2026, 11, 1),
      ),
    ];
  });

  List<String> titles(List<GroceryList> result) =>
      result.map((GroceryList list) => list.title).toList();

  test('status filtering keeps all/active/completed/archived distinct', () {
    expect(queryGroceryLists(lists).length, 5);
    expect(
      titles(queryGroceryLists(lists, status: GroceryListFilter.active)),
      <String>['Zebra weekly', 'Monthly restock'],
    );
    expect(
      titles(queryGroceryLists(lists, status: GroceryListFilter.completed)),
      <String>['Alpha personal', 'Party supplies'],
    );
    expect(
      titles(queryGroceryLists(lists, status: GroceryListFilter.archived)),
      <String>['Uncategorised ideas'],
    );
  });

  test('category filtering supports predefined categories and no category', () {
    expect(
      titles(queryGroceryLists(lists, categoryId: GroceryCategory.weekly.id)),
      <String>['Zebra weekly'],
    );
    expect(
      titles(queryGroceryLists(lists, categoryId: GroceryCategory.noneId)),
      <String>['Uncategorised ideas'],
    );
    expect(
      titles(queryGroceryLists(lists, categoryId: allCategoriesFilter)).length,
      5,
    );
  });

  test('status and category filters work together', () {
    expect(
      titles(
        queryGroceryLists(
          lists,
          status: GroceryListFilter.completed,
          categoryId: GroceryCategory.party.id,
        ),
      ),
      <String>['Party supplies'],
    );
    expect(
      queryGroceryLists(
        lists,
        status: GroceryListFilter.active,
        categoryId: GroceryCategory.party.id,
      ),
      isEmpty,
    );
  });

  test('sorts by recently updated and by name alphabetically', () {
    expect(
      titles(queryGroceryLists(lists, sort: GroceryListSort.recentlyUpdated)),
      <String>[
        'Alpha personal',
        'Zebra weekly',
        'Party supplies',
        'Monthly restock',
        'Uncategorised ideas',
      ],
    );
    expect(
      titles(queryGroceryLists(lists, sort: GroceryListSort.name)),
      <String>[
        'Alpha personal',
        'Monthly restock',
        'Party supplies',
        'Uncategorised ideas',
        'Zebra weekly',
      ],
    );
  });

  test('sorts by budget highest first with unbudgeted lists last', () {
    expect(
      titles(queryGroceryLists(lists, sort: GroceryListSort.budget)),
      <String>[
        'Monthly restock',
        'Party supplies',
        'Zebra weekly',
        'Alpha personal',
        'Uncategorised ideas',
      ],
    );
  });

  test('sorts by estimated total highest first', () {
    expect(
      titles(queryGroceryLists(lists, sort: GroceryListSort.estimatedTotal)),
      <String>[
        'Alpha personal',
        'Party supplies',
        'Zebra weekly',
        'Monthly restock',
        'Uncategorised ideas',
      ],
    );
  });

  test('sorting never mutates the source list', () {
    final List<String> original = titles(lists);

    queryGroceryLists(lists, sort: GroceryListSort.name);
    queryGroceryLists(lists, status: GroceryListFilter.active);

    expect(titles(lists), original);
  });
}
