// Plan next cash-flow cycle income + limits (web Plan next cycle).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/currency/currency_controller.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../activity/domain/cycle.dart';
import '../../../planned/data/planned_reserve.dart';
import '../../../planned/data/planned_reserve_store.dart';
import '../../../planned/domain/planned_logic.dart';
import '../../../settings/data/app_settings.dart';
import '../../../settings/data/app_settings_store.dart';
import '../../../transactions/data/transaction_store.dart';
import '../../data/budget.dart';
import '../../data/category_style.dart';
import '../../data/next_cycle_budget.dart';
import '../../domain/budget_cycle.dart';
import '../../domain/budget_logic.dart';

Future<void> showNextCyclePlanSheet(
  BuildContext context, {
  required List<Budget> currentCycleBudgets,
}) {
  return showAppSheet<void>(
    context: context,
    builder: (_) => NextCyclePlanSheet(
      currentCycleBudgets: currentCycleBudgets,
    ),
  );
}

class NextCyclePlanSheet extends StatefulWidget {
  const NextCyclePlanSheet({super.key, required this.currentCycleBudgets});

  final List<Budget> currentCycleBudgets;

  @override
  State<NextCyclePlanSheet> createState() => _NextCyclePlanSheetState();
}

class _NextCyclePlanSheetState extends State<NextCyclePlanSheet> {
  late final TextEditingController _income;
  late final Map<String, TextEditingController> _drafts;
  late bool _carryForward;
  bool _saving = false;
  String? _error;
  List<PlannedReserve> _pendingReserves = const [];
  final Set<String> _acceptedReserveIds = {};

  @override
  void initState() {
    super.initState();
    final settings = AppSettingsStore.instance;
    final draft = draftForNextCycle(
      currentCycleBudgets: widget.currentCycleBudgets,
      transactions: TransactionStore.instance.transactions,
      monthlyIncome: settings.monthlyIncome,
      cycleStartDay: settings.cycleStartDay,
      carryForward: settings.nextCycleBudget?.carryForward ?? true,
      existing: settings.nextCycleBudget,
    );
    _carryForward = draft.carryForward;
    _income = TextEditingController(
      text: draft.monthlyIncome > 0
          ? (draft.monthlyIncome == draft.monthlyIncome.roundToDouble()
              ? draft.monthlyIncome.round().toString()
              : draft.monthlyIncome.toString())
          : '',
    );

    var limits = Map<String, double>.from(draft.limits);
    final nextBounds = getNextCycleDayBounds(settings.cycleStartDay);
    if (settings.plannedReservesEnabled) {
      _pendingReserves = unappliedReservesForCycle(
        PlannedReserveStore.instance.active,
        cycleStart: nextBounds.start,
        cycleEnd: nextBounds.end,
      );
      if (_pendingReserves.isNotEmpty &&
          settings.plannedReserveAllocationMode ==
              PlannedReserveAllocationMode.auto) {
        limits = applyReserveTotalsToLimits(
          limits: {
            for (final b in widget.currentCycleBudgets)
              b.id: limits[b.id] ?? b.limit,
          },
          budgets: widget.currentCycleBudgets,
          reserves: _pendingReserves,
        );
        _acceptedReserveIds.addAll(_pendingReserves.map((r) => r.id));
      }
    }

    _drafts = {
      for (final b in widget.currentCycleBudgets)
        b.id: TextEditingController(
          text: () {
            final n = limits[b.id] ?? b.limit;
            if (n <= 0) return '';
            return n == n.roundToDouble() ? n.round().toString() : n.toString();
          }(),
        ),
    };

    if (settings.plannedReservesEnabled &&
        settings.plannedReserveAllocationMode ==
            PlannedReserveAllocationMode.ask &&
        _pendingReserves.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _promptReserves();
      });
    }
  }

  void _applyReservesToDrafts(Iterable<PlannedReserve> reserves) {
    final current = <String, double>{
      for (final b in widget.currentCycleBudgets)
        b.id: double.tryParse(_drafts[b.id]?.text.trim() ?? '') ?? 0,
    };
    final next = applyReserveTotalsToLimits(
      limits: current,
      budgets: widget.currentCycleBudgets,
      reserves: reserves,
    );
    for (final b in widget.currentCycleBudgets) {
      final n = next[b.id] ?? 0;
      _drafts[b.id]?.text =
          n <= 0 ? '' : (n == n.roundToDouble() ? n.round().toString() : '$n');
    }
    _acceptedReserveIds.addAll(reserves.map((r) => r.id));
    setState(() {});
  }

  Future<void> _promptReserves() async {
    final format = CurrencyController.instance.format;
    final colors = AppColors.of(context);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: colors.surfaceElevated,
          title: Text(
            'Include planned reserves?',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'These costs fall in the next cycle. Add them to category limits?',
                  style: TextStyle(fontSize: 13, color: colors.textMuted),
                ),
                const SizedBox(height: 12),
                for (final r in _pendingReserves) ...[
                  Text(
                    '${r.title} · ${r.category}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    '${format(r.amount)} · ${r.dueDate}',
                    style: TextStyle(fontSize: 12, color: colors.textMuted),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: colors.accent),
              child: const Text('Add to budgets'),
            ),
          ],
        );
      },
    );
    if (accepted == true && mounted) {
      _applyReservesToDrafts(_pendingReserves);
    }
  }

  @override
  void dispose() {
    _income.dispose();
    for (final c in _drafts.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _rebuildFromCarry() async {
    final settings = AppSettingsStore.instance;
    final draft = buildNextCycleDraft(
      budgets: widget.currentCycleBudgets,
      transactions: TransactionStore.instance.transactions,
      monthlyIncome: double.tryParse(_income.text.trim()) ??
          settings.monthlyIncome,
      cycleStartDay: settings.cycleStartDay,
      carryForward: _carryForward,
    );
    for (final b in widget.currentCycleBudgets) {
      final n = draft.limits[b.id] ?? 0;
      _drafts[b.id]?.text =
          n <= 0 ? '' : (n == n.roundToDouble() ? n.round().toString() : '$n');
    }
    setState(() {});
  }

  Future<void> _submit() async {
    final income = double.tryParse(_income.text.trim()) ?? 0;
    if (income < 0) {
      setState(() => _error = 'Enter a valid income amount.');
      return;
    }
    final limits = <String, double>{
      for (final b in widget.currentCycleBudgets)
        b.id: double.tryParse(_drafts[b.id]?.text.trim() ?? '') ?? 0,
    };
    final total = limits.values.fold<double>(0, (s, v) => s + v);
    if (total > income + 0.0001) {
      setState(() {
        _error =
            'Over by ${CurrencyController.instance.format(total - income)}. Lower some category amounts.';
      });
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final next = getNextCycleDayBounds(
        AppSettingsStore.instance.cycleStartDay,
      );
      await AppSettingsStore.instance.setNextCycleBudget(
        NextCycleBudget(
          cycleStart: next.start,
          monthlyIncome: income,
          limits: limits,
          carryForward: _carryForward,
          preparedAt: DateTime.now().toUtc().toIso8601String(),
        ),
      );
      if (_acceptedReserveIds.isNotEmpty) {
        await PlannedReserveStore.instance.markApplied(
          _acceptedReserveIds,
          next.start,
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
      AppToast.success(
        context,
        'Next cycle budget saved · starts ${next.start}.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not save next cycle budget.';
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
    final next = getNextCycleDayBounds(AppSettingsStore.instance.cycleStartDay);
    final income = double.tryParse(_income.text.trim()) ?? 0;
    final allocated = _drafts.values.fold<double>(0, (s, c) {
      final n = double.tryParse(c.text.trim()) ?? 0;
      return s + (n > 0 ? n : 0);
    });
    final over = allocated > income + 0.0001;

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
                'Plan next cycle budget',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Starts ${formatBoundsLabel(next)}',
                style: TextStyle(fontSize: 12, color: colors.textMuted),
              ),
              if (_pendingReserves.isNotEmpty) ...[
                const SizedBox(height: 10),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surfaceHover,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _acceptedReserveIds.length == _pendingReserves.length
                              ? 'Planned reserves included'
                              : '${_pendingReserves.length} planned reserve'
                                  '${_pendingReserves.length == 1 ? '' : 's'} next cycle',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _pendingReserves
                              .map((r) =>
                                  '${r.title} (${format(r.amount)} · ${r.category})')
                              .join(' · '),
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textMuted,
                          ),
                        ),
                        if (_acceptedReserveIds.length !=
                            _pendingReserves.length) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _promptReserves,
                            child: const Text('Review & add'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    Icons.payments_outlined,
                    size: 15,
                    color: colors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Next cycle income',
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
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 18,
                        color: colors.textMuted,
                      ),
                      const SizedBox(width: 10),
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
                          controller: _income,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                          ],
                          decoration: const InputDecoration(
                            hintText: '0',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          onChanged: (_) => setState(() => _error = null),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(
                  Icons.redo_rounded,
                  color: colors.textMuted,
                ),
                title: Text(
                  'Carry forward leftover',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'Add unspent amounts into next limits',
                  style: TextStyle(fontSize: 12, color: colors.textMuted),
                ),
                value: _carryForward,
                activeThumbColor: colors.accent,
                onChanged: (v) async {
                  setState(() => _carryForward = v);
                  await _rebuildFromCarry();
                },
              ),
              Text(
                'Allocated ${format(allocated)}'
                '${income > 0 ? ' · ${over ? 'Over' : 'Left'} ${format(over ? allocated - income : income - allocated)}' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  color: over ? colors.error : colors.textMuted,
                ),
              ),
              const SizedBox(height: 12),
              for (final b in widget.currentCycleBudgets) ...[
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
                        Icon(
                          Icons.payments_outlined,
                          size: 18,
                          color: colors.textMuted,
                        ),
                        const SizedBox(width: 10),
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
                  _saving ? 'Saving…' : 'Save next cycle plan',
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
