/// Units available in the first Product Catalog milestone.
enum ProductUnit {
  piece,
  kilogram,
  gram,
  liter,
  milliliter,
  pack,
  box,
  bottle,
  can,
  dozen,
  bundle,
}

extension ProductUnitX on ProductUnit {
  /// Stable value stored in SQLite.
  String get value => switch (this) {
    ProductUnit.piece => 'piece',
    ProductUnit.kilogram => 'kg',
    ProductUnit.gram => 'g',
    ProductUnit.liter => 'l',
    ProductUnit.milliliter => 'ml',
    ProductUnit.pack => 'pack',
    ProductUnit.box => 'box',
    ProductUnit.bottle => 'bottle',
    ProductUnit.can => 'can',
    ProductUnit.dozen => 'dozen',
    ProductUnit.bundle => 'bundle',
  };

  String get label => switch (this) {
    ProductUnit.piece => 'Piece',
    ProductUnit.kilogram => 'Kilogram',
    ProductUnit.gram => 'Gram',
    ProductUnit.liter => 'Liter',
    ProductUnit.milliliter => 'Milliliter',
    ProductUnit.pack => 'Pack',
    ProductUnit.box => 'Box',
    ProductUnit.bottle => 'Bottle',
    ProductUnit.can => 'Can',
    ProductUnit.dozen => 'Dozen',
    ProductUnit.bundle => 'Bundle',
  };

  static ProductUnit? fromValue(String value) {
    for (final ProductUnit unit in ProductUnit.values) {
      if (unit.value == value) return unit;
    }
    return null;
  }
}
