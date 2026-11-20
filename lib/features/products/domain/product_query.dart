import 'product.dart';

const String allProductCategoriesFilter = '__all_product_categories__';

/// Pure search/filter/sort rules for the catalog screens.
List<Product> queryProducts(
  Iterable<Product> products, {
  String search = '',
  String categoryId = allProductCategoriesFilter,
  ProductSort sort = ProductSort.name,
}) {
  final String query = search.trim().toLowerCase();

  final List<Product> result = products.where((Product product) {
    if (categoryId != allProductCategoriesFilter &&
        product.categoryId != categoryId) {
      return false;
    }
    if (query.isEmpty) return true;
    return product.name.toLowerCase().contains(query) ||
        (product.brand?.toLowerCase().contains(query) ?? false);
  }).toList();

  switch (sort) {
    case ProductSort.name:
      result.sort((Product a, Product b) {
        final int byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        if (byName != 0) return byName;
        return a.id.compareTo(b.id);
      });
    case ProductSort.recentlyAdded:
      result.sort((Product a, Product b) {
        final int byDate = b.createdAt.compareTo(a.createdAt);
        if (byDate != 0) return byDate;
        return a.id.compareTo(b.id);
      });
    case ProductSort.recentlyUpdated:
      result.sort((Product a, Product b) {
        final int byDate = b.updatedAt.compareTo(a.updatedAt);
        if (byDate != 0) return byDate;
        return a.id.compareTo(b.id);
      });
  }
  return result;
}

/// Returns products whose names are close enough to warrant a warning, while
/// still allowing the user to create a separate product.
List<Product> findSimilarProductsByName(
  Iterable<Product> products,
  String name, {
  String? excludeId,
}) {
  final String candidate = _normalizeName(name);
  if (candidate.isEmpty) return const <Product>[];

  return products.where((Product product) {
    if (product.id == excludeId) return false;
    final String existing = _normalizeName(product.name);
    if (existing == candidate) return true;
    if (candidate.length >= 4 && existing.contains(candidate)) return true;
    if (existing.length >= 4 && candidate.contains(existing)) return true;
    return false;
  }).toList();
}

String _normalizeName(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}
