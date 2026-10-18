import 'dart:convert';
import 'dart:math';

/// Where the shared sheet is published (web-share/, on GitHub Pages, under
/// the Bowie domain). The token goes after the "#", so it never reaches that
/// server. The root forwards to the sheet page, which keeps links short.
const shareBaseUrl = String.fromEnvironment(
  'SHARE_BASE_URL',
  defaultValue: 'https://ficha.bowieapp.pet/',
);

/// How long a link works (docs/produto/ficha-compartilhada.md).
const shareDays = 60;

/// What the link shows.
enum SharePreset {
  care(
    'care',
    'Hotel ou creche',
    'Dados do pet, cuidados e alergias, remédios em uso, vacinas com '
        'comprovante e o seu contato.',
  ),
  vet(
    'vet',
    'Veterinário',
    'Tudo da ficha de hotel e creche, mais o diário com fotos e arquivos '
        'de exames.',
  );

  const SharePreset(this.wire, this.label, this.description);

  final String wire;
  final String label;
  final String description;

  static SharePreset fromWire(String value) =>
      values.firstWhere((p) => p.wire == value, orElse: () => care);
}

/// A link to the pet's sheet. It always shows the current data.
class PetShare {
  const PetShare({
    required this.id,
    required this.petId,
    required this.token,
    required this.preset,
    required this.createdAt,
    required this.expiresAt,
    this.label,
    this.revokedAt,
    this.lastViewedAt,
  });

  final String id;
  final String petId;

  /// The only key to the sheet: 43 random characters.
  final String token;
  final SharePreset preset;

  /// For whom: "Hotel Pet Feliz".
  final String? label;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? revokedAt;
  final DateTime? lastViewedAt;

  bool isActive(DateTime now) => revokedAt == null && expiresAt.isAfter(now);

  String get url => '$shareBaseUrl#$token';

  static PetShare fromRow(Map<String, dynamic> row) {
    DateTime? time(String key) {
      final value = row[key];
      return value is String ? DateTime.parse(value).toUtc() : null;
    }

    return PetShare(
      id: row['id'] as String,
      petId: row['pet_id'] as String,
      token: row['token'] as String,
      preset: SharePreset.fromWire(row['preset'] as String),
      label: row['label'] as String?,
      createdAt: time('created_at')!,
      expiresAt: time('expires_at')!,
      revokedAt: time('revoked_at'),
      lastViewedAt: time('last_viewed_at'),
    );
  }
}

/// 32 random bytes in base64url, without padding: 43 characters.
String newShareToken([Random? random]) {
  final source = random ?? Random.secure();
  final bytes = List<int>.generate(32, (_) => source.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}
