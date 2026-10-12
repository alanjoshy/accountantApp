// Add / edit category budget sheet (web budgets Add category form).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/currency/currency_controller.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../activity/domain/cycle.dart';
import '../../../settings/data/app_settings_store.dart';
import '../../data/budget.dart';
import '../../data/budget_store.dart';
import '../../domain/budget_logic.dart';

enum _PeriodMode { current, custom }

Future<void> showBudgetFormSheet(BuildContext context, {Budget? budget}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.of(context).surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => BudgetFormSheet(budget: budget),
  );
}

class BudgetFormSheet extends StatefulWidget {
  const BudgetFormSheet({super.key, this.budget});

  final Budget? budget;

  @override
  State<BudgetFormSheet> createState() => _BudgetFormSheetState();
}

class _BudgetFormSheetState extends State<BudgetFormSheet> {
  late final TextEditingController _category;
  late final TextEditingController _amount;
  late _PeriodMode _periodMode;
  late DateTime _start;
  late DateTime _end;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.budget;
    _category = TextEditingController(text: existing?.category ?? '');
    final limit = existing?.limit;
    _amount = TextEditingController(
      text: limit == null || limit <= 0
          ? ''
          : (limit == limit.roundToDouble()
              ? limit.round().toString()
              : limit.toString()),
    );

    if (existing != null && existing.hasCustomRange) {
      _periodMode = _PeriodMode.custom;
      _start = DateTime.tryParse(existing.startDate!) ?? _monthStart(DateTime.now());
      _end = DateTime.tryParse(existing.endDate!) ?? _monthEnd(DateTime.now());
    } else {
      _periodMode = _PeriodMode.current;
      final now = DateTime.now();
      _start = _monthStart(now);
      _end = _monthEnd(now);
    }
  }

  @override
  void dispose() {
    _category.dispose();
    _amount.dispose();
    super.dispose();
  }

  DateTime _monthStart(DateTime d) => DateTime(d.year, d.month, 1);

  DateTime _monthEnd(DateTime d) => DateTime(d.year, d.month + 1, 0);

  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _monthLabel(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  String _prettyRange(DateTime start, DateTime end) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    String fmt(DateTime d) => '${months[d.month - 1]} ${d.day}';
    if (start.year == end.year) {
      return '${fmt(start)} – ${fmt(end)}, ${end.year}';
    }
    return '${fmt(start)}, ${start.year} – ${fmt(end)}, ${end.year}';
  }

  double _maxAllowed() {
    final income = AppSettingsStore.instance.monthlyIncome;
    final excludeId = widget.budget?.id;
    final cycle = getCurrentCycleDayBounds(
      AppSettingsStore.instance.cycleStartDay,
    );
    final current = listedBudgetsForWindow(
      BudgetStore.instance.budgets,
      cycle,
      includeUndated: true,
    );
    final others = current
        .where((b) => b.id != excludeId)
        .fold<double>(0, (sum, b) => sum + b.limit);
    final max = income - others;
    return max < 0 ? 0 : max;
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Select month',
    );
    if (picked == null) return;
    setState(() {
      _start = _monthStart(picked);
      _end = _monthEnd(picked);
      _error = null;
    });
  }

  Future<void> _pickDay({required bool isStart}) async {
    final initial = isStart ? _start : _end;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = DateTime(picked.year, picked.month, picked.day);
        if (_end.isBefore(_start)) _end = _start;
      } else {
        _end = DateTime(picked.year, picked.month, picked.day);
        if (_end.isBefore(_start)) _start = _end;
      }
      _error = null;
    });
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final category = _category.text.trim();
    if (category.isEmpty) {
      setState(() => _error = 'Enter a category name.');
      HapticFeedback.heavyImpact();
      return;
    }
    if (category.length > 40) {
      setState(() => _error = 'Category name is too long (max 40 characters).');
      HapticFeedback.heavyImpact();
      return;
    }
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount < 0) {
      setState(() => _error = 'Enter a valid amount.');
      HapticFeedback.heavyImpact();
      return;
    }

    final duplicate = BudgetStore.instance.budgets.any(
      (b) =>
          b.id != widget.budget?.id &&
          b.category.toLowerCase() == category.toLowerCase(),
    );
    if (duplicate) {
      setState(() => _error = 'That category already exists.');
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() => _saving = true);
    try {
      final existing = widget.budget;
      final cycle = getCurrentCycleDayBounds(
        AppSettingsStore.instance.cycleStartDay,
      );
      final start =
          _periodMode == _PeriodMode.custom ? _ymd(_start) : cycle.start;
      final end = _periodMode == _PeriodMode.custom ? _ymd(_end) : cycle.end;
      if (existing == null) {
        await BudgetStore.instance.add(
          category: category,
          limit: amount,
          startDate: start,
          endDate: end,
        );
      } else {
        await BudgetStore.instance.update(
          existing.copyWith(
            category: category,
            limit: amount,
            startDate: start,
            endDate: end,
          ),
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
      AppToast.success(
        context,
        existing == null
            ? (_periodMode == _PeriodMode.custom
                ? 'Category added for those dates.'
                : 'Category added for this cycle.')
            : 'Category updated.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't save this category.";
        _saving = false;
      });
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _delete() async {
    final existing = widget.budget;
    if (existing == null) return;
    final colors = AppColors.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceElevated,
        title: Text(
          'Remove category?',
          style: TextStyle(color: colors.textPrimary),
        ),
        content: Text(
          existing.hasCustomRange
              ? '“${existing.category}” will be removed for ${existing.startDate} – ${existing.endDate}. Transactions are not deleted.'
              : '“${existing.category}” will be removed from this period. Transactions are not deleted.',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: colors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove', style: TextStyle(color: colors.error)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await BudgetStore.instance.delete(existing.id);
    if (!mounted) return;
    Navigator.pop(context);
    AppToast.warning(context, 'Category removed.');
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final editing = widget.budget != null;
    final symbol = CurrencyController.instance.symbol;
    final format = CurrencyController.instance.format;
    final maxAllowed = _maxAllowed();
    final cycle = getCurrentCycleRange(AppSettingsStore.instance.cycleStartDay);
    final cycleLabel = _prettyRange(
      DateTime(cycle.start.year, cycle.start.month, cycle.start.day),
      DateTime(cycle.end.year, cycle.end.month, cycle.end.day),
    );

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
                editing ? 'Edit category' : 'Add category',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _FieldLabel('Category', colors),
              TextField(
                controller: _category,
                textInputAction: TextInputAction.next,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                decoration: _decoration(colors, hint: 'e.g. Grocery'),
              ),
              const SizedBox(height: 14),
              _FieldLabel('Allocate from income', colors),
              _CurrencyField(
                controller: _amount,
                symbol: symbol,
                colors: colors,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  'Max ${format(maxAllowed)} available from your income',
                  style: TextStyle(fontSize: 12, color: colors.textMuted),
                ),
              ),
              const SizedBox(height: 14),
              _FieldLabel('Budget period', colors),
              Row(
                children: [
                  Expanded(
                    child: _PeriodChip(
                      label: 'This cycle',
                      selected: _periodMode == _PeriodMode.current,
                      colors: colors,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _periodMode = _PeriodMode.current;
                          _error = null;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PeriodChip(
                      label: 'Custom dates',
                      selected: _periodMode == _PeriodMode.custom,
                      colors: colors,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _periodMode = _PeriodMode.custom;
                          _error = null;
                        });
                      },
                    ),
                  ),
                ],
              ),
              if (_periodMode == _PeriodMode.current) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    'Only this cash-flow month ($cycleLabel). It does not stay forever — next cycle gets its own copy unless you remove it here first.',
                    style: TextStyle(fontSize: 12, color: colors.textMuted),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 12),
                _FieldLabel('Month', colors),
                _DateButton(
                  colors: colors,
                  label: _monthLabel(_start),
                  onTap: _pickMonth,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _FieldLabel('Start', colors),
                          _DateButton(
                            colors: colors,
                            label: _ymd(_start),
                            onTap: () => _pickDay(isStart: true),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _FieldLabel('End', colors),
                          _DateButton(
                            colors: colors,
                            label: _ymd(_end),
                            onTap: () => _pickDay(isStart: false),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                  _saving
                      ? 'Saving…'
                      : (editing ? 'Save changes' : 'Add category'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (editing) ...[
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _saving ? null : _delete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.error,
                    side: BorderSide(color: colors.error.withValues(alpha: 0.45)),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Remove from this period',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
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

  InputDecoration _decoration(AppPalette colors, {required String hint}) {
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, this.colors);

  final String text;
  final AppPalette colors;

  @override
  Widget build(BuildContext context) {
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
}

class _CurrencyField extends StatelessWidget {
  const _CurrencyField({
    required this.controller,
    required this.symbol,
    required this.colors,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String symbol;
  final AppPalette colors;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: colors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colors.textMuted,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final AppPalette colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? colors.accentMuted : colors.surfaceHover,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? colors.accent : colors.border,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? colors.accent : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.colors,
    required this.label,
    required this.onTap,
  });

  final AppPalette colors;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.surfaceHover,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
