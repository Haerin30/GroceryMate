import 'package:flutter/material.dart';

import '../../../app/router/app_destination.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../data/grocery_list_repository.dart';
import '../domain/grocery_category.dart';
import '../domain/grocery_list.dart';
import '../domain/grocery_list_query.dart';
import '../state/grocery_list_controller.dart';
import 'widgets/grocery_list_card.dart';
import 'widgets/grocery_list_form_sheet.dart';

/// First screen of the app. It renders repository-backed lists and owns the
/// create/edit/delete/status flows.
class GroceryListsScreen extends StatefulWidget {
  const GroceryListsScreen({super.key, this.controller, this.repository});

  /// Optional so tests can inject a controller with deterministic data/time.
  final GroceryListController? controller;

  /// Production persistence boundary; ignored when [controller] is supplied.
  final GroceryListRepository? repository;

  @override
  State<GroceryListsScreen> createState() => _GroceryListsScreenState();
}

class _GroceryListsScreenState extends State<GroceryListsScreen> {
  static const Duration _sectionAnimationDuration = Duration(milliseconds: 220);

  late final GroceryListController _controller =
      widget.controller ?? GroceryListController(repository: widget.repository);

  GroceryListFilter _filter = GroceryListFilter.all;
  String _categoryId = allCategoriesFilter;
  GroceryListSort _sort = GroceryListSort.recentlyUpdated;
  bool _categoriesExpanded = true;

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

  void _showMessage(String message, {VoidCallback? onUndo}) {
    if (!mounted) return;
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
          action: onUndo == null
              ? null
              : SnackBarAction(label: 'Undo', onPressed: onUndo),
        ),
      );
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
            }) async {
              if (list == null) {
                await _controller.addList(
                  title: title,
                  category: category,
                  budget: budget,
                  newCategoryName: newCategoryName,
                );
                _showMessage('List created.');
              } else {
                await _controller.updateList(
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

    await _controller.deleteList(list.id);
    _showMessage('List deleted.');
  }

  /// Returns `true` only when the repository accepted the new status, so a
  /// failed swipe can animate back instead of leaving a false success message.
  Future<bool> _changeStatus(GroceryList list, GroceryListStatus status) async {
    final GroceryListStatus previousStatus = list.status;
    try {
      final GroceryList? updated = await _controller.setStatus(list.id, status);
      if (updated == null) {
        _showMessage('Could not update status.');
        return false;
      }
      _showMessage(
        'Marked as ${status.label.toLowerCase()}.',
        onUndo: () => _undoStatus(updated.id, previousStatus),
      );
      return true;
    } catch (_) {
      _showMessage('Could not update status.');
      return false;
    }
  }

  Future<void> _undoStatus(String id, GroceryListStatus previousStatus) async {
    try {
      final GroceryList? restored = await _controller.setStatus(
        id,
        previousStatus,
      );
      if (restored == null) {
        _showMessage('Could not restore status.');
        return;
      }
      _showMessage('Status restored.');
    } catch (_) {
      _showMessage('Could not restore status.');
    }
  }

  Widget _categorySection(ThemeData theme) {
    final String compactLabel = _categoryLabel(_categoryId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          button: true,
          label: _categoriesExpanded
              ? 'Collapse categories'
              : 'Expand categories',
          child: InkWell(
            key: const Key('category-section-toggle'),
            onTap: () =>
                setState(() => _categoriesExpanded = !_categoriesExpanded),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                child: Row(
                  children: <Widget>[
                    Text(
                      'Categories',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _categoriesExpanded ? '' : compactLabel,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      duration: _sectionAnimationDuration,
                      curve: Curves.easeInOut,
                      turns: _categoriesExpanded ? 0.5 : 0,
                      child: const Icon(Icons.expand_more),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        ClipRect(
          child: AnimatedSize(
            duration: _sectionAnimationDuration,
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: _sectionAnimationDuration,
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              // AnimatedSize owns height. Animating Align.heightFactor here
              // too makes the two animations fight over the same dimension and
              // can leave the chips clipped at zero height after a toggle.
              transitionBuilder: (Widget child, Animation<double> animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: _categoriesExpanded
                  ? KeyedSubtree(
                      key: const ValueKey<String>('categories-expanded'),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 2),
                        child: Wrap(
                          spacing: 6,
                          children: <Widget>[
                            for (final String id in _categoryIds)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: ChoiceChip(
                                  label: Text(_categoryLabel(id)),
                                  selected: _categoryId == id,
                                  onSelected: (_) =>
                                      setState(() => _categoryId = id),
                                ),
                              ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox(
                      key: ValueKey<String>('categories-collapsed'),
                      width: double.infinity,
                      height: 0,
                    ),
            ),
          ),
        ),
      ],
    );
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
            child: CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Your lists',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SingleChildScrollView(
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
                              onSelected: (_) =>
                                  setState(() => _filter = filter),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: _categorySection(theme)),
                SliverToBoxAdapter(
                  child: Padding(
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
                        Flexible(
                          child: PopupMenuButton<GroceryListSort>(
                            tooltip: 'Sort lists',
                            icon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(Icons.sort),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _sort.label,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelLarge,
                                  ),
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
                        ),
                      ],
                    ),
                  ),
                ),
                if (visibleLists.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyStateView(
                      icon: Icons.shopping_cart_outlined,
                      title: _controller.lists.isEmpty
                          ? 'No lists yet'
                          : 'No lists here yet',
                      message: _controller.lists.isEmpty
                          ? 'Tap + to add your first grocery list.'
                          : 'Try another filter or category.',
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate((
                      BuildContext context,
                      int index,
                    ) {
                      final GroceryList list = visibleLists[index];
                      // The id alone is the key. The card keeps its own
                      // gesture state keyed by this stable identity.
                      return GroceryListCard(
                        key: ValueKey<String>('grocery-list-${list.id}'),
                        groceryList: list,
                        onTap: () =>
                            _showComingSoon(context, 'Opening grocery lists'),
                        onEdit: () => _openForm(list: list),
                        onDelete: () => _confirmDelete(list),
                        onStatusChanged: (GroceryListStatus status) =>
                            _changeStatus(list, status),
                      );
                    }, childCount: visibleLists.length),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
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
