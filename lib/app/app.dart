import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import 'router/app_routes.dart';
import 'theme/app_theme.dart';

/// Root widget of GroceryMate.
///
/// Keeping global configuration here (title, themes, routing) makes it easy to
/// add a Riverpod `ProviderScope` around this widget later without touching the
/// feature screens.
class GroceryScanApp extends StatelessWidget {
  const GroceryScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      initialRoute: AppRoutes.groceryLists,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
