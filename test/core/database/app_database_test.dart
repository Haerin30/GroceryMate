import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_scan/core/database/app_database.dart';
import 'package:grocery_scan/features/grocery_lists/domain/grocery_category.dart';
import 'package:grocery_scan/features/grocery_lists/domain/grocery_list.dart';

Future<AppDatabase> openMemoryDatabase() async {
  final AppDatabase database = AppDatabase(NativeDatabase.memory());
  addTearDown(() => database.close());
  // Force the migration/seeding callbacks to run before assertions.
  await database.select(database.categories).get();
  return database;
}

Future<({AppDatabase database, Directory directory, String path})>
openFileDatabase() async {
  final Directory directory = await Directory.systemTemp.createTemp(
    'grocery_mate_db_test_',
  );
  final String path =
      '${directory.path}${Platform.pathSeparator}'
      'grocery_mate_test.sqlite';
  final AppDatabase database = AppDatabase(NativeDatabase(File(path)));
  addTearDown(() async {
    await database.close();
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  });
  await database.select(database.categories).get();
  return (database: database, directory: directory, path: path);
}

void main() {
  group('schema and seeding', () {
    test('creates the three expected tables', () async {
      final AppDatabase database = await openMemoryDatabase();

      final List<String> tableNames =
          (await database
                  .customSelect(
                    "SELECT name FROM sqlite_master WHERE type = 'table' "
                    "AND name NOT LIKE 'sqlite_%'",
                  )
                  .get())
              .map((QueryRow row) => row.read<String>('name'))
              .toList();

      expect(
        tableNames,
        containsAll(<String>[
          'categories',
          'grocery_lists',
          'grocery_list_items',
        ]),
      );
    });

    test('seeds six system categories and five sample lists', () async {
      final AppDatabase database = await openMemoryDatabase();

      final List<CategoryRow> categories = await database
          .select(database.categories)
          .get();
      final List<GroceryListRow> lists = await database
          .select(database.groceryLists)
          .get();

      expect(categories, hasLength(6));
      expect(
        categories.map((CategoryRow row) => row.name),
        containsAll(<String>[
          'Weekly',
          'Monthly',
          'Personal',
          'Family',
          'Party',
          'Other',
        ]),
      );
      expect(categories.every((CategoryRow row) => row.isSystem), isTrue);
      expect(categories.map((CategoryRow row) => row.sortOrder), <int>[
        0,
        1,
        2,
        3,
        4,
        5,
      ]);
      expect(lists, hasLength(5));
      expect(
        lists.map((GroceryListRow row) => row.name),
        containsAll(<String>[
          'Weekly groceries',
          'Meal prep ingredients',
          'Household restock',
          'Weekend BBQ',
          "Last month's essentials",
        ]),
      );
    });

    test(
      'maps seeded budgets to centavos and preserves status/category',
      () async {
        final AppDatabase database = await openMemoryDatabase();

        final GroceryListRow weekly = await (database.select(
          database.groceryLists,
        )..where((table) => table.name.equals('Weekly groceries'))).getSingle();
        final GroceryListRow bbq = await (database.select(
          database.groceryLists,
        )..where((table) => table.name.equals('Weekend BBQ'))).getSingle();
        final GroceryListRow essentials =
            await (database.select(database.groceryLists)..where(
                  (table) => table.name.equals("Last month's essentials"),
                ))
                .getSingle();

        expect(weekly.budget, 150000);
        expect(weekly.categoryId, GroceryCategory.weekly.id);
        expect(weekly.status, GroceryListStatus.active);
        expect(weekly.updatedAt.toUtc(), DateTime.utc(2026, 11, 20));
        expect(bbq.budget, 300000);
        expect(bbq.status, GroceryListStatus.completed);
        expect(essentials.status, GroceryListStatus.archived);
        expect(essentials.budget, isNull);
      },
    );
  });

  group('foreign keys', () {
    test('deleting a category sets grocery list categoryId to null', () async {
      final AppDatabase database = await openMemoryDatabase();

      await (database.delete(
        database.categories,
      )..where((table) => table.id.equals(GroceryCategory.weekly.id))).go();

      final GroceryListRow weekly = await (database.select(
        database.groceryLists,
      )..where((table) => table.name.equals('Weekly groceries'))).getSingle();
      expect(weekly.categoryId, isNull);
    });

    test('deleting a list cascades to its items', () async {
      final AppDatabase database = await openMemoryDatabase();
      final String listId =
          (await database.select(database.groceryLists).get()).first.id;
      final DateTime now = DateTime.utc(2026, 11, 20);

      await database
          .into(database.groceryListItems)
          .insert(
            GroceryListItemsCompanion.insert(
              id: 'item-1',
              groceryListId: listId,
              itemName: 'Milk',
              quantityMilli: 1500,
              unit: const Value('ml'),
              estimatedUnitPrice: const Value(7500),
              createdAt: now,
              updatedAt: now,
            ),
          );
      expect(
        await database.select(database.groceryListItems).get(),
        hasLength(1),
      );

      await (database.delete(
        database.groceryLists,
      )..where((table) => table.id.equals(listId))).go();

      expect(await database.select(database.groceryListItems).get(), isEmpty);
    });
  });

  group('constraints', () {
    test(
      'rejects duplicate category names ignoring case and whitespace',
      () async {
        final AppDatabase database = await openMemoryDatabase();

        await expectLater(
          database
              .into(database.categories)
              .insert(
                CategoriesCompanion.insert(
                  id: 'duplicate-category',
                  name: '  WEEKLY  ',
                  createdAt: DateTime.utc(2026, 11, 20),
                ),
              ),
          throwsA(isA<SqliteException>()),
        );
      },
    );

    test(
      'rejects negative budgets, invalid statuses, and bad item values',
      () async {
        final AppDatabase database = await openMemoryDatabase();
        final DateTime now = DateTime.utc(2026, 11, 20);
        final String listId =
            (await database.select(database.groceryLists).get()).first.id;

        await expectLater(
          database
              .into(database.groceryLists)
              .insert(
                GroceryListsCompanion.insert(
                  id: 'negative-budget',
                  name: 'Invalid budget',
                  budget: const Value(-1),
                  status: GroceryListStatus.active,
                  createdAt: now,
                  updatedAt: now,
                ),
              ),
          throwsA(isA<SqliteException>()),
        );

        await expectLater(
          database.customStatement(
            "INSERT INTO grocery_lists "
            "(id, name, status, created_at, updated_at) VALUES "
            "('invalid-status', 'Invalid status', 'paused', "
            "'2026-11-20T00:00:00.000Z', '2026-11-20T00:00:00.000Z')",
          ),
          throwsA(isA<SqliteException>()),
        );

        await expectLater(
          database
              .into(database.groceryListItems)
              .insert(
                GroceryListItemsCompanion.insert(
                  id: 'zero-quantity',
                  groceryListId: listId,
                  itemName: 'Bread',
                  quantityMilli: 0,
                  createdAt: now,
                  updatedAt: now,
                ),
              ),
          throwsA(isA<SqliteException>()),
        );

        await expectLater(
          database
              .into(database.groceryListItems)
              .insert(
                GroceryListItemsCompanion.insert(
                  id: 'negative-price',
                  groceryListId: listId,
                  itemName: 'Rice',
                  quantityMilli: 1000,
                  estimatedUnitPrice: const Value(-1),
                  createdAt: now,
                  updatedAt: now,
                ),
              ),
          throwsA(isA<SqliteException>()),
        );
      },
    );
  });

  group('reopening', () {
    test('does not duplicate samples or bring back deleted lists', () async {
      final ({AppDatabase database, Directory directory, String path}) opened =
          await openFileDatabase();
      final AppDatabase first = opened.database;

      final String deletedId =
          (await first.select(first.groceryLists).get()).first.id;
      await (first.delete(
        first.groceryLists,
      )..where((table) => table.id.equals(deletedId))).go();
      await first
          .into(first.groceryLists)
          .insert(
            GroceryListsCompanion.insert(
              id: 'user-created',
              name: 'User list',
              status: GroceryListStatus.active,
              createdAt: DateTime.utc(2026, 11, 20),
              updatedAt: DateTime.utc(2026, 11, 20),
            ),
          );
      await first.close();

      final AppDatabase reopened = AppDatabase(
        NativeDatabase(File(opened.path)),
      );
      addTearDown(() => reopened.close());

      final List<GroceryListRow> lists = await reopened
          .select(reopened.groceryLists)
          .get();
      final List<CategoryRow> categories = await reopened
          .select(reopened.categories)
          .get();

      expect(categories, hasLength(6));
      expect(lists, hasLength(5));
      expect(
        lists.map((GroceryListRow row) => row.id),
        isNot(contains(deletedId)),
      );
      expect(
        lists.map((GroceryListRow row) => row.id),
        contains('user-created'),
      );
    });
  });
}
