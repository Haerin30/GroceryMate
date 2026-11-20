import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_scan/features/products/domain/product.dart';
import 'package:grocery_scan/features/products/domain/product_query.dart';
import 'package:grocery_scan/features/products/domain/product_unit.dart';

Product buildProduct({
  required String id,
  required String name,
  String? brand,
  String categoryId = 'cat-1',
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  return Product(
    id: id,
    name: name,
    categoryId: categoryId,
    categoryName: categoryId == 'cat-1' ? 'Pantry' : 'Bakery',
    unit: ProductUnit.piece,
    brand: brand,
    isArchived: false,
    createdAt: createdAt ?? DateTime(2026, 11, 1),
    updatedAt: updatedAt ?? DateTime(2026, 11, 10),
  );
}

void main() {
  group('product query rules', () {
    final List<Product> products = <Product>[
      buildProduct(
        id: '1',
        name: 'Milk',
        brand: 'Fresh Co',
        createdAt: DateTime(2026, 11, 1),
        updatedAt: DateTime(2026, 11, 20),
      ),
      buildProduct(
        id: '2',
        name: 'Bread',
        brand: 'Bakery House',
        categoryId: 'cat-2',
        createdAt: DateTime(2026, 11, 3),
        updatedAt: DateTime(2026, 11, 5),
      ),
      buildProduct(
        id: '3',
        name: 'Green apples',
        brand: 'Orchard',
        createdAt: DateTime(2026, 11, 2),
        updatedAt: DateTime(2026, 11, 12),
      ),
    ];

    test('searches by name and brand case-insensitively', () {
      expect(
        queryProducts(products, search: 'milk').map((Product p) => p.id),
        <String>['1'],
      );
      expect(
        queryProducts(products, search: 'BAKERY').map((Product p) => p.id),
        <String>['2'],
      );
    });

    test('filters by product category', () {
      expect(
        queryProducts(products, categoryId: 'cat-2').map((Product p) => p.id),
        <String>['2'],
      );
    });

    test('sorts by name, recently added, and recently updated', () {
      expect(
        queryProducts(
          products,
          sort: ProductSort.name,
        ).map((Product p) => p.id),
        <String>['2', '3', '1'],
      );
      expect(
        queryProducts(
          products,
          sort: ProductSort.recentlyAdded,
        ).map((Product p) => p.id),
        <String>['2', '3', '1'],
      );
      expect(
        queryProducts(
          products,
          sort: ProductSort.recentlyUpdated,
        ).map((Product p) => p.id),
        <String>['1', '3', '2'],
      );
    });

    test('detects similar names but keeps exact duplicates distinct', () {
      expect(
        findSimilarProductsByName(products, 'Milk 1L').map((Product p) => p.id),
        <String>['1'],
      );
      expect(
        findSimilarProductsByName(products, 'Milk', excludeId: '1'),
        isEmpty,
      );
    });
  });
}
