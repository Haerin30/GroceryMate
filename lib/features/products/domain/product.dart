import 'product_unit.dart';

/// Domain model used by the Product Catalog UI. It has no Drift dependency.
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.unit,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
    this.brand,
    this.barcode,
    this.imagePath,
    this.notes,
  });

  final String id;
  final String name;
  final String categoryId;
  final String categoryName;
  final ProductUnit unit;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? brand;
  final String? barcode;
  final String? imagePath;
  final String? notes;
}

enum ProductSort { name, recentlyAdded, recentlyUpdated }

extension ProductSortX on ProductSort {
  String get label => switch (this) {
    ProductSort.name => 'Name (A-Z)',
    ProductSort.recentlyAdded => 'Recently added',
    ProductSort.recentlyUpdated => 'Recently updated',
  };
}
