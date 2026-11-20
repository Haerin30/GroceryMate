import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grocery_scan/app/app.dart';

void main() {
  testWidgets('starts on Grocery Lists with the core controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const GroceryScanApp());
    await tester.pump();

    expect(find.text('Grocery Lists'), findsOneWidget);
    expect(find.text('Your lists'), findsOneWidget);
    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.barcode_reader), findsOneWidget);
    expect(find.byIcon(Icons.calculate), findsOneWidget);

    for (final String filter in <String>[
      'All',
      'Active',
      'Completed',
      'Archived',
    ]) {
      expect(find.widgetWithText(ChoiceChip, filter), findsOneWidget);
    }

    expect(find.text('Weekly groceries'), findsOneWidget);
  });

  testWidgets('navigation drawer lists every GroceryMate section', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const GroceryScanApp());

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    for (final String label in <String>[
      'Grocery Lists',
      'Product Catalog',
      'Product Prices',
      'Budget',
      'Statistics',
      'Shopping History',
      'Settings',
    ]) {
      expect(
        find.widgetWithText(NavigationDrawerDestination, label),
        findsOneWidget,
      );
    }
  });

  testWidgets('opens the Product Catalog from the navigation drawer', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const GroceryScanApp());

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(NavigationDrawerDestination, 'Product Catalog'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Product Catalog'), findsOneWidget);
    expect(find.byKey(const Key('product-search-field')), findsOneWidget);
    expect(find.byTooltip('Add Product'), findsOneWidget);
  });
}
