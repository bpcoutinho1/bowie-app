import 'package:uuid/uuid.dart';

import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/core/text.dart';
import 'package:bowie/features/auth/domain/app_user.dart';
import 'package:bowie/features/contacts/domain/contact.dart';
import 'package:bowie/features/houses/houses.dart';
import 'package:bowie/features/pets/data/pet_local_store.dart';

/// What a person fills in on the contact form.
class ContactInput {
  const ContactInput({
    required this.name,
    required this.category,
    this.phone,
    this.email,
    this.address,
    this.notes,
  });

  final String name;
  final ContactCategory category;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
}

class ContactsRepository {
  ContactsRepository(this._store, {Uuid? ids, DateTime Function()? now})
    : _houses = Houses(_store),
      _ids = ids ?? const Uuid(),
      _now = now ?? DateTime.now;

  final PetLocalStore _store;
  final Houses _houses;
  final Uuid _ids;
  final DateTime Function() _now;

  Stream<ChangeReason> get changes => _store.changes;

  /// The house's contacts by category (in the order of [ContactCategory]),
  /// then by name.
  Future<List<Contact>> list(String houseId) async {
    return (await _store.listContacts(houseId))..sort((a, b) {
      final byCategory = a.category.index.compareTo(b.category.index);
      if (byCategory != 0) return byCategory;
      return foldText(a.name).compareTo(foldText(b.name));
    });
  }

  Future<Contact?> get(String id) => _store.getContact(id);

  /// The contacts of the house a pet belongs to, for the diary.
  Future<List<Contact>> listForPet(String petId) async {
    final house = await _store.houseOfPet(petId);
    return house == null ? const [] : list(house);
  }

  Future<Contact> save({
    String? id,
    required String houseId,
    required ContactInput input,
    required AppUser byUser,
  }) async {
    await _houses.requireMember(houseId, byUser);
    final name = input.name.trim();
    if (name.isEmpty) throw const AppFailure('Digite o nome.');
    if (name.length > 80) {
      throw const AppFailure('Use no máximo 80 caracteres no nome.');
    }
    String? phone;
    final rawPhone = input.phone?.trim() ?? '';
    if (rawPhone.isNotEmpty) {
      phone = normalizePhone(rawPhone);
      if (phone == null) {
        throw const AppFailure('Confira o telefone, com DDD.');
      }
    }
    final email = normalizeEmail(input.email ?? '');
    if (email.isNotEmpty && !emailLooksValid(email)) {
      throw const AppFailure('Confira o email.');
    }
    final address = _optional(input.address, 'o endereço', 200);
    final notes = _optional(input.notes, 'as observações', 500);

    final contact = Contact(
      id: id ?? _ids.v4(),
      houseId: houseId,
      name: name,
      category: input.category,
      phone: phone,
      email: email.isEmpty ? null : email,
      address: address,
      notes: notes,
      updatedBy: byUser.id,
      updatedAt: _now().toUtc(),
    );
    await _store.saveContact(contact);
    return contact;
  }

  /// Diary entries that point to a deleted contact keep showing its name.
  Future<void> delete({required String id, required AppUser byUser}) async {
    final contact = await _store.getContact(id);
    if (contact == null || contact.deletedAt != null) {
      throw const AppFailure('Este contato não está mais disponível.');
    }
    await _houses.requireMember(contact.houseId, byUser);
    final now = _now().toUtc();
    await _store.saveContact(
      contact.copyWith(deletedAt: now, updatedAt: now, updatedBy: byUser.id),
    );
  }

  String? _optional(String? value, String what, int max) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (text.length > max) {
      throw AppFailure('Use no máximo $max caracteres para $what.');
    }
    return text;
  }
}
