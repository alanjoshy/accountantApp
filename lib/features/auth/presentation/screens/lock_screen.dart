// App lock / PIN unlock (web AppLockGate).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../data/app_lock_store.dart';
import '../../domain/pin_crypto.dart';
import '../widgets/pin_entry.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _setupMode = !AppLockStore.hasPin;
  }

  @override
  void dispose() {
    _verifyTimer?.cancel();
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
        final delay = next.length == 6 ? Duration.zero : const Duration(milliseconds: 450);
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
    final delay = next.length == 6 ? Duration.zero : const Duration(milliseconds: 550);
    _verifyTimer = Timer(delay, () => _unlock(next));
  }

  void _maybeConfirmSetup(String next) {
    if (!PinCrypto.isValid(next)) return;
    _verifyTimer?.cancel();
    final delay = next.length == 6 ? Duration.zero : const Duration(milliseconds: 450);
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
      await AppLockStore.setPin(next);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pushReplacementNamed(AppRouter.home);
    });
  }

  Future<void> _unlock(String pin) async {
    if (_verifying) return;
    _verifying = true;
    setState(() => _busy = true);

    final ok = AppLockStore.verify(pin);
    if (!mounted) return;

    if (ok) {
      HapticFeedback.mediumImpact();
      Navigator.of(context).pushReplacementNamed(AppRouter.home);
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
    if (!_setupMode) return 'Enter your PIN to continue.';
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 384),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.accentMuted,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      size: 24,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _title,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.lockTitle,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _subtitle,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.lockSubtitle,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PinEntry(
                    value: _pin,
                    onChanged: _onPinChanged,
                    disabled: _busy,
                    error: _error.isNotEmpty,
                    errorMessage: _error.isEmpty ? null : _error,
                    hint: _hint,
                    autoFocus: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
