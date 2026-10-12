import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/features/auth/domain/app_user.dart';

Session session(Map<String, dynamic> metadata) => Session(
  accessToken: 'token',
  tokenType: 'bearer',
  user: User(
    id: 'bruno-1',
    appMetadata: const {},
    userMetadata: metadata,
    aud: 'authenticated',
    email: 'Bruno@Example.com',
    createdAt: '2026-10-12T00:00:00Z',
  ),
);

void main() {
  test('name and cell phone are cleaned up', () {
    final profile = checkProfile(
      name: '  Bruno   Coutinho ',
      phone: '+55 (11) 98765-4321',
    );
    expect(profile.name, 'Bruno Coutinho');
    expect(profile.phone, '11987654321');
  });

  test('a missing name or a landline is refused', () {
    expect(
      () => checkProfile(name: ' ', phone: '11987654321'),
      throwsA(isA<AppFailure>()),
    );
    expect(
      () => checkProfile(name: 'Bruno', phone: '(11) 3456-7890'),
      throwsA(isA<AppFailure>()),
    );
    expect(
      () => checkProfile(name: 'Bruno', phone: '98765'),
      throwsA(isA<AppFailure>()),
    );
  });

  test('the session carries the name and phone saved in the account', () {
    final user = userFromSession(
      session({'name': 'Bruno', 'phone': '11987654321'}),
    )!;
    expect(user.email, 'bruno@example.com');
    expect(user.name, 'Bruno');
    expect(user.phone, '11987654321');
    expect(user.profileComplete, isTrue);
  });

  test('older accounts are asked to complete the profile', () {
    final user = userFromSession(session({'name': '  '}))!;
    expect(user.name, isNull);
    expect(user.profileComplete, isFalse);
  });
}
