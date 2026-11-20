/// A product category, independent of grocery list categories.
class ProductCategory {
  const ProductCategory({
    required this.id,
    required this.name,
    required this.isPredefined,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final bool isPredefined;
  final int sortOrder;

  static String normalizeName(String name) {
    return name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String? cleanName(String name) {
    final String cleaned = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) return null;
    return cleaned;
  }

  /// Seeded only on first database creation or when upgrading to schema 2.
  static const List<ProductCategory> predefined = <ProductCategory>[
    ProductCategory(
      id: 'a1000000-0000-4000-8000-000000000001',
      name: 'Produce',
      isPredefined: true,
      sortOrder: 0,
    ),
    ProductCategory(
      id: 'a1000000-0000-4000-8000-000000000002',
      name: 'Dairy & Eggs',
      isPredefined: true,
      sortOrder: 1,
    ),
    ProductCategory(
      id: 'a1000000-0000-4000-8000-000000000003',
      name: 'Meat & Seafood',
      isPredefined: true,
      sortOrder: 2,
    ),
    ProductCategory(
      id: 'a1000000-0000-4000-8000-000000000004',
      name: 'Bakery',
      isPredefined: true,
      sortOrder: 3,
    ),
    ProductCategory(
      id: 'a1000000-0000-4000-8000-000000000005',
      name: 'Pantry',
      isPredefined: true,
      sortOrder: 4,
    ),
    ProductCategory(
      id: 'a1000000-0000-4000-8000-000000000006',
      name: 'Frozen Foods',
      isPredefined: true,
      sortOrder: 5,
    ),
    ProductCategory(
      id: 'a1000000-0000-4000-8000-000000000007',
      name: 'Beverages',
      isPredefined: true,
      sortOrder: 6,
    ),
    ProductCategory(
      id: 'a1000000-0000-4000-8000-000000000008',
      name: 'Household',
      isPredefined: true,
      sortOrder: 7,
    ),
    ProductCategory(
      id: 'a1000000-0000-4000-8000-000000000009',
      name: 'Personal Care',
      isPredefined: true,
      sortOrder: 8,
    ),
    ProductCategory(
      id: 'a1000000-0000-4000-8000-000000000010',
      name: 'Other',
      isPredefined: true,
      sortOrder: 9,
    ),
  ];
}
