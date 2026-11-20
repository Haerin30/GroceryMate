import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_scan/core/database/app_database.dart';
import 'package:grocery_scan/features/products/data/drift_product_repository.dart';
import 'package:grocery_scan/features/products/domain/product.dart';
import 'package:grocery_scan/features/products/domain/product_category.dart';
import 'package:grocery_scan/features/products/domain/product_input.dart';
import 'package:grocery_scan/features/products/domain/product_query.dart';
import 'package:grocery_scan/features/products/domain/product_unit.dart';

ProductInput productInput({
  required String name,
  String? categoryId,
  String? barcode,
  String? brand,
  String? imagePath,
}) {
  return ProductInput(
    name: name,
    categoryId: categoryId ?? ProductCategory.predefined.first.id,
    unit: ProductUnit.piece,
    brand: brand,
    barcode: barcode,
    imagePath: imagePath,
  );
}

({AppDatabase database, DriftProductRepository repository}) openRepository() {
  final AppDatabase database = AppDatabase(NativeDatabase.memory());
  addTearDown(() => database.close());
  final DriftProductRepository repository = DriftProductRepository(
    database,
    now: () => DateTime(2026, 11, 20, 9),
  );
  return (database: database, repository: repository);
}

void main() {
  group('DriftProductRepository', () {
    test(
      'seeds categories and creates a product with all optional fields',
      () async {
        final ({AppDatabase database, DriftProductRepository repository})
        opened = openRepository();
        final AppDatabase database = opened.database;
        final DriftProductRepository repository = opened.repository;
        await repository.getCategories();
        final List<ProductCategory> categories = await repository
            .getCategories();
        expect(categories, hasLength(ProductCategory.predefined.length));

        final Product created = await repository.createProduct(
          productInput(
            name: 'Whole milk',
            brand: 'Fresh Co',
            barcode: ' 123-456 ',
            imagePath: '/tmp/milk.jpg',
          ),
        );

        expect(created.name, 'Whole milk');
        expect(created.barcode, '123456');
        expect(created.imagePath, '/tmp/milk.jpg');
        expect(created.categoryName, 'Produce');
        expect(created.updatedAt, DateTime(2026, 11, 20, 9));
        expect(await repository.getProduct(created.id), isNotNull);
        expect(database.productBarcodes, isNotNull);
      },
    );

    test(
      'edits a product and rejects another product with the same barcode',
      () async {
        final DriftProductRepository repository = openRepository().repository;
        final Product first = await repository.createProduct(
          productInput(name: 'Milk', barcode: '111'),
        );
        final Product second = await repository.createProduct(
          productInput(name: 'Bread'),
        );

        final Product? updated = await repository.updateProduct(
          second.id,
          productInput(name: 'Bread', barcode: '222'),
        );
        expect(updated?.barcode, '222');

        await expectLater(
          repository.updateProduct(
            second.id,
            productInput(name: 'Bread', barcode: '111'),
          ),
          throwsA(isA<ArgumentError>()),
        );
        await expectLater(
          repository.createProduct(
            productInput(name: 'Other milk', barcode: '111'),
          ),
          throwsA(isA<ArgumentError>()),
        );
        expect((await repository.getAllProducts()), hasLength(2));
        expect(first.barcode, '111');
      },
    );

    test('archives and restores while keeping the record', () async {
      final DriftProductRepository repository = openRepository().repository;
      final Product created = await repository.createProduct(
        productInput(name: 'Rice'),
      );

      final Product? archived = await repository.setArchived(
        created.id,
        archived: true,
      );
      expect(archived?.isArchived, isTrue);
      expect(await repository.getProducts(archived: true), hasLength(1));
      expect(await repository.getProducts(archived: false), isEmpty);

      final Product? restored = await repository.setArchived(
        created.id,
        archived: false,
      );
      expect(restored?.isArchived, isFalse);
      expect(await repository.getProducts(archived: false), hasLength(1));
    });

    test('allows duplicate names and reports similar products', () async {
      final DriftProductRepository repository = openRepository().repository;
      final Product first = await repository.createProduct(
        productInput(name: 'Milk'),
      );
      final Product second = await repository.createProduct(
        productInput(name: 'Milk 1L'),
      );

      expect(second.id, isNot(first.id));
      final List<Product> similar = await repository.findSimilarProducts(
        'Milk',
      );
      expect(
        similar.map((Product p) => p.id),
        containsAll(<String>[first.id, second.id]),
      );
    });

    test('creates custom categories case-insensitively', () async {
      final DriftProductRepository repository = openRepository().repository;
      final ProductCategory first = await repository.addCategory('  Local  ');
      final ProductCategory second = await repository.addCategory('LOCAL');

      expect(first.name, 'Local');
      expect(second.id, first.id);
      expect(await repository.getCategories(), hasLength(11));
    });

    test('search and sorting work on persisted products', () async {
      final DriftProductRepository repository = openRepository().repository;
      await repository.createProduct(
        productInput(name: 'Milk', brand: 'Fresh Co'),
      );
      await repository.createProduct(
        productInput(name: 'Bread', brand: 'Bakery House'),
      );

      final List<Product> all = await repository.getAllProducts();
      expect(
        queryProducts(all, search: 'fresh').map((Product p) => p.name),
        <String>['Milk'],
      );
      expect(
        queryProducts(all, sort: ProductSort.name).map((Product p) => p.name),
        <String>['Bread', 'Milk'],
      );
    });

    test('watchProducts emits archived and active changes', () async {
      final DriftProductRepository repository = openRepository().repository;
      final Product created = await repository.createProduct(
        productInput(name: 'Rice'),
      );
      final List<Product> active = await repository
          .watchProducts(archived: false)
          .first;
      expect(active.map((Product p) => p.id), contains(created.id));

      await repository.setArchived(created.id, archived: true);
      final List<Product> archived = await repository
          .watchProducts(archived: true)
          .first;
      expect(archived.map((Product p) => p.id), contains(created.id));
    });

    test('persists products across database reopen', () async {
      final Directory directory = await Directory.systemTemp.createTemp(
        'grocery_mate_product_test_',
      );
      final String path =
          '${directory.path}${Platform.pathSeparator}products.sqlite';
      addTearDown(() {
        if (directory.existsSync()) {
          directory.deleteSync(recursive: true);
        }
      });

      final AppDatabase first = AppDatabase(NativeDatabase(File(path)));
      final DriftProductRepository firstRepository = DriftProductRepository(
        first,
        now: () => DateTime(2026, 11, 20, 9),
      );
      final Product created = await firstRepository.createProduct(
        productInput(name: 'Persisted milk', barcode: '999'),
      );
      await first.close();

      final AppDatabase reopened = AppDatabase(NativeDatabase(File(path)));
      addTearDown(() => reopened.close());
      final DriftProductRepository secondRepository = DriftProductRepository(
        reopened,
      );
      final Product? loaded = await secondRepository.getProduct(created.id);

      expect(loaded?.name, 'Persisted milk');
      expect(loaded?.barcode, '999');
    });
  });
}
