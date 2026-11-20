import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/id_generator.dart';
import '../domain/grocery_category.dart';
import '../domain/grocery_list.dart';
import '../domain/grocery_list_input.dart';
import 'grocery_list_repository.dart';

/// Drift-backed implementation of [GroceryListRepository].
class DriftGroceryListRepository implements GroceryListRepository {
  DriftGroceryListRepository(this._database, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _database;
  final DateTime Function() _now;

  @override
  Stream<List<GroceryList>> watchLists() => _listsSelectable().watch();

  @override
  Stream<List<GroceryCategory>> watchCategories() =>
      _categoriesSelectable().watch();

  @override
  Future<List<GroceryList>> getAllLists() => _listsSelectable().get();

  @override
  Future<GroceryList?> getList(String id) async {
    final List<GroceryList> matches = await _listsSelectable(id: id).get();
    return matches.isEmpty ? null : matches.first;
  }

  @override
  Future<GroceryList> createList({
    required String title,
    GroceryCategory? category,
    double? budget,
    String? newCategoryName,
  }) {
    final String cleanTitle = GroceryListInput.cleanTitle(title);
    final int? cents = GroceryListInput.budgetToCentavos(budget);

    return _database.transaction(() async {
      final CategoryRow? categoryRow = await _resolveCategoryRow(
        category,
        newCategoryName,
      );
      final DateTime now = _now().toUtc();
      final String id = IdGenerator.uuidV4();

      await _database
          .into(_database.groceryLists)
          .insert(
            GroceryListsCompanion.insert(
              id: id,
              name: cleanTitle,
              categoryId: Value(categoryRow?.id),
              budget: Value(cents),
              status: GroceryListStatus.active,
              createdAt: now,
              updatedAt: now,
            ),
          );

      return GroceryList(
        id: id,
        title: cleanTitle,
        category: categoryRow == null ? null : _mapCategory(categoryRow),
        status: GroceryListStatus.active,
        budget: GroceryListInput.budgetFromCentavos(cents),
        updatedAt: now.toLocal(),
      );
    });
  }

  @override
  Future<GroceryList?> updateList(
    String id, {
    required String title,
    GroceryCategory? category,
    required double? budget,
    String? newCategoryName,
  }) {
    final String cleanTitle = GroceryListInput.cleanTitle(title);
    final int? cents = GroceryListInput.budgetToCentavos(budget);

    return _database.transaction(() async {
      final GroceryListRow? existing = await _listRow(id);
      if (existing == null) return null;

      final CategoryRow? categoryRow = await _resolveCategoryRow(
        category,
        newCategoryName,
      );
      final DateTime now = _now().toUtc();

      await (_database.update(
        _database.groceryLists,
      )..where((table) => table.id.equals(id))).write(
        GroceryListsCompanion(
          name: Value(cleanTitle),
          categoryId: Value(categoryRow?.id),
          budget: Value(cents),
          updatedAt: Value(now),
        ),
      );

      return GroceryList(
        id: id,
        title: cleanTitle,
        category: categoryRow == null ? null : _mapCategory(categoryRow),
        status: existing.status,
        budget: GroceryListInput.budgetFromCentavos(cents),
        updatedAt: now.toLocal(),
      );
    });
  }

  @override
  Future<bool> deleteList(String id) async {
    final int deleted = await (_database.delete(
      _database.groceryLists,
    )..where((table) => table.id.equals(id))).go();
    return deleted > 0;
  }

  @override
  Future<GroceryList?> setStatus(String id, GroceryListStatus status) async {
    final GroceryListRow? existing = await _listRow(id);
    if (existing == null) return null;
    if (existing.status == status) return getList(id);

    final DateTime now = _now().toUtc();
    await (_database.update(
      _database.groceryLists,
    )..where((table) => table.id.equals(id))).write(
      GroceryListsCompanion(status: Value(status), updatedAt: Value(now)),
    );

    return getList(id);
  }

  @override
  Future<GroceryCategory> addCustomCategory(String name) {
    final String? cleanName = GroceryCategory.cleanName(name);
    if (cleanName == null) {
      throw ArgumentError.value(name, 'name', 'Category name is required');
    }
    return _insertOrFindCustomCategory(cleanName).then(_mapCategory);
  }

  Selectable<GroceryList> _listsSelectable({String? id}) {
    final select = _database.select(_database.groceryLists);
    if (id != null) {
      select.where((table) => table.id.equals(id));
    }

    final query = select.join([
      leftOuterJoin(
        _database.categories,
        _database.categories.id.equalsExp(_database.groceryLists.categoryId),
      ),
    ]);
    return query.map((TypedResult row) {
      final GroceryListRow list = row.readTable(_database.groceryLists);
      final CategoryRow? category = row.readTableOrNull(_database.categories);
      return _mapList(list, category == null ? null : _mapCategory(category));
    });
  }

  Selectable<GroceryCategory> _categoriesSelectable() {
    final query = _database.select(_database.categories)
      ..orderBy([
        (table) => OrderingTerm.asc(table.sortOrder),
        (table) => OrderingTerm.asc(table.name),
      ]);
    return query.map(_mapCategory);
  }

  Future<GroceryListRow?> _listRow(String id) async {
    final List<GroceryListRow> rows = await (_database.select(
      _database.groceryLists,
    )..where((table) => table.id.equals(id))).get();
    return rows.isEmpty ? null : rows.first;
  }

  Future<CategoryRow?> _categoryByName(String name) async {
    final String key = GroceryCategory.normalizeName(name);
    final List<CategoryRow> rows = await _database
        .select(_database.categories)
        .get();
    for (final CategoryRow row in rows) {
      if (GroceryCategory.normalizeName(row.name) == key) return row;
    }
    return null;
  }

  Future<CategoryRow?> _resolveCategoryRow(
    GroceryCategory? category,
    String? newCategoryName,
  ) async {
    final String? cleanName = GroceryCategory.cleanName(newCategoryName ?? '');
    if (cleanName != null) {
      final CategoryRow? existing = await _categoryByName(cleanName);
      return existing ?? _insertOrFindCustomCategory(cleanName);
    }
    if (category == null) return null;

    final List<CategoryRow> rows = await (_database.select(
      _database.categories,
    )..where((table) => table.id.equals(category.id))).get();
    if (rows.isEmpty) {
      throw ArgumentError.value(
        category.id,
        'category',
        'Unknown grocery category',
      );
    }
    return rows.first;
  }

  Future<CategoryRow> _insertOrFindCustomCategory(String cleanName) async {
    final CategoryRow? existing = await _categoryByName(cleanName);
    if (existing != null) return existing;

    final List<CategoryRow> rows = await _database
        .select(_database.categories)
        .get();
    final int sortOrder =
        rows.fold<int>(0, (int max, CategoryRow row) {
          return row.sortOrder > max ? row.sortOrder : max;
        }) +
        1;
    final DateTime now = _now().toUtc();
    final String id = IdGenerator.uuidV4();

    await _database
        .into(_database.categories)
        .insert(
          CategoriesCompanion.insert(
            id: id,
            name: cleanName,
            isSystem: const Value(false),
            sortOrder: Value(sortOrder),
            createdAt: now,
          ),
        );

    return CategoryRow(
      id: id,
      name: cleanName,
      isSystem: false,
      sortOrder: sortOrder,
      createdAt: now,
    );
  }

  GroceryCategory _mapCategory(CategoryRow row) => GroceryCategory(
    id: row.id,
    name: row.name,
    isPredefined: row.isSystem,
    sortOrder: row.sortOrder,
  );

  /// Dates are stored as UTC instants and converted to local time only here,
  /// at the boundary where the UI consumes them.
  GroceryList _mapList(GroceryListRow row, GroceryCategory? category) =>
      GroceryList(
        id: row.id,
        title: row.name,
        category: category,
        status: row.status,
        budget: GroceryListInput.budgetFromCentavos(row.budget),
        updatedAt: row.updatedAt.toLocal(),
      );
}
