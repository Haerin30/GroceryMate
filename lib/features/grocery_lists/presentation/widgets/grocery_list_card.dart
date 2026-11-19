import 'package:flutter/material.dart';

import '../../domain/grocery_list.dart';

enum _CardAction { edit, active, completed, archived, delete }

/// One grocery list in the overview. Editing, status changes, and deletion are
/// delegated to the parent so the card stays reusable.
class GroceryListCard extends StatelessWidget {
  const GroceryListCard({
    super.key,
    required this.groceryList,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChanged,
  });

  final GroceryList groceryList;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<GroceryListStatus> onStatusChanged;

  void _handleAction(_CardAction action) {
    switch (action) {
      case _CardAction.edit:
        onEdit();
      case _CardAction.active:
        onStatusChanged(GroceryListStatus.active);
      case _CardAction.completed:
        onStatusChanged(GroceryListStatus.completed);
      case _CardAction.archived:
        onStatusChanged(GroceryListStatus.archived);
      case _CardAction.delete:
        onDelete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final String categoryLabel = groceryList.category?.name ?? 'No category';

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: colors.primaryContainer,
          foregroundColor: colors.onPrimaryContainer,
          child: const Icon(Icons.shopping_basket_outlined),
        ),
        title: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                groceryList.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _StatusBadge(status: groceryList.status),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('$categoryLabel  •  ${groceryList.itemCount} items'),
              const SizedBox(height: 2),
              Text(
                groceryList.budget == null
                    ? 'Budget: Not set'
                    : 'Budget: ${_formatMoney(groceryList.budget!)}',
                style: TextStyle(
                  color: groceryList.budget == null
                      ? colors.onSurfaceVariant
                      : colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Estimated total: ${_formatMoney(groceryList.estimatedTotal)}',
              ),
              const SizedBox(height: 2),
              Text(
                'Updated ${MaterialLocalizations.of(context).formatCompactDate(groceryList.updatedAt)}',
              ),
            ],
          ),
        ),
        trailing: PopupMenuButton<_CardAction>(
          tooltip: 'List options',
          onSelected: _handleAction,
          itemBuilder: (BuildContext context) => <PopupMenuEntry<_CardAction>>[
            const PopupMenuItem<_CardAction>(
              value: _CardAction.edit,
              child: Row(
                children: <Widget>[
                  Icon(Icons.edit_outlined),
                  SizedBox(width: 12),
                  Text('Edit'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem<_CardAction>(
              value: _CardAction.active,
              enabled: groceryList.status != GroceryListStatus.active,
              child: const Text('Mark as active'),
            ),
            PopupMenuItem<_CardAction>(
              value: _CardAction.completed,
              enabled: groceryList.status != GroceryListStatus.completed,
              child: const Text('Mark as completed'),
            ),
            PopupMenuItem<_CardAction>(
              value: _CardAction.archived,
              enabled: groceryList.status != GroceryListStatus.archived,
              child: const Text('Mark as archived'),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<_CardAction>(
              value: _CardAction.delete,
              child: Row(
                children: <Widget>[
                  Icon(Icons.delete_outline),
                  SizedBox(width: 12),
                  Text('Delete'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatMoney(double amount) => '₱${amount.toStringAsFixed(2)}';

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final GroceryListStatus status;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final (Color background, Color foreground) = switch (status) {
      GroceryListStatus.active => (
        colors.primaryContainer,
        colors.onPrimaryContainer,
      ),
      GroceryListStatus.completed => (
        colors.secondaryContainer,
        colors.onSecondaryContainer,
      ),
      GroceryListStatus.archived => (
        colors.surfaceContainerHighest,
        colors.onSurfaceVariant,
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
