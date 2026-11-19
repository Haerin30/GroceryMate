import 'package:flutter/material.dart';

import 'app_routes.dart';

/// The six sections shown in the navigation drawer, in display order.
enum AppDestination {
  groceryLists,
  productPrices,
  budget,
  statistics,
  shoppingHistory,
  settings;
}

extension AppDestinationX on AppDestination {
  String get label => switch (this) {
        AppDestination.groceryLists => 'Grocery Lists',
        AppDestination.productPrices => 'Product Prices',
        AppDestination.budget => 'Budget',
        AppDestination.statistics => 'Statistics',
        AppDestination.shoppingHistory => 'Shopping History',
        AppDestination.settings => 'Settings',
      };

  IconData get icon => switch (this) {
        AppDestination.groceryLists => Icons.list_alt_outlined,
        AppDestination.productPrices => Icons.local_offer_outlined,
        AppDestination.budget => Icons.account_balance_wallet_outlined,
        AppDestination.statistics => Icons.bar_chart_outlined,
        AppDestination.shoppingHistory => Icons.history,
        AppDestination.settings => Icons.settings_outlined,
      };

  String get route => switch (this) {
        AppDestination.groceryLists => AppRoutes.groceryLists,
        AppDestination.productPrices => AppRoutes.productPrices,
        AppDestination.budget => AppRoutes.budget,
        AppDestination.statistics => AppRoutes.statistics,
        AppDestination.shoppingHistory => AppRoutes.shoppingHistory,
        AppDestination.settings => AppRoutes.settings,
      };
}
