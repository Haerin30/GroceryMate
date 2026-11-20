import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/utils/id_generator.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';
import '../domain/product_category.dart';
import '../domain/product_input.dart';
import '../domain/product_query.dart';

/// Repository-backed ChangeNotifier for the Product Catalog.
///
/// Without a repository it keeps the same in-memory behavior used by focused
/// widget tests, so no screen needs to know about Drift.
class ProductController extends ChangeNotifier {
  ProductController({
    this.repository,
    List<Product>? initialProducts,
    List<ProductCategory>? initialCategories,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    _activeProducts = <Product>[
      for (final Product product in initialProducts ?? const <Product>[])
        if (!product.isArchived) product,
    ];
    _archivedProducts = <Product>[
      for (final Product product in initialProducts ?? const <Product>[])
        if (product.isArchived) product,
    ];
    _categories = <ProductCategory>[...?initialCategories];
    if (repository == null && initialCategories == null) {
      _categories = List<ProductCategory>.of(ProductCategory.predefined);
    }

    final ProductRepository? repo = repository;
    if (repo != null) {
      _subscriptions.add(
        repo.watchProducts(archived: false).listen((List<Product> products) {
          _activeProducts = List<Product>.of(products);
          _notify();
        }, onError: (Object error) => _setError(error.toString())),
      );
      _subscriptions.add(
        repo.watchProducts(archived: true).listen((List<Product> products) {
          _archivedProducts = List<Product>.of(products);
          _notify();
        }, onError: (Object error) => _setError(error.toString())),
      );
      _subscriptions.add(
        repo.watchCategories().listen((List<ProductCategory> categories) {
          _categories = List<ProductCategory>.of(categories);
          _notify();
        }, onError: (Object error) => _setError(error.toString())),
      );
    }
  }

  final ProductRepository? repository;
  final DateTime Function() _now;
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  List<Product> _activeProducts = <Product>[];
  List<Product> _archivedProducts = <Product>[];
  List<ProductCategory> _categories = <ProductCategory>[];
  String? _error;
  bool _disposed = false;

  List<Product> get activeProducts =>
      List<Product>.unmodifiable(_activeProducts);
  List<Product> get archivedProducts =>
      List<Product>.unmodifiable(_archivedProducts);
  List<Product> get allProducts => List<Product>.unmodifiable(<Product>[
    ..._activeProducts,
    ..._archivedProducts,
  ]);
  List<ProductCategory> get categories =>
      List<ProductCategory>.unmodifiable(_categories);
  String? get error => _error;

  Future<void> refresh() async {
    final ProductRepository? repo = repository;
    if (repo == null) {
      _notify();
      return;
    }
    try {
      final List<Product> active = await repo.getProducts(archived: false);
      final List<Product> archived = await repo.getProducts(archived: true);
      final List<ProductCategory> categories = await repo.getCategories();
      _activeProducts = active;
      _archivedProducts = archived;
      _categories = categories;
      _error = null;
      _notify();
    } catch (error) {
      _setError(error.toString());
      rethrow;
    }
  }

  Future<ProductCategory> addCategory(String name) async {
    final String? cleanName = ProductCategory.cleanName(name);
    if (cleanName == null) {
      throw ArgumentError.value(name, 'name', 'Category name is required');
    }
    final ProductCategory? existing = _categoryByName(cleanName);
    if (existing != null) return existing;

    final ProductRepository? repo = repository;
    if (repo != null) {
      final ProductCategory category = await repo.addCategory(cleanName);
      _categories = <ProductCategory>[..._categories, category];
      _notify();
      return category;
    }

    final ProductCategory category = ProductCategory(
      id: IdGenerator.uuidV4(),
      name: cleanName,
      isPredefined: false,
      sortOrder:
          _categories.fold<int>(
            0,
            (int max, ProductCategory item) =>
                item.sortOrder > max ? item.sortOrder : max,
          ) +
          1,
    );
    _categories = <ProductCategory>[..._categories, category];
    _notify();
    return category;
  }

  Future<Product> createProduct(ProductInput input) async {
    final ProductInput cleanInput = _cleanInput(input);
    _categoryById(cleanInput.categoryId);
    await _ensureBarcodeAvailable(cleanInput.barcode);

    final ProductRepository? repo = repository;
    if (repo != null) {
      return repo.createProduct(cleanInput);
    }

    final DateTime now = _now();
    final ProductCategory category = _categoryById(cleanInput.categoryId);
    final Product product = Product(
      id: IdGenerator.uuidV4(),
      name: cleanInput.name,
      categoryId: category.id,
      categoryName: category.name,
      unit: cleanInput.unit,
      brand: cleanInput.brand,
      barcode: cleanInput.barcode,
      imagePath: cleanInput.imagePath,
      notes: cleanInput.notes,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    );
    _activeProducts = <Product>[..._activeProducts, product];
    _notify();
    return product;
  }

  Future<Product?> updateProduct(String id, ProductInput input) async {
    final ProductInput cleanInput = _cleanInput(input);
    _categoryById(cleanInput.categoryId);
    await _ensureBarcodeAvailable(cleanInput.barcode, excludeId: id);

    final ProductRepository? repo = repository;
    if (repo != null) {
      return repo.updateProduct(id, cleanInput);
    }

    final int activeIndex = _activeProducts.indexWhere(
      (Product item) => item.id == id,
    );
    final int archivedIndex = _archivedProducts.indexWhere(
      (Product item) => item.id == id,
    );
    if (activeIndex < 0 && archivedIndex < 0) return null;

    final Product existing = activeIndex >= 0
        ? _activeProducts[activeIndex]
        : _archivedProducts[archivedIndex];
    final ProductCategory category = _categoryById(cleanInput.categoryId);
    final Product updated = Product(
      id: id,
      name: cleanInput.name,
      categoryId: category.id,
      categoryName: category.name,
      unit: cleanInput.unit,
      brand: cleanInput.brand,
      barcode: cleanInput.barcode,
      imagePath: cleanInput.imagePath,
      notes: cleanInput.notes,
      isArchived: existing.isArchived,
      createdAt: existing.createdAt,
      updatedAt: _now(),
    );

    if (activeIndex >= 0) {
      _activeProducts = <Product>[..._activeProducts]..[activeIndex] = updated;
    } else {
      _archivedProducts = <Product>[..._archivedProducts]
        ..[archivedIndex] = updated;
    }
    _notify();
    return updated;
  }

  Future<Product?> setArchived(String id, {required bool archived}) async {
    final ProductRepository? repo = repository;
    if (repo != null) {
      return repo.setArchived(id, archived: archived);
    }

    final Product? product = findProduct(id);
    if (product == null) return null;
    if (product.isArchived == archived) return product;

    final Product moved = Product(
      id: product.id,
      name: product.name,
      categoryId: product.categoryId,
      categoryName: product.categoryName,
      unit: product.unit,
      brand: product.brand,
      barcode: product.barcode,
      imagePath: product.imagePath,
      notes: product.notes,
      isArchived: archived,
      createdAt: product.createdAt,
      updatedAt: _now(),
    );
    _activeProducts = _activeProducts
        .where((Product item) => item.id != id)
        .toList();
    _archivedProducts = _archivedProducts
        .where((Product item) => item.id != id)
        .toList();
    if (archived) {
      _archivedProducts = <Product>[..._archivedProducts, moved];
    } else {
      _activeProducts = <Product>[..._activeProducts, moved];
    }
    _notify();
    return moved;
  }

  Product? findProduct(String id) {
    for (final Product product in allProducts) {
      if (product.id == id) return product;
    }
    return null;
  }

  Future<List<Product>> findSimilarProducts(
    String name, {
    String? excludeId,
  }) async {
    final ProductRepository? repo = repository;
    if (repo != null) {
      return repo.findSimilarProducts(name, excludeId: excludeId);
    }
    return findSimilarProductsByName(allProducts, name, excludeId: excludeId);
  }

  Future<Product?> findByBarcode(String barcode, {String? excludeId}) async {
    final String? cleanBarcode = ProductInput.cleanBarcode(barcode);
    if (cleanBarcode == null) return null;

    final ProductRepository? repo = repository;
    if (repo != null) {
      return repo.findByBarcode(cleanBarcode, excludeId: excludeId);
    }
    for (final Product product in allProducts) {
      if (product.id == excludeId) continue;
      if (product.barcode == cleanBarcode) return product;
    }
    return null;
  }

  ProductInput _cleanInput(ProductInput input) => ProductInput(
    name: ProductInput.cleanName(input.name),
    categoryId: input.categoryId,
    unit: input.unit,
    brand: ProductInput.cleanOptional(input.brand),
    barcode: ProductInput.cleanBarcode(input.barcode),
    imagePath: ProductInput.cleanOptional(input.imagePath),
    notes: ProductInput.cleanOptional(input.notes),
  );

  ProductCategory _categoryById(String id) {
    for (final ProductCategory category in _categories) {
      if (category.id == id) return category;
    }
    throw ArgumentError.value(id, 'categoryId', 'Unknown product category');
  }

  ProductCategory? _categoryByName(String name) {
    final String key = ProductCategory.normalizeName(name);
    for (final ProductCategory category in _categories) {
      if (ProductCategory.normalizeName(category.name) == key) {
        return category;
      }
    }
    return null;
  }

  Future<void> _ensureBarcodeAvailable(
    String? barcode, {
    String? excludeId,
  }) async {
    if (barcode == null) return;
    final Product? owner = await findByBarcode(barcode, excludeId: excludeId);
    if (owner != null) {
      throw ArgumentError.value(
        barcode,
        'barcode',
        'This barcode is already assigned to another product',
      );
    }
  }

  void _setError(String message) {
    _error = message;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final StreamSubscription<dynamic> subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }
}
