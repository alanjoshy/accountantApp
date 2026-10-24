// Create / edit a planned budget reserve.

import 'package:flutter/material.dart';

import '../../../../app/currency/currency_controller.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../activity/domain/cycle.dart';
import '../../../budgets/data/budget_store.dart';
import '../../../scheduled/domain/scheduled_logic.dart';
import '../../../transactions/presentation/widgets/category_option_chip.dart';
import '../../data/planned_reserve.dart';
import '../../data/planned_reserve_store.dart';

Future<void> showPlannedFormSheet(
  BuildContext context, {
  PlannedReserve? existing,
}) {
  return showAppSheet<void>(
    context: context,
    builder: (_) => PlannedFormSheet(existing: existing),
  );
}

class PlannedFormSheet extends StatefulWidget {
  const PlannedFormSheet({super.key, this.existing});

  final PlannedReserve? existing;

  @override
  State<PlannedFormSheet> createState() => _PlannedFormSheetState();
}

class _PlannedFormSheetState extends State<PlannedFormSheet> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late String _category;
  late String _dueDate;
  String? _error;
  bool _saving = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final cats = budgetCategoryChoices(
      BudgetStore.instance.budgets.map((b) => b.category).toList(),
    );
    final existing = widget.existing;
    if (existing != null) {
      _title.text = existing.title;
      _amount.text = existing.amount == existing.amount.roundToDouble()
          ? existing.amount.round().toString()
          : existing.amount.toString();
      _note.text = existing.note ?? '';
      _category = cats.contains(existing.category)
          ? existing.category
          : (cats.isNotEmpty ? cats.first : existing.category);
      _dueDate = existing.dueDate;
    } else {
      _category = cats.isNotEmpty ? cats.first : 'Transport';
      _dueDate = toCycleDayKey(DateTime.now().add(const Duration(days: 30)));
    }
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
      setState(() => _dueDate = toCycleDayKey(picked));
    }
  }

  Future<void> _save() async {
    setState(() => _error = null);
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'What is this for?');
      return;
    }
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount above zero.');
      return;
    }
    if (_category.trim().isEmpty) {
      setState(() => _error = 'Pick a budget category.');
      return;
    }

    setState(() => _saving = true);
    try {
      if (_editing) {
        await PlannedReserveStore.instance.update(
          widget.existing!.copyWith(
            title: title,
            amount: amount,
            category: _category.trim(),
            dueDate: _dueDate,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
            clearNote: _note.text.trim().isEmpty,
            clearAppliedCycleStart: true,
          ),
        );
      } else {
        await PlannedReserveStore.instance.add(
          title: title,
          amount: amount,
          category: _category.trim(),
          dueDate: _dueDate,
          note: _note.text.trim(),
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
      AppToast.success(
        context,
        _editing ? 'Planned reserve updated.' : 'Planned reserve added.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not save.';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final symbol = CurrencyController.instance.symbol;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final cats = budgetCategoryChoices(
      BudgetStore.instance.budgets.map((b) => b.category).toList(),
    );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
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
                _editing ? 'Edit planned reserve' : 'Plan a future expense',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Reserves budget only — no payment is created until you spend it.',
                style: TextStyle(fontSize: 13, color: colors.textMuted),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Title',
                  hintText: 'Car insurance',
                  filled: true,
                  fillColor: colors.surfaceHover,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '$symbol ',
                  filled: true,
                  fillColor: colors.surfaceHover,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Budget category',
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
                children: cats.map((c) {
                  final style = resolveCategoryStyle(
                    c,
                    budgets: BudgetStore.instance.budgets,
                  );
                  return CategoryOptionChip(
                    label: c,
                    selected: _category == c,
                    icon: style.icon,
                    accentColor: style.color,
                    onTap: () => setState(() => _category = c),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Expected date',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  _dueDate,
                  style: TextStyle(color: colors.textMuted),
                ),
                trailing: Icon(Icons.calendar_today_rounded,
                    color: colors.accent, size: 20),
                onTap: _pickDate,
              ),
              TextField(
                controller: _note,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Note (optional)',
                  filled: true,
                  fillColor: colors.surfaceHover,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(fontSize: 13, color: colors.error),
                ),
              ],
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(_saving ? 'Saving…' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
