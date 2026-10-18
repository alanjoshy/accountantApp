// Bulk-edit category limits against monthly income (web Allocate sheet).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/currency/currency_controller.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../data/budget.dart';
import '../../data/budget_store.dart';
import '../../data/category_style.dart';
import '../../domain/budget_logic.dart';

Future<void> showAllocateBudgetSheet(
  BuildContext context, {
  required List<Budget> budgets,
  required double pool,
}) {
  return showAppSheet<void>(
    context: context,
    builder: (_) => AllocateBudgetSheet(budgets: budgets, pool: pool),
  );
}

class AllocateBudgetSheet extends StatefulWidget {
  const AllocateBudgetSheet({
    super.key,
    required this.budgets,
    required this.pool,
  });

  final List<Budget> budgets;
  final double pool;

  @override
  State<AllocateBudgetSheet> createState() => _AllocateBudgetSheetState();
}

class _AllocateBudgetSheetState extends State<AllocateBudgetSheet> {
  late final Map<String, TextEditingController> _drafts;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _drafts = {
      for (final b in widget.budgets)
        b.id: TextEditingController(
          text: b.limit > 0
              ? (b.limit == b.limit.roundToDouble()
                  ? b.limit.round().toString()
                  : b.limit.toString())
              : '',
        ),
    };
  }

  @override
  void dispose() {
    for (final c in _drafts.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _total {
    var sum = 0.0;
    for (final c in _drafts.values) {
      final n = double.tryParse(c.text.trim()) ?? 0;
      if (n > 0) sum += n;
    }
    return sum;
  }

  Future<void> _submit() async {
    final total = _total;
    if (total > widget.pool + 0.0001 && widget.pool > 0) {
      setState(() {
        _error =
            'Over by ${CurrencyController.instance.format(total - widget.pool)}. Lower some category amounts.';
      });
      HapticFeedback.heavyImpact();
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final rows = <({String id, double limit})>[
        for (final b in widget.budgets)
          (
            id: b.id,
            limit: double.tryParse(_drafts[b.id]?.text.trim() ?? '') ?? 0,
          ),
      ];
      await BudgetStore.instance.updateLimits(rows);
      if (!mounted) return;
      Navigator.pop(context);
      AppToast.success(
        context,
        total > 0 ? 'Category amounts saved.' : 'Category amounts cleared.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't save allocations.";
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final format = CurrencyController.instance.format;
    final symbol = CurrencyController.instance.symbol;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final remaining = remainingToAllocate(widget.pool, [
      for (final b in widget.budgets)
        b.copyWith(
          limit: double.tryParse(_drafts[b.id]?.text.trim() ?? '') ?? 0,
        ),
    ]);
    final over = _total > widget.pool + 0.0001 && widget.pool > 0;

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
                'Allocate to categories',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Split your planned income across categories. Leave a field at 0 to skip it.',
                style: TextStyle(fontSize: 12, color: colors.textMuted),
              ),
              const SizedBox(height: 6),
              Text(
                'Pool ${format(widget.pool)} · '
                '${over ? 'Over' : 'Left'} ${format(over ? _total - widget.pool : remaining)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: over ? colors.error : colors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              for (final b in widget.budgets) ...[
                Row(
                  children: [
                    Icon(
                      categoryIconData(b.icon),
                      size: 16,
                      color: categoryColorFromHex(b.color),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      b.category,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
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
                        Text(
                          symbol,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: colors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _drafts[b.id],
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.]'),
                              ),
                            ],
                            decoration: const InputDecoration(
                              hintText: '0',
                              border: InputBorder.none,
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 12),
                            ),
                            onChanged: (_) => setState(() => _error = null),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
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
                  _saving ? 'Saving…' : 'Save allocations',
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
}
