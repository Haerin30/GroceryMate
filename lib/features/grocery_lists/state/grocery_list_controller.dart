import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/utils/id_generator.dart';
import '../data/grocery_list_repository.dart';
import '../data/sample_grocery_lists.dart';
import '../domain/grocery_category.dart';
import '../domain/grocery_list.dart';
import '../domain/grocery_list_input.dart';

/// ChangeNotifier used by the screens.
///
/// When a [repository] is supplied, stream subscriptions keep the visible data
/// in sync with SQLite and every mutation is delegated to the repository.
/// Without one, the controller keeps the same data in memory, which keeps the
/// focused widget tests lightweight and deterministic.
class GroceryListController extends ChangeNotifier {
  GroceryListController({
    GroceryListRepository? repository,
    List<GroceryList>? initialLists,
    List<GroceryCategory>? customCategories,
    DateTime Function()? now,
  }) : _repository = repository,
       _lists = List<GroceryList>.of(
         initialLists ??
             (repository == null ? sampleGroceryLists : const <GroceryList>[]),
       ),
       _customCategories = List<GroceryCategory>.of(
         customCategories ?? const <GroceryCategory>[],
       ),
       _now = now ?? DateTime.now,
       _categories = List<GroceryCategory>.of(GroceryCategory.predefined) {
    if (repository != null) {
      _listenTo(repository);
    }
  }

  final GroceryListRepository? _repository;
  final DateTime Function() _now;
  final List<GroceryList> _lists;
  final List<GroceryCategory> _customCategories;
  List<GroceryCategory> _categories;
  StreamSubscription<List<GroceryList>>? _listsSubscription;
  StreamSubscription<List<GroceryCategory>>? _categoriesSubscription;
  bool _disposed = false;

  List<GroceryList> get lists => List<GroceryList>.unmodifiable(_lists);

  List<GroceryCategory> get customCategories =>
      List<GroceryCategory>.unmodifiable(_customCategories);

  List<GroceryCategory> get availableCategories => List<GroceryCategory>.of(
    _repository == null
        ? <GroceryCategory>[...GroceryCategory.predefined, ..._customCategories]
        : _categories,
  );

  /// Finds a predefined or custom category by name, ignoring case and
  /// surrounding whitespace. Used to prevent duplicate categories.
  GroceryCategory? findCategory(String name) {
    final String key = GroceryCategory.normalizeName(name);
    if (key.isEmpty) return null;
    for (final GroceryCategory category in availableCategories) {
      if (GroceryCategory.normalizeName(category.name) == key) {
        return category;
      }
    }
    return null;
  }

  /// Adds a custom category, or returns the existing match when the name is a
  /// duplicate (case- and whitespace-insensitive).
  Future<GroceryCategory> addCustomCategory(String name) async {
    final String cleanName =
        GroceryCategory.cleanName(name) ??
        (throw ArgumentError.value(name, 'name', 'Category name is required'));

    if (_repository != null) {
      return _repository.addCustomCategory(cleanName);
    }

    final GroceryCategory? existing = findCategory(cleanName);
    if (existing != null) return existing;

    final GroceryCategory category = _makeCustomCategory(cleanName);
    _customCategories.add(category);
    _notify();
    return category;
  }

  /// Creates a new active list and returns it.
  Future<GroceryList> addList({
    required String title,
    GroceryCategory? category,
    double? budget,
    String? newCategoryName,
  }) async {
    if (_repository != null) {
      return _repository.createList(
        title: title,
        category: category,
        budget: budget,
        newCategoryName: newCategoryName,
      );
    }

    final GroceryList list = GroceryList(
      id: IdGenerator.uuidV4(),
      title: GroceryListInput.cleanTitle(title),
      category: _resolveLocalCategory(category, newCategoryName),
      status: GroceryListStatus.active,
      budget: GroceryListInput.cleanBudget(budget),
      updatedAt: _now(),
    );
    _lists.add(list);
    _notify();
    return list;
  }

  /// Edits name/category/budget while keeping the id, status, and item data.
  /// Returns `null` when the id is unknown.
  Future<GroceryList?> updateList(
    String id, {
    required String title,
    GroceryCategory? category,
    required double? budget,
    String? newCategoryName,
  }) async {
    if (_repository != null) {
      return _repository.updateList(
        id,
        title: title,
        category: category,
        budget: budget,
        newCategoryName: newCategoryName,
      );
    }

    final int index = _indexOf(id);
    if (index == -1) return null;

    final GroceryList previous = _lists[index];
    final GroceryList updated = GroceryList(
      id: previous.id,
      title: GroceryListInput.cleanTitle(title),
      category: _resolveLocalCategory(category, newCategoryName),
      status: previous.status,
      itemCount: previous.itemCount,
      estimatedTotal: previous.estimatedTotal,
      budget: GroceryListInput.cleanBudget(budget),
      updatedAt: _now(),
    );
    _lists[index] = updated;
    _notify();
    return updated;
  }

  /// Changes a list's status and refreshes its last-modified timestamp.
  Future<GroceryList?> setStatus(String id, GroceryListStatus status) async {
    if (_repository != null) {
      return _repository.setStatus(id, status);
    }

    final int index = _indexOf(id);
    if (index == -1) return null;

    final GroceryList previous = _lists[index];
    if (previous.status == status) return previous;

    final GroceryList updated = GroceryList(
      id: previous.id,
      title: previous.title,
      category: previous.category,
      status: status,
      itemCount: previous.itemCount,
      estimatedTotal: previous.estimatedTotal,
      budget: previous.budget,
      updatedAt: _now(),
    );
    _lists[index] = updated;
    _notify();
    return updated;
  }

  /// Removes a list. Returns `false` when the id is unknown.
  Future<bool> deleteList(String id) async {
    if (_repository != null) {
      return _repository.deleteList(id);
    }

    final int before = _lists.length;
    _lists.removeWhere((GroceryList list) => list.id == id);
    final bool removed = _lists.length < before;
    if (removed) _notify();
    return removed;
  }

  void _listenTo(GroceryListRepository repository) {
    _listsSubscription = repository.watchLists().listen((
      List<GroceryList> lists,
    ) {
      _lists
        ..clear()
        ..addAll(lists);
      _notify();
    });
    _categoriesSubscription = repository.watchCategories().listen((
      List<GroceryCategory> categories,
    ) {
      _categories = List<GroceryCategory>.of(categories);
      _customCategories
        ..clear()
        ..addAll(
          categories.where(
            (GroceryCategory category) => !category.isPredefined,
          ),
        );
      _notify();
    });
  }

  int _indexOf(String id) =>
      _lists.indexWhere((GroceryList list) => list.id == id);

  GroceryCategory _makeCustomCategory(String cleanName) {
    final int nextSortOrder = _categories.fold<int>(
      0,
      (int max, GroceryCategory category) =>
          category.sortOrder > max ? category.sortOrder : max,
    );
    return GroceryCategory(
      id: IdGenerator.uuidV4(),
      name: cleanName,
      sortOrder: nextSortOrder + 1,
    );
  }

  /// Resolves the form's category choice. A new category name wins over an
  /// existing selection, mirroring what the form shows to the user.
  GroceryCategory? _resolveLocalCategory(
    GroceryCategory? category,
    String? newCategoryName,
  ) {
    final String? cleanName = GroceryCategory.cleanName(newCategoryName ?? '');
    if (cleanName == null) return category;

    final GroceryCategory? existing = findCategory(cleanName);
    if (existing != null) return existing;

    final GroceryCategory created = _makeCustomCategory(cleanName);
    _customCategories.add(created);
    return created;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _listsSubscription?.cancel();
    _categoriesSubscription?.cancel();
    super.dispose();
  }
}
