// Thin wrapper around local_auth (injectable for tests).

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

typedef BiometricAuthenticate = Future<bool> Function({
  required String reason,
});

enum BiometricKind { none, fingerprint, face, other }

enum BiometricAuthStatus {
  success,
  canceled,
  unavailable,
  lockout,
  failed,
}

class BiometricAuthResult {
  const BiometricAuthResult(this.status);

  final BiometricAuthStatus status;

  bool get success => status == BiometricAuthStatus.success;

  /// User dismissed the prompt or asked for PIN instead — stay silent.
  bool get isCanceled => status == BiometricAuthStatus.canceled;

  String? get userMessage {
    switch (status) {
      case BiometricAuthStatus.success:
      case BiometricAuthStatus.canceled:
        return null;
      case BiometricAuthStatus.unavailable:
        return 'Biometrics unavailable. Enter your PIN.';
      case BiometricAuthStatus.lockout:
        return 'Too many attempts. Enter your PIN.';
      case BiometricAuthStatus.failed:
        return 'Couldn’t unlock with biometrics. Enter your PIN.';
    }
  }
}

class BiometricAuth {
  BiometricAuth._();
  static final instance = BiometricAuth._();

  LocalAuthentication _auth = LocalAuthentication();
  BiometricAuthenticate? _overrideAuthenticate;
  Future<bool> Function()? _overrideAvailable;
  Future<BiometricKind> Function()? _overrideKind;

  @visibleForTesting
  void debugOverride({
    BiometricAuthenticate? authenticate,
    Future<bool> Function()? available,
    Future<BiometricKind> Function()? kind,
  }) {
    _overrideAuthenticate = authenticate;
    _overrideAvailable = available;
    _overrideKind = kind;
  }

  @visibleForTesting
  void debugClearOverride() {
    _overrideAuthenticate = null;
    _overrideAvailable = null;
    _overrideKind = null;
    _auth = LocalAuthentication();
  }

  Future<bool> isAvailable() async {
    if (_overrideAvailable != null) return _overrideAvailable!();
    try {
      // Hardware check first — some Android devices report an empty enrolled
      // list even when Class 2/3 biometrics can still prompt.
      if (await _auth.canCheckBiometrics) return true;
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<BiometricKind> preferredKind() async {
    if (_overrideKind != null) return _overrideKind!();
    try {
      final enrolled = await _auth.getAvailableBiometrics();
      if (enrolled.contains(BiometricType.face)) return BiometricKind.face;
      if (enrolled.contains(BiometricType.fingerprint) ||
          enrolled.contains(BiometricType.iris)) {
        return BiometricKind.fingerprint;
      }
      if (enrolled.contains(BiometricType.strong) ||
          enrolled.contains(BiometricType.weak)) {
        return BiometricKind.other;
      }
      return enrolled.isEmpty ? BiometricKind.none : BiometricKind.other;
    } catch (_) {
      return BiometricKind.none;
    }
  }

  IconData iconFor(BiometricKind kind) {
    switch (kind) {
      case BiometricKind.face:
        return Icons.face_rounded;
      case BiometricKind.fingerprint:
      case BiometricKind.other:
      case BiometricKind.none:
        return Icons.fingerprint_rounded;
    }
  }

  String labelFor(BiometricKind kind) {
    switch (kind) {
      case BiometricKind.face:
        return 'Use Face ID';
      case BiometricKind.fingerprint:
        return 'Use fingerprint';
      case BiometricKind.other:
      case BiometricKind.none:
        return 'Use biometrics';
    }
  }

  Future<BiometricAuthResult> authenticate({
    required String reason,
  }) async {
    if (_overrideAuthenticate != null) {
      final ok = await _overrideAuthenticate!(reason: reason);
      return BiometricAuthResult(
        ok ? BiometricAuthStatus.success : BiometricAuthStatus.canceled,
      );
    }
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        // App PIN is the weekly fallback — don't offer device credentials.
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      return BiometricAuthResult(
        ok ? BiometricAuthStatus.success : BiometricAuthStatus.failed,
      );
    } on LocalAuthException catch (e) {
      return mapException(e);
    } catch (_) {
      return const BiometricAuthResult(BiometricAuthStatus.failed);
    }
  }

  Future<void> stop() async {
    if (_overrideAuthenticate != null) return;
    try {
      await _auth.stopAuthentication();
    } catch (_) {}
  }

  @visibleForTesting
  static BiometricAuthResult mapException(LocalAuthException e) {
    switch (e.code) {
      case LocalAuthExceptionCode.userCanceled:
      case LocalAuthExceptionCode.systemCanceled:
      case LocalAuthExceptionCode.userRequestedFallback:
        return const BiometricAuthResult(BiometricAuthStatus.canceled);
      case LocalAuthExceptionCode.noBiometricHardware:
      case LocalAuthExceptionCode.noBiometricsEnrolled:
      case LocalAuthExceptionCode.noCredentialsSet:
      case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
      case LocalAuthExceptionCode.uiUnavailable:
        return const BiometricAuthResult(BiometricAuthStatus.unavailable);
      case LocalAuthExceptionCode.temporaryLockout:
      case LocalAuthExceptionCode.biometricLockout:
        return const BiometricAuthResult(BiometricAuthStatus.lockout);
      default:
        return const BiometricAuthResult(BiometricAuthStatus.failed);
    }
  }
}
