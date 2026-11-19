import 'package:flutter/material.dart';

import '../../domain/grocery_category.dart';
import '../../domain/grocery_list.dart';
import '../../state/grocery_list_controller.dart';

/// Data returned by the form. [newCategoryName] is set only when the user chose
/// "Create new category", so the controller can add it atomically with the list.
typedef GroceryListFormSubmit = void Function({
  required String title,
  GroceryCategory? category,
  required double? budget,
  String? newCategoryName,
});

/// Bottom sheet used for both creating and editing a grocery list.
class GroceryListFormSheet extends StatefulWidget {
  const GroceryListFormSheet({
    super.key,
    required this.controller,
    this.list,
    required this.onSubmit,
  });

  final GroceryListController controller;
  final GroceryList? list;
  final GroceryListFormSubmit onSubmit;

  @override
  State<GroceryListFormSheet> createState() => _GroceryListFormSheetState();
}

class _GroceryListFormSheetState extends State<GroceryListFormSheet> {
  static const String _newCategory = '__new_category__';

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController = TextEditingController(
    text: widget.list?.title ?? '',
  );
  late final TextEditingController _budgetController = TextEditingController(
    text: widget.list?.budget?.toStringAsFixed(2) ?? '',
  );
  late final TextEditingController _newCategoryController =
      TextEditingController();
  late String _selectedCategoryId =
      widget.list?.category?.id ?? GroceryCategory.noneId;

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    _newCategoryController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final String clean = value?.trim() ?? '';
    if (clean.isEmpty) return 'Enter a list name.';
    return null;
  }

  String? _validateBudget(String? value) {
    final String clean = (value ?? '').replaceAll(',', '').trim();
    if (clean.isEmpty) return null; // Budget is optional.
    final double? amount = double.tryParse(clean);
    if (amount == null) return 'Enter a valid amount.';
    if (amount < 0) return 'Budget must be zero or more.';
    return null;
  }

  String? _validateNewCategory(String? value) {
    final String clean = value?.trim() ?? '';
    if (clean.isEmpty) return 'Enter a category name.';
    if (widget.controller.findCategory(clean) != null) {
      return 'A category with this name already exists.';
    }
    return null;
  }

  double? _parseBudget(String value) {
    final String clean = value.replaceAll(',', '').trim();
    return clean.isEmpty ? null : double.tryParse(clean);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    GroceryCategory? category;
    String? newCategoryName;
    if (_selectedCategoryId == _newCategory) {
      newCategoryName = _newCategoryController.text.trim();
    } else if (_selectedCategoryId != GroceryCategory.noneId) {
      for (final GroceryCategory item
          in widget.controller.availableCategories) {
        if (item.id == _selectedCategoryId) {
          category = item;
          break;
        }
      }
    }

    widget.onSubmit(
      title: _nameController.text.trim(),
      category: category,
      budget: _parseBudget(_budgetController.text),
      newCategoryName: newCategoryName,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isEditing = widget.list != null;
    final InputDecoration decoration = InputDecoration(
      border: const OutlineInputBorder(),
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerLowest,
    );

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                isEditing ? 'Edit list' : 'New grocery list',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('grocery-list-name-field'),
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: decoration.copyWith(
                  labelText: 'List name',
                  prefixIcon: const Icon(Icons.list_alt_outlined),
                ),
                validator: _validateName,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const Key('grocery-list-category-field'),
                initialValue: _selectedCategoryId,
                decoration: decoration.copyWith(
                  labelText: 'Category',
                  prefixIcon: const Icon(Icons.category_outlined),
                ),
                items: <DropdownMenuItem<String>>[
                  const DropdownMenuItem<String>(
                    value: GroceryCategory.noneId,
                    child: Text('No category'),
                  ),
                  for (final GroceryCategory category
                      in widget.controller.availableCategories)
                    DropdownMenuItem<String>(
                      value: category.id,
                      child: Text(category.name),
                    ),
                  const DropdownMenuItem<String>(
                    value: _newCategory,
                    child: Text('Create new category…'),
                  ),
                ],
                onChanged: (String? value) {
                  if (value != null) {
                    setState(() => _selectedCategoryId = value);
                  }
                },
              ),
              if (_selectedCategoryId == _newCategory) ...<Widget>[
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('grocery-list-new-category-field'),
                  controller: _newCategoryController,
                  textInputAction: TextInputAction.next,
                  decoration: decoration.copyWith(
                    labelText: 'New category name',
                    prefixIcon: const Icon(Icons.add),
                  ),
                  validator: _validateNewCategory,
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('grocery-list-budget-field'),
                controller: _budgetController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                decoration: decoration.copyWith(
                  labelText: 'Budget (optional, ₱)',
                  prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                ),
                validator: _validateBudget,
              ),
              const SizedBox(height: 8),
              Text(
                'Leave the budget blank if you do not want to set one.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
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
                    key: const Key('grocery-list-save-button'),
                    onPressed: _submit,
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
