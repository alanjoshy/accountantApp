// PIN (and optional biometric) sheet for sensitive actions.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../data/app_lock_store.dart';
import '../../domain/app_session.dart';
import '../../domain/biometric_auth.dart';
import '../../domain/pin_crypto.dart';
import '../../domain/sensitive_access_session.dart';
import 'pin_entry.dart';

/// Returns true when the user authenticated for sensitive UI.
Future<bool> ensureSensitiveAccess(
  BuildContext context, {
  String title = 'Reveal balances',
  String subtitle = 'Confirm it’s you to show account amounts.',
}) async {
  if (SensitiveAccessSession.instance.isRevealed) return true;
  if (!AppLockStore.instance.protectAccountBalances ||
      !AppLockStore.instance.hasPin) {
    return true;
  }

  final lock = AppLockStore.instance;
  if (lock.canUseBiometricUnlock) {
    AppSession.instance.setAuthenticating(true);
    final bio = await BiometricAuth.instance.authenticate(
      reason: 'Unlock to show account balances',
    );
    AppSession.instance.setAuthenticating(false);
    if (bio.success) {
      SensitiveAccessSession.instance.reveal();
      return true;
    }
  }

  if (!context.mounted) return false;
  final ok = await showUnlockSheet(
    context,
    title: lock.requiresWeeklyPin() ? 'Weekly PIN check' : title,
    subtitle: lock.requiresWeeklyPin()
        ? 'Enter your PIN once this week to keep using biometrics.'
        : subtitle,
  );
  if (ok == true) {
    SensitiveAccessSession.instance.reveal();
    return true;
  }
  return false;
}

Future<bool?> showUnlockSheet(
  BuildContext context, {
  String title = 'Enter PIN',
  String subtitle = 'Enter your PIN to continue.',
}) {
  return showAppSheet<bool>(
    context: context,
    builder: (ctx) => _UnlockSheetBody(title: title, subtitle: subtitle),
  );
}

class _UnlockSheetBody extends StatefulWidget {
  const _UnlockSheetBody({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  State<_UnlockSheetBody> createState() => _UnlockSheetBodyState();
}

class _UnlockSheetBodyState extends State<_UnlockSheetBody> {
  String _pin = '';
  String _error = '';
  bool _busy = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onPinChanged(String next) {
    setState(() {
      _pin = next;
      _error = '';
    });
    if (!PinCrypto.isValid(next) || _busy) return;
    _timer?.cancel();
    final delay =
        next.length == 6 ? Duration.zero : const Duration(milliseconds: 450);
    _timer = Timer(delay, () => _verify(next));
  }

  Future<void> _verify(String pin) async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = AppLockStore.instance.verify(pin);
    if (!mounted) return;
    if (ok) {
      await AppLockStore.instance.markPinUnlock();
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(true);
      return;
    }
    HapticFeedback.heavyImpact();
    setState(() {
      _error = 'Wrong PIN.';
      _pin = '';
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg + bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            widget.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: colors.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          PinEntry(
            value: _pin,
            onChanged: _onPinChanged,
            disabled: _busy,
            error: _error.isNotEmpty,
            errorMessage: _error.isEmpty ? null : _error,
            hint: _busy ? 'Checking…' : 'Enter 4–6 digit PIN',
            autoFocus: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
