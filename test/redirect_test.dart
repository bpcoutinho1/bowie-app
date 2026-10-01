import 'package:flutter_test/flutter_test.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/app/router.dart';

void main() {
  test('loading stays on the loading route', () {
    expect(redirectFor(AuthGate.loading, '/loading'), isNull);
    expect(redirectFor(AuthGate.loading, '/pets'), '/loading');
  });

  test('signed out users can only see login', () {
    expect(redirectFor(AuthGate.signedOut, '/login'), isNull);
    expect(redirectFor(AuthGate.signedOut, '/pets/new'), '/login');
  });

  test('a saved session stays locked until the device is unlocked', () {
    expect(redirectFor(AuthGate.locked, '/unlock'), isNull);
    expect(redirectFor(AuthGate.locked, '/pets/1'), '/unlock');
  });

  test('an unlocked session leaves the auth screens', () {
    expect(redirectFor(AuthGate.ready, '/login'), '/pets');
    expect(redirectFor(AuthGate.ready, '/unlock'), '/pets');
    expect(redirectFor(AuthGate.ready, '/loading'), '/pets');
    expect(redirectFor(AuthGate.ready, '/pets'), isNull);
    expect(redirectFor(AuthGate.ready, '/pets/new'), isNull);
  });
}
