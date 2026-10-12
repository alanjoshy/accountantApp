// Edit / delete a transaction (web TransactionDetailSheet subset).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../settings/data/app_settings_store.dart';
import '../../data/transaction.dart';
import '../../data/transaction_store.dart';

Future<void> showTransactionDetailSheet(
  BuildContext context,
  MoneyTransaction tx,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.of(context).surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
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
  late final TextEditingController _category;
  late final TextEditingController _note;
  late TransactionType _type;
  late DateTime _date;
  late final Set<String> _selectedTags;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    _title = TextEditingController(text: t.title);
    _amount = TextEditingController(text: _num(t.amount));
    _category = TextEditingController(text: t.category);
    _note = TextEditingController(text: t.note ?? '');
    _type = t.type == TransactionType.transfer
        ? TransactionType.expense
        : t.type;
    _date = DateTime.tryParse(t.date)?.toLocal() ?? DateTime.now();
    _selectedTags = {...t.tags};
  }

  String _num(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();

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

  Future<void> _save() async {
    setState(() => _error = null);
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Enter a title.');
      return;
    }
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount above zero.');
      return;
    }
    final category = _category.text.trim();
    if (category.isEmpty) {
      setState(() => _error = 'Enter a category.');
      return;
    }
    setState(() => _saving = true);
    try {
      await TransactionStore.instance.update(
        widget.transaction.copyWith(
          title: title,
          amount: amount,
          type: _type,
          category: category,
          date: _date.toIso8601String(),
          note: _note.text.trim(),
          tags: _selectedTags.toList(),
          clearNote: _note.text.trim().isEmpty,
        ),
      );
      if (!mounted) return;
      Navigator.pop(context);
      AppToast.success(context, 'Transaction updated.');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't update this transaction.";
        _saving = false;
      });
    }
  }

  Future<void> _delete() async {
    final colors = AppColors.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceElevated,
        title: Text('Delete transaction?',
            style: TextStyle(color: colors.textPrimary)),
        content: Text(
          '“${widget.transaction.title}” will be removed.',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: colors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: colors.error)),
          ),
        ],
      ),
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
                    icon: Icon(Icons.delete_outline_rounded,
                        color: colors.error),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final (type, label) in [
                    (TransactionType.expense, 'Expense'),
                    (TransactionType.income, 'Income'),
                  ])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: _type == type,
                          onSelected: (_) => setState(() => _type = type),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                decoration: _dec(colors, 'Title'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: _dec(colors, 'Amount'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _category,
                decoration: _dec(colors, 'Category'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _pickDate,
                child: Text(
                  '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _note,
                decoration: _dec(colors, 'Note'),
              ),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
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
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(_saving ? 'Saving…' : 'Save changes'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: colors.error)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(AppPalette colors, String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: colors.surfaceHover,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
