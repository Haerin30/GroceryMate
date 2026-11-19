import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_scan/features/grocery_lists/domain/grocery_category.dart';
import 'package:grocery_scan/features/grocery_lists/domain/grocery_list.dart';
import 'package:grocery_scan/features/grocery_lists/state/grocery_list_controller.dart';

void main() {
  late DateTime now;
  late GroceryListController controller;

  setUp(() {
    now = DateTime(2026, 11, 20, 9);
    controller = GroceryListController(
      initialLists: const <GroceryList>[],
      now: () => now,
    );
  });

  group('create', () {
    test('creates a list with trimmed name, category, and budget', () {
      final GroceryList list = controller.addList(
        title: '  Weekly shop  ',
        category: GroceryCategory.weekly,
        budget: 1250.50,
      );

      expect(list.id, isNotEmpty);
      expect(list.title, 'Weekly shop');
      expect(list.category, GroceryCategory.weekly);
      expect(list.budget, 1250.50);
      expect(list.status, GroceryListStatus.active);
      expect(list.itemCount, 0);
      expect(list.estimatedTotal, 0);
      expect(list.updatedAt, now);
      expect(controller.lists, <GroceryList>[list]);
    });

    test('allows no category and no budget', () {
      final GroceryList list = controller.addList(title: 'Errands');

      expect(list.category, isNull);
      expect(list.budget, isNull);
    });

    test('rejects an empty or whitespace-only name', () {
      expect(() => controller.addList(title: '   '), throwsArgumentError);
      expect(controller.lists, isEmpty);
    });

    test('rejects negative, non-numeric, and non-finite budgets', () {
      expect(
        () => controller.addList(title: 'A', budget: -0.01),
        throwsArgumentError,
      );
      expect(
        () => controller.addList(title: 'B', budget: double.nan),
        throwsArgumentError,
      );
      expect(
        () => controller.addList(title: 'C', budget: double.infinity),
        throwsArgumentError,
      );
      expect(controller.lists, isEmpty);
    });

    test('creates a custom category together with the list', () {
      final GroceryList list = controller.addList(
        title: 'Holiday supplies',
        newCategoryName: '  Holiday  ',
      );

      expect(list.category?.name, 'Holiday');
      expect(list.category?.isPredefined, isFalse);
      expect(controller.customCategories, hasLength(1));
    });
  });

  group('categories', () {
    test('offers all predefined categories', () {
      expect(
        controller.availableCategories.map((GroceryCategory c) => c.name),
        containsAll(<String>[
          'Weekly',
          'Monthly',
          'Personal',
          'Family',
          'Party',
          'Other',
        ]),
      );
    });

    test('creates custom categories and prevents duplicates', () {
      final GroceryCategory holiday = controller.addCustomCategory(' Holiday ');
      final GroceryCategory same = controller.addCustomCategory('holiday');
      final GroceryCategory weekly = controller.addCustomCategory(' WEEKLY ');

      expect(holiday.name, 'Holiday');
      expect(same.id, holiday.id);
      expect(weekly.id, GroceryCategory.weekly.id);
      expect(weekly.isPredefined, isTrue);
      expect(controller.customCategories, hasLength(1));
      expect(controller.findCategory('  hOlIdAy '), holiday);
      expect(controller.findCategory('   '), isNull);
    });

    test('reuses a duplicate custom name when saving a list', () {
      controller.addCustomCategory('Garden');
      final GroceryList list = controller.addList(
        title: 'Seeds',
        newCategoryName: 'garden',
      );

      expect(list.category?.name, 'Garden');
      expect(controller.customCategories, hasLength(1));
    });
  });

  group('update', () {
    test('edits name, category, and budget while keeping a stable id', () {
      final GroceryList list = controller.addList(
        title: 'Old name',
        category: GroceryCategory.weekly,
        budget: 100,
      );
      now = now.add(const Duration(days: 1));

      final GroceryList? updated = controller.updateList(
        list.id,
        title: ' New name ',
        category: GroceryCategory.family,
        budget: 250,
      );

      expect(updated?.id, list.id);
      expect(updated?.title, 'New name');
      expect(updated?.category, GroceryCategory.family);
      expect(updated?.budget, 250);
      expect(updated?.updatedAt, now);
      expect(controller.lists.single.title, 'New name');
    });

    test('can clear the category and budget', () {
      final GroceryList list = controller.addList(
        title: 'With extras',
        category: GroceryCategory.party,
        budget: 500,
      );

      final GroceryList? updated = controller.updateList(
        list.id,
        title: 'Without extras',
        category: null,
        budget: null,
      );

      expect(updated?.category, isNull);
      expect(updated?.budget, isNull);
    });

    test('returns null for an unknown id', () {
      expect(
        controller.updateList('missing', title: 'X', budget: null),
        isNull,
      );
    });
  });

  group('delete', () {
    test('removes a list and reports unknown ids', () {
      final GroceryList list = controller.addList(title: 'To delete');

      expect(controller.deleteList(list.id), isTrue);
      expect(controller.lists, isEmpty);
      expect(controller.deleteList(list.id), isFalse);
    });
  });

  group('status', () {
    test('changes status and refreshes the last-modified timestamp', () {
      final GroceryList list = controller.addList(title: 'Status test');
      now = now.add(const Duration(hours: 2));

      final GroceryList? completed = controller.setStatus(
        list.id,
        GroceryListStatus.completed,
      );

      expect(completed?.status, GroceryListStatus.completed);
      expect(completed?.updatedAt, now);
      expect(controller.lists.single.status, GroceryListStatus.completed);

      final DateTime changedAt = now;
      now = now.add(const Duration(hours: 2));
      final GroceryList? unchanged = controller.setStatus(
        list.id,
        GroceryListStatus.completed,
      );
      expect(unchanged?.updatedAt, changedAt);
    });

    test('supports archived and active statuses', () {
      final GroceryList list = controller.addList(title: 'Lifecycle');

      expect(
        controller.setStatus(list.id, GroceryListStatus.archived)?.status,
        GroceryListStatus.archived,
      );
      expect(
        controller.setStatus(list.id, GroceryListStatus.active)?.status,
        GroceryListStatus.active,
      );
    });
  });
}
