/// A spending or income bucket.
///
/// [isIncome] separates money coming in from money going out, so the same
/// table serves both sides of the ledger.
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.iconCode,
    required this.colorIndex,
    required this.isIncome,
    this.archived = false,
  });

  final int id;
  final String name;

  /// Codepoint of a Material icon. Storing the codepoint keeps the table
  /// schema plain — no serialized widget trees in the database.
  final int iconCode;
  final int colorIndex;
  final bool isIncome;
  final bool archived;

  Category copyWith({
    int? id,
    String? name,
    int? iconCode,
    int? colorIndex,
    bool? isIncome,
    bool? archived,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      iconCode: iconCode ?? this.iconCode,
      colorIndex: colorIndex ?? this.colorIndex,
      isIncome: isIncome ?? this.isIncome,
      archived: archived ?? this.archived,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'icon_code': iconCode,
        'color_index': colorIndex,
        'is_income': isIncome ? 1 : 0,
        'archived': archived ? 1 : 0,
      };

  static Category fromMap(Map<String, Object?> m) => Category(
        id: m['id']! as int,
        name: m['name']! as String,
        iconCode: (m['icon_code'] ?? 0xe318) as int,
        colorIndex: (m['color_index'] ?? 0) as int,
        isIncome: (m['is_income'] ?? 0) == 1,
        archived: (m['archived'] ?? 0) == 1,
      );
}
