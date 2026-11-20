import 'product_unit.dart';

/// Validated values shared by the product form, controller, and repository.
class ProductInput {
  const ProductInput({
    required this.name,
    required this.categoryId,
    required this.unit,
    this.brand,
    this.barcode,
    this.imagePath,
    this.notes,
  });

  final String name;
  final String categoryId;
  final ProductUnit unit;
  final String? brand;
  final String? barcode;
  final String? imagePath;
  final String? notes;

  static String cleanName(String value) {
    final String cleaned = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) {
      throw ArgumentError.value(value, 'name', 'Product name is required');
    }
    return cleaned;
  }

  static String? cleanOptional(String? value) {
    final String? cleaned = value?.trim();
    if (cleaned == null || cleaned.isEmpty) return null;
    return cleaned;
  }

  /// Normalizes user-entered barcodes so spacing and hyphens do not create a
  /// second record for the same physical code.
  static String? cleanBarcode(String? value) {
    final String? cleaned = cleanOptional(value)
        ?.replaceAll(RegExp(r'[\s-]'), '');
    if (cleaned == null || cleaned.isEmpty) return null;
    return cleaned;
  }
}
