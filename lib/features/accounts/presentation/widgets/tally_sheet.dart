// Match account balance to actual amount (web tally).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/currency/currency_controller.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../transactions/data/transaction.dart';
import '../../../transactions/data/transaction_store.dart';
import '../../data/account.dart';
import '../../data/account_store.dart';
import '../../domain/account_balances.dart';

Future<void> showTallySheet(BuildContext context, MoneyAccount account) {
  return showAppSheet<void>(
    context: context,
    builder: (_) => TallySheet(account: account),
  );
}

class TallySheet extends StatefulWidget {
  const TallySheet({super.key, required this.account});

  final MoneyAccount account;

  @override
  State<TallySheet> createState() => _TallySheetState();
}

class _TallySheetState extends State<TallySheet> {
  late final TextEditingController _actual;
  final _note = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final bal = widget.account.balance;
    _actual = TextEditingController(
      text: bal == bal.roundToDouble()
          ? bal.round().toString()
          : bal.toString(),
    );
  }

  @override
  void dispose() {
    _actual.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final actual = double.tryParse(_actual.text.trim());
    if (actual == null || actual < 0) {
      setState(() => _error = 'Enter a valid balance (0 or more).');
      return;
    }
    final previous = widget.account.balance;
    final difference = roundMoney(actual - previous);
    if (difference.abs() < 0.005) {
      setState(() => _error = 'Balance already matches — nothing to tally.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      final dayKey =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final at = now.toUtc().toIso8601String();
      await AccountStore.instance.updateAccount(
        widget.account.copyWith(balance: actual, updatedAt: at),
      );
      final note = _note.text.trim().isEmpty
          ? (difference > 0
              ? 'Tally · credit / round off'
              : 'Tally · debit / round off')
          : _note.text.trim();
      // Adjustment transfers skip auto balance sync.
      await TransactionStore.instance.add(
        title: 'Tally · ${widget.account.name}',
        amount: difference.abs(),
        type: TransactionType.transfer,
        category: 'Adjustment',
        date: dayKey,
        note: note,
        accountId: widget.account.id,
      );
      if (!mounted) return;
      Navigator.pop(context);
      AppToast.success(
        context,
        difference > 0
            ? 'Balance increased by ${CurrencyController.instance.format(difference)}.'
            : 'Balance decreased by ${CurrencyController.instance.format(difference.abs())}.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't tally this account.";
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final format = CurrencyController.instance.format;
    final symbol = CurrencyController.instance.symbol;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final actual = double.tryParse(_actual.text.trim());
    final diff = actual == null
        ? null
        : roundMoney(actual - widget.account.balance);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          12,
          AppSpacing.md,
          AppSpacing.md + bottomInset,
        ),
        child: SingleChildScrollView(
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
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Tally ${widget.account.name}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Match the balance to what you actually have',
                style: TextStyle(fontSize: 13, color: colors.textMuted),
              ),
              const SizedBox(height: 14),
              Text(
                'Current balance',
                style: TextStyle(fontSize: 12, color: colors.textMuted),
              ),
              Text(
                format(widget.account.balance),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _actual,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Actual balance',
                  prefixText: '$symbol ',
                  filled: true,
                  fillColor: colors.surfaceHover,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              if (diff != null && diff.abs() >= 0.005) ...[
                const SizedBox(height: 8),
                Text(
                  diff > 0
                      ? 'Will credit ${format(diff)}'
                      : 'Will debit ${format(diff.abs())}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: diff > 0 ? colors.success : colors.error,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: _note,
                decoration: InputDecoration(
                  labelText: 'Note (optional)',
                  filled: true,
                  fillColor: colors.surfaceHover,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: TextStyle(color: colors.error)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(_saving ? 'Saving…' : 'Apply tally'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
