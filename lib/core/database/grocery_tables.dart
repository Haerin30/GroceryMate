import 'package:drift/drift.dart';

import 'grocery_status_converter.dart';

/// Persisted system and user-created categories.
@DataClassName('CategoryRow')
@TableIndex.sql(
  'CREATE UNIQUE INDEX categories_normalized_name_unique '
  'ON categories (lower(trim(name)));',
)
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => <String>[
    'CHECK (length(trim(name)) > 0)',
  ];
}

/// Grocery list metadata. Monetary values are integer centavos.
@DataClassName('GroceryListRow')
@TableIndex(name: 'grocery_lists_category_id', columns: {#categoryId})
@TableIndex(name: 'grocery_lists_status', columns: {#status})
@TableIndex(name: 'grocery_lists_updated_at', columns: {#updatedAt})
class GroceryLists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get categoryId => text().nullable().references(
    Categories,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get budget => integer().nullable()();
  TextColumn get status => text().map(const GroceryListStatusConverter())();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => <String>[
    'CHECK (length(trim(name)) > 0)',
    "CHECK (status IN ('active', 'completed', 'archived'))",
    'CHECK (budget IS NULL OR budget >= 0)',
  ];
}

/// Placeholder for the upcoming grocery item feature.
///
/// No CRUD or UI is exposed for this table in the persistence milestone.
@DataClassName('GroceryListItemRow')
@TableIndex(name: 'grocery_list_items_list_id', columns: {#groceryListId})
class GroceryListItems extends Table {
  TextColumn get id => text()();
  TextColumn get groceryListId =>
      text().references(GroceryLists, #id, onDelete: KeyAction.cascade)();
  TextColumn get itemName => text()();
  IntColumn get quantityMilli => integer()();
  TextColumn get unit => text().nullable()();
  IntColumn get estimatedUnitPrice => integer().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isChecked => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => <String>[
    'CHECK (length(trim(item_name)) > 0)',
    'CHECK (quantity_milli > 0)',
    'CHECK (estimated_unit_price IS NULL OR estimated_unit_price >= 0)',
  ];
}
