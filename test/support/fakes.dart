import 'dart:async';
import 'dart:typed_data';

import 'package:bowie/core/sync/network_status.dart';
import 'package:bowie/features/health/domain/vaccine_dose.dart';
import 'package:bowie/features/pets/data/pet_remote_api.dart';
import 'package:bowie/features/pets/domain/pet.dart';
import 'package:bowie/features/pets/domain/pet_tutor.dart';
import 'package:bowie/features/shopping/domain/shopping_item.dart';

class FakeNetwork implements NetworkStatus {
  FakeNetwork({this.online = true});

  bool online;
  final _changes = StreamController<bool>.broadcast();

  @override
  Future<bool> get isOnline async => online;

  @override
  Stream<bool> get onStatusChanged => _changes.stream;
}

class FakeRemote implements PetRemoteApi {
  final pets = <Pet>[];
  final tutors = <PetTutor>[];
  final calls = <String>[];

  @override
  Future<void> upsertPet(Map<String, dynamic> row) async {
    calls.add('pets');
    final pet = Pet.fromRow(Map<String, Object?>.from(row));
    pets.removeWhere((item) => item.id == pet.id);
    pets.add(pet);
  }

  @override
  Future<void> upsertTutor(Map<String, dynamic> row) async {
    calls.add('pet_tutors');
    final tutor = PetTutor.fromRow(Map<String, Object?>.from(row));
    tutors.removeWhere((item) => item.id == tutor.id);
    tutors.add(tutor);
  }

  final doses = <VaccineDose>[];

  @override
  Future<void> upsertDose(Map<String, dynamic> row) async {
    calls.add('pet_vaccines');
    final dose = VaccineDose.fromRow(Map<String, Object?>.from(row));
    doses.removeWhere((item) => item.id == dose.id);
    doses.add(dose);
  }

  @override
  Future<List<VaccineDose>> pullDoses() async => List.of(doses);

  final shopping = <ShoppingItem>[];

  @override
  Future<void> upsertShoppingItem(Map<String, dynamic> row) async {
    calls.add('shopping_items');
    final item = ShoppingItem.fromRow(Map<String, Object?>.from(row));
    shopping.removeWhere((other) => other.id == item.id);
    shopping.add(item);
  }

  @override
  Future<List<ShoppingItem>> pullShoppingItems() async => List.of(shopping);

  final photos = <String, Uint8List>{};

  @override
  Future<void> uploadPhoto(String path, Uint8List photo) async {
    calls.add('upload $path');
    photos[path] = photo;
  }

  @override
  Future<void> removePhoto(String path) async {
    calls.add('remove $path');
    photos.remove(path);
  }

  @override
  Future<Uint8List?> downloadPhoto(String path) async => photos[path];

  /// Mirrors transfer_pet on the server.
  @override
  Future<void> transferPet({
    required String petId,
    required String tutorId,
  }) async {
    calls.add('transfer');
    final now = DateTime.now().toUtc();
    for (var i = 0; i < tutors.length; i++) {
      final tutor = tutors[i];
      if (tutor.petId != petId) continue;
      final role = tutor.id == tutorId
          ? PetRole.owner
          : tutor.role == PetRole.owner
          ? PetRole.tutor
          : tutor.role;
      tutors[i] = PetTutor(
        id: tutor.id,
        petId: tutor.petId,
        userId: tutor.userId,
        email: tutor.email,
        role: role,
        status: tutor.status,
        updatedAt: now,
        deletedAt: tutor.deletedAt,
      );
    }
  }

  @override
  Future<List<Pet>> pullPets() async => List.of(pets);

  @override
  Future<List<PetTutor>> pullTutors() async => List.of(tutors);
}
