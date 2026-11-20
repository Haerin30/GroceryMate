import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_scan/core/database/app_database.dart';
import 'package:grocery_scan/features/grocery_lists/domain/grocery_list.dart';
import 'package:grocery_scan/features/products/domain/product_category.dart';

Future<AppDatabase> openMemoryDatabase() async {
  final AppDatabase database = AppDatabase(NativeDatabase.memory());
  addTearDown(() => database.close());
  await database.select(database.productCategories).get();
  return database;
}

void main() {
  group('product catalog schema', () {
    test(
      'creates product tables and seeds categories only on first run',
      () async {
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
            'product_categories',
            'products',
            'product_barcodes',
          ]),
        );

        final List<ProductCategoryRow> categories = await database
            .select(database.productCategories)
            .get();
        expect(categories, hasLength(ProductCategory.predefined.length));
        expect(
          categories.map((ProductCategoryRow row) => row.name),
          containsAll(<String>['Produce', 'Pantry', 'Beverages', 'Other']),
        );
        expect(
          categories.every((ProductCategoryRow row) => row.isPredefined),
          isTrue,
        );
      },
    );

    test(
      'allows duplicate names but enforces unit, category, and barcode rules',
      () async {
        final AppDatabase database = await openMemoryDatabase();
        final String categoryId =
            (await database.select(database.productCategories).get()).first.id;
        final DateTime now = DateTime.utc(2026, 11, 20);

        await database
            .into(database.products)
            .insert(
              ProductsCompanion.insert(
                id: 'product-1',
                name: 'Milk',
                categoryId: categoryId,
                unit: 'piece',
                createdAt: now,
                updatedAt: now,
              ),
            );
        await database
            .into(database.products)
            .insert(
              ProductsCompanion.insert(
                id: 'product-2',
                name: 'Milk',
                categoryId: categoryId,
                unit: 'piece',
                createdAt: now,
                updatedAt: now,
              ),
            );

        await expectLater(
          database
              .into(database.productCategories)
              .insert(
                ProductCategoriesCompanion.insert(
                  id: 'duplicate-category',
                  name: 'produce',
                  createdAt: now,
                  updatedAt: now,
                ),
              ),
          throwsA(isA<SqliteException>()),
        );
        await expectLater(
          database
              .into(database.products)
              .insert(
                ProductsCompanion.insert(
                  id: 'bad-unit',
                  name: 'Invalid',
                  categoryId: categoryId,
                  unit: 'furlong',
                  createdAt: now,
                  updatedAt: now,
                ),
              ),
          throwsA(isA<SqliteException>()),
        );
        await expectLater(
          database
              .into(database.products)
              .insert(
                ProductsCompanion.insert(
                  id: 'bad-category',
                  name: 'Invalid',
                  categoryId: 'missing',
                  unit: 'piece',
                  createdAt: now,
                  updatedAt: now,
                ),
              ),
          throwsA(isA<SqliteException>()),
        );

        await database
            .into(database.productBarcodes)
            .insert(
              ProductBarcodesCompanion.insert(
                id: 'barcode-1',
                productId: 'product-1',
                value: '123456',
                createdAt: now,
              ),
            );
        await expectLater(
          database
              .into(database.productBarcodes)
              .insert(
                ProductBarcodesCompanion.insert(
                  id: 'barcode-2',
                  productId: 'product-2',
                  value: '123456',
                  createdAt: now,
                ),
              ),
          throwsA(isA<SqliteException>()),
        );
      },
    );

    test(
      'upgrading schema 1 to 2 preserves grocery data and adds the catalog',
      () async {
        final Directory directory = await Directory.systemTemp.createTemp(
          'grocery_mate_migration_test_',
        );
        final String path =
            '${directory.path}${Platform.pathSeparator}grocery_mate.sqlite';
        addTearDown(() {
          if (directory.existsSync()) {
            directory.deleteSync(recursive: true);
          }
        });

        final AppDatabase first = AppDatabase(NativeDatabase(File(path)));
        await first.select(first.categories).get();
        await first
            .into(first.groceryLists)
            .insert(
              GroceryListsCompanion.insert(
                id: 'grocery-before-upgrade',
                name: 'Existing list',
                status: GroceryListStatus.active,
                createdAt: DateTime.utc(2026, 11, 1),
                updatedAt: DateTime.utc(2026, 11, 1),
              ),
            );
        await first.customStatement('DROP TABLE IF EXISTS product_barcodes;');
        await first.customStatement('DROP TABLE IF EXISTS products;');
        await first.customStatement('DROP TABLE IF EXISTS product_categories;');
        await first.customStatement('PRAGMA user_version = 1;');
        await first.close();

        final AppDatabase reopened = AppDatabase(NativeDatabase(File(path)));
        addTearDown(() => reopened.close());
        await reopened.select(reopened.productCategories).get();

        final List<ProductCategoryRow> categories = await reopened
            .select(reopened.productCategories)
            .get();
        expect(categories, hasLength(ProductCategory.predefined.length));
        expect(
          (await reopened.select(reopened.groceryLists).get()).map(
            (GroceryListRow row) => row.id,
          ),
          contains('grocery-before-upgrade'),
        );
        expect(
          (await reopened.select(reopened.categories).get()),
          hasLength(6),
          reason: 'grocery categories must not be duplicated by the migration',
        );
      },
    );
  });
}
