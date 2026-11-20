import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../features/grocery_lists/data/grocery_list_repository.dart';
import '../features/products/data/product_repository.dart';
import 'router/app_routes.dart';
import 'theme/app_theme.dart';

/// Root widget of GroceryMate.
class GroceryScanApp extends StatelessWidget {
  const GroceryScanApp({super.key, this.repository, this.productRepository});

  /// Supplied by `main()`; widget tests can omit both to use in-memory data.
  final GroceryListRepository? repository;

  /// Product Catalog persistence boundary.
  final ProductRepository? productRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      initialRoute: AppRoutes.groceryLists,
      onGenerateRoute: (RouteSettings settings) => AppRoutes.onGenerateRoute(
        settings,
        repository: repository,
        productRepository: productRepository,
      ),
    );
  }
}
