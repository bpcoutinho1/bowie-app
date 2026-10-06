/// Where an item is: on the list to buy, or among the frequent items after
/// it was bought (docs/produto/compras.md).
enum ShoppingStatus {
  toBuy('to_buy'),
  bought('bought');

  const ShoppingStatus(this.wire);

  final String wire;

  static ShoppingStatus fromWire(String value) =>
      values.firstWhere((status) => status.wire == value);
}

/// One item of a house's shopping list.
class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.houseId,
    required this.name,
    required this.status,
    required this.updatedAt,
    this.details,
    this.catalogKey,
    this.updatedBy,
    this.deletedAt,
  });

  final String id;

  /// The main tutor's user id: the house the list belongs to.
  final String houseId;
  final String name;

  /// Brand, size: "Golden 15 kg".
  final String? details;

  /// The catalog entry that gives the icon, when there is one.
  final String? catalogKey;
  final ShoppingStatus status;
  final String? updatedBy;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  ShoppingItem copyWith({
    String? name,
    String? details,
    String? catalogKey,
    ShoppingStatus? status,
    String? updatedBy,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDetails = false,
    bool clearCatalogKey = false,
  }) {
    return ShoppingItem(
      id: id,
      houseId: houseId,
      name: name ?? this.name,
      details: clearDetails ? null : details ?? this.details,
      catalogKey: clearCatalogKey ? null : catalogKey ?? this.catalogKey,
      status: status ?? this.status,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, Object?> toRow() {
    return {
      'id': id,
      'house_id': houseId,
      'name': name,
      'details': details,
      'catalog_key': catalogKey,
      'status': status.wire,
      'updated_by': updatedBy,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'deleted_at': deletedAt?.toUtc().toIso8601String(),
    };
  }

  static ShoppingItem fromRow(Map<String, Object?> row) {
    final deleted = row['deleted_at'] as String?;
    return ShoppingItem(
      id: row['id']! as String,
      houseId: row['house_id']! as String,
      name: row['name']! as String,
      details: row['details'] as String?,
      catalogKey: row['catalog_key'] as String?,
      status: ShoppingStatus.fromWire(row['status']! as String),
      updatedBy: row['updated_by'] as String?,
      updatedAt: DateTime.parse(row['updated_at']! as String).toUtc(),
      deletedAt: deleted == null ? null : DateTime.parse(deleted).toUtc(),
    );
  }
}

/// A house: the pets of one main tutor and everyone who cares for them.
class House {
  const House({
    required this.id,
    required this.ownerEmail,
    required this.isMine,
  });

  /// The main tutor's user id.
  final String id;
  final String ownerEmail;
  final bool isMine;

  /// "Minha casa", or "Casa de ana@example.com" until accounts have a name.
  String get label => isMine ? 'Minha casa' : 'Casa de $ownerEmail';
}
