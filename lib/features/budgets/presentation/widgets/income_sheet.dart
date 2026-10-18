// Set monthly income from Budgets (web income sheet).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/currency/currency_controller.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../settings/data/app_settings_store.dart';

Future<void> showIncomeSheet(
  BuildContext context, {
  VoidCallback? onSavedWithCategories,
}) {
  return showAppSheet<void>(
    context: context,
    builder: (_) => IncomeSheet(onSavedWithCategories: onSavedWithCategories),
  );
}

class IncomeSheet extends StatefulWidget {
  const IncomeSheet({super.key, this.onSavedWithCategories});

  final VoidCallback? onSavedWithCategories;

  @override
  State<IncomeSheet> createState() => _IncomeSheetState();
}

class _IncomeSheetState extends State<IncomeSheet> {
  late final TextEditingController _income;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final value = AppSettingsStore.instance.monthlyIncome;
    _income = TextEditingController(
      text: value <= 0
          ? ''
          : (value == value.roundToDouble()
              ? value.round().toString()
              : value.toString()),
    );
  }

  @override
  void dispose() {
    _income.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final parsed = double.tryParse(_income.text.trim()) ?? 0;
    if (parsed < 0) {
      setState(() => _error = 'Enter a valid monthly income.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AppSettingsStore.instance.setMonthlyIncome(parsed);
      if (!mounted) return;
      Navigator.pop(context);
      AppToast.success(
        context,
        parsed > 0 ? 'Monthly income saved.' : 'Monthly income cleared.',
      );
      if (parsed > 0) widget.onSavedWithCategories?.call();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't save income.";
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final symbol = CurrencyController.instance.symbol;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          8,
          AppSpacing.md,
          AppSpacing.md + bottomInset,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Monthly income',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'This is your budget pool for the cycle. Next you’ll split it across categories.',
              style: TextStyle(fontSize: 12, color: colors.textMuted),
            ),
            const SizedBox(height: 14),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceHover,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Text(
                      symbol,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: colors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _income,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          hintText: '0.00',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _saving ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                _saving ? 'Saving…' : 'Save income',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
