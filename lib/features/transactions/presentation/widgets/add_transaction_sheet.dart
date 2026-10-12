// Add income / expense sheet (dock +).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../settings/data/app_settings_store.dart';
import '../../data/transaction.dart';
import '../../data/transaction_store.dart';

Future<void> showAddTransactionSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.of(context).surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
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
  final _category = TextEditingController();
  final _note = TextEditingController();
  TransactionType _type = TransactionType.expense;
  DateTime _date = DateTime.now();
  final _selectedTags = <String>{};
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _category.dispose();
    _note.dispose();
    super.dispose();
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
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Enter a title.');
      HapticFeedback.heavyImpact();
      return;
    }
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount above zero.');
      HapticFeedback.heavyImpact();
      return;
    }
    final category = _category.text.trim();
    if (category.isEmpty) {
      setState(() => _error = 'Enter a category.');
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() => _saving = true);
    try {
      await TransactionStore.instance.add(
        title: title,
        amount: amount,
        type: _type,
        category: category,
        date: _date.toIso8601String(),
        note: _note.text.trim(),
        tags: _selectedTags.toList(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      AppToast.success(context, 'Transaction saved.');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't save this transaction.";
        _saving = false;
      });
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final tags = AppSettingsStore.instance.tags;

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
                'Add transaction',
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
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Row(
                    children: [
                      for (final (type, label) in [
                        (TransactionType.expense, 'Expense'),
                        (TransactionType.income, 'Income'),
                      ])
                        Expanded(
                          child: Material(
                            color: _type == type
                                ? colors.accent
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _type = type);
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
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
              const SizedBox(height: 12),
              _label('Title', colors),
              TextField(
                controller: _title,
                textInputAction: TextInputAction.next,
                decoration: _decoration(colors, 'e.g. Groceries'),
              ),
              const SizedBox(height: 12),
              _label('Amount', colors),
              TextField(
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: _decoration(colors, '0'),
              ),
              const SizedBox(height: 12),
              _label('Category', colors),
              TextField(
                controller: _category,
                textInputAction: TextInputAction.next,
                decoration: _decoration(colors, 'e.g. Food'),
              ),
              const SizedBox(height: 12),
              _label('Date', colors),
              OutlinedButton(
                onPressed: _pickDate,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.textPrimary,
                  side: BorderSide(color: colors.border),
                  alignment: Alignment.centerLeft,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
                child: Text(
                  '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
                ),
              ),
              const SizedBox(height: 12),
              _label('Note (optional)', colors),
              TextField(
                controller: _note,
                decoration: _decoration(colors, 'Optional note'),
              ),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                _label('Tags', colors),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in tags)
                      FilterChip(
                        label: Text(tag),
                        selected: _selectedTags.contains(tag),
                        onSelected: (v) {
                          setState(() {
                            if (v) {
                              _selectedTags.add(tag);
                            } else {
                              _selectedTags.remove(tag);
                            }
                          });
                        },
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
