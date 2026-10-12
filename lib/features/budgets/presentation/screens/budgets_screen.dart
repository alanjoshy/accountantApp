// Budgets tab — Last / This cycle / Next with allocate + spend.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/currency/currency_controller.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../activity/domain/cycle.dart';
import '../../../settings/data/app_settings_store.dart';
import '../../../transactions/data/transaction_store.dart';
import '../../data/budget.dart';
import '../../data/budget_store.dart';
import '../../domain/budget_logic.dart';
import '../widgets/allocate_budget_sheet.dart';
import '../widgets/budget_form_sheet.dart';
import '../widgets/income_sheet.dart';
import '../widgets/next_cycle_plan_sheet.dart';

enum _CycleView { previous, current, next }

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  _CycleView _view = _CycleView.current;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      BudgetStore.instance.syncCycles();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return ListenableBuilder(
      listenable: Listenable.merge([
        BudgetStore.instance,
        AppSettingsStore.instance,
        TransactionStore.instance,
        CurrencyController.instance,
      ]),
      builder: (context, _) {
        final all = BudgetStore.instance.budgets;
        final settings = AppSettingsStore.instance;
        final txs = TransactionStore.instance.transactions;
        final cycleDay = settings.cycleStartDay;
        final currentBounds = getCurrentCycleDayBounds(cycleDay);
        final previousBounds = getPreviousCycleDayBounds(cycleDay);
        final nextBounds = getNextCycleDayBounds(cycleDay);

        final currentBudgets = listedBudgetsForWindow(
          all,
          currentBounds,
          includeUndated: true,
        );
        final cycleBudgets = [
          for (final b in currentBudgets)
            if (isCycleScopedBudget(b, currentBounds)) b,
        ];
        final previousBudgets = previousCycleDisplayBudgets(
          all,
          previousBounds,
          currentBounds,
        );
        final nextView = nextCycleDisplayBudgets(
          all,
          cycleBudgets,
          currentBounds,
          nextBounds,
          settings.nextCycleBudget,
        );

        final viewBudgets = switch (_view) {
          _CycleView.previous => previousBudgets,
          _CycleView.current => currentBudgets,
          _CycleView.next => nextView.budgets,
        };
        final viewBounds = switch (_view) {
          _CycleView.previous => previousBounds,
          _CycleView.current => currentBounds,
          _CycleView.next => nextBounds,
        };
        final viewLabel = formatBoundsLabel(viewBounds);
        final viewIncome = switch (_view) {
          _CycleView.next => () {
              final planned = settings.nextCycleBudget?.monthlyIncome ?? 0;
              return planned > 0 ? planned : settings.monthlyIncome;
            }(),
          _CycleView.previous => 0.0,
          _CycleView.current => settings.monthlyIncome,
        };

        final allocated = totalAllocated(viewBudgets);
        final remaining = remainingToAllocate(viewIncome, viewBudgets);
        final overAllocated =
            _view != _CycleView.previous &&
            allocated > viewIncome &&
            viewIncome > 0;
        final incomeReady = settings.monthlyIncome > 0;
        final canEdit = _view == _CycleView.current;

        var budgetTotal = 0.0;
        var spentTotal = 0.0;
        for (final b in viewBudgets) {
          if (b.limit <= 0) continue;
          budgetTotal += b.limit;
          spentTotal += spentForBudget(
            b,
            txs,
            cycleStartDay: cycleDay,
          );
        }
        final left = (budgetTotal - spentTotal).clamp(0.0, double.infinity);
        final elapsed = switch (_view) {
          _CycleView.current => cycleElapsedDays(cycleDay),
          _CycleView.previous =>
            inclusiveDayCount(previousBounds.start, previousBounds.end),
          _CycleView.next => 0,
        };
        final dailyAvg = elapsed > 0 ? spentTotal / elapsed : 0.0;

        final format = CurrencyController.instance.format;
        final subtitle = switch (_view) {
          _CycleView.next => 'Next cycle · $viewLabel',
          _CycleView.previous => 'Last cycle · $viewLabel',
          _CycleView.current => 'Your cash-flow month · $viewLabel',
        };

        return ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.lg + bottom,
          ),
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Budgets',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (incomeReady && canEdit)
                          IconButton(
                            tooltip: 'Add category',
                            onPressed: () => showBudgetFormSheet(context),
                            icon: Icon(
                              Icons.add_circle_outline_rounded,
                              color: colors.accent,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _CycleTabs(
                      view: _view,
                      colors: colors,
                      onChanged: (v) {
                        HapticFeedback.selectionClick();
                        setState(() => _view = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    _IncomeCard(
                      colors: colors,
                      label: switch (_view) {
                        _CycleView.next => 'Next cycle income',
                        _CycleView.previous => 'Last cycle plan',
                        _CycleView.current => 'Monthly income',
                      },
                      value: _view == _CycleView.previous
                          ? (allocated > 0
                              ? format(allocated)
                              : 'No saved plan')
                          : (viewIncome > 0
                              ? format(viewIncome)
                              : 'Not set'),
                      hint: switch (_view) {
                        _CycleView.previous => 'Read-only history',
                        _CycleView.next => 'Tap to plan next cycle',
                        _CycleView.current =>
                          'Tap to ${incomeReady ? 'edit' : 'add'} your income',
                      },
                      enabled: _view != _CycleView.previous,
                      onTap: () {
                        if (_view == _CycleView.previous) return;
                        if (_view == _CycleView.next) {
                          showNextCyclePlanSheet(
                            context,
                            currentCycleBudgets: cycleBudgets,
                          );
                          return;
                        }
                        showIncomeSheet(
                          context,
                          onSavedWithCategories: currentBudgets.isNotEmpty
                              ? () => showAllocateBudgetSheet(
                                    context,
                                    budgets: currentBudgets,
                                    pool:
                                        AppSettingsStore.instance.monthlyIncome,
                                  )
                              : null,
                        );
                      },
                    ),
                    if (incomeReady || _view == _CycleView.previous) ...[
                      const SizedBox(height: 10),
                      if (_view != _CycleView.previous)
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                colors: colors,
                                label: 'Allocated',
                                value: format(allocated),
                                valueColor: overAllocated
                                    ? colors.error
                                    : colors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _StatCard(
                                colors: colors,
                                label: 'Left to allocate',
                                value: format(remaining),
                                valueColor: remaining <= 0
                                    ? colors.textMuted
                                    : colors.accent,
                              ),
                            ),
                          ],
                        ),
                      if (budgetTotal > 0 || spentTotal > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                colors: colors,
                                label: 'Allocated',
                                value: format(budgetTotal),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _StatCard(
                                colors: colors,
                                label: _view == _CycleView.next
                                    ? 'Logged'
                                    : 'Spent',
                                value: format(spentTotal),
                                valueColor: colors.accent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                colors: colors,
                                label: 'Remaining',
                                value: format(left),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _view == _CycleView.next
                                  ? const SizedBox.shrink()
                                  : _StatCard(
                                      colors: colors,
                                      label: 'Daily avg',
                                      value: format(dailyAvg),
                                    ),
                            ),
                          ],
                        ),
                      ],
                      if (_view == _CycleView.next) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Expenses dated $viewLabel reduce this plan, including amounts you log before the cycle starts.',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ],
                    if (incomeReady && canEdit && currentBudgets.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Material(
                        color: colors.surfaceElevated,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: () => showAllocateBudgetSheet(
                            context,
                            budgets: currentBudgets,
                            pool: settings.monthlyIncome,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: colors.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: colors.accentMuted,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: colors.accent.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.tune_rounded,
                                    color: colors.accent,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Allocate to categories',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: colors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        remainingToAllocate(
                                                  settings.monthlyIncome,
                                                  currentBudgets,
                                                ) >
                                                0
                                            ? '${format(remainingToAllocate(settings.monthlyIncome, currentBudgets))} left — set amounts for each category'
                                            : 'Adjust how income is split across categories',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (incomeReady &&
                        canEdit &&
                        cycleBudgets.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: () => showNextCyclePlanSheet(
                          context,
                          currentCycleBudgets: cycleBudgets,
                        ),
                        icon: Icon(Icons.event_available_rounded,
                            color: colors.accent, size: 18),
                        label: Text(
                          settings.nextCycleBudget != null
                              ? 'Edit next cycle plan'
                              : 'Plan next cycle',
                          style: TextStyle(color: colors.accent),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (!incomeReady && _view == _CycleView.current)
                      _EmptyCard(
                        colors: colors,
                        title: 'Set your monthly income',
                        body:
                            'Budgets allocate income across categories for this cash-flow cycle.',
                        actionLabel: 'Add income',
                        onAction: () => showIncomeSheet(context),
                      )
                    else if (viewBudgets.isEmpty)
                      _EmptyCard(
                        colors: colors,
                        title: _view == _CycleView.previous
                            ? 'No last-cycle categories'
                            : _view == _CycleView.next
                                ? 'No next-cycle plan yet'
                                : 'No categories yet',
                        body: _view == _CycleView.current
                            ? 'Add a category to allocate income and track spend.'
                            : _view == _CycleView.next
                                ? 'Plan next cycle from This cycle, or wait for rollover.'
                                : 'Nothing was saved for that cycle.',
                        actionLabel: canEdit ? 'Add category' : null,
                        onAction: canEdit
                            ? () => showBudgetFormSheet(context)
                            : null,
                      )
                    else
                      for (final b in viewBudgets)
                        _BudgetTile(
                          key: ValueKey('${_view.name}-${b.id}-${b.limit}'),
                          budget: b,
                          spent: spentForBudget(
                            b,
                            txs,
                            cycleStartDay: cycleDay,
                          ),
                          colors: colors,
                          format: format,
                          editable: canEdit ||
                              (_view == _CycleView.next && !nextView.isPreview),
                          onTap: () {
                            if (_view == _CycleView.previous) return;
                            if (_view == _CycleView.next && nextView.isPreview) {
                              showNextCyclePlanSheet(
                                context,
                                currentCycleBudgets: cycleBudgets,
                              );
                              return;
                            }
                            if (!canEdit && _view != _CycleView.next) return;
                            showBudgetFormSheet(context, budget: b);
                          },
                          onDelete: canEdit
                              ? () => _confirmDelete(context, b)
                              : null,
                        ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, Budget budget) async {
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
          '“${budget.category}” will be removed from this period. Transactions are not deleted.',
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
    if (ok != true || !context.mounted) return;
    await BudgetStore.instance.delete(budget.id);
    if (!context.mounted) return;
    AppToast.warning(context, 'Category removed.');
  }
}

class _CycleTabs extends StatelessWidget {
  const _CycleTabs({
    required this.view,
    required this.colors,
    required this.onChanged,
  });

  final _CycleView view;
  final AppPalette colors;
  final ValueChanged<_CycleView> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(_CycleView id, String label) {
      final active = view == id;
      return Expanded(
        child: Material(
          color: active ? colors.accentMuted : colors.surfaceHover,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => onChanged(id),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: active ? colors.accent : colors.border,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: active ? colors.accent : colors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        chip(_CycleView.previous, 'Last'),
        const SizedBox(width: 8),
        chip(_CycleView.current, 'This cycle'),
        const SizedBox(width: 8),
        chip(_CycleView.next, 'Next'),
      ],
    );
  }
}

class _IncomeCard extends StatelessWidget {
  const _IncomeCard({
    required this.colors,
    required this.label,
    required this.value,
    required this.hint,
    required this.enabled,
    required this.onTap,
  });

  final AppPalette colors;
  final String label;
  final String value;
  final String hint;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.surfaceElevated,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                        color: colors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hint,
                      style: TextStyle(fontSize: 12, color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              if (enabled)
                Icon(Icons.edit_outlined, size: 16, color: colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.colors,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final AppPalette colors;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: valueColor ?? colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetTile extends StatelessWidget {
  const _BudgetTile({
    super.key,
    required this.budget,
    required this.spent,
    required this.colors,
    required this.format,
    required this.editable,
    required this.onTap,
    this.onDelete,
  });

  final Budget budget;
  final double spent;
  final AppPalette colors;
  final String Function(double) format;
  final bool editable;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final remaining = (budget.limit - spent).clamp(0.0, double.infinity);
    final ratio = budget.limit > 0 ? (spent / budget.limit).clamp(0.0, 1.5) : 0.0;
    final over = spent > budget.limit && budget.limit > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: editable ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            budget.category,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            budget.hasCustomRange
                                ? '${budget.startDate} – ${budget.endDate}'
                                : 'This cycle',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      format(budget.limit),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (onDelete != null)
                      IconButton(
                        tooltip: 'Remove',
                        onPressed: onDelete,
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: colors.error,
                        ),
                      ),
                  ],
                ),
                if (budget.limit > 0) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: ratio.clamp(0.02, 1),
                      minHeight: 6,
                      backgroundColor: colors.surfaceHover,
                      color: over ? colors.error : colors.accent,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    over
                        ? 'Spent ${format(spent)} · over by ${format(spent - budget.limit)}'
                        : 'Spent ${format(spent)} · ${format(remaining)} left',
                    style: TextStyle(
                      fontSize: 11,
                      color: over ? colors.error : colors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.colors,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final AppPalette colors;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: colors.textMuted),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
