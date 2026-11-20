import '../domain/grocery_category.dart';
import '../domain/grocery_list.dart';

/// Persistence boundary used by the state controller.
///
/// Presentation code never talks to Drift directly, so the repository can be
/// backed by SQLite in the app and by a fake in isolated tests.
abstract class GroceryListRepository {
  Stream<List<GroceryList>> watchLists();
  Stream<List<GroceryCategory>> watchCategories();

  Future<List<GroceryList>> getAllLists();
  Future<GroceryList?> getList(String id);

  Future<GroceryList> createList({
    required String title,
    GroceryCategory? category,
    double? budget,
    String? newCategoryName,
  });

  Future<GroceryList?> updateList(
    String id, {
    required String title,
    GroceryCategory? category,
    required double? budget,
    String? newCategoryName,
  });

  Future<bool> deleteList(String id);

  Future<GroceryList?> setStatus(String id, GroceryListStatus status);

  Future<GroceryCategory> addCustomCategory(String name);
}
