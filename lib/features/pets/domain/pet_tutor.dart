enum PetRole { owner, tutor }

enum TutorStatus { pending, accepted }

class PetTutor {
  const PetTutor({
    required this.id,
    required this.petId,
    required this.userId,
    required this.email,
    required this.role,
    required this.status,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String petId;
  final String? userId;
  final String email;
  final PetRole role;
  final TutorStatus status;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  PetTutor copyWith({
    String? userId,
    TutorStatus? status,
    DateTime? updatedAt,
    bool clearUserId = false,
  }) {
    return PetTutor(
      id: id,
      petId: petId,
      userId: clearUserId ? null : userId ?? this.userId,
      email: email,
      role: role,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt,
    );
  }

  Map<String, Object?> toRow() {
    return {
      'id': id,
      'pet_id': petId,
      'user_id': userId,
      'email': email,
      'role': role.name,
      'status': status.name,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'deleted_at': deletedAt?.toUtc().toIso8601String(),
    };
  }

  static PetTutor fromRow(Map<String, Object?> row) {
    final deleted = row['deleted_at'];
    return PetTutor(
      id: row['id']! as String,
      petId: row['pet_id']! as String,
      userId: row['user_id'] as String?,
      email: row['email']! as String,
      role: PetRole.values.byName(row['role']! as String),
      status: TutorStatus.values.byName(row['status']! as String),
      updatedAt: DateTime.parse(row['updated_at']! as String).toUtc(),
      deletedAt: deleted == null
          ? null
          : DateTime.parse(deleted as String).toUtc(),
    );
  }
}

class TutorInvite {
  const TutorInvite({required this.tutor, required this.petName});

  final PetTutor tutor;
  final String petName;
}
