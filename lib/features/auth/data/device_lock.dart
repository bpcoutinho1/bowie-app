import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

import 'package:bowie/core/error/app_failure.dart';

class DeviceLock {
  DeviceLock({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  Future<bool> isSupported() => _auth.isDeviceSupported();

  Future<void> unlock() async {
    try {
      final unlocked = await _auth.authenticate(
        localizedReason: 'Desbloqueie para ver os dados dos seus pets.',
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Desbloquear o Bowie',
            cancelButton: 'Cancelar',
          ),
          IOSAuthMessages(
            cancelButton: 'Cancelar',
            localizedFallbackTitle: 'Usar código',
          ),
        ],
        biometricOnly: false,
        sensitiveTransaction: false,
        persistAcrossBackgrounding: true,
      );
      if (!unlocked) {
        throw const AppFailure('O desbloqueio foi cancelado.');
      }
    } on LocalAuthException catch (error) {
      throw AppFailure(_message(error));
    }
  }

  String _message(LocalAuthException error) {
    return switch (error.code) {
      LocalAuthExceptionCode.userCanceled ||
      LocalAuthExceptionCode.systemCanceled ||
      LocalAuthExceptionCode.timeout => 'O desbloqueio foi cancelado.',
      LocalAuthExceptionCode.noCredentialsSet =>
        'Configure um código de bloqueio no celular para usar o Bowie.',
      _ => 'Não foi possível desbloquear. Tente de novo.',
    };
  }
}
