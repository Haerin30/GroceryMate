import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'core/database/app_database.dart';
import 'features/grocery_lists/data/drift_grocery_list_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final AppDatabase database = AppDatabase();
  final DriftGroceryListRepository repository = DriftGroceryListRepository(
    database,
  );

  runApp(GroceryScanApp(repository: repository));
}
