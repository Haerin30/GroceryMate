import 'package:drift/drift.dart';

/// Product categories are deliberately separate from grocery list categories.
@DataClassName('ProductCategoryRow')
@TableIndex.sql(
  'CREATE UNIQUE INDEX product_categories_normalized_name_unique '
  'ON product_categories (lower(trim(name)));',
)
class ProductCategories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  BoolColumn get isPredefined => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => <String>[
    'CHECK (length(trim(name)) > 0)',
  ];
}

/// Product names are intentionally not unique: similar/duplicate products are
/// allowed when the user explicitly chooses to continue.
@DataClassName('ProductRow')
@TableIndex(name: 'products_category_id', columns: {#categoryId})
@TableIndex(name: 'products_is_archived', columns: {#isArchived})
@TableIndex(name: 'products_name', columns: {#name})
@TableIndex(name: 'products_created_at', columns: {#createdAt})
@TableIndex(name: 'products_updated_at', columns: {#updatedAt})
class Products extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get categoryId =>
      text().references(ProductCategories, #id, onDelete: KeyAction.restrict)();
  TextColumn get unit => text()();
  TextColumn get brand => text().nullable()();
  TextColumn get imagePath => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => <String>[
    'CHECK (length(trim(name)) > 0)',
    "CHECK (unit IN ('piece', 'kg', 'g', 'l', 'ml', 'pack', 'box', "
        "'bottle', 'can', 'dozen', 'bundle'))",
    'CHECK (is_archived IN (0, 1))',
  ];
}

/// One optional barcode per product. The value is globally unique.
@DataClassName('ProductBarcodeRow')
@TableIndex(
  name: 'product_barcodes_product_id_unique',
  columns: {#productId},
  unique: true,
)
@TableIndex(
  name: 'product_barcodes_value_unique',
  columns: {#value},
  unique: true,
)
class ProductBarcodes extends Table {
  TextColumn get id => text()();
  TextColumn get productId =>
      text().references(Products, #id, onDelete: KeyAction.cascade)();
  TextColumn get value => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => <String>[
    'CHECK (length(trim(value)) > 0)',
  ];
}
