import 'package:drift/drift.dart';

import '../../features/grocery_lists/domain/grocery_list.dart';

/// Maps the domain status to a readable TEXT value in SQLite.
class GroceryListStatusConverter
    extends TypeConverter<GroceryListStatus, String> {
  const GroceryListStatusConverter();

  @override
  GroceryListStatus fromSql(String fromDb) => switch (fromDb) {
    'active' => GroceryListStatus.active,
    'completed' => GroceryListStatus.completed,
    'archived' => GroceryListStatus.archived,
    _ => throw ArgumentError.value(
      fromDb,
      'status',
      'Unknown grocery list status',
    ),
  };

  @override
  String toSql(GroceryListStatus value) => value.storageValue;
}
