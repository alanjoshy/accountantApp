// App lock / PIN unlock (web AppLockGate).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../data/app_lock_store.dart';
import '../../domain/app_session.dart';
import '../../domain/biometric_auth.dart';
import '../../domain/pin_crypto.dart';
import '../widgets/pin_entry.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({
    super.key,
    this.hasPin,
    this.verifyPin,
    this.savePin,
    this.tryBiometricOnStart = true,
  });

  /// Optional seams for tests — defaults to [AppLockStore].
  final bool Function()? hasPin;
  final bool Function(String pin)? verifyPin;
  final Future<void> Function(String pin)? savePin;
  final bool tryBiometricOnStart;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _pin = '';
  String _confirmPin = '';
  String _error = '';
  bool _busy = false;
  bool _setupMode = false;
  bool _confirmStep = false;
  Timer? _verifyTimer;
  bool _verifying = false;
  bool _biometricAvailable = false;
  bool _biometricPrompting = false;
  bool _pinAutoFocus = true;
  BiometricKind _biometricKind = BiometricKind.none;
  String _bioNotice = '';

  bool get _hasPin => widget.hasPin?.call() ?? AppLockStore.instance.hasPin;

  bool _verify(String pin) =>
      widget.verifyPin?.call(pin) ?? AppLockStore.instance.verify(pin);

  Future<void> _save(String pin) =>
      widget.savePin?.call(pin) ?? AppLockStore.instance.setPin(pin);

  bool get _weeklyPinDue => AppLockStore.instance.requiresWeeklyPin();

  bool get _canBiometric =>
      _biometricAvailable && AppLockStore.instance.canUseBiometricUnlock;

  @override
  void initState() {
    super.initState();
    _setupMode = !_hasPin;
    if (!_setupMode) {
      // Don't fight the system biometric sheet with the PIN keyboard.
      _pinAutoFocus = !widget.tryBiometricOnStart;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _probeBiometric();
      });
    }
  }

  Future<void> _probeBiometric() async {
    final available = await BiometricAuth.instance.isAvailable();
    final kind = available
        ? await BiometricAuth.instance.preferredKind()
        : BiometricKind.none;
    if (!mounted) return;
    setState(() {
      _biometricAvailable = available;
      _biometricKind = kind;
    });
    if (widget.tryBiometricOnStart &&
        available &&
        AppLockStore.instance.canUseBiometricUnlock) {
      await _tryBiometric();
    }
    if (!mounted) return;
    setState(() => _pinAutoFocus = true);
  }

  Future<void> _tryBiometric() async {
    if (_setupMode || _busy || _biometricPrompting) return;
    if (!AppLockStore.instance.canUseBiometricUnlock) return;
    FocusManager.instance.primaryFocus?.unfocus();
    AppSession.instance.setAuthenticating(true);
    setState(() {
      _biometricPrompting = true;
      _bioNotice = '';
      _pinAutoFocus = false;
    });
    final result = await BiometricAuth.instance.authenticate(
      reason: 'Unlock Accountant',
    );
    AppSession.instance.setAuthenticating(false);
    if (!mounted) return;
    if (result.success) {
      HapticFeedback.mediumImpact();
      await _enterApp(viaPin: false);
      return;
    }
    setState(() {
      _biometricPrompting = false;
      _pinAutoFocus = true;
      _bioNotice = result.userMessage ?? '';
      if (result.status == BiometricAuthStatus.unavailable) {
        _biometricAvailable = false;
      }
    });
  }

  Future<void> _enterApp({required bool viaPin}) async {
    if (viaPin) {
      await AppLockStore.instance.markPinUnlock();
    }
    AppSession.instance.unlock();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.home);
  }

  @override
  void dispose() {
    _verifyTimer?.cancel();
    if (_biometricPrompting) {
      unawaited(BiometricAuth.instance.stop());
      AppSession.instance.setAuthenticating(false);
    }
    super.dispose();
  }

  void _onPinChanged(String next) {
    setState(() {
      _pin = next;
      _error = '';
    });

    if (_setupMode) {
      if (_confirmStep) {
        _maybeConfirmSetup(next);
      } else if (PinCrypto.isValid(next)) {
        _verifyTimer?.cancel();
        final delay =
            next.length == 6 ? Duration.zero : const Duration(milliseconds: 450);
        _verifyTimer = Timer(delay, () {
          if (!mounted) return;
          setState(() {
            _confirmPin = next;
            _pin = '';
            _confirmStep = true;
          });
        });
      }
      return;
    }

    if (!PinCrypto.isValid(next) || _verifying) return;

    _verifyTimer?.cancel();
    final delay =
        next.length == 6 ? Duration.zero : const Duration(milliseconds: 550);
    _verifyTimer = Timer(delay, () => _unlock(next));
  }

  void _maybeConfirmSetup(String next) {
    if (!PinCrypto.isValid(next)) return;
    _verifyTimer?.cancel();
    final delay =
        next.length == 6 ? Duration.zero : const Duration(milliseconds: 450);
    _verifyTimer = Timer(delay, () async {
      if (!mounted) return;
      if (next != _confirmPin) {
        HapticFeedback.heavyImpact();
        setState(() {
          _error = 'PINs do not match.';
          _pin = '';
          _confirmPin = '';
          _confirmStep = false;
        });
        return;
      }
      setState(() => _busy = true);
      await _save(next);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      await _enterApp(viaPin: true);
    });
  }

  Future<void> _unlock(String pin) async {
    if (_verifying) return;
    _verifying = true;
    setState(() => _busy = true);

    final ok = _verify(pin);
    if (!mounted) return;

    if (ok) {
      HapticFeedback.mediumImpact();
      await _enterApp(viaPin: true);
      return;
    }

    HapticFeedback.heavyImpact();
    setState(() {
      _error = 'Wrong PIN.';
      _pin = '';
      _busy = false;
      _verifying = false;
    });
  }

  String get _title {
    if (!_setupMode) return 'Accountant is locked';
    return _confirmStep ? 'Confirm PIN' : 'Set your PIN';
  }

  String get _subtitle {
    if (!_setupMode) {
      if (_weeklyPinDue && AppLockStore.instance.biometricEnabled) {
        return 'Weekly PIN check — enter your PIN to continue.';
      }
      return 'Enter your PIN to continue.';
    }
    return _confirmStep
        ? 'Enter the same PIN again.'
        : 'Choose a 4–6 digit PIN to lock Accountant.';
  }

  String? get _hint {
    if (_error.isNotEmpty) return null;
    if (_busy) return 'Checking…';
    if (_setupMode && _confirmStep) return 'Confirm 4–6 digit PIN';
    return 'Enter 4–6 digit PIN';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final showBio = !_setupMode && _canBiometric;
    final weeklyNote = !_setupMode &&
        _weeklyPinDue &&
        AppLockStore.instance.biometricEnabled &&
        _biometricAvailable;

    return Scaffold(
      backgroundColor: colors.background,
      // Keyboard shortens the body; scroll instead of overflowing.
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 384),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: colors.accentMuted,
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusLg),
                              border: Border.all(
                                color: colors.accent.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Icon(
                              Icons.lock_rounded,
                              size: 24,
                              color: colors.accent,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            _title,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.lockTitle.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _subtitle,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.lockSubtitle.copyWith(
                              color: colors.textMuted,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          PinEntry(
                            value: _pin,
                            onChanged: _onPinChanged,
                            disabled: _busy,
                            error: _error.isNotEmpty,
                            errorMessage: _error.isEmpty ? null : _error,
                            hint: _hint,
                            autoFocus: _pinAutoFocus && !_biometricPrompting,
                          ),
                          if (_bioNotice.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              _bioNotice,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.textMuted,
                              ),
                            ),
                          ],
                          if (weeklyNote) ...[
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Fingerprint / Face ID unlock again after this PIN.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.textMuted,
                              ),
                            ),
                          ],
                          if (showBio) ...[
                            const SizedBox(height: AppSpacing.md),
                            TextButton.icon(
                              onPressed: (_busy || _biometricPrompting)
                                  ? null
                                  : _tryBiometric,
                              icon: Icon(
                                BiometricAuth.instance.iconFor(_biometricKind),
                              ),
                              label: Text(
                                BiometricAuth.instance.labelFor(_biometricKind),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
