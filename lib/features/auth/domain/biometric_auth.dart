// Thin wrapper around local_auth (injectable for tests).

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

typedef BiometricAuthenticate = Future<bool> Function({
  required String reason,
});

enum BiometricKind { none, fingerprint, face, other }

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
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      final can = await _auth.canCheckBiometrics;
      if (!can) return false;
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
      if (enrolled.contains(BiometricType.fingerprint)) {
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
        return Icons.fingerprint_rounded;
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
        return 'Use biometrics';
      case BiometricKind.none:
        return 'Use biometrics';
    }
  }

  Future<bool> authenticate({
    required String reason,
  }) async {
    if (_overrideAuthenticate != null) {
      return _overrideAuthenticate!(reason: reason);
    }
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        // App PIN is the weekly fallback — don't offer device credentials here.
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
