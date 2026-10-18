// Create scheduled payment sheet.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/currency/currency_controller.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../accounts/data/account_store.dart';
import '../../../accounts/domain/payments.dart';
import '../../../accounts/presentation/widgets/account_chip_picker.dart';
import '../../../accounts/presentation/widgets/payment_mode_picker.dart';
import '../../../budgets/data/budget_store.dart';
import '../../../settings/data/app_settings_store.dart';
import '../../../transactions/data/transaction_store.dart';
import '../../../transactions/presentation/widgets/tag_picker.dart';
import '../../data/scheduled_payment.dart';
import '../../data/scheduled_payment_store.dart';
import '../../domain/scheduled_logic.dart';

Future<void> showScheduledFormSheet(BuildContext context) {
  return showAppSheet<void>(
    context: context,
    builder: (_) => const ScheduledFormSheet(),
  );
}

class ScheduledFormSheet extends StatefulWidget {
  const ScheduledFormSheet({super.key});

  @override
  State<ScheduledFormSheet> createState() => _ScheduledFormSheetState();
}

class _ScheduledFormSheetState extends State<ScheduledFormSheet> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();

  late String _category;
  late ScheduleRepeat _repeat;
  late String _dueDate;
  late PaymentMode _paymentMode;
  String? _accountId;
  List<String> _tags = [];
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final settings = AppSettingsStore.instance;
    final cats = budgetCategoryChoices(
      BudgetStore.instance.budgets.map((b) => b.category).toList(),
    );
    _category = cats.first;
    _repeat = ScheduleRepeat.monthly;
    _dueDate = scheduleTodayKey();
    _paymentMode = settings.defaultPaymentMode;
    final accounts = AccountStore.instance.accounts;
    final preferred = settings.defaultAccountId;
    final stillExists = accounts.any((a) => a.id == preferred);
    _accountId = stillExists
        ? preferred
        : (accounts.isNotEmpty ? accounts.first.id : null);
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final parts = _dueDate.split('-');
    final initial = parts.length == 3
        ? DateTime(
            int.tryParse(parts[0]) ?? DateTime.now().year,
            int.tryParse(parts[1]) ?? 1,
            int.tryParse(parts[2]) ?? 1,
          )
        : DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _dueDate = scheduleTodayKey(picked));
    }
  }

  Future<void> _save() async {
    setState(() => _error = null);
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Enter a name.');
      return;
    }
    final amount = double.tryParse(_amount.text.trim().replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount above zero.');
      return;
    }
    if (_accountId == null || _accountId!.isEmpty) {
      setState(() => _error = 'Pick an account to deduct from.');
      return;
    }

    final check = checkBudgetExceed(
      category: _category,
      amount: amount,
      dueDate: _dueDate,
      repeat: _repeat,
      budgets: BudgetStore.instance.budgets,
      transactions: TransactionStore.instance.transactions,
      cycleStartDay: AppSettingsStore.instance.cycleStartDay,
    );
    if (check.exceeds) {
      final over = CurrencyController.instance.format(check.overBy);
      setState(() {
        _error =
            'Would exceed $_category by $over this cycle '
            '(${check.occurrences} payment${check.occurrences == 1 ? '' : 's'}).';
      });
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() => _saving = true);
    final dueNow = isDueOrOverdue(_dueDate);
    try {
      await ScheduledPaymentStore.instance.add(
        title: title,
        amount: amount,
        category: _category,
        dueDate: _dueDate,
        repeat: _repeat,
        accountId: _accountId!,
        paymentMode: _paymentMode,
        tags: _tags,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      AppToast.show(
        context,
        dueNow
            ? 'Paid now · ${CurrencyController.instance.format(amount)} processed.'
            : 'Payment scheduled.',
        tone: AppToastTone.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e is StateError
            ? e.message
            : "Couldn't schedule this payment.";
      });
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cats = budgetCategoryChoices(
      BudgetStore.instance.budgets.map((b) => b.category).toList(),
    );
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final settings = AppSettingsStore.instance;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
              'Schedule payment',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _title,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Rent, EMI, Netflix…',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '${CurrencyController.instance.symbol} ',
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'From budget category',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Amount counts against this category budget.',
              style: TextStyle(fontSize: 11, color: colors.textMuted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in cats)
                  ChoiceChip(
                    label: Text(c),
                    selected: _category == c,
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() => _category = c);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Repeat',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final o in repeatOptions)
                  ChoiceChip(
                    label: Text(o.short),
                    selected: _repeat == o.id,
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() => _repeat = o.id);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _repeat == ScheduleRepeat.once ? 'Due date' : 'Starts on',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              subtitle: Text(
                formatDueHeading(_dueDate),
                style: TextStyle(color: colors.textSecondary),
              ),
              trailing: Icon(Icons.calendar_today_rounded, color: colors.accent),
              onTap: _pickDate,
            ),
            const SizedBox(height: 8),
            Text(
              'From account',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            AccountChipPicker(
              accounts: AccountStore.instance.accounts,
              value: _accountId,
              defaultId: settings.defaultAccountId,
              onChanged: (id) => setState(() => _accountId = id),
            ),
            const SizedBox(height: 12),
            Text(
              'Payment mode',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            PaymentModePicker(
              value: _paymentMode,
              defaultId: settings.defaultPaymentMode,
              onChanged: (m) => setState(() => _paymentMode = m),
            ),
            const SizedBox(height: 12),
            Text(
              'Tags',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TagPicker(
              availableTags: settings.tags,
              selected: _tags,
              onChange: (t) => setState(() => _tags = t),
              onCreateTag: (name) => AppSettingsStore.instance.addTag(name),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(fontSize: 13, color: colors.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(_saving ? 'Saving…' : 'Schedule'),
            ),
          ],
        ),
      ),
    );
  }
}
