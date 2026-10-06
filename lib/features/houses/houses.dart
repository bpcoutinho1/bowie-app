import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/features/auth/domain/app_user.dart';
import 'package:bowie/features/pets/data/pet_local_store.dart';

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

/// The houses a person belongs to (docs/produto/compras.md). Shopping and
/// contacts belong to a house.
class Houses {
  Houses(this._store);

  final PetLocalStore _store;

  /// The houses [user] belongs to, their own first.
  Future<List<House>> list(AppUser user) async {
    final rows = await _store.listHouses(normalizeEmail(user.email));
    return [
      for (final row in rows)
        House(
          id: row.id,
          ownerEmail: row.ownerEmail,
          isMine: row.id == user.id,
        ),
    ]..sort((a, b) => a.isMine == b.isMine ? 0 : (a.isMine ? -1 : 1));
  }

  Future<void> requireMember(String houseId, AppUser user) async {
    if (houseId == user.id) return;
    final houses = await list(user);
    if (!houses.any((house) => house.id == houseId)) {
      throw const AppFailure('Você não faz parte desta casa.');
    }
  }
}
