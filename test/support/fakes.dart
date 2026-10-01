import 'dart:async';

import 'package:bowie/core/sync/network_status.dart';
import 'package:bowie/features/pets/data/pet_remote_api.dart';
import 'package:bowie/features/pets/domain/pet.dart';
import 'package:bowie/features/pets/domain/pet_tutor.dart';

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

  @override
  Future<List<Pet>> pullPets() async => List.of(pets);

  @override
  Future<List<PetTutor>> pullTutors() async => List.of(tutors);
}
