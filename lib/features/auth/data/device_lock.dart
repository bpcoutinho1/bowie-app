import 'package:local_auth/local_auth.dart';

import 'package:bowie/core/error/app_failure.dart';

class DeviceLock {
  DeviceLock({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  Future<bool> isSupported() => _auth.isDeviceSupported();

  Future<void> unlock() async {
    try {
      final unlocked = await _auth.authenticate(
        localizedReason:
            'Unlock Bowie with Face ID, Touch ID, or your device passcode.',
        biometricOnly: false,
        sensitiveTransaction: false,
        persistAcrossBackgrounding: true,
      );
      if (!unlocked) {
        throw const AppFailure('Authentication was canceled.');
      }
    } on LocalAuthException catch (error) {
      throw AppFailure(_message(error));
    }
  }

  String _message(LocalAuthException error) {
    return switch (error.code) {
      LocalAuthExceptionCode.userCanceled ||
      LocalAuthExceptionCode.systemCanceled ||
      LocalAuthExceptionCode.timeout => 'Authentication was canceled.',
      LocalAuthExceptionCode.noCredentialsSet =>
        'Set a device passcode to unlock Bowie.',
      _ => error.description ?? 'Could not unlock this device.',
    };
  }
}
