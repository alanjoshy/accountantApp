// Edit / delete a transaction (aligned with AddTransactionSheet).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/currency/currency_controller.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../accounts/data/account_store.dart';
import '../../../accounts/domain/payments.dart';
import '../../../accounts/presentation/widgets/account_chip_picker.dart';
import '../../../accounts/presentation/widgets/payment_mode_picker.dart';
import '../../../budgets/data/budget_store.dart';
import '../../../budgets/domain/budget_logic.dart';
import '../../../settings/data/app_settings_store.dart';
import '../../data/transaction.dart';
import '../../data/transaction_store.dart';
import '../../domain/transaction_categories.dart';
import 'category_option_chip.dart';
import 'tag_picker.dart';

Future<void> showTransactionDetailSheet(
  BuildContext context,
  MoneyTransaction tx,
) {
  return showAppSheet<void>(
    context: context,
    builder: (_) => TransactionDetailSheet(transaction: tx),
  );
}

class TransactionDetailSheet extends StatefulWidget {
  const TransactionDetailSheet({super.key, required this.transaction});

  final MoneyTransaction transaction;

  @override
  State<TransactionDetailSheet> createState() => _TransactionDetailSheetState();
}

class _TransactionDetailSheetState extends State<TransactionDetailSheet> {
  late final TextEditingController _title;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late TransactionType _type;
  late DateTime _date;
  late String _category;
  late PaymentMode _paymentMode;
  String? _accountId;
  late List<String> _selectedTags;
  late bool _moreOpen;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    _title = TextEditingController(text: t.title);
    _amount = TextEditingController(text: _num(t.amount));
    _note = TextEditingController(text: t.note ?? '');
    _type = t.type == TransactionType.transfer
        ? TransactionType.expense
        : t.type;
    _date = DateTime.tryParse(t.date)?.toLocal() ?? DateTime.now();
    _category = t.category.trim().isEmpty
        ? (_type == TransactionType.expense
            ? _defaultExpenseCategory()
            : categoriesForType(TransactionType.income).first)
        : t.category;
    _paymentMode =
        t.paymentMode ?? AppSettingsStore.instance.defaultPaymentMode;
    final accounts = AccountStore.instance.accounts;
    final preferred =
        t.accountId ?? AppSettingsStore.instance.defaultAccountId;
    final stillExists = accounts.any((a) => a.id == preferred);
    _accountId = stillExists
        ? preferred
        : (accounts.isNotEmpty ? accounts.first.id : null);
    _selectedTags = [...t.tags];
    _moreOpen = _selectedTags.isNotEmpty || (t.note?.trim().isNotEmpty ?? false);
  }

  String _num(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  List<String> _categoriesFor(TransactionType type) {
    if (type == TransactionType.income) {
      return categoriesForType(TransactionType.income);
    }
    final budgetCats = BudgetStore.instance.budgets.map((b) => b.category);
    return sortCategoriesByUsage(
      expenseCategoriesWithBudgets(budgetCats),
      TransactionStore.instance.transactions,
    );
  }

  List<String> _categories() {
    final base = _categoriesFor(_type);
    final current = _category.trim();
    if (current.isEmpty) return base;
    final has = base.any((c) => c.toLowerCase() == current.toLowerCase());
    if (has) return base;
    return [current, ...base];
  }

  String _defaultExpenseCategory() {
    final budgetCats = BudgetStore.instance.budgets.map((b) => b.category);
    return pickDefaultExpenseCategory(
      expenseCategoriesWithBudgets(budgetCats),
      TransactionStore.instance.transactions,
      fallback: AppSettingsStore.instance.defaultCategory,
    );
  }

  Map<String, CategoryCycleUsage> _usageByCategory() {
    if (_type != TransactionType.expense) return const {};
    return categoryCycleUsageByName(
      BudgetStore.instance.budgets,
      TransactionStore.instance.transactions,
      cycleStartDay: AppSettingsStore.instance.cycleStartDay,
      now: _date,
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    setState(() => _error = null);
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount above zero.');
      HapticFeedback.heavyImpact();
      return;
    }
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = _type == TransactionType.expense
          ? 'What was this for?'
          : 'Where is this from?');
      HapticFeedback.heavyImpact();
      return;
    }
    if (_category.trim().isEmpty) {
      setState(() => _error = 'Pick a category.');
      HapticFeedback.heavyImpact();
      return;
    }
    setState(() => _saving = true);
    try {
      final dayKey =
          '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';
      await TransactionStore.instance.update(
        widget.transaction.copyWith(
          title: title,
          amount: amount,
          type: _type,
          category: _category.trim(),
          date: dayKey,
          note: _note.text.trim(),
          tags: _selectedTags,
          paymentMode: _paymentMode,
          accountId: _accountId,
          clearNote: _note.text.trim().isEmpty,
        ),
      );
      if (!mounted) return;
      Navigator.pop(context);
      AppToast.success(context, 'Transaction updated.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is StateError
            ? e.message
            : "Couldn't update this transaction.";
        _saving = false;
      });
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _delete() async {
    final ok = await AppToast.confirm(
      context,
      title: 'Delete transaction?',
      message: '“${widget.transaction.title}” will be removed.',
    );
    if (ok != true || !mounted) return;
    await TransactionStore.instance.delete(widget.transaction.id);
    if (!mounted) return;
    Navigator.pop(context);
    AppToast.warning(context, 'Transaction deleted.');
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final symbol = CurrencyController.instance.symbol;
    final categories = _categories();
    final usage = _usageByCategory();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          8,
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
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Edit transaction',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _delete,
                    tooltip: 'Delete',
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: colors.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceHover,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      for (final (type, label) in [
                        (TransactionType.expense, 'Spent'),
                        (TransactionType.income, 'Received'),
                      ])
                        Expanded(
                          child: Material(
                            color: _type == type
                                ? colors.accent
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _type = type;
                                  final cats = _categoriesFor(type);
                                  final keep = cats.any(
                                    (c) =>
                                        c.toLowerCase() ==
                                        _category.toLowerCase(),
                                  );
                                  if (!keep) {
                                    _category = type == TransactionType.expense
                                        ? _defaultExpenseCategory()
                                        : cats.first;
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  label,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _type == type
                                        ? Colors.white
                                        : colors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _label('How much?', colors),
              TextField(
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
                decoration: _decoration(colors, '0').copyWith(
                  prefixText: '$symbol ',
                  prefixStyle: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: colors.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _label(
                _type == TransactionType.expense ? 'What for?' : 'From where?',
                colors,
              ),
              TextField(
                controller: _title,
                textInputAction: TextInputAction.next,
                decoration: _decoration(
                  colors,
                  _type == TransactionType.expense
                      ? 'e.g. Lunch, Uber, groceries'
                      : 'e.g. Salary, freelance',
                ),
              ),
              const SizedBox(height: 14),
              _label('Date', colors),
              OutlinedButton(
                onPressed: _pickDate,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.textPrimary,
                  side: BorderSide(color: colors.border),
                  alignment: Alignment.centerLeft,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
                ),
              ),
              const SizedBox(height: 14),
              _label('Category', colors),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categories.map((c) {
                  final style = resolveCategoryStyle(
                    c,
                    budgets: BudgetStore.instance.budgets,
                  );
                  return CategoryOptionChip(
                    label: c,
                    selected: _category.toLowerCase() == c.toLowerCase(),
                    usage: usage[c.toLowerCase()],
                    icon: style.icon,
                    accentColor: style.color,
                    onTap: () => setState(() => _category = c),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              _label('Payment mode', colors),
              PaymentModePicker(
                value: _paymentMode,
                defaultId: AppSettingsStore.instance.defaultPaymentMode,
                onChanged: (m) => setState(() => _paymentMode = m),
              ),
              const SizedBox(height: 14),
              _label('Account', colors),
              AccountChipPicker(
                accounts: AccountStore.instance.accounts,
                value: _accountId,
                defaultId: AppSettingsStore.instance.defaultAccountId,
                onChanged: (id) => setState(() => _accountId = id),
              ),
              const SizedBox(height: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _moreOpen = !_moreOpen);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Tags & note (optional)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                        Icon(
                          _moreOpen
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          color: colors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_moreOpen) ...[
                ListenableBuilder(
                  listenable: AppSettingsStore.instance,
                  builder: (context, _) {
                    return TagPicker(
                      availableTags: AppSettingsStore.instance.tags,
                      selected: _selectedTags,
                      onChange: (next) => setState(() {
                        _selectedTags
                          ..clear()
                          ..addAll(next);
                      }),
                      onCreateTag: AppSettingsStore.instance.addTag,
                    );
                  },
                ),
                const SizedBox(height: 12),
                _label('Note', colors),
                TextField(
                  controller: _note,
                  maxLines: 2,
                  decoration:
                      _decoration(colors, 'Anything else to remember'),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _saving ? 'Saving…' : 'Save changes',
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
      ),
    );
  }

  Widget _label(String text, AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colors.textSecondary,
        ),
      ),
    );
  }

  InputDecoration _decoration(AppPalette colors, String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: colors.surfaceHover,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.accent),
      ),
    );
  }
}
