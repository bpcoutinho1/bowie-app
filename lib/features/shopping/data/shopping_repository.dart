import 'package:uuid/uuid.dart';

import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/core/text.dart';
import 'package:bowie/features/auth/domain/app_user.dart';
import 'package:bowie/features/pets/data/pet_local_store.dart';
import 'package:bowie/features/shopping/domain/shopping_catalog.dart';
import 'package:bowie/features/shopping/domain/shopping_item.dart';

/// A house's list, split as the screen shows it. Both parts in name order.
class ShoppingList {
  const ShoppingList({required this.toBuy, required this.frequent});

  final List<ShoppingItem> toBuy;
  final List<ShoppingItem> frequent;
}

class ShoppingRepository {
  ShoppingRepository(this._store, {Uuid? ids, DateTime Function()? now})
    : _ids = ids ?? const Uuid(),
      _now = now ?? DateTime.now;

  final PetLocalStore _store;
  final Uuid _ids;
  final DateTime Function() _now;

  Stream<ChangeReason> get changes => _store.changes;

  /// The houses [user] belongs to, their own first.
  Future<List<House>> listHouses(AppUser user) async {
    final rows = await _store.listHouses(normalizeEmail(user.email));
    final houses = [
      for (final row in rows)
        House(
          id: row.id,
          ownerEmail: row.ownerEmail,
          isMine: row.id == user.id,
        ),
    ]..sort((a, b) => a.isMine == b.isMine ? 0 : (a.isMine ? -1 : 1));
    return houses;
  }

  Future<ShoppingList> listItems(String houseId) async {
    final items = await _store.listShoppingItems(houseId)
      ..sort((a, b) => foldText(a.name).compareTo(foldText(b.name)));
    return ShoppingList(
      toBuy: [
        for (final item in items)
          if (item.status == ShoppingStatus.toBuy) item,
      ],
      frequent: [
        for (final item in items)
          if (item.status == ShoppingStatus.bought) item,
      ],
    );
  }

  /// Puts an item on the list. A name already among the frequent items goes
  /// back to the list instead of becoming a second item.
  Future<ShoppingItem> add({
    required String houseId,
    required String name,
    String? details,
    String? catalogKey,
    required AppUser byUser,
  }) async {
    await _requireMember(houseId, byUser);
    final cleanName = _name(name);
    final cleanDetails = _details(details);
    final key = foldText(cleanName);
    final existing = (await _store.listShoppingItems(
      houseId,
    )).where((item) => foldText(item.name) == key).firstOrNull;
    if (existing != null) {
      if (existing.status == ShoppingStatus.toBuy) {
        throw AppFailure('${existing.name} já está na lista.');
      }
      final back = existing.copyWith(
        status: ShoppingStatus.toBuy,
        details: cleanDetails,
        updatedBy: byUser.id,
        updatedAt: _timestamp,
      );
      await _store.saveShoppingItem(back);
      return back;
    }
    final item = ShoppingItem(
      id: _ids.v4(),
      houseId: houseId,
      name: cleanName,
      details: cleanDetails,
      catalogKey: catalogKey ?? matchCatalog(cleanName)?.key,
      status: ShoppingStatus.toBuy,
      updatedBy: byUser.id,
      updatedAt: _timestamp,
    );
    await _store.saveShoppingItem(item);
    return item;
  }

  /// Bought items go to the frequent items; a tap there brings them back.
  Future<ShoppingItem> setStatus({
    required String id,
    required ShoppingStatus status,
    required AppUser byUser,
  }) async {
    final item = await _require(id, byUser);
    final changed = item.copyWith(
      status: status,
      updatedBy: byUser.id,
      updatedAt: _timestamp,
    );
    await _store.saveShoppingItem(changed);
    return changed;
  }

  Future<void> edit({
    required String id,
    required String name,
    String? details,
    required AppUser byUser,
  }) async {
    final item = await _require(id, byUser);
    final cleanName = _name(name);
    final key = foldText(cleanName);
    final clash = (await _store.listShoppingItems(
      item.houseId,
    )).any((other) => other.id != id && foldText(other.name) == key);
    if (clash) throw AppFailure('Já existe um item chamado $cleanName.');
    final cleanDetails = _details(details);
    await _store.saveShoppingItem(
      item.copyWith(
        name: cleanName,
        details: cleanDetails,
        clearDetails: cleanDetails == null,
        catalogKey: item.catalogKey ?? matchCatalog(cleanName)?.key,
        updatedBy: byUser.id,
        updatedAt: _timestamp,
      ),
    );
  }

  /// Removes the item from the house, frequent items included.
  Future<void> delete({required String id, required AppUser byUser}) async {
    final item = await _require(id, byUser);
    final now = _timestamp;
    await _store.saveShoppingItem(
      item.copyWith(deletedAt: now, updatedAt: now, updatedBy: byUser.id),
    );
  }

  Future<ShoppingItem> _require(String id, AppUser user) async {
    final item = await _store.getShoppingItem(id);
    if (item == null) {
      throw const AppFailure('Este item não está mais na lista.');
    }
    await _requireMember(item.houseId, user);
    return item;
  }

  Future<void> _requireMember(String houseId, AppUser user) async {
    if (houseId == user.id) return;
    final houses = await listHouses(user);
    if (!houses.any((house) => house.id == houseId)) {
      throw const AppFailure('Você não faz parte desta casa.');
    }
  }

  String _name(String name) {
    final text = name.trim();
    if (text.isEmpty) throw const AppFailure('Digite o nome do item.');
    if (text.length > 80) {
      throw const AppFailure('Use no máximo 80 caracteres no nome.');
    }
    return text;
  }

  String? _details(String? details) {
    final text = details?.trim() ?? '';
    if (text.isEmpty) return null;
    if (text.length > 120) {
      throw const AppFailure('Use no máximo 120 caracteres na descrição.');
    }
    return text;
  }

  DateTime get _timestamp => _now().toUtc();
}
