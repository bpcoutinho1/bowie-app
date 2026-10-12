import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/features/contacts/domain/contact.dart';

class AppUser {
  const AppUser({required this.id, required this.email, this.name, this.phone});

  final String id;
  final String email;

  /// How the person wants to be called, as typed at sign up.
  final String? name;

  /// Cell phone digits with area code, like "11987654321".
  final String? phone;

  /// Accounts made before name and phone were asked are completed in
  /// "Minha conta".
  bool get profileComplete => name != null && phone != null;
}

String normalizeEmail(String value) => value.trim().toLowerCase();

bool emailLooksValid(String value) {
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalizeEmail(value));
}

/// The name and cell phone of an account, cleaned up, or an [AppFailure]
/// saying what to fix.
({String name, String phone}) checkProfile({
  required String name,
  required String phone,
}) {
  final cleanName = name.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (cleanName.length < 2) throw const AppFailure('Digite o seu nome.');
  if (cleanName.length > 80) {
    throw const AppFailure('Use um nome com até 80 caracteres.');
  }
  final digits = normalizePhone(phone);
  if (digits == null || !isMobile(digits)) {
    throw const AppFailure('Digite um celular com DDD, como (11) 98765-4321.');
  }
  return (name: cleanName, phone: digits);
}
