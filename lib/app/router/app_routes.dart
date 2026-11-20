import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../features/grocery_lists/data/grocery_list_repository.dart';
import '../../features/grocery_lists/presentation/grocery_lists_screen.dart';
import '../../features/products/data/product_repository.dart';
import '../../features/products/presentation/products_screen.dart';
import '../../shared/widgets/coming_soon_view.dart';

/// Central place for route names.
abstract final class AppRoutes {
  static const String groceryLists = '/';
  static const String productCatalog = '/product-catalog';
  static const String productPrices = '/product-prices';
  static const String budget = '/budget';
  static const String statistics = '/statistics';
  static const String shoppingHistory = '/shopping-history';
  static const String settings = '/settings';

  static Route<dynamic> onGenerateRoute(
    RouteSettings settings, {
    GroceryListRepository? repository,
    ProductRepository? productRepository,
  }) {
    final String name = settings.name ?? groceryLists;

    if (name == groceryLists) {
      return MaterialPageRoute<dynamic>(
        settings: settings,
        builder: (_) => GroceryListsScreen(repository: repository),
      );
    }
    if (name == productCatalog) {
      return MaterialPageRoute<dynamic>(
        settings: settings,
        builder: (_) => ProductsScreen(repository: productRepository),
      );
    }

    return MaterialPageRoute<dynamic>(
      settings: settings,
      builder: (_) =>
          ComingSoonView(title: _featureTitles[name] ?? AppConstants.appName),
    );
  }

  static const Map<String, String> _featureTitles = <String, String>{
    productPrices: 'Product Prices',
    budget: 'Budget',
    statistics: 'Statistics',
    shoppingHistory: 'Shopping History',
    settings: 'Settings',
  };
}
