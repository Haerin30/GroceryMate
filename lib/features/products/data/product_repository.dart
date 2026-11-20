import '../domain/product.dart';
import '../domain/product_category.dart';
import '../domain/product_input.dart';

/// Persistence boundary for the Product Catalog. UI code never imports Drift.
abstract class ProductRepository {
  Stream<List<Product>> watchProducts({required bool archived});
  Stream<List<ProductCategory>> watchCategories();

  Future<List<Product>> getProducts({required bool archived});
  Future<List<Product>> getAllProducts();
  Future<List<ProductCategory>> getCategories();
  Future<Product?> getProduct(String id);
  Future<List<Product>> findSimilarProducts(String name, {String? excludeId});
  Future<Product?> findByBarcode(String barcode, {String? excludeId});

  Future<ProductCategory> addCategory(String name);
  Future<Product> createProduct(ProductInput input);
  Future<Product?> updateProduct(String id, ProductInput input);
  Future<Product?> setArchived(String id, {required bool archived});
}
