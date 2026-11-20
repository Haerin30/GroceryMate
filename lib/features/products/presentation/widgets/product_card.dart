import 'package:flutter/material.dart';

import '../../domain/product.dart';
import '../../domain/product_unit.dart';

/// Compact catalog row. No swipe behavior: archiving uses the explicit menu.
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onEdit,
    required this.onArchiveChanged,
  });

  final Product product;
  final VoidCallback onEdit;
  final ValueChanged<bool> onArchiveChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final String subtitle = <String>[
      if (product.brand != null && product.brand!.isNotEmpty) product.brand!,
      product.categoryName,
      product.unit.label,
      if (product.barcode != null) 'Barcode ${product.barcode}',
    ].join(' • ');

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: product.isArchived
              ? colors.surfaceContainerHighest
              : colors.primaryContainer,
          child: Icon(
            product.isArchived ? Icons.archive_outlined : Icons.inventory_2,
            color: product.isArchived
                ? colors.onSurfaceVariant
                : colors.onPrimaryContainer,
          ),
        ),
        title: Text(product.name, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: PopupMenuButton<_ProductMenuAction>(
          tooltip: 'Product options',
          onSelected: (_ProductMenuAction action) {
            switch (action) {
              case _ProductMenuAction.edit:
                onEdit();
              case _ProductMenuAction.archive:
                onArchiveChanged(true);
              case _ProductMenuAction.restore:
                onArchiveChanged(false);
            }
          },
          itemBuilder: (BuildContext context) =>
              <PopupMenuEntry<_ProductMenuAction>>[
                const PopupMenuItem<_ProductMenuAction>(
                  value: _ProductMenuAction.edit,
                  child: Text('Edit'),
                ),
                PopupMenuItem<_ProductMenuAction>(
                  value: product.isArchived
                      ? _ProductMenuAction.restore
                      : _ProductMenuAction.archive,
                  child: Text(product.isArchived ? 'Restore' : 'Archive'),
                ),
              ],
        ),
        onTap: onEdit,
      ),
    );
  }
}

enum _ProductMenuAction { edit, archive, restore }
