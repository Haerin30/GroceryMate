import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_scan/features/products/domain/product.dart';
import 'package:grocery_scan/features/products/domain/product_category.dart';
import 'package:grocery_scan/features/products/domain/product_input.dart';
import 'package:grocery_scan/features/products/domain/product_unit.dart';
import 'package:grocery_scan/features/products/state/product_controller.dart';

ProductInput input({
  required String name,
  String? categoryId,
  String? barcode,
  String? brand,
}) {
  return ProductInput(
    name: name,
    categoryId: categoryId ?? ProductCategory.predefined.first.id,
    unit: ProductUnit.piece,
    brand: brand,
    barcode: barcode,
  );
}

void main() {
  group('ProductController', () {
    late ProductController controller;
    late DateTime now;

    setUp(() {
      now = DateTime(2026, 11, 20, 9);
      controller = ProductController(
        initialProducts: const <Product>[],
        now: () => now,
      );
    });

    tearDown(() => controller.dispose());

    test('creates and edits a product', () async {
      final Product created = await controller.createProduct(
        input(name: 'Whole milk', brand: 'Fresh Co'),
      );

      expect(created.name, 'Whole milk');
      expect(controller.activeProducts, hasLength(1));

      final Product? updated = await controller.updateProduct(
        created.id,
        input(name: 'Low-fat milk', brand: 'Fresh Co'),
      );
      expect(updated?.name, 'Low-fat milk');
      expect(controller.activeProducts.single.name, 'Low-fat milk');
    });

    test('validates required product fields', () async {
      await expectLater(
        controller.createProduct(input(name: '   ')),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        controller.createProduct(
          input(name: 'Bread', categoryId: 'missing-category'),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('archives and restores without deleting', () async {
      final Product created = await controller.createProduct(
        input(name: 'Rice'),
      );

      await controller.setArchived(created.id, archived: true);
      expect(controller.activeProducts, isEmpty);
      expect(controller.archivedProducts.single.id, created.id);

      await controller.setArchived(created.id, archived: false);
      expect(controller.activeProducts.single.id, created.id);
      expect(controller.archivedProducts, isEmpty);
    });

    test('creates a custom category and deduplicates it', () async {
      final ProductCategory first = await controller.addCategory('  Local  ');
      final ProductCategory second = await controller.addCategory('LOCAL');

      expect(first.name, 'Local');
      expect(second.id, first.id);
      expect(
        controller.categories.where(
          (ProductCategory c) => c.isPredefined == false,
        ),
        hasLength(1),
      );
    });

    test('warns about similar names and prevents duplicate barcodes', () async {
      final Product first = await controller.createProduct(
        input(name: 'Milk', barcode: '123456'),
      );

      final List<Product> similar = await controller.findSimilarProducts(
        'Milk 1L',
      );
      expect(similar.single.id, first.id);

      await expectLater(
        controller.createProduct(input(name: 'Milk 1L', barcode: '123456')),
        throwsA(isA<ArgumentError>()),
      );
      expect(controller.activeProducts, hasLength(1));
    });
  });
}
