import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_scan/core/database/app_database.dart';
import 'package:grocery_scan/features/grocery_lists/data/drift_grocery_list_repository.dart';
import 'package:grocery_scan/features/grocery_lists/domain/grocery_category.dart';
import 'package:grocery_scan/features/grocery_lists/domain/grocery_list.dart';

Future<DriftGroceryListRepository> openRepository({
  DateTime Function()? now,
}) async {
  final AppDatabase database = AppDatabase(NativeDatabase.memory());
  addTearDown(() => database.close());
  final DriftGroceryListRepository repository = DriftGroceryListRepository(
    database,
    now: now,
  );
  await repository.getAllLists(); // Run first-run seeding.
  return repository;
}

void main() {
  final DateTime fixedNow = DateTime.utc(2026, 11, 21, 9);
  final DateTime nextNow = fixedNow.add(const Duration(hours: 2));

  test(
    'creates and reads a list with persisted category and centavos budget',
    () async {
      final DriftGroceryListRepository repository = await openRepository(
        now: () => fixedNow,
      );

      final GroceryList created = await repository.createList(
        title: '  Repository shop  ',
        category: GroceryCategory.weekly,
        budget: 1250.50,
      );
      final GroceryList? stored = await repository.getList(created.id);

      expect(created.id, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4')));
      expect(created.title, 'Repository shop');
      expect(created.category?.id, GroceryCategory.weekly.id);
      expect(created.budget, 1250.50);
      expect(created.updatedAt.toUtc(), fixedNow);
      expect(stored?.title, 'Repository shop');
      expect(stored?.category?.id, GroceryCategory.weekly.id);
      expect(stored?.budget, 1250.50);
    },
  );

  test('updates name, category, and budget while keeping the id', () async {
    DateTime now = fixedNow;
    final DriftGroceryListRepository repository = await openRepository(
      now: () => now,
    );
    final GroceryList created = await repository.createList(
      title: 'Before',
      category: GroceryCategory.weekly,
      budget: 100,
    );
    now = nextNow;

    final GroceryList? updated = await repository.updateList(
      created.id,
      title: ' After ',
      category: GroceryCategory.family,
      budget: 250.75,
    );
    final GroceryList? stored = await repository.getList(created.id);

    expect(updated?.id, created.id);
    expect(updated?.title, 'After');
    expect(updated?.category?.id, GroceryCategory.family.id);
    expect(updated?.budget, 250.75);
    expect(updated?.updatedAt.toUtc(), nextNow);
    expect(stored?.title, 'After');
    expect(stored?.category?.id, GroceryCategory.family.id);
    expect(stored?.budget, 250.75);
  });

  test('clears category and budget on update', () async {
    final DriftGroceryListRepository repository = await openRepository(
      now: () => fixedNow,
    );
    final GroceryList created = await repository.createList(
      title: 'With extras',
      category: GroceryCategory.party,
      budget: 500,
    );

    final GroceryList? updated = await repository.updateList(
      created.id,
      title: 'Without extras',
      category: null,
      budget: null,
    );

    expect(updated?.category, isNull);
    expect(updated?.budget, isNull);
  });

  test('persists status changes and refreshes updatedAt', () async {
    DateTime now = fixedNow;
    final DriftGroceryListRepository repository = await openRepository(
      now: () => now,
    );
    final GroceryList created = await repository.createList(title: 'Lifecycle');
    now = nextNow;

    final GroceryList? completed = await repository.setStatus(
      created.id,
      GroceryListStatus.completed,
    );
    final GroceryList? archived = await repository.setStatus(
      created.id,
      GroceryListStatus.archived,
    );
    now = nextNow.add(const Duration(hours: 2));
    final GroceryList? reactivated = await repository.setStatus(
      created.id,
      GroceryListStatus.active,
    );

    expect(completed?.status, GroceryListStatus.completed);
    expect(archived?.status, GroceryListStatus.archived);
    expect(
      (await repository.getList(created.id))?.status,
      GroceryListStatus.active,
    );
    expect(archived?.updatedAt.toUtc(), nextNow);
    expect(reactivated?.status, GroceryListStatus.active);
    expect(reactivated?.updatedAt.toUtc(), now);
  });

  test('deletes a list and reports unknown ids', () async {
    final DriftGroceryListRepository repository = await openRepository(
      now: () => fixedNow,
    );
    final GroceryList created = await repository.createList(title: 'Delete me');

    expect(await repository.deleteList(created.id), isTrue);
    expect(await repository.getList(created.id), isNull);
    expect(await repository.deleteList(created.id), isFalse);
  });

  test('persists custom categories and deduplicates case variants', () async {
    final DriftGroceryListRepository repository = await openRepository(
      now: () => fixedNow,
    );

    final GroceryCategory holiday = await repository.addCustomCategory(
      ' Holiday ',
    );
    final GroceryCategory duplicate = await repository.addCustomCategory(
      'holiday',
    );
    final GroceryCategory predefined = await repository.addCustomCategory(
      ' WEEKLY ',
    );
    final List<GroceryCategory> categories = await repository
        .watchCategories()
        .first;

    expect(holiday.name, 'Holiday');
    expect(holiday.isPredefined, isFalse);
    expect(duplicate.id, holiday.id);
    expect(predefined.id, GroceryCategory.weekly.id);
    expect(categories, hasLength(7));
    expect(
      categories.where((GroceryCategory category) => !category.isPredefined),
      hasLength(1),
    );
  });

  test('watchLists emits current data after a create', () async {
    final DriftGroceryListRepository repository = await openRepository(
      now: () => fixedNow,
    );
    final Stream<List<GroceryList>> lists = repository.watchLists();

    expect((await lists.first), hasLength(5));
    await repository.createList(title: 'Streamed list');
    expect((await lists.first), hasLength(6));
    expect(
      (await lists.first).map((GroceryList list) => list.title),
      contains('Streamed list'),
    );
  });
}
