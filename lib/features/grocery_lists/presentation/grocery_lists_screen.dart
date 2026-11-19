import 'package:flutter/material.dart';

import '../../../app/router/app_destination.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../domain/grocery_category.dart';
import '../domain/grocery_list.dart';
import '../domain/grocery_list_query.dart';
import '../state/grocery_list_controller.dart';
import 'widgets/grocery_list_card.dart';
import 'widgets/grocery_list_form_sheet.dart';

/// First screen of the app. It renders the in-memory lists and owns the
/// create/edit/delete/status flows; persistence comes in a later milestone.
class GroceryListsScreen extends StatefulWidget {
  const GroceryListsScreen({super.key, this.controller});

  /// Optional so tests can inject a controller with deterministic data/time.
  final GroceryListController? controller;

  @override
  State<GroceryListsScreen> createState() => _GroceryListsScreenState();
}

class _GroceryListsScreenState extends State<GroceryListsScreen> {
  late final GroceryListController _controller =
      widget.controller ?? GroceryListController();

  GroceryListFilter _filter = GroceryListFilter.all;
  String _categoryId = allCategoriesFilter;
  GroceryListSort _sort = GroceryListSort.recentlyUpdated;

  List<String> get _categoryIds => <String>[
    allCategoriesFilter,
    GroceryCategory.noneId,
    for (final GroceryCategory category in _controller.availableCategories)
      category.id,
  ];

  String _categoryLabel(String id) {
    if (id == allCategoriesFilter) return 'All categories';
    if (id == GroceryCategory.noneId) return 'No category';
    for (final GroceryCategory category in _controller.availableCategories) {
      if (category.id == id) return category.name;
    }
    return 'All categories';
  }

  List<GroceryList> get _visibleLists => queryGroceryLists(
    _controller.lists,
    status: _filter,
    categoryId: _categoryId,
    sort: _sort,
  );

  void _showMessage(String message) {
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openForm({GroceryList? list}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) => GroceryListFormSheet(
        controller: _controller,
        list: list,
        onSubmit:
            ({
              required String title,
              GroceryCategory? category,
              required double? budget,
              String? newCategoryName,
            }) {
              if (list == null) {
                _controller.addList(
                  title: title,
                  category: category,
                  budget: budget,
                  newCategoryName: newCategoryName,
                );
                _showMessage('List created.');
              } else {
                _controller.updateList(
                  list.id,
                  title: title,
                  category: category,
                  budget: budget,
                  newCategoryName: newCategoryName,
                );
                _showMessage('List updated.');
              }
            },
      ),
    );
  }

  Future<void> _confirmDelete(GroceryList list) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Delete list?'),
        content: Text(
          '“${list.title}” will be removed from your lists. '
          'This cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    _controller.deleteList(list.id);
    _showMessage('List deleted.');
  }

  void _changeStatus(GroceryList list, GroceryListStatus status) {
    _controller.setStatus(list.id, status);
    _showMessage('Marked as ${status.label.toLowerCase()}.');
  }

  void _handleDestinationSelected(int index) {
    final AppDestination destination = AppDestination.values[index];
    Navigator.of(context).pop(); // Close the drawer first.
    if (destination == AppDestination.groceryLists) {
      return;
    }
    Navigator.of(context).pushNamed(destination.route);
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$feature is coming soon.')));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final ThemeData theme = Theme.of(context);
        final List<GroceryList> visibleLists = _visibleLists;

        return Scaffold(
          appBar: AppBar(
            leading: Builder(
              builder: (BuildContext context) => IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'Open navigation menu',
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            title: const Text('Grocery Lists'),
            actions: <Widget>[
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Add List',
                onPressed: () => _openForm(),
              ),
              IconButton(
                icon: const Icon(Icons.barcode_reader),
                tooltip: 'Barcode Scanner',
                onPressed: () => _showComingSoon(context, 'Barcode scanning'),
              ),
              IconButton(
                icon: const Icon(Icons.calculate),
                tooltip: 'Calculator',
                onPressed: () => _showComingSoon(context, 'Calculator'),
              ),
            ],
          ),
          drawer: _AppDrawer(onDestinationSelected: _handleDestinationSelected),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Your lists',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: <Widget>[
                      for (final GroceryListFilter filter
                          in GroceryListFilter.values)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(filter.label),
                            selected: _filter == filter,
                            onSelected: (_) => setState(() => _filter = filter),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Text(
                    'Categories',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Wrap(
                    spacing: 6,
                    children: <Widget>[
                      for (final String id in _categoryIds)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: ChoiceChip(
                            label: Text(_categoryLabel(id)),
                            selected: _categoryId == id,
                            onSelected: (_) => setState(() => _categoryId = id),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: Row(
                    children: <Widget>[
                      Text(
                        '${visibleLists.length} lists',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      PopupMenuButton<GroceryListSort>(
                        tooltip: 'Sort lists',
                        icon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(Icons.sort),
                            const SizedBox(width: 4),
                            Text(
                              _sort.label,
                              style: theme.textTheme.labelLarge,
                            ),
                          ],
                        ),
                        onSelected: (GroceryListSort value) =>
                            setState(() => _sort = value),
                        itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<GroceryListSort>>[
                              for (final GroceryListSort option
                                  in GroceryListSort.values)
                                PopupMenuItem<GroceryListSort>(
                                  value: option,
                                  child: Text(option.label),
                                ),
                            ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: visibleLists.isEmpty
                      ? EmptyStateView(
                          icon: Icons.shopping_cart_outlined,
                          title: _controller.lists.isEmpty
                              ? 'No lists yet'
                              : 'No lists here yet',
                          message: _controller.lists.isEmpty
                              ? 'Tap + to add your first grocery list.'
                              : 'Try another filter or category.',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                          itemCount: visibleLists.length,
                          itemBuilder: (BuildContext context, int index) {
                            final GroceryList list = visibleLists[index];
                            return GroceryListCard(
                              groceryList: list,
                              onTap: () => _showComingSoon(
                                context,
                                'Opening grocery lists',
                              ),
                              onEdit: () => _openForm(list: list),
                              onDelete: () => _confirmDelete(list),
                              onStatusChanged: (GroceryListStatus status) =>
                                  _changeStatus(list, status),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer({required this.onDestinationSelected});

  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return NavigationDrawer(
      selectedIndex: 0,
      onDestinationSelected: onDestinationSelected,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                backgroundColor: colors.primary,
                child: const Icon(Icons.shopping_cart, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      AppConstants.appName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      AppConstants.appTagline,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(),
        for (final AppDestination destination in AppDestination.values)
          NavigationDrawerDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.icon),
            label: Text(destination.label),
          ),
      ],
    );
  }
}
