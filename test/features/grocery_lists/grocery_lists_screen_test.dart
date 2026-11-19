import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_scan/features/grocery_lists/domain/grocery_category.dart';
import 'package:grocery_scan/features/grocery_lists/domain/grocery_list.dart';
import 'package:grocery_scan/features/grocery_lists/presentation/grocery_lists_screen.dart';
import 'package:grocery_scan/features/grocery_lists/presentation/widgets/grocery_list_card.dart';
import 'package:grocery_scan/features/grocery_lists/state/grocery_list_controller.dart';

void main() {
  late GroceryListController controller;

  setUp(() {
    controller = GroceryListController(
      initialLists: const <GroceryList>[],
      now: () => DateTime(2026, 11, 20, 9),
    );
  });

  Widget buildApp() =>
      MaterialApp(home: GroceryListsScreen(controller: controller));

  Future<void> pumpApp(WidgetTester tester) async {
    // A tall surface keeps every ListTile built so card-order assertions are
    // not dependent on offscreen ListView laziness.
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
  }

  Future<void> openAddForm(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Add List'));
    await tester.pumpAndSettle();
  }

  Future<void> openCardMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('List options'));
    await tester.pumpAndSettle();
  }

  List<String> cardTitles(WidgetTester tester) => tester
      .widgetList<GroceryListCard>(find.byType(GroceryListCard))
      .map((GroceryListCard card) => card.groceryList.title)
      .toList();

  Future<void> selectNewCategoryOption(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('grocery-list-category-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create new category…').last);
    await tester.pumpAndSettle();
  }

  group('create', () {
    testWidgets('creates a list with a name, category, and budget', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      expect(find.text('No lists yet'), findsOneWidget);

      await openAddForm(tester);
      await tester.enterText(
        find.byKey(const Key('grocery-list-name-field')),
        'Monthly shop',
      );
      await tester.enterText(
        find.byKey(const Key('grocery-list-budget-field')),
        '1200',
      );
      await tester.tap(find.byKey(const Key('grocery-list-save-button')));
      await tester.pumpAndSettle();

      expect(controller.lists, hasLength(1));
      expect(controller.lists.single.title, 'Monthly shop');
      expect(find.text('Monthly shop'), findsOneWidget);
      expect(find.text('Budget: ₱1200.00'), findsOneWidget);
      expect(find.text('No lists yet'), findsNothing);
    });

    testWidgets('requires a non-empty name', (WidgetTester tester) async {
      await pumpApp(tester);
      await openAddForm(tester);

      await tester.tap(find.byKey(const Key('grocery-list-save-button')));
      await tester.pump();

      expect(find.text('Enter a list name.'), findsOneWidget);
      expect(controller.lists, isEmpty);
    });

    testWidgets('validates an optional budget', (WidgetTester tester) async {
      await pumpApp(tester);
      await openAddForm(tester);
      await tester.enterText(
        find.byKey(const Key('grocery-list-name-field')),
        'Budget checks',
      );

      await tester.enterText(
        find.byKey(const Key('grocery-list-budget-field')),
        '-5',
      );
      await tester.tap(find.byKey(const Key('grocery-list-save-button')));
      await tester.pump();
      expect(find.text('Budget must be zero or more.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('grocery-list-budget-field')),
        'abc',
      );
      await tester.tap(find.byKey(const Key('grocery-list-save-button')));
      await tester.pump();
      expect(find.text('Enter a valid amount.'), findsOneWidget);
      expect(controller.lists, isEmpty);

      await tester.enterText(
        find.byKey(const Key('grocery-list-budget-field')),
        '',
      );
      await tester.tap(find.byKey(const Key('grocery-list-save-button')));
      await tester.pumpAndSettle();

      expect(controller.lists.single.budget, isNull);
      expect(find.text('Budget: Not set'), findsOneWidget);
    });
  });

  group('update and delete', () {
    setUp(() {
      controller = GroceryListController(
        initialLists: <GroceryList>[
          GroceryList(
            id: 'seed',
            title: 'Weekly groceries',
            category: GroceryCategory.weekly,
            status: GroceryListStatus.active,
            budget: 100,
            updatedAt: DateTime(2026, 11, 18),
          ),
        ],
        now: () => DateTime(2026, 11, 20, 9),
      );
    });

    testWidgets('edits name, category, and budget immediately', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      await openCardMenu(tester);
      await tester.tap(find.text('Edit').last);
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('grocery-list-name-field')),
            )
            .controller!
            .text,
        'Weekly groceries',
      );

      await tester.enterText(
        find.byKey(const Key('grocery-list-name-field')),
        'Renamed list',
      );
      await tester.enterText(
        find.byKey(const Key('grocery-list-budget-field')),
        '999',
      );
      await tester.tap(find.byKey(const Key('grocery-list-save-button')));
      await tester.pumpAndSettle();

      expect(controller.lists.single.id, 'seed');
      expect(controller.lists.single.title, 'Renamed list');
      expect(controller.lists.single.budget, 999);
      expect(find.text('Renamed list'), findsOneWidget);
      expect(find.text('Budget: ₱999.00'), findsOneWidget);
      expect(find.text('Weekly groceries'), findsNothing);
    });

    testWidgets('deletes only after confirmation', (WidgetTester tester) async {
      await pumpApp(tester);

      await openCardMenu(tester);
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(find.text('Delete list?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(controller.lists, hasLength(1));
      expect(find.text('Weekly groceries'), findsOneWidget);

      await openCardMenu(tester);
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(controller.lists, isEmpty);
      expect(find.byType(GroceryListCard), findsNothing);
      expect(find.text('No lists yet'), findsOneWidget);
    });

    testWidgets('changes status from the card menu', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      await openCardMenu(tester);
      await tester.tap(find.text('Mark as completed'));
      await tester.pumpAndSettle();

      expect(controller.lists.single.status, GroceryListStatus.completed);
      expect(
        find.descendant(
          of: find.byType(GroceryListCard),
          matching: find.text('Completed'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(ChoiceChip, 'Completed'));
      await tester.pumpAndSettle();
      expect(cardTitles(tester), <String>['Weekly groceries']);
    });
  });

  group('categories', () {
    testWidgets('creates a custom category and blocks duplicates', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      await openAddForm(tester);
      await selectNewCategoryOption(tester);

      await tester.enterText(
        find.byKey(const Key('grocery-list-new-category-field')),
        'Holiday',
      );
      await tester.enterText(
        find.byKey(const Key('grocery-list-name-field')),
        'Party food',
      );
      await tester.tap(find.byKey(const Key('grocery-list-save-button')));
      await tester.pumpAndSettle();

      expect(controller.customCategories.single.name, 'Holiday');
      expect(controller.lists.single.category?.name, 'Holiday');
      expect(find.widgetWithText(ChoiceChip, 'Holiday'), findsOneWidget);

      await openAddForm(tester);
      await selectNewCategoryOption(tester);
      await tester.enterText(
        find.byKey(const Key('grocery-list-new-category-field')),
        '  holiday  ',
      );
      await tester.enterText(
        find.byKey(const Key('grocery-list-name-field')),
        'Another list',
      );
      await tester.tap(find.byKey(const Key('grocery-list-save-button')));
      await tester.pump();
      expect(
        find.text('A category with this name already exists.'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('grocery-list-new-category-field')),
        'Weekly',
      );
      await tester.tap(find.byKey(const Key('grocery-list-save-button')));
      await tester.pump();
      expect(
        find.text('A category with this name already exists.'),
        findsOneWidget,
      );
      expect(controller.customCategories, hasLength(1));
      expect(controller.lists, hasLength(1));

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
    });
  });

  group('filtering and sorting', () {
    setUp(() {
      controller = GroceryListController(
        initialLists: <GroceryList>[
          GroceryList(
            id: '1',
            title: 'Weekly groceries',
            category: GroceryCategory.weekly,
            status: GroceryListStatus.active,
            updatedAt: DateTime(2026, 11, 20),
          ),
          GroceryList(
            id: '2',
            title: 'Weekend BBQ',
            category: GroceryCategory.party,
            status: GroceryListStatus.completed,
            budget: 3000,
            updatedAt: DateTime(2026, 11, 10),
          ),
          GroceryList(
            id: '3',
            title: 'Party leftovers',
            category: GroceryCategory.party,
            status: GroceryListStatus.active,
            updatedAt: DateTime(2026, 11, 8),
          ),
        ],
        now: () => DateTime(2026, 11, 20, 9),
      );
    });

    testWidgets('status and category filters work together', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      expect(cardTitles(tester).length, 3);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Completed'));
      await tester.pumpAndSettle();
      expect(cardTitles(tester), <String>['Weekend BBQ']);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Party'));
      await tester.pumpAndSettle();
      expect(cardTitles(tester), <String>['Weekend BBQ']);

      await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
      await tester.pumpAndSettle();
      expect(cardTitles(tester), <String>['Weekend BBQ', 'Party leftovers']);

      await tester.tap(find.widgetWithText(ChoiceChip, 'All categories'));
      await tester.pumpAndSettle();
      expect(cardTitles(tester).length, 3);
    });

    testWidgets('sorts by budget and name with no-budget lists last', (
      WidgetTester tester,
    ) async {
      controller = GroceryListController(
        initialLists: <GroceryList>[
          GroceryList(
            id: '1',
            title: 'Zed high',
            budget: 500,
            estimatedTotal: 5,
            updatedAt: DateTime(2026, 11, 20),
          ),
          GroceryList(
            id: '2',
            title: 'Alpha low',
            budget: 100,
            estimatedTotal: 20,
            updatedAt: DateTime(2026, 11, 18),
          ),
          GroceryList(
            id: '3',
            title: 'No budget',
            estimatedTotal: 10,
            updatedAt: DateTime(2026, 11, 16),
          ),
        ],
        now: () => DateTime(2026, 11, 20, 9),
      );
      await pumpApp(tester);

      await tester.tap(find.byTooltip('Sort lists'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Budget (highest first)'));
      await tester.pumpAndSettle();
      expect(cardTitles(tester), <String>[
        'Zed high',
        'Alpha low',
        'No budget',
      ]);

      await tester.tap(find.byTooltip('Sort lists'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Name (A–Z)'));
      await tester.pumpAndSettle();
      expect(cardTitles(tester), <String>[
        'Alpha low',
        'No budget',
        'Zed high',
      ]);

      await tester.tap(find.byTooltip('Sort lists'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Estimated total (highest first)'));
      await tester.pumpAndSettle();
      expect(cardTitles(tester), <String>[
        'Alpha low',
        'No budget',
        'Zed high',
      ]);
    });
  });
}
