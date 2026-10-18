// Set / change PIN from Settings.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../data/app_lock_store.dart';
import '../../domain/pin_crypto.dart';
import 'pin_entry.dart';

Future<bool?> showPinSetupSheet(
  BuildContext context, {
  required String title,
  String? currentPinRequired,
}) {
  return showAppSheet<bool>(
    context: context,
    builder: (ctx) => _PinSetupSheetBody(
      title: title,
      currentPinRequired: currentPinRequired,
    ),
  );
}

class _PinSetupSheetBody extends StatefulWidget {
  const _PinSetupSheetBody({
    required this.title,
    this.currentPinRequired,
  });

  final String title;
  final String? currentPinRequired;

  @override
  State<_PinSetupSheetBody> createState() => _PinSetupSheetBodyState();
}

class _PinSetupSheetBodyState extends State<_PinSetupSheetBody> {
  String _pin = '';
  String _confirm = '';
  String _error = '';
  bool _busy = false;
  bool _needCurrent = false;
  bool _confirmStep = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _needCurrent = widget.currentPinRequired == 'verify';
  }

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

    if (_needCurrent) {
      if (!PinCrypto.isValid(next) || _busy) return;
      _timer?.cancel();
      final delay =
          next.length == 6 ? Duration.zero : const Duration(milliseconds: 450);
      _timer = Timer(delay, () {
        if (!mounted) return;
        if (!AppLockStore.instance.verify(next)) {
          HapticFeedback.heavyImpact();
          setState(() {
            _error = 'Wrong PIN.';
            _pin = '';
          });
          return;
        }
        setState(() {
          _needCurrent = false;
          _pin = '';
          _confirmStep = false;
        });
      });
      return;
    }

    if (_confirmStep) {
      if (!PinCrypto.isValid(next)) return;
      _timer?.cancel();
      final delay =
          next.length == 6 ? Duration.zero : const Duration(milliseconds: 450);
      _timer = Timer(delay, () async {
        if (!mounted) return;
        if (next != _confirm) {
          HapticFeedback.heavyImpact();
          setState(() {
            _error = 'PINs do not match.';
            _pin = '';
            _confirm = '';
            _confirmStep = false;
          });
          return;
        }
        setState(() => _busy = true);
        await AppLockStore.instance.setPin(next);
        if (!mounted) return;
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop(true);
      });
      return;
    }

    if (!PinCrypto.isValid(next)) return;
    _timer?.cancel();
    final delay =
        next.length == 6 ? Duration.zero : const Duration(milliseconds: 450);
    _timer = Timer(delay, () {
      if (!mounted) return;
      setState(() {
        _confirm = next;
        _pin = '';
        _confirmStep = true;
      });
    });
  }

  String get _subtitle {
    if (_needCurrent) return 'Enter your current PIN first.';
    if (_confirmStep) return 'Enter the same PIN again.';
    return 'Choose a 4–6 digit PIN.';
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
            _subtitle,
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
            hint: _busy ? 'Saving…' : 'Enter 4–6 digit PIN',
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
