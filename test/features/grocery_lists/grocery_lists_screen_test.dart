import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_scan/features/grocery_lists/domain/grocery_category.dart';
import 'package:grocery_scan/features/grocery_lists/domain/grocery_list.dart';
import 'package:grocery_scan/features/grocery_lists/presentation/grocery_lists_screen.dart';
import 'package:grocery_scan/features/grocery_lists/presentation/widgets/grocery_list_card.dart';
import 'package:grocery_scan/features/grocery_lists/state/grocery_list_controller.dart';

/// Records status writes and can simulate a repository failure without pulling
/// Drift into every widget test.
class TrackingController extends GroceryListController {
  TrackingController({
    required List<GroceryList> initialLists,
    this.failStatusUpdate = false,
  }) : super(initialLists: initialLists, now: () => DateTime(2026, 11, 20, 9));

  final bool failStatusUpdate;
  final List<GroceryListStatus> statusCalls = <GroceryListStatus>[];

  @override
  Future<GroceryList?> setStatus(String id, GroceryListStatus status) async {
    statusCalls.add(status);
    if (failStatusUpdate) {
      throw StateError('Simulated SQLite write failure');
    }
    return super.setStatus(id, status);
  }
}

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

  Future<void> pumpApp(
    WidgetTester tester, {
    Size size = const Size(800, 1600),
  }) async {
    // A tall surface keeps every ListTile built so card-order assertions are
    // not dependent on offscreen ListView laziness. Swipe tests opt into a
    // phone-sized surface so the drag distance stays within the card.
    await tester.binding.setSurfaceSize(size);
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

  Finder cardWithId(String id) => find.byKey(Key('grocery-list-$id'));

  /// Explicit pointer moves give the horizontal recognizer a full drag, which
  /// is closer to a real finger than the instantaneous [WidgetTester.drag].
  Future<void> swipeCard(
    WidgetTester tester,
    String id,
    Offset distance,
  ) async {
    expect(cardWithId(id), findsOneWidget);
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(cardWithId(id)),
    );
    const int steps = 10;
    for (int step = 1; step <= steps; step++) {
      await gesture.moveBy(distance / steps.toDouble());
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

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

  group('collapsible categories', () {
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
            updatedAt: DateTime(2026, 11, 10),
          ),
        ],
        now: () => DateTime(2026, 11, 20, 9),
      );
    });

    testWidgets('collapses to the selected label and expands without losing '
        'the combined filters', (WidgetTester tester) async {
      await pumpApp(tester);

      // Expanded is the first-launch default.
      expect(find.widgetWithText(ChoiceChip, 'All categories'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'No category'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Completed'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Party'));
      await tester.pumpAndSettle();
      expect(cardTitles(tester), <String>['Weekend BBQ']);

      await tester.tap(find.byKey(const Key('category-section-toggle')));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ChoiceChip, 'All categories'), findsNothing);
      expect(find.text('Party'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Completed'))
            .selected,
        isTrue,
      );
      expect(cardTitles(tester), <String>['Weekend BBQ']);

      await tester.tap(find.byKey(const Key('category-section-toggle')));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ChoiceChip, 'All categories'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Party'))
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Completed'))
            .selected,
        isTrue,
      );
      expect(cardTitles(tester), <String>['Weekend BBQ']);
    });

    testWidgets('repeated collapse and expand cycles keep working with a '
        'selected category', (WidgetTester tester) async {
      await pumpApp(tester);
      expect(find.widgetWithText(ChoiceChip, 'All categories'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Party'));
      await tester.pumpAndSettle();

      final Finder toggle = find.byKey(const Key('category-section-toggle'));
      for (int cycle = 0; cycle < 3; cycle++) {
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(ChoiceChip, 'All categories'),
          findsNothing,
          reason: 'chips still visible after collapsing in cycle $cycle',
        );
        expect(find.text('Party'), findsOneWidget);

        await tester.tap(toggle);
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(ChoiceChip, 'All categories'),
          findsOneWidget,
          reason: 'expanded chips missing after cycle $cycle',
        );
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Party'))
              .selected,
          isTrue,
        );
      }

      // A second tap during the collapse animation must still reach the same
      // compact header and leave the chips expanded.
      await tester.tap(toggle);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ChoiceChip, 'All categories'), findsOneWidget);
    });

    testWidgets('stays inside the vertical scroll view on a small phone', (
      WidgetTester tester,
    ) async {
      controller = GroceryListController(
        initialLists: <GroceryList>[
          for (int index = 1; index <= 6; index++)
            GroceryList(
              id: '$index',
              title: 'List $index',
              category: GroceryCategory.weekly,
              status: GroceryListStatus.active,
              updatedAt: DateTime(2026, 11, 20),
            ),
        ],
        now: () => DateTime(2026, 11, 20, 9),
      );
      await pumpApp(tester, size: const Size(360, 640));
      final Finder toggle = find.byKey(const Key('category-section-toggle'));

      expect(
        find.descendant(of: find.byType(CustomScrollView), matching: toggle),
        findsOneWidget,
      );
      final double initialTop = tester.getTopLeft(toggle).dy;
      expect(initialTop, greaterThanOrEqualTo(0));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -180));
      await tester.pumpAndSettle();

      // The header scrolls with the cards instead of staying pinned.
      expect(initialTop, greaterThanOrEqualTo(0));
      expect(tester.getTopLeft(toggle).dy, lessThan(initialTop));
      expect(find.byType(GroceryListCard), findsWidgets);
    });
  });

  group('swipe status transitions', () {
    const List<
      ({
        String from,
        GroceryListStatus status,
        double dx,
        GroceryListStatus expected,
      })
    >
    transitions =
        <
          ({
            String from,
            GroceryListStatus status,
            double dx,
            GroceryListStatus expected,
          })
        >[
          (
            from: 'active right',
            status: GroceryListStatus.active,
            dx: 140,
            expected: GroceryListStatus.completed,
          ),
          (
            from: 'active left',
            status: GroceryListStatus.active,
            dx: -140,
            expected: GroceryListStatus.archived,
          ),
          (
            from: 'completed right',
            status: GroceryListStatus.completed,
            dx: 140,
            expected: GroceryListStatus.active,
          ),
          (
            from: 'completed left',
            status: GroceryListStatus.completed,
            dx: -140,
            expected: GroceryListStatus.archived,
          ),
          (
            from: 'archived right',
            status: GroceryListStatus.archived,
            dx: 140,
            expected: GroceryListStatus.active,
          ),
          (
            from: 'archived left',
            status: GroceryListStatus.archived,
            dx: -140,
            expected: GroceryListStatus.completed,
          ),
        ];

    for (final transition in transitions) {
      testWidgets('${transition.from} → ${transition.expected.label}', (
        WidgetTester tester,
      ) async {
        controller = GroceryListController(
          initialLists: <GroceryList>[
            GroceryList(
              id: 'swipe',
              title: 'Swipe target',
              category: GroceryCategory.weekly,
              status: transition.status,
              updatedAt: DateTime(2026, 11, 20),
            ),
          ],
          now: () => DateTime(2026, 11, 20, 9),
        );
        await pumpApp(tester, size: const Size(400, 900));

        await swipeCard(tester, 'swipe', Offset(transition.dx, 0));

        expect(controller.lists, hasLength(1));
        expect(controller.lists.single.id, 'swipe');
        expect(controller.lists.single.status, transition.expected);
        expect(
          find.descendant(
            of: cardWithId('swipe'),
            matching: find.text(transition.expected.label),
          ),
          findsOneWidget,
        );
        expect(
          find.text('Marked as ${transition.expected.label.toLowerCase()}.'),
          findsOneWidget,
        );
      });
    }

    testWidgets('shows a distinct icon and label while swiping left', (
      WidgetTester tester,
    ) async {
      controller = GroceryListController(
        initialLists: <GroceryList>[
          GroceryList(
            id: 'swipe',
            title: 'Swipe target',
            status: GroceryListStatus.active,
            updatedAt: DateTime(2026, 11, 20),
          ),
        ],
        now: () => DateTime(2026, 11, 20, 9),
      );
      await pumpApp(tester, size: const Size(400, 900));

      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(cardWithId('swipe')),
      );
      for (int step = 0; step < 7; step++) {
        await gesture.moveBy(const Offset(-10, 0));
        await tester.pump();
      }

      expect(find.text('Archive'), findsOneWidget);
      expect(find.byIcon(Icons.archive_outlined), findsOneWidget);
      expect(controller.lists.single.status, GroceryListStatus.active);

      await gesture.moveBy(const Offset(-70, 0));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(controller.lists.single.status, GroceryListStatus.archived);
    });

    testWidgets('requires the commit threshold and ignores vertical drags', (
      WidgetTester tester,
    ) async {
      controller = GroceryListController(
        initialLists: <GroceryList>[
          GroceryList(
            id: 'swipe',
            title: 'Swipe target',
            status: GroceryListStatus.active,
            updatedAt: DateTime(2026, 11, 20),
          ),
        ],
        now: () => DateTime(2026, 11, 20, 9),
      );
      await pumpApp(tester, size: const Size(400, 900));

      await swipeCard(tester, 'swipe', const Offset(40, 0));
      expect(controller.lists.single.status, GroceryListStatus.active);
      expect(find.text('Marked as completed.'), findsNothing);

      await swipeCard(tester, 'swipe', const Offset(0, -220));
      expect(controller.lists.single.status, GroceryListStatus.active);
      expect(find.text('Marked as completed.'), findsNothing);

      await swipeCard(tester, 'swipe', const Offset(140, 0));
      expect(controller.lists.single.status, GroceryListStatus.completed);
    });

    testWidgets('keeps the card and reports failure when persistence throws', (
      WidgetTester tester,
    ) async {
      controller = TrackingController(
        initialLists: <GroceryList>[
          GroceryList(
            id: 'swipe',
            title: 'Swipe target',
            status: GroceryListStatus.active,
            updatedAt: DateTime(2026, 11, 20),
          ),
        ],
        failStatusUpdate: true,
      );
      await pumpApp(tester, size: const Size(400, 900));

      await swipeCard(tester, 'swipe', const Offset(140, 0));

      expect(controller.lists.single.status, GroceryListStatus.active);
      expect(
        (controller as TrackingController).statusCalls,
        <GroceryListStatus>[GroceryListStatus.completed],
      );
      expect(cardWithId('swipe'), findsOneWidget);
      expect(find.text('Could not update status.'), findsOneWidget);
      expect(find.text('Marked as completed.'), findsNothing);
      expect(find.widgetWithText(SnackBarAction, 'Undo'), findsNothing);
    });

    testWidgets('undo restores the previous status through the controller', (
      WidgetTester tester,
    ) async {
      controller = TrackingController(
        initialLists: <GroceryList>[
          GroceryList(
            id: 'swipe',
            title: 'Swipe target',
            status: GroceryListStatus.active,
            updatedAt: DateTime(2026, 11, 20),
          ),
        ],
      );
      await pumpApp(tester, size: const Size(400, 900));

      await swipeCard(tester, 'swipe', const Offset(140, 0));
      expect(controller.lists.single.status, GroceryListStatus.completed);

      await tester.tap(find.widgetWithText(SnackBarAction, 'Undo'));
      await tester.pumpAndSettle();

      expect(controller.lists.single.status, GroceryListStatus.active);
      expect(
        (controller as TrackingController).statusCalls,
        <GroceryListStatus>[
          GroceryListStatus.completed,
          GroceryListStatus.active,
        ],
      );
      expect(
        find.descendant(of: cardWithId('swipe'), matching: find.text('Active')),
        findsOneWidget,
      );
      expect(find.text('Status restored.'), findsOneWidget);
    });
  });
}
