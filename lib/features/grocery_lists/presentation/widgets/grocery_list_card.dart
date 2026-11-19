import 'package:flutter/material.dart';

import '../../domain/grocery_list.dart';

/// One grocery list in the overview. Tapping is delegated to the parent so the
/// card stays reusable when real navigation is added.
class GroceryListCard extends StatelessWidget {
  const GroceryListCard({
    super.key,
    required this.groceryList,
    required this.onTap,
  });

  final GroceryList groceryList;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: colors.primaryContainer,
          foregroundColor: colors.onPrimaryContainer,
          child: const Icon(Icons.shopping_basket_outlined),
        ),
        title: Text(
          groceryList.title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text('${groceryList.category}  •  ${groceryList.itemCount} items'),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            _StatusBadge(status: groceryList.status),
            const SizedBox(height: 6),
            Text(
              '\$${groceryList.estimatedTotal.toStringAsFixed(2)}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final GroceryListStatus status;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final (Color background, Color foreground) = switch (status) {
      GroceryListStatus.active => (
          colors.primaryContainer,
          colors.onPrimaryContainer
        ),
      GroceryListStatus.completed => (
          colors.secondaryContainer,
          colors.onSecondaryContainer
        ),
      GroceryListStatus.archived => (
          colors.surfaceContainerHighest,
          colors.onSurfaceVariant
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}
