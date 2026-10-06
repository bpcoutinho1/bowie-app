/// Kinds of professionals and places a house keeps in touch with.
enum ContactCategory {
  vet('vet', 'Veterinário'),
  nutritionist('nutritionist', 'Nutricionista'),
  physio('physio', 'Fisioterapeuta'),
  trainer('trainer', 'Adestrador'),
  daycare('daycare', 'Creche'),
  hotel('hotel', 'Hotelzinho'),
  groomer('groomer', 'Banho e tosa'),
  walker('walker', 'Passeador'),
  lab('lab', 'Laboratório'),
  petShop('pet_shop', 'Pet shop'),
  other('other', 'Outro');

  const ContactCategory(this.wire, this.label);

  final String wire;
  final String label;

  static ContactCategory fromWire(String value) =>
      values.firstWhere((c) => c.wire == value, orElse: () => other);
}

/// A person or place in the house's contact book.
class Contact {
  const Contact({
    required this.id,
    required this.houseId,
    required this.name,
    required this.category,
    required this.updatedAt,
    this.phone,
    this.email,
    this.address,
    this.notes,
    this.updatedBy,
    this.deletedAt,
  });

  final String id;

  /// The main tutor's user id, as for the shopping list.
  final String houseId;
  final String name;
  final ContactCategory category;

  /// Digits only, with the area code: "11987654321".
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
  final String? updatedBy;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  Contact copyWith({
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? updatedBy,
  }) {
    return Contact(
      id: id,
      houseId: houseId,
      name: name,
      category: category,
      phone: phone,
      email: email,
      address: address,
      notes: notes,
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
      'category': category.wire,
      'phone': phone,
      'email': email,
      'address': address,
      'notes': notes,
      'updated_by': updatedBy,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'deleted_at': deletedAt?.toUtc().toIso8601String(),
    };
  }

  static Contact fromRow(Map<String, Object?> row) {
    final deleted = row['deleted_at'] as String?;
    return Contact(
      id: row['id']! as String,
      houseId: row['house_id']! as String,
      name: row['name']! as String,
      category: ContactCategory.fromWire(row['category']! as String),
      phone: row['phone'] as String?,
      email: row['email'] as String?,
      address: row['address'] as String?,
      notes: row['notes'] as String?,
      updatedBy: row['updated_by'] as String?,
      updatedAt: DateTime.parse(row['updated_at']! as String).toUtc(),
      deletedAt: deleted == null ? null : DateTime.parse(deleted).toUtc(),
    );
  }
}

/// Keeps the digits of a Brazilian phone, dropping a leading 55 country
/// code. Null when it cannot be a phone (10 or 11 digits with area code).
String? normalizePhone(String input) {
  var digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('0')) digits = digits.substring(1);
  if (digits.length > 11 && digits.startsWith('55')) {
    digits = digits.substring(2);
  }
  if (digits.length != 10 && digits.length != 11) return null;
  return digits;
}

/// "(11) 98765-4321" or "(11) 3456-7890".
String formatPhone(String digits) {
  if (digits.length < 10) return digits;
  final area = digits.substring(0, 2);
  final rest = digits.substring(2);
  final split = rest.length - 4;
  return '($area) ${rest.substring(0, split)}-${rest.substring(split)}';
}

/// Cell phones (11 digits, starting with 9 after the area code) can get a
/// WhatsApp message.
bool isMobile(String digits) => digits.length == 11 && digits[2] == '9';
