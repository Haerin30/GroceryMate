import 'package:flutter/material.dart';

import '../../domain/product.dart';
import '../../domain/product_category.dart';
import '../../domain/product_input.dart';
import '../../domain/product_query.dart';
import '../../domain/product_unit.dart';
import '../../state/product_controller.dart';

typedef ProductFormSubmit = Future<void> Function(ProductInput input);

/// Reusable create/edit form. Duplicate names are only a warning and never
/// block saving a distinct product.
class ProductFormSheet extends StatefulWidget {
  const ProductFormSheet({
    super.key,
    required this.controller,
    required this.onSubmit,
    this.product,
    this.onOpenExisting,
  });

  final ProductController controller;
  final Product? product;
  final ProductFormSubmit onSubmit;
  final ValueChanged<Product>? onOpenExisting;

  @override
  State<ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<ProductFormSheet> {
  static const String _newCategoryValue = '__new_product_category__';

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _brandController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _imagePathController;
  late final TextEditingController _notesController;
  late final TextEditingController _newCategoryController;

  late String _categoryId;
  late ProductUnit _unit;
  String? _formError;
  String? _barcodeError;

  @override
  void initState() {
    super.initState();
    final Product? product = widget.product;
    _nameController = TextEditingController(text: product?.name ?? '');
    _brandController = TextEditingController(text: product?.brand ?? '');
    _barcodeController = TextEditingController(text: product?.barcode ?? '');
    _imagePathController = TextEditingController(
      text: product?.imagePath ?? '',
    );
    _notesController = TextEditingController(text: product?.notes ?? '');
    _newCategoryController = TextEditingController();
    _categoryId = product?.categoryId ?? _firstCategoryId();
    _unit = product?.unit ?? ProductUnit.piece;
  }

  String _firstCategoryId() {
    final List<ProductCategory> categories = widget.controller.categories;
    return categories.isEmpty ? _newCategoryValue : categories.first.id;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _barcodeController.dispose();
    _imagePathController.dispose();
    _notesController.dispose();
    _newCategoryController.dispose();
    super.dispose();
  }

  List<Product> get _similarProducts => findSimilarProductsByName(
    widget.controller.allProducts,
    _nameController.text,
    excludeId: widget.product?.id,
  );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _formError = null;
      _barcodeError = null;
    });

    try {
      final String barcodeText = _barcodeController.text;
      final Product? barcodeOwner = await widget.controller.findByBarcode(
        barcodeText,
        excludeId: widget.product?.id,
      );
      if (barcodeOwner != null) {
        setState(() {
          _barcodeError =
              'This barcode is already used by ${barcodeOwner.name}.';
        });
        return;
      }

      String categoryId = _categoryId;
      if (_categoryId == _newCategoryValue) {
        final ProductCategory category = await widget.controller.addCategory(
          _newCategoryController.text,
        );
        categoryId = category.id;
      }

      await widget.onSubmit(
        ProductInput(
          name: _nameController.text,
          categoryId: categoryId,
          unit: _unit,
          brand: _brandController.text,
          barcode: barcodeText,
          imagePath: _imagePathController.text,
          notes: _notesController.text,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => _formError = error.toString());
    }
  }

  InputDecoration _decoration(String label, {IconData? prefixIcon}) =>
      InputDecoration(
        labelText: label,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        border: const OutlineInputBorder(),
      );

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<Product> similar = _similarProducts;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                widget.product == null ? 'Add product' : 'Edit product',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              if (_formError != null) ...<Widget>[
                Text(
                  _formError!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                key: const Key('product-name-field'),
                controller: _nameController,
                decoration: _decoration(
                  'Product name',
                  prefixIcon: Icons.shopping_bag_outlined,
                ),
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
                validator: (String? value) {
                  try {
                    ProductInput.cleanName(value ?? '');
                    return null;
                  } catch (_) {
                    return 'Enter a product name.';
                  }
                },
              ),
              if (similar.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'A similar product already exists: '
                        '${similar.first.name}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () =>
                              widget.onOpenExisting?.call(similar.first),
                          child: const Text('Open existing product'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const Key('product-category-field'),
                initialValue: _categoryId,
                decoration: _decoration(
                  'Product category',
                  prefixIcon: Icons.category_outlined,
                ),
                items: <DropdownMenuItem<String>>[
                  for (final ProductCategory category
                      in widget.controller.categories)
                    DropdownMenuItem<String>(
                      value: category.id,
                      child: Text(category.name),
                    ),
                  const DropdownMenuItem<String>(
                    value: _newCategoryValue,
                    child: Text('Create new category…'),
                  ),
                ],
                onChanged: (String? value) =>
                    setState(() => _categoryId = value ?? _firstCategoryId()),
              ),
              if (_categoryId == _newCategoryValue) ...<Widget>[
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('product-new-category-field'),
                  controller: _newCategoryController,
                  decoration: _decoration('New category name'),
                  validator: (String? value) =>
                      ProductCategory.cleanName(value ?? '') == null
                      ? 'Enter a category name.'
                      : null,
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<ProductUnit>(
                key: const Key('product-unit-field'),
                initialValue: _unit,
                decoration: _decoration(
                  'Default unit',
                  prefixIcon: Icons.straighten_outlined,
                ),
                items: <DropdownMenuItem<ProductUnit>>[
                  for (final ProductUnit unit in ProductUnit.values)
                    DropdownMenuItem<ProductUnit>(
                      value: unit,
                      child: Text(unit.label),
                    ),
                ],
                onChanged: (ProductUnit? value) =>
                    setState(() => _unit = value ?? ProductUnit.piece),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('product-brand-field'),
                controller: _brandController,
                decoration: _decoration(
                  'Brand (optional)',
                  prefixIcon: Icons.branding_watermark_outlined,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('product-barcode-field'),
                controller: _barcodeController,
                decoration: _decoration(
                  'Barcode (optional)',
                  prefixIcon: Icons.barcode_reader,
                ).copyWith(errorText: _barcodeError),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('product-image-path-field'),
                controller: _imagePathController,
                decoration: _decoration(
                  'Local image path (optional)',
                  prefixIcon: Icons.image_outlined,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('product-notes-field'),
                controller: _notesController,
                decoration: _decoration(
                  'Notes (optional)',
                  prefixIcon: Icons.notes_outlined,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('product-save-button'),
                    onPressed: _save,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
