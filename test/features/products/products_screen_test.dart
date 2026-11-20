import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_scan/features/products/domain/product.dart';
import 'package:grocery_scan/features/products/domain/product_category.dart';
import 'package:grocery_scan/features/products/domain/product_unit.dart';
import 'package:grocery_scan/features/products/presentation/products_screen.dart';
import 'package:grocery_scan/features/products/presentation/widgets/product_card.dart';
import 'package:grocery_scan/features/products/state/product_controller.dart';

Product buildProduct({
  required String id,
  required String name,
  required ProductCategory category,
  String? brand,
  String? barcode,
  bool isArchived = false,
  DateTime? createdAt,
}) {
  return Product(
    id: id,
    name: name,
    categoryId: category.id,
    categoryName: category.name,
    unit: ProductUnit.piece,
    brand: brand,
    barcode: barcode,
    isArchived: isArchived,
    createdAt: createdAt ?? DateTime(2026, 11, 1),
    updatedAt: DateTime(2026, 11, 10),
  );
}

void main() {
  late ProductController controller;
  late ProductCategory produce;
  late ProductCategory bakery;
  late ProductCategory pantry;

  setUp(() {
    produce = ProductCategory.predefined.firstWhere(
      (ProductCategory category) => category.name == 'Produce',
    );
    bakery = ProductCategory.predefined.firstWhere(
      (ProductCategory category) => category.name == 'Bakery',
    );
    pantry = ProductCategory.predefined.firstWhere(
      (ProductCategory category) => category.name == 'Pantry',
    );
    controller = ProductController(
      initialProducts: <Product>[
        buildProduct(
          id: '1',
          name: 'Milk',
          category: produce,
          brand: 'Fresh Co',
          barcode: '111',
          createdAt: DateTime(2026, 11, 1),
        ),
        buildProduct(
          id: '2',
          name: 'Bread',
          category: bakery,
          createdAt: DateTime(2026, 11, 3),
        ),
        buildProduct(
          id: '3',
          name: 'Cornflakes',
          category: pantry,
          isArchived: true,
        ),
      ],
      now: () => DateTime(2026, 11, 20, 9),
    );
  });

  tearDown(() => controller.dispose());

  Future<void> pumpApp(
    WidgetTester tester, {
    Size size = const Size(800, 1200),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: ProductsScreen(controller: controller)),
    );
    await tester.pumpAndSettle();
  }

  Finder cardWithId(String id) => find.byKey(Key('product-$id'));

  List<String> cardNames(WidgetTester tester) => tester
      .widgetList<ProductCard>(find.byType(ProductCard))
      .map((ProductCard card) {
        return card.product.name;
      })
      .toList();

  Future<void> enterText(WidgetTester tester, String key, String text) async {
    await tester.enterText(find.byKey(Key(key)), text);
    await tester.pumpAndSettle();
  }

  testWidgets('shows active products and keeps archived products hidden', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('Product Catalog'), findsOneWidget);
    expect(cardNames(tester), <String>['Bread', 'Milk']);
    expect(find.text('Cornflakes'), findsNothing);
    expect(find.text('2 products'), findsOneWidget);
    expect(find.byTooltip('Show archived products'), findsOneWidget);
  });

  testWidgets('opens archived products and restores them', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Show archived products'));
    await tester.pumpAndSettle();
    expect(find.text('Archived Products'), findsOneWidget);
    expect(cardNames(tester), <String>['Cornflakes']);

    await tester.tap(
      find.descendant(
        of: cardWithId('3'),
        matching: find.byTooltip('Product options'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();

    expect(cardWithId('3'), findsNothing);
    expect(find.text('No archived products'), findsOneWidget);
    expect(controller.activeProducts.map((Product p) => p.id), contains('3'));
  });

  testWidgets('archives a product from its card menu', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(
      find.descendant(
        of: cardWithId('1'),
        matching: find.byTooltip('Product options'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();

    expect(cardWithId('1'), findsNothing);
    expect(controller.archivedProducts.map((Product p) => p.id), contains('1'));
  });

  testWidgets('searches by product name and brand', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await enterText(tester, 'product-search-field', 'fresh');
    expect(cardNames(tester), <String>['Milk']);

    await enterText(tester, 'product-search-field', 'bread');
    expect(cardNames(tester), <String>['Bread']);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(cardNames(tester), <String>['Bread', 'Milk']);
  });

  testWidgets('filters by category and changes sort order', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    final Finder bakeryChip = find.widgetWithText(ChoiceChip, 'Bakery');
    await tester.ensureVisible(bakeryChip);
    await tester.pumpAndSettle();
    await tester.tap(bakeryChip);
    await tester.pumpAndSettle();
    expect(cardNames(tester), <String>['Bread']);

    final Finder allChip = find.widgetWithText(ChoiceChip, 'All categories');
    await tester.ensureVisible(allChip);
    await tester.pumpAndSettle();
    await tester.tap(allChip);
    await tester.pumpAndSettle();
    expect(cardNames(tester), <String>['Bread', 'Milk']);

    await tester.tap(find.byTooltip('Sort products'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(PopupMenuItem<ProductSort>, 'Recently added'),
    );
    await tester.pumpAndSettle();
    expect(cardNames(tester), <String>['Bread', 'Milk']);
  });

  testWidgets('creates and edits a product from the reusable form', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Add Product'));
    await tester.pumpAndSettle();
    await enterText(tester, 'product-name-field', 'Apples');
    await enterText(tester, 'product-brand-field', 'Orchard');
    await tester.tap(find.byKey(const Key('product-save-button')));
    await tester.pumpAndSettle();

    expect(cardNames(tester), <String>['Apples', 'Bread', 'Milk']);
    expect(
      controller.activeProducts
          .firstWhere((Product p) => p.name == 'Apples')
          .brand,
      'Orchard',
    );

    await tester.tap(
      find.descendant(
        of: cardWithId('1'),
        matching: find.byTooltip('Product options'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await enterText(tester, 'product-name-field', 'Chocolate milk');
    await tester.tap(find.byKey(const Key('product-save-button')));
    await tester.pumpAndSettle();

    expect(find.text('Chocolate milk'), findsOneWidget);
    expect(find.text('Milk'), findsNothing);
  });

  testWidgets('warns about a similar name and opens the existing product', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Add Product'));
    await tester.pumpAndSettle();
    await enterText(tester, 'product-name-field', 'Milk 1L');

    expect(
      find.textContaining('A similar product already exists: Milk'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Open existing product'));
    await tester.pumpAndSettle();

    expect(find.text('Edit product'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(find.byKey(const Key('product-name-field'))),
      isNotNull,
    );
    expect(find.text('Milk 1L'), findsNothing);
  });

  testWidgets('allows a duplicate name but prevents a duplicate barcode', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Add Product'));
    await tester.pumpAndSettle();
    await enterText(tester, 'product-name-field', 'Milk 1L');
    await enterText(tester, 'product-barcode-field', '111');
    await tester.tap(find.byKey(const Key('product-save-button')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('This barcode is already used by Milk'),
      findsOneWidget,
    );
    expect(cardNames(tester), <String>['Bread', 'Milk']);

    await enterText(tester, 'product-barcode-field', '222');
    await tester.tap(find.byKey(const Key('product-save-button')));
    await tester.pumpAndSettle();
    expect(cardNames(tester), <String>['Bread', 'Milk', 'Milk 1L']);
  });

  testWidgets('creates a custom product category from the form', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Add Product'));
    await tester.pumpAndSettle();
    await enterText(tester, 'product-name-field', 'Cereal');
    await tester.tap(find.byKey(const Key('product-category-field')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(DropdownMenuItem<String>, 'Create new category…'),
    );
    await tester.pumpAndSettle();
    await enterText(tester, 'product-new-category-field', 'Breakfast');
    await tester.tap(find.byKey(const Key('product-save-button')));
    await tester.pumpAndSettle();

    expect(
      controller.categories.map((ProductCategory c) => c.name),
      contains('Breakfast'),
    );
    expect(find.widgetWithText(ChoiceChip, 'Breakfast'), findsOneWidget);
    expect(cardNames(tester), contains('Cereal'));
  });

  testWidgets('shows an empty state when the catalog has no products', (
    WidgetTester tester,
  ) async {
    controller.dispose();
    controller = ProductController(initialProducts: const <Product>[]);
    await pumpApp(tester);

    expect(find.text('No products yet'), findsOneWidget);
    expect(find.text('Tap + to add your first product.'), findsOneWidget);
  });
}
