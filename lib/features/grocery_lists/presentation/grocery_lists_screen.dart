import 'package:flutter/material.dart';

import '../../../app/router/app_destination.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../data/sample_grocery_lists.dart';
import '../domain/grocery_list.dart';
import 'widgets/grocery_list_card.dart';

/// Single-select filters shown under the screen title.
enum GroceryListFilter { all, active, completed, archived }

/// Sorting options for the list overview.
enum GroceryListSort { recentlyUpdated, name, estimatedTotal }

extension GroceryListFilterX on GroceryListFilter {
  String get label => switch (this) {
        GroceryListFilter.all => 'All',
        GroceryListFilter.active => 'Active',
        GroceryListFilter.completed => 'Completed',
        GroceryListFilter.archived => 'Archived',
      };
}

extension GroceryListSortX on GroceryListSort {
  String get label => switch (this) {
        GroceryListSort.recentlyUpdated => 'Recently updated',
        GroceryListSort.name => 'Name',
        GroceryListSort.estimatedTotal => 'Estimated total',
      };
}

/// First screen of the app. It only renders and filters preview data; adding,
/// editing, and persisting lists come in later milestones.
class GroceryListsScreen extends StatefulWidget {
  const GroceryListsScreen({super.key});

  @override
  State<GroceryListsScreen> createState() => _GroceryListsScreenState();
}

class _GroceryListsScreenState extends State<GroceryListsScreen> {
  static const String _allCategories = 'All categories';

  GroceryListFilter _filter = GroceryListFilter.all;
  String _category = _allCategories;
  GroceryListSort _sort = GroceryListSort.recentlyUpdated;

  List<String> get _categories {
    final Set<String> categories = <String>{
      for (final GroceryList list in sampleGroceryLists) list.category,
    };
    final List<String> sorted = categories.toList()..sort();
    return <String>[_allCategories, ...sorted];
  }

  List<GroceryList> get _visibleLists {
    final List<GroceryList> lists = sampleGroceryLists.where((GroceryList list) {
      final bool matchesFilter = switch (_filter) {
        GroceryListFilter.all => true,
        GroceryListFilter.active => list.status == GroceryListStatus.active,
        GroceryListFilter.completed =>
          list.status == GroceryListStatus.completed,
        GroceryListFilter.archived =>
          list.status == GroceryListStatus.archived,
      };
      final bool matchesCategory =
          _category == _allCategories || list.category == _category;
      return matchesFilter && matchesCategory;
    }).toList();

    switch (_sort) {
      case GroceryListSort.recentlyUpdated:
        lists.sort((GroceryList a, GroceryList b) =>
            b.updatedAt.compareTo(a.updatedAt));
      case GroceryListSort.name:
        lists.sort((GroceryList a, GroceryList b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case GroceryListSort.estimatedTotal:
        lists.sort((GroceryList a, GroceryList b) =>
            b.estimatedTotal.compareTo(a.estimatedTotal));
    }

    return lists;
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
            tooltip: 'Add Grocery List',
            onPressed: () => _showComingSoon(context, 'Adding lists'),
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
                  for (final GroceryListFilter filter in GroceryListFilter.values)
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
                  for (final String category in _categories)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: ChoiceChip(
                        label: Text(category),
                        selected: _category == category,
                        onSelected: (_) => setState(() => _category = category),
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
                        Text(_sort.label, style: theme.textTheme.labelLarge),
                      ],
                    ),
                    onSelected: (GroceryListSort value) =>
                        setState(() => _sort = value),
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<GroceryListSort>>[
                      for (final GroceryListSort option in GroceryListSort.values)
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
                  ? const EmptyStateView(
                      icon: Icons.shopping_cart_outlined,
                      title: 'No lists here yet',
                      message: 'Try another filter or category.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      itemCount: visibleLists.length,
                      itemBuilder: (BuildContext context, int index) =>
                          GroceryListCard(
                        groceryList: visibleLists[index],
                        onTap: () =>
                            _showComingSoon(context, 'Opening grocery lists'),
                      ),
                    ),
            ),
          ],
        ),
      ),
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
