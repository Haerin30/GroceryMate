import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../features/grocery_lists/data/sample_grocery_lists.dart';
import '../../features/grocery_lists/domain/grocery_category.dart';
import '../../features/grocery_lists/domain/grocery_list.dart';
import '../../features/grocery_lists/domain/grocery_list_input.dart';
import 'grocery_status_converter.dart';
import 'grocery_tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Categories, GroceryLists, GroceryListItems])
class AppDatabase extends _$AppDatabase {
  /// Production constructor. `driftDatabase` resolves the platform-specific
  /// application documents directory on native platforms, uses IndexedDB/OPFS
  /// on the web, and opens SQLite in a background isolate.
  AppDatabase([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: _databaseName,
              web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.js'),
              ),
            ),
      );

  static const String _databaseName = 'grocery_mate';

  /// Fixed timestamp keeps first-run seeding deterministic.
  static final DateTime _seedCreatedAt = DateTime.utc(2026, 10, 1);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator migrator) async {
      await migrator.createAll();
      await _seedFirstRun();
    },
    beforeOpen: (OpeningDetails details) async {
      // SQLite does not enable foreign keys by default.
      await customStatement('PRAGMA foreign_keys = ON;');
    },
  );

  Future<void> _seedFirstRun() async {
    await transaction(() async {
      final List<CategoryRow> existingCategories = await select(categories)
          .get();
      if (existingCategories.isNotEmpty) return;

      await batch((Batch batch) {
        batch.insertAll(categories, <CategoriesCompanion>[
          for (final GroceryCategory category in GroceryCategory.predefined)
            CategoriesCompanion.insert(
              id: category.id,
              name: category.name,
              isSystem: const Value(true),
              sortOrder: Value(category.sortOrder),
              createdAt: _seedCreatedAt,
            ),
        ]);
        batch.insertAll(groceryLists, <GroceryListsCompanion>[
          for (final GroceryList list in sampleGroceryLists)
            GroceryListsCompanion.insert(
              id: list.id,
              name: list.title,
              categoryId: Value(list.category?.id),
              budget: Value(GroceryListInput.budgetToCentavos(list.budget)),
              status: list.status,
              createdAt: list.updatedAt.toUtc(),
              updatedAt: list.updatedAt.toUtc(),
            ),
        ]);
      });
    });
  }
}
