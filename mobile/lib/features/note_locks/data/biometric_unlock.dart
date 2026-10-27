import 'package:local_auth/local_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/logging/log_tags.dart';

part 'biometric_unlock.g.dart';

/// How a fingerprint or face prompt ended.
enum BiometricOutcome {
  unlocked,

  /// Cancelled or not recognised; the person can try again.
  failed,

  /// Too many tries; the device asks for its own unlock first.
  lockedOut,

  /// Nothing to prompt with: no fingerprint, face, PIN, pattern or
  /// password on the device.
  unavailable,
}

@Riverpod(keepAlive: true)
BiometricUnlock biometricUnlock(Ref ref) => LocalAuthBiometricUnlock();

/// The system's fingerprint or face prompt, with the device's own screen
/// lock allowed instead.
abstract class BiometricUnlock {
  /// Whether the device can prompt at all.
  Future<bool> isAvailable();

  Future<BiometricOutcome> authenticate(String reason);
}

class LocalAuthBiometricUnlock implements BiometricUnlock {
  final _auth = LocalAuthentication();

  @override
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (e) {
      AppLogger.instance.warn(LogTags.noteLocks, 'Biometric check failed: $e');
      return false;
    }
  }

  @override
  Future<BiometricOutcome> authenticate(String reason) async {
    try {
      final ok = await _auth.authenticate(localizedReason: reason);
      return ok ? BiometricOutcome.unlocked : BiometricOutcome.failed;
    } on LocalAuthException catch (e) {
      AppLogger.instance.info(
        LogTags.noteLocks,
        'Biometric prompt: ${e.code.name}',
      );
      return switch (e.code) {
        LocalAuthExceptionCode.noBiometricHardware ||
        LocalAuthExceptionCode.noCredentialsSet ||
        LocalAuthExceptionCode.noBiometricsEnrolled ||
        LocalAuthExceptionCode.uiUnavailable => BiometricOutcome.unavailable,
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout => BiometricOutcome.lockedOut,
        _ => BiometricOutcome.failed,
      };
    } catch (e) {
      AppLogger.instance.warn(LogTags.noteLocks, 'Biometric prompt failed: $e');
      return BiometricOutcome.failed;
    }
  }
}
