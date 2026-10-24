// Add / edit permanent category (no period — until deleted).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/currency/currency_controller.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../settings/data/app_settings_store.dart';
import '../../data/budget.dart';
import '../../data/budget_store.dart';
import '../../data/category_style.dart';

Future<void> showBudgetFormSheet(BuildContext context, {Budget? budget}) {
  return showAppSheet<void>(
    context: context,
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
  late String _icon;
  late String _color;
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
    _icon = existing?.icon ?? 'more';
    _color = existing?.color ?? categoryColorOptions.first;
  }

  @override
  void dispose() {
    _category.dispose();
    _amount.dispose();
    super.dispose();
  }

  double _maxAllowed() {
    final income = AppSettingsStore.instance.monthlyIncome;
    final excludeId = widget.budget?.id;
    final others = BudgetStore.instance.budgets
        .where((b) => b.id != excludeId && !b.hasCustomRange)
        .fold<double>(0, (sum, b) => sum + b.limit);
    final max = income - others;
    return max < 0 ? 0 : max;
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
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    if (amount < 0) {
      setState(() => _error = 'Enter a valid amount.');
      HapticFeedback.heavyImpact();
      return;
    }

    final duplicate = BudgetStore.instance.budgets.any(
      (b) =>
          b.id != widget.budget?.id &&
          !b.hasCustomRange &&
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
      if (existing == null) {
        await BudgetStore.instance.add(
          category: category,
          limit: amount,
          icon: _icon,
          color: _color,
        );
      } else {
        await BudgetStore.instance.update(
          existing.copyWith(
            category: category,
            limit: amount,
            icon: _icon,
            color: _color,
            clearDates: true,
          ),
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
      AppToast.success(
        context,
        existing == null ? 'Category added.' : 'Category updated.',
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
    final ok = await AppToast.confirm(
      context,
      title: 'Remove category?',
      message:
          '“${existing.category}” will be removed. Transactions are not deleted.',
      confirmLabel: 'Remove',
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
              const SizedBox(height: 4),
              Text(
                'Leave amount at 0 to hide it from the list until you allocate.',
                style: TextStyle(fontSize: 12, color: colors.textMuted),
              ),
              const SizedBox(height: 16),
              _FieldLabel(
                'Category',
                colors,
                Icons.label_outline_rounded,
              ),
              TextField(
                controller: _category,
                textInputAction: TextInputAction.next,
                onChanged: (value) {
                  if (_error != null) setState(() => _error = null);
                  if (widget.budget == null) {
                    setState(() {
                      _icon = defaultIconForCategory(value);
                      _color = defaultColorForCategory(value);
                    });
                  }
                },
                decoration: _decoration(
                  colors,
                  hint: 'e.g. Grocery',
                  prefixIcon: Icons.category_outlined,
                ),
              ),
              const SizedBox(height: 14),
              _FieldLabel(
                'Icon',
                colors,
                Icons.emoji_emotions_outlined,
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final key in categoryIconOptions)
                    _IconPick(
                      iconKey: key,
                      selected: _icon == key,
                      accent: categoryColorFromHex(_color),
                      colors: colors,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _icon = key);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _FieldLabel(
                'Color',
                colors,
                Icons.palette_outlined,
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final hex in categoryColorOptions)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _color = hex);
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: categoryColorFromHex(hex),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _color == hex
                                ? colors.textPrimary
                                : colors.border,
                            width: _color == hex ? 2.5 : 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _FieldLabel(
                'Allocate from income',
                colors,
                Icons.account_balance_wallet_outlined,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceHover,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.payments_outlined,
                        size: 22,
                        color: colors.textMuted,
                      ),
                      const SizedBox(width: 10),
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
                          controller: _amount,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
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
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onChanged: (_) {
                            if (_error != null) setState(() => _error = null);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  'Max ${format(maxAllowed)} available from your income',
                  style: TextStyle(fontSize: 12, color: colors.textMuted),
                ),
              ),
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
                    side: BorderSide(
                      color: colors.error.withValues(alpha: 0.45),
                    ),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Remove category',
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

  InputDecoration _decoration(
    AppPalette colors, {
    required String hint,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: colors.surfaceHover,
      prefixIcon: prefixIcon == null
          ? null
          : Icon(prefixIcon, size: 20, color: colors.textMuted),
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
  const _FieldLabel(this.text, this.colors, this.icon);

  final String text;
  final AppPalette colors;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 15, color: colors.textMuted),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconPick extends StatelessWidget {
  const _IconPick({
    required this.iconKey,
    required this.selected,
    required this.accent,
    required this.colors,
    required this.onTap,
  });

  final String iconKey;
  final bool selected;
  final Color accent;
  final AppPalette colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? accent.withValues(alpha: 0.15) : colors.surfaceHover,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? accent : colors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Icon(
            categoryIconData(iconKey),
            size: 20,
            color: selected ? accent : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
