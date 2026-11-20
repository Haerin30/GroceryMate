import 'package:flutter/material.dart';

import '../../../app/router/app_destination.dart';
import '../../../app/widgets/app_navigation_drawer.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';
import '../domain/product_category.dart';
import '../domain/product_input.dart';
import '../domain/product_query.dart';
import '../state/product_controller.dart';
import 'widgets/product_card.dart';
import 'widgets/product_form_sheet.dart';

/// Offline-first Product Catalog screen. Active and archived products share
/// search, category filtering, and sorting, but never mix in one list.
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key, this.controller, this.repository});

  final ProductController? controller;
  final ProductRepository? repository;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  late final ProductController _controller =
      widget.controller ?? ProductController(repository: widget.repository);

  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  String _categoryId = allProductCategoriesFilter;
  ProductSort _sort = ProductSort.name;
  bool _showArchived = false;

  List<Product> get _visibleProducts => queryProducts(
    _showArchived ? _controller.archivedProducts : _controller.activeProducts,
    search: _search,
    categoryId: _categoryId,
    sort: _sort,
  );

  @override
  void dispose() {
    _searchController.dispose();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _handleDestinationSelected(AppDestination destination) {
    Navigator.of(context).pop();
    if (destination == AppDestination.productCatalog) return;
    Navigator.of(context).pushNamed(destination.route);
  }

  Future<void> _openForm({Product? product}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) => ProductFormSheet(
        controller: _controller,
        product: product,
        onSubmit: (ProductInput input) async {
          if (product == null) {
            await _controller.createProduct(input);
            _showMessage('Product created.');
          } else {
            final Product? updated = await _controller.updateProduct(
              product.id,
              input,
            );
            if (updated == null) {
              throw StateError('Product no longer exists');
            }
            _showMessage('Product updated.');
          }
        },
        onOpenExisting: (Product existing) {
          Navigator.of(context).pop();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _openForm(product: existing);
          });
        },
      ),
    );
  }

  Future<void> _changeArchive(Product product, {required bool archived}) async {
    try {
      final Product? updated = await _controller.setArchived(
        product.id,
        archived: archived,
      );
      if (!mounted) return;
      _showMessage(
        updated == null
            ? 'Could not update product.'
            : archived
            ? 'Product archived.'
            : 'Product restored.',
      );
    } catch (_) {
      _showMessage('Could not update product.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final ThemeData theme = Theme.of(context);
        final List<Product> visibleProducts = _visibleProducts;
        final bool hasAnyProducts = _showArchived
            ? _controller.archivedProducts.isNotEmpty
            : _controller.activeProducts.isNotEmpty;
        final String emptyTitle = !hasAnyProducts
            ? (_showArchived ? 'No archived products' : 'No products yet')
            : 'No products here yet';
        final String emptyMessage = !hasAnyProducts
            ? 'Tap + to add your first product.'
            : 'Try another search, category, or sort.';

        return Scaffold(
          appBar: AppBar(
            leading: Builder(
              builder: (BuildContext context) => IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'Open navigation menu',
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            title: Text(
              _showArchived ? 'Archived Products' : 'Product Catalog',
            ),
            actions: <Widget>[
              IconButton(
                icon: Icon(
                  _showArchived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                ),
                tooltip: _showArchived
                    ? 'Show active products'
                    : 'Show archived products',
                onPressed: () => setState(() => _showArchived = !_showArchived),
              ),
            ],
          ),
          drawer: AppNavigationDrawer(
            selectedDestination: AppDestination.productCatalog,
            onDestinationSelected: _handleDestinationSelected,
          ),
          floatingActionButton: FloatingActionButton(
            key: const Key('add-product-button'),
            tooltip: 'Add Product',
            onPressed: () => _openForm(),
            child: const Icon(Icons.add),
          ),
          body: SafeArea(
            child: CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: TextField(
                      key: const Key('product-search-field'),
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'Search products',
                        hintText: 'Name or brand',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _search.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _search = '');
                                },
                              ),
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerLowest,
                      ),
                      onChanged: (String value) =>
                          setState(() => _search = value),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: <Widget>[
                        ChoiceChip(
                          label: const Text('All categories'),
                          selected: _categoryId == allProductCategoriesFilter,
                          onSelected: (_) => setState(
                            () => _categoryId = allProductCategoriesFilter,
                          ),
                        ),
                        const SizedBox(width: 8),
                        for (final ProductCategory category
                            in _controller.categories) ...<Widget>[
                          ChoiceChip(
                            label: Text(category.name),
                            selected: _categoryId == category.id,
                            onSelected: (_) =>
                                setState(() => _categoryId = category.id),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                    child: Row(
                      children: <Widget>[
                        Text(
                          '${visibleProducts.length} products',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        Flexible(
                          child: PopupMenuButton<ProductSort>(
                            tooltip: 'Sort products',
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
                            initialValue: _sort,
                            onSelected: (ProductSort value) =>
                                setState(() => _sort = value),
                            itemBuilder: (BuildContext context) =>
                                <PopupMenuEntry<ProductSort>>[
                                  for (final ProductSort option
                                      in ProductSort.values)
                                    PopupMenuItem<ProductSort>(
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
                if (visibleProducts.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyStateView(
                      icon: _showArchived
                          ? Icons.archive_outlined
                          : Icons.inventory_2_outlined,
                      title: emptyTitle,
                      message: emptyMessage,
                    ),
                  )
                else
                  SliverList.builder(
                    itemCount: visibleProducts.length,
                    itemBuilder: (BuildContext context, int index) {
                      final Product product = visibleProducts[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ProductCard(
                          key: ValueKey<String>('product-${product.id}'),
                          product: product,
                          onEdit: () => _openForm(product: product),
                          onArchiveChanged: (bool archived) =>
                              _changeArchive(product, archived: archived),
                        ),
                      );
                    },
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 88)),
              ],
            ),
          ),
        );
      },
    );
  }
}
