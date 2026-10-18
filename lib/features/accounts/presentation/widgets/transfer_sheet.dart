// Move money between accounts.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/currency/currency_controller.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../transactions/data/transaction.dart';
import '../../../transactions/data/transaction_store.dart';
import '../../data/account_store.dart';
import 'account_chip_picker.dart';

Future<void> showTransferSheet(BuildContext context) {
  return showAppSheet<void>(
    context: context,
    builder: (_) => const TransferSheet(),
  );
}

class TransferSheet extends StatefulWidget {
  const TransferSheet({super.key});

  @override
  State<TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<TransferSheet> {
  late String? _fromId;
  late String? _toId;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final accounts = AccountStore.instance.accounts;
    _fromId = accounts.isNotEmpty ? accounts.first.id : null;
    _toId = accounts.length > 1 ? accounts[1].id : null;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final from = AccountStore.instance.byId(_fromId);
    final to = AccountStore.instance.byId(_toId);
    if (from == null || to == null) {
      setState(() => _error = 'Pick two accounts.');
      return;
    }
    if (from.id == to.id) {
      setState(() => _error = 'Pick two different accounts.');
      return;
    }
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount greater than zero.');
      return;
    }
    if (from.balance < amount) {
      setState(() {
        _error =
            'Only ${CurrencyController.instance.format(from.balance)} available in ${from.name}.';
      });
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
      await TransactionStore.instance.add(
        title: '${from.name} → ${to.name}',
        amount: amount,
        type: TransactionType.transfer,
        category: 'Transfer',
        date: dayKey,
        note: _note.text.trim().isEmpty ? 'Self transfer' : _note.text.trim(),
        accountId: from.id,
        toAccountId: to.id,
      );
      if (!mounted) return;
      Navigator.pop(context);
      AppToast.success(context, 'Transfer saved.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is StateError ? e.message : "Couldn't transfer.";
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final symbol = CurrencyController.instance.symbol;
    final accounts = AccountStore.instance.accounts;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

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
                'Transfer',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Move money between your accounts',
                style: TextStyle(fontSize: 13, color: colors.textMuted),
              ),
              const SizedBox(height: 14),
              Text(
                'From',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              AccountChipPicker(
                accounts: accounts,
                value: _fromId,
                onChanged: (id) => setState(() => _fromId = id),
              ),
              const SizedBox(height: 12),
              Text(
                'To',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              AccountChipPicker(
                accounts: accounts,
                value: _toId,
                onChanged: (id) => setState(() => _toId = id),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '$symbol ',
                  filled: true,
                  fillColor: colors.surfaceHover,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
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
                child: Text(_saving ? 'Transferring…' : 'Transfer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
