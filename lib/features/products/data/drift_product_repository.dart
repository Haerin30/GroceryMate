import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/product_tables.dart';
import '../../../core/utils/id_generator.dart';
import '../domain/product.dart';
import '../domain/product_category.dart';
import '../domain/product_input.dart';
import '../domain/product_query.dart';
import '../domain/product_unit.dart';
import 'product_repository.dart';

/// Drift-backed implementation of [ProductRepository].
class DriftProductRepository implements ProductRepository {
  DriftProductRepository(this._database, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _database;
  final DateTime Function() _now;

  @override
  Stream<List<Product>> watchProducts({required bool archived}) =>
      _productsSelectable(archived: archived).watch();

  @override
  Stream<List<ProductCategory>> watchCategories() =>
      _categoriesSelectable().watch();

  @override
  Future<List<Product>> getProducts({required bool archived}) =>
      _productsSelectable(archived: archived).get();

  @override
  Future<List<Product>> getAllProducts() => _productsSelectable().get();

  @override
  Future<List<ProductCategory>> getCategories() =>
      _categoriesSelectable().get();

  @override
  Future<Product?> getProduct(String id) async {
    final List<Product> matches = await _productsSelectable(id: id).get();
    return matches.isEmpty ? null : matches.first;
  }

  @override
  Future<List<Product>> findSimilarProducts(
    String name, {
    String? excludeId,
  }) async {
    final List<Product> all = await getAllProducts();
    return findSimilarProductsByName(all, name, excludeId: excludeId);
  }

  @override
  Future<Product?> findByBarcode(String barcode, {String? excludeId}) async {
    final String? cleanBarcode = ProductInput.cleanBarcode(barcode);
    if (cleanBarcode == null) return null;

    final List<ProductBarcodeRow> rows =
        await (_database.select(_database.productBarcodes)..where(
              (ProductBarcodes table) => table.value.equals(cleanBarcode),
            ))
            .get();
    for (final ProductBarcodeRow row in rows) {
      if (row.productId == excludeId) continue;
      return getProduct(row.productId);
    }
    return null;
  }

  @override
  Future<ProductCategory> addCategory(String name) {
    final String? cleanName = ProductCategory.cleanName(name);
    if (cleanName == null) {
      throw ArgumentError.value(name, 'name', 'Category name is required');
    }
    return _database.transaction(() async {
      final ProductCategoryRow? existing = await _categoryByName(cleanName);
      if (existing != null) return _mapCategory(existing);

      final int sortOrder = await _nextCategorySortOrder();
      final DateTime now = _now().toUtc();
      final String id = IdGenerator.uuidV4();
      await _database
          .into(_database.productCategories)
          .insert(
            ProductCategoriesCompanion.insert(
              id: id,
              name: cleanName,
              isPredefined: const Value(false),
              sortOrder: Value(sortOrder),
              createdAt: now,
              updatedAt: now,
            ),
          );
      return ProductCategory(
        id: id,
        name: cleanName,
        isPredefined: false,
        sortOrder: sortOrder,
      );
    });
  }

  @override
  Future<Product> createProduct(ProductInput input) {
    final String cleanName = ProductInput.cleanName(input.name);
    final String? barcode = ProductInput.cleanBarcode(input.barcode);

    return _database.transaction(() async {
      final ProductCategoryRow category = await _resolveCategory(
        input.categoryId,
      );
      await _ensureBarcodeAvailable(barcode);

      final DateTime now = _now().toUtc();
      final String id = IdGenerator.uuidV4();
      await _database
          .into(_database.products)
          .insert(
            ProductsCompanion.insert(
              id: id,
              name: cleanName,
              categoryId: category.id,
              unit: input.unit.value,
              brand: Value(ProductInput.cleanOptional(input.brand)),
              imagePath: Value(ProductInput.cleanOptional(input.imagePath)),
              notes: Value(ProductInput.cleanOptional(input.notes)),
              isArchived: const Value(false),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _writeBarcode(id, barcode, now);

      final Product? created = await getProduct(id);
      if (created == null) {
        throw StateError('Product could not be read after creation');
      }
      return created;
    });
  }

  @override
  Future<Product?> updateProduct(String id, ProductInput input) {
    final String cleanName = ProductInput.cleanName(input.name);
    final String? barcode = ProductInput.cleanBarcode(input.barcode);

    return _database.transaction(() async {
      final ProductRow? existing = await _productRow(id);
      if (existing == null) return null;

      final ProductCategoryRow category = await _resolveCategory(
        input.categoryId,
      );
      await _ensureBarcodeAvailable(barcode, excludeProductId: id);

      final DateTime now = _now().toUtc();
      await (_database.update(
        _database.products,
      )..where((Products table) => table.id.equals(id))).write(
        ProductsCompanion(
          name: Value(cleanName),
          categoryId: Value(category.id),
          unit: Value(input.unit.value),
          brand: Value(ProductInput.cleanOptional(input.brand)),
          imagePath: Value(ProductInput.cleanOptional(input.imagePath)),
          notes: Value(ProductInput.cleanOptional(input.notes)),
          updatedAt: Value(now),
        ),
      );
      await (_database.delete(
        _database.productBarcodes,
      )..where((ProductBarcodes table) => table.productId.equals(id))).go();
      await _writeBarcode(id, barcode, now);

      return getProduct(id);
    });
  }

  @override
  Future<Product?> setArchived(String id, {required bool archived}) async {
    final ProductRow? existing = await _productRow(id);
    if (existing == null) return null;

    await (_database.update(
      _database.products,
    )..where((Products table) => table.id.equals(id))).write(
      ProductsCompanion(
        isArchived: Value(archived),
        updatedAt: Value(_now().toUtc()),
      ),
    );
    return getProduct(id);
  }

  Selectable<Product> _productsSelectable({bool? archived, String? id}) {
    final SimpleSelectStatement<Products, ProductRow> select = _database.select(
      _database.products,
    );
    if (archived != null) {
      select.where((Products table) => table.isArchived.equals(archived));
    }
    if (id != null) {
      select.where((Products table) => table.id.equals(id));
    }

    final JoinedSelectStatement<HasResultSet, dynamic> query = select.join([
      innerJoin(
        _database.productCategories,
        _database.productCategories.id.equalsExp(_database.products.categoryId),
      ),
      leftOuterJoin(
        _database.productBarcodes,
        _database.productBarcodes.productId.equalsExp(_database.products.id),
      ),
    ]);
    return query.map((TypedResult row) {
      final ProductRow product = row.readTable(_database.products);
      final ProductCategoryRow category = row.readTable(
        _database.productCategories,
      );
      final ProductBarcodeRow? barcode = row.readTableOrNull(
        _database.productBarcodes,
      );
      return _mapProduct(product, category, barcode?.value);
    });
  }

  Selectable<ProductCategory> _categoriesSelectable() {
    final SimpleSelectStatement<ProductCategories, ProductCategoryRow> select =
        _database.select(_database.productCategories)
          ..orderBy(<OrderingTerm Function(ProductCategories)>[
            (ProductCategories table) => OrderingTerm.asc(table.sortOrder),
            (ProductCategories table) => OrderingTerm.asc(table.name),
          ]);
    return select.map(_mapCategory);
  }

  Future<ProductRow?> _productRow(String id) async {
    final List<ProductRow> rows = await (_database.select(
      _database.products,
    )..where((Products table) => table.id.equals(id))).get();
    return rows.isEmpty ? null : rows.first;
  }

  Future<ProductCategoryRow?> _categoryByName(String name) async {
    final String key = ProductCategory.normalizeName(name);
    final List<ProductCategoryRow> rows = await _database
        .select(_database.productCategories)
        .get();
    for (final ProductCategoryRow row in rows) {
      if (ProductCategory.normalizeName(row.name) == key) return row;
    }
    return null;
  }

  Future<int> _nextCategorySortOrder() async {
    final List<ProductCategoryRow> rows = await _database
        .select(_database.productCategories)
        .get();
    return rows.fold<int>(0, (int max, ProductCategoryRow row) {
          return row.sortOrder > max ? row.sortOrder : max;
        }) +
        1;
  }

  Future<ProductCategoryRow> _resolveCategory(String categoryId) async {
    final List<ProductCategoryRow> rows = await (_database.select(
      _database.productCategories,
    )..where((ProductCategories table) => table.id.equals(categoryId))).get();
    if (rows.isEmpty) {
      throw ArgumentError.value(
        categoryId,
        'categoryId',
        'Unknown product category',
      );
    }
    return rows.first;
  }

  Future<void> _ensureBarcodeAvailable(
    String? barcode, {
    String? excludeProductId,
  }) async {
    if (barcode == null) return;
    final List<ProductBarcodeRow> rows = await (_database.select(
      _database.productBarcodes,
    )..where((ProductBarcodes table) => table.value.equals(barcode))).get();
    for (final ProductBarcodeRow row in rows) {
      if (row.productId == excludeProductId) continue;
      throw ArgumentError.value(
        barcode,
        'barcode',
        'This barcode is already assigned to another product',
      );
    }
  }

  Future<void> _writeBarcode(
    String productId,
    String? barcode,
    DateTime now,
  ) async {
    if (barcode == null) return;
    await _database
        .into(_database.productBarcodes)
        .insert(
          ProductBarcodesCompanion.insert(
            id: IdGenerator.uuidV4(),
            productId: productId,
            value: barcode,
            createdAt: now,
          ),
        );
  }

  ProductCategory _mapCategory(ProductCategoryRow row) => ProductCategory(
    id: row.id,
    name: row.name,
    isPredefined: row.isPredefined,
    sortOrder: row.sortOrder,
  );

  /// Dates are stored as UTC instants and converted only at this boundary.
  Product _mapProduct(
    ProductRow row,
    ProductCategoryRow category,
    String? barcode,
  ) => Product(
    id: row.id,
    name: row.name,
    categoryId: category.id,
    categoryName: category.name,
    unit: ProductUnitX.fromValue(row.unit) ?? ProductUnit.piece,
    brand: row.brand,
    barcode: barcode,
    imagePath: row.imagePath,
    notes: row.notes,
    isArchived: row.isArchived,
    createdAt: row.createdAt.toLocal(),
    updatedAt: row.updatedAt.toLocal(),
  );
}
