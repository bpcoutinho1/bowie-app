class AppUser {
  const AppUser({required this.id, required this.email});

  final String id;
  final String email;
}

String normalizeEmail(String value) => value.trim().toLowerCase();

bool emailLooksValid(String value) {
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalizeEmail(value));
}
