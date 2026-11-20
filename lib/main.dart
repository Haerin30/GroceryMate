import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'core/database/app_database.dart';
import 'features/grocery_lists/data/drift_grocery_list_repository.dart';
import 'features/products/data/drift_product_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final AppDatabase database = AppDatabase();
  final DriftGroceryListRepository repository = DriftGroceryListRepository(
    database,
  );
  final DriftProductRepository productRepository = DriftProductRepository(
    database,
  );

  runApp(
    GroceryScanApp(
      repository: repository,
      productRepository: productRepository,
    ),
  );
}
