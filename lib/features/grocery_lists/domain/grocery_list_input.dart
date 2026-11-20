/// Validation and money conversion shared by the in-memory controller and the
/// Drift repository.
abstract final class GroceryListInput {
  static String cleanTitle(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(value, 'title', 'List name is required');
    }
    return trimmed;
  }

  static double? cleanBudget(double? value) {
    if (value == null) return null;
    if (!value.isFinite || value < 0) {
      throw ArgumentError.value(
        value,
        'budget',
        'Budget must be a non-negative number',
      );
    }
    return value;
  }

  /// Converts a peso amount to the integer centavos used by SQLite.
  static int? budgetToCentavos(double? value) {
    final double? clean = cleanBudget(value);
    return clean == null ? null : (clean * 100).round();
  }

  /// Converts persisted centavos back to the domain's peso amount.
  static double? budgetFromCentavos(int? centavos) =>
      centavos == null ? null : centavos / 100;
}
