import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_scan/features/grocery_lists/domain/grocery_list.dart';

void main() {
  test('maps all six swipe transitions and their action labels', () {
    final Map<(GroceryListStatus, bool), GroceryListSwipeAction>
    expected = <(GroceryListStatus, bool), GroceryListSwipeAction>{
      (GroceryListStatus.active, true): GroceryListSwipeAction.complete,
      (GroceryListStatus.active, false): GroceryListSwipeAction.archive,
      (GroceryListStatus.completed, true): GroceryListSwipeAction.reactivate,
      (GroceryListStatus.completed, false): GroceryListSwipeAction.archive,
      (GroceryListStatus.archived, true): GroceryListSwipeAction.reactivate,
      (GroceryListStatus.archived, false): GroceryListSwipeAction.markCompleted,
    };

    for (final MapEntry<(GroceryListStatus, bool), GroceryListSwipeAction> entry
        in expected.entries) {
      final GroceryListSwipeAction action = entry.key.$1.swipeAction(
        toEnd: entry.key.$2,
      );
      expect(
        action,
        entry.value,
        reason: '${entry.key.$1}, toEnd=${entry.key.$2}',
      );
    }

    expect(
      <String>{
        for (final GroceryListSwipeAction action
            in GroceryListSwipeAction.values)
          action.label,
      },
      <String>{'Complete', 'Archive', 'Reactivate', 'Mark completed'},
    );
  });
}
