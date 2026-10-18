// Record collection / repayment against an open debt.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/currency/currency_controller.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../data/debt.dart';
import '../../data/debt_store.dart';
import '../../domain/debt_logic.dart';

Future<void> showDebtPaySheet(BuildContext context, Debt debt) {
  return showAppSheet<void>(
    context: context,
    builder: (_) => DebtPaySheet(debt: debt),
  );
}

class DebtPaySheet extends StatefulWidget {
  const DebtPaySheet({super.key, required this.debt});

  final Debt debt;

  @override
  State<DebtPaySheet> createState() => _DebtPaySheetState();
}

class _DebtPaySheetState extends State<DebtPaySheet> {
  late final TextEditingController _amount;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final remaining = debtRemaining(widget.debt);
    _amount = TextEditingController(
      text: remaining == remaining.roundToDouble()
          ? remaining.round().toString()
          : remaining.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isBorrow = debtKind(widget.debt) == DebtKind.borrow;
    final remaining = debtRemaining(widget.debt);
    final parsed = double.tryParse(_amount.text.trim());
    if (parsed == null || !(parsed > 0)) {
      setState(() => _error = 'Enter an amount greater than zero.');
      return;
    }
    if (parsed > remaining + 0.000001) {
      setState(() {
        _error =
            "Can't be more than remaining ${CurrencyController.instance.format(remaining)}.";
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated =
          await DebtStore.instance.recordPayment(widget.debt.id, parsed);
      if (!mounted) return;
      Navigator.pop(context);
      final person = widget.debt.personName;
      if (updated.status == DebtStatus.collected) {
        AppToast.success(
          context,
          isBorrow ? 'Fully repaid $person.' : 'Fully collected from $person.',
        );
      } else {
        final left = debtRemaining(updated);
        final fmt = CurrencyController.instance.format;
        AppToast.success(
          context,
          isBorrow
              ? 'Recorded ${fmt(parsed)}. ${fmt(left)} left to repay.'
              : 'Recorded ${fmt(parsed)}. ${fmt(left)} left to collect.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ArgumentError
            ? e.message?.toString() ?? "Couldn't record this amount."
            : "Couldn't record this amount.";
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final symbol = CurrencyController.instance.symbol;
    final format = CurrencyController.instance.format;
    final isBorrow = debtKind(widget.debt) == DebtKind.borrow;
    final remaining = debtRemaining(widget.debt);
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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isBorrow ? 'Record repayment' : 'Record collection',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.debt.personName} · ${format(remaining)} left',
              style: TextStyle(fontSize: 13, color: colors.textMuted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: InputDecoration(
                prefixText: '$symbol ',
                filled: true,
                fillColor: colors.surfaceHover,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colors.border),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(color: colors.error, fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
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
              child: Text(_saving ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
