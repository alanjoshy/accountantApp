// Add spend / income sheet (web AddTransactionSheet parity).

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

Future<void> showAddTransactionSheet(BuildContext context) {
  return showAppSheet<void>(
    context: context,
    builder: (_) => const AddTransactionSheet(),
  );
}

class AddTransactionSheet extends StatefulWidget {
  const AddTransactionSheet({super.key});

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  TransactionType _type = TransactionType.expense;
  DateTime _date = DateTime.now();
  String _category = spendCategories.first;
  late PaymentMode _paymentMode;
  String? _accountId;
  final _selectedTags = <String>[];
  bool _moreOpen = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final settings = AppSettingsStore.instance;
    _category = _defaultExpenseCategory();
    _paymentMode = settings.defaultPaymentMode;
    final accounts = AccountStore.instance.accounts;
    final preferred = settings.defaultAccountId;
    final stillExists = accounts.any((a) => a.id == preferred);
    _accountId = stillExists
        ? preferred
        : (accounts.isNotEmpty ? accounts.first.id : null);
    final key = settings.resolveDefaultTransactionDate();
    final parts = key.split('-');
    if (parts.length == 3) {
      _date = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    }
    final tag = settings.defaultTag;
    if (tag != null && tag.isNotEmpty) {
      _selectedTags.add(tag);
      _moreOpen = true;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  List<String> _categories() {
    if (_type == TransactionType.income) {
      return categoriesForType(TransactionType.income);
    }
    final budgetCats = BudgetStore.instance.budgets.map((b) => b.category);
    return sortCategoriesByUsage(
      expenseCategoriesWithBudgets(budgetCats),
      TransactionStore.instance.transactions,
    );
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

  Future<void> _submit() async {
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
      await TransactionStore.instance.add(
        title: title,
        amount: amount,
        type: _type,
        category: _category.trim(),
        // Store calendar day only so cycle filters never shift by timezone.
        date: dayKey,
        note: _note.text.trim(),
        tags: _selectedTags,
        paymentMode: _paymentMode,
        accountId: _accountId,
      );
      await AppSettingsStore.instance.setLastTransactionDate(dayKey);
      if (!mounted) return;
      Navigator.pop(context);
      AppToast.success(context, 'Transaction saved.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is StateError
            ? e.message
            : "Couldn't save this transaction.";
        _saving = false;
      });
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final symbol = CurrencyController.instance.symbol;
    final categories = _categories();
    final usage = _usageByCategory();
    if (!categories.contains(_category) && categories.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _category = _type == TransactionType.expense
              ? _defaultExpenseCategory()
              : categories.first;
        });
      });
    }

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
              Text(
                _type == TransactionType.expense ? 'Add spend' : 'Add income',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
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
                                  final cats = type == TransactionType.income
                                      ? categoriesForType(TransactionType.income)
                                      : _categories();
                                  if (!cats.contains(_category)) {
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
                autofocus: true,
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
                    selected: _category == c,
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
                  _saving ? 'Saving…' : 'Save',
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
