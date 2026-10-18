// Add lend / borrow entry.

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

Future<void> showDebtFormSheet(
  BuildContext context, {
  DebtKind initialKind = DebtKind.lend,
}) {
  return showAppSheet<void>(
    context: context,
    builder: (_) => DebtFormSheet(initialKind: initialKind),
  );
}

class DebtFormSheet extends StatefulWidget {
  const DebtFormSheet({super.key, this.initialKind = DebtKind.lend});

  final DebtKind initialKind;

  @override
  State<DebtFormSheet> createState() => _DebtFormSheetState();
}

class _DebtFormSheetState extends State<DebtFormSheet> {
  late DebtKind _kind;
  late final TextEditingController _person;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late String _lentDate;
  late String _dueDate;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind;
    _person = TextEditingController();
    _amount = TextEditingController();
    _note = TextEditingController();
    final today = todayKey();
    _lentDate = today;
    _dueDate = today;
  }

  @override
  void dispose() {
    _person.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool lent}) async {
    final raw = lent ? _lentDate : _dueDate;
    final parts = raw.split('-');
    final initial = parts.length == 3
        ? DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          )
        : DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    final key = todayKey(picked);
    setState(() {
      if (lent) {
        _lentDate = key;
        if (_dueDate.compareTo(_lentDate) < 0) _dueDate = _lentDate;
      } else {
        _dueDate = key;
      }
    });
  }

  Future<void> _submit() async {
    final name = _person.text.trim();
    if (name.isEmpty) {
      setState(() {
        _error = _kind == DebtKind.borrow
            ? 'Enter who you borrowed from.'
            : 'Enter who you lent money to.';
      });
      return;
    }
    if (name.length > 48) {
      setState(() => _error = 'Name is too long (max 48 characters).');
      return;
    }
    final parsed = double.tryParse(_amount.text.trim());
    if (parsed == null || !(parsed > 0)) {
      setState(() => _error = 'Enter an amount greater than zero.');
      return;
    }
    if (_dueDate.compareTo(_lentDate) < 0) {
      setState(() => _error = 'Due date should be on or after the start date.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await DebtStore.instance.addDebt(
        personName: name,
        amount: parsed,
        lentDate: _lentDate,
        dueDate: _dueDate,
        kind: _kind,
        note: _note.text,
      );
      if (!mounted) return;
      Navigator.pop(context);
      AppToast.success(
        context,
        _kind == DebtKind.borrow
            ? 'Borrowed from $name saved.'
            : 'Lent to $name saved.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't save this entry.";
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final symbol = CurrencyController.instance.symbol;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final suggestions = personNameSuggestions(DebtStore.instance.debts);
    final q = _person.text.trim().toLowerCase();
    final filtered = (q.isEmpty
            ? suggestions.take(8)
            : suggestions.where(
                (n) => n.toLowerCase().contains(q) && n.toLowerCase() != q,
              ))
        .take(8)
        .toList();

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
                _kind == DebtKind.borrow ? 'Money borrowed' : 'Money lent',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _KindChip(
                      label: 'I lent',
                      active: _kind == DebtKind.lend,
                      colors: colors,
                      onTap: () => setState(() {
                        _kind = DebtKind.lend;
                        _error = null;
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _KindChip(
                      label: 'I borrowed',
                      active: _kind == DebtKind.borrow,
                      colors: colors,
                      onTap: () => setState(() {
                        _kind = DebtKind.borrow;
                        _error = null;
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                _kind == DebtKind.borrow ? 'Borrowed from' : 'Lent to',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _person,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() => _error = null),
                decoration: InputDecoration(
                  hintText: 'e.g. Rahul',
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
              if (filtered.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final name in filtered)
                      ActionChip(
                        label: Text(name, style: const TextStyle(fontSize: 12)),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _person.text = name;
                            _error = null;
                          });
                        },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Amount',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _amount,
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                      label: _kind == DebtKind.borrow ? 'Borrowed on' : 'Lent on',
                      value: formatDebtDay(_lentDate),
                      colors: colors,
                      onTap: () => _pickDate(lent: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DateField(
                      label: 'Due date',
                      value: formatDebtDay(_dueDate),
                      colors: colors,
                      onTap: () => _pickDate(lent: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Note (optional)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _note,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Optional note',
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
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.label,
    required this.active,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final bool active;
  final AppPalette colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? colors.accentMuted : colors.surfaceHover,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? colors.accent : colors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: active ? colors.accent : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final String value;
  final AppPalette colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colors.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        Material(
          color: colors.surfaceHover,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.border),
              ),
              child: Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
