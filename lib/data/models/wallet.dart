/// Domain model for a wallet — cash, bank account, e-wallet.
///
/// Balances are stored as a starting amount; the live balance is derived by
/// folding every transaction tagged to this wallet.
class Wallet {
  const Wallet({
    required this.id,
    required this.name,
    required this.openingBalance,
    required this.colorIndex,
    this.archived = false,
  });

  final int id;
  final String name;
  final num openingBalance;
  final int colorIndex;
  final bool archived;

  Wallet copyWith({
    int? id,
    String? name,
    num? openingBalance,
    int? colorIndex,
    bool? archived,
  }) {
    return Wallet(
      id: id ?? this.id,
      name: name ?? this.name,
      openingBalance: openingBalance ?? this.openingBalance,
      colorIndex: colorIndex ?? this.colorIndex,
      archived: archived ?? this.archived,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'opening_balance': openingBalance,
        'color_index': colorIndex,
        'archived': archived ? 1 : 0,
      };

  static Wallet fromMap(Map<String, Object?> m) => Wallet(
        id: m['id']! as int,
        name: m['name']! as String,
        openingBalance: m['opening_balance']! as num,
        colorIndex: (m['color_index'] ?? 0) as int,
        archived: (m['archived'] ?? 0) == 1,
      );
}
