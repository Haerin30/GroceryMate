import 'package:flutter/foundation.dart';

import '../data/sample_grocery_lists.dart';
import '../domain/grocery_category.dart';
import '../domain/grocery_list.dart';

/// In-memory state and business logic for Grocery List Management.
///
/// Widgets talk to this controller instead of mutating lists themselves. It is
/// deliberately persistence-free; a repository-backed notifier can replace it
/// later without changing the feature's widgets.
class GroceryListController extends ChangeNotifier {
  GroceryListController({
    List<GroceryList>? initialLists,
    List<GroceryCategory>? customCategories,
    DateTime Function()? now,
  }) : _lists = List<GroceryList>.of(initialLists ?? sampleGroceryLists),
       _customCategories = List<GroceryCategory>.of(
         customCategories ?? const <GroceryCategory>[],
       ),
       _now = now ?? DateTime.now;

  final List<GroceryList> _lists;
  final List<GroceryCategory> _customCategories;
  final DateTime Function() _now;
  int _nextId = 1;

  List<GroceryList> get lists => List<GroceryList>.unmodifiable(_lists);
  List<GroceryCategory> get customCategories =>
      List<GroceryCategory>.unmodifiable(_customCategories);
  List<GroceryCategory> get availableCategories => <GroceryCategory>[
    ...GroceryCategory.predefined,
    ..._customCategories,
  ];

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
  GroceryCategory addCustomCategory(String name) {
    final String cleanName =
        GroceryCategory.cleanName(name) ??
        (throw ArgumentError.value(name, 'name', 'Category name is required'));
    final GroceryCategory? existing = findCategory(cleanName);
    if (existing != null) return existing;

    final GroceryCategory category = GroceryCategory(
      id: _newCategoryId(),
      name: cleanName,
    );
    _customCategories.add(category);
    notifyListeners();
    return category;
  }

  /// Creates a new active list and returns it.
  GroceryList addList({
    required String title,
    GroceryCategory? category,
    double? budget,
    String? newCategoryName,
  }) {
    final GroceryList list = GroceryList(
      id: _newListId(),
      title: _cleanTitle(title),
      category: _resolveCategory(category, newCategoryName),
      status: GroceryListStatus.active,
      budget: _cleanBudget(budget),
      updatedAt: _now(),
    );
    _lists.add(list);
    notifyListeners();
    return list;
  }

  /// Edits name/category/budget while keeping the id, status, and item data.
  /// Returns `null` when the id is unknown.
  GroceryList? updateList(
    String id, {
    required String title,
    GroceryCategory? category,
    required double? budget,
    String? newCategoryName,
  }) {
    final int index = _indexOf(id);
    if (index == -1) return null;

    final GroceryList previous = _lists[index];
    final GroceryList updated = GroceryList(
      id: previous.id,
      title: _cleanTitle(title),
      category: _resolveCategory(category, newCategoryName),
      status: previous.status,
      itemCount: previous.itemCount,
      estimatedTotal: previous.estimatedTotal,
      budget: _cleanBudget(budget),
      updatedAt: _now(),
    );
    _lists[index] = updated;
    notifyListeners();
    return updated;
  }

  /// Changes a list's status and refreshes its last-modified timestamp.
  GroceryList? setStatus(String id, GroceryListStatus status) {
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
    notifyListeners();
    return updated;
  }

  /// Removes a list. Returns `false` when the id is unknown.
  bool deleteList(String id) {
    final int before = _lists.length;
    _lists.removeWhere((GroceryList list) => list.id == id);
    final bool removed = _lists.length < before;
    if (removed) notifyListeners();
    return removed;
  }

  int _indexOf(String id) =>
      _lists.indexWhere((GroceryList list) => list.id == id);

  String _newListId() {
    String id;
    do {
      id = 'list-${_nextId++}';
    } while (_indexOf(id) != -1);
    return id;
  }

  String _newCategoryId() {
    int candidate = _customCategories.length + 1;
    while (availableCategories.any(
      (GroceryCategory item) => item.id == 'custom-$candidate',
    )) {
      candidate++;
    }
    return 'custom-$candidate';
  }

  String _cleanTitle(String title) {
    final String trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(title, 'title', 'List name is required');
    }
    return trimmed;
  }

  double? _cleanBudget(double? budget) {
    if (budget == null) return null;
    if (!budget.isFinite || budget < 0) {
      throw ArgumentError.value(
        budget,
        'budget',
        'Budget must be a non-negative number',
      );
    }
    return budget;
  }

  /// Resolves the form's category choice. A new category name wins over an
  /// existing selection, mirroring what the form shows to the user.
  GroceryCategory? _resolveCategory(
    GroceryCategory? category,
    String? newCategoryName,
  ) {
    final String? cleanName = GroceryCategory.cleanName(newCategoryName ?? '');
    if (cleanName == null) return category;

    final GroceryCategory? existing = findCategory(cleanName);
    if (existing != null) return existing;

    final GroceryCategory created = GroceryCategory(
      id: _newCategoryId(),
      name: cleanName,
    );
    _customCategories.add(created);
    return created;
  }
}
