// Budgets tab — Last / This cycle / Next with allocate + spend.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/currency/currency_controller.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../activity/domain/cycle.dart';
import '../../../settings/data/app_settings_store.dart';
import '../../../transactions/data/transaction_store.dart';
import '../../data/budget.dart';
import '../../data/budget_store.dart';
import '../../data/category_style.dart';
import '../../domain/budget_logic.dart';
import '../widgets/allocate_budget_sheet.dart';
import '../widgets/budget_charts.dart';
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
        // Main list: only categories with an allocated amount.
        final listedBudgets = [
          for (final b in viewBudgets)
            if (b.limit > 0) b,
        ];
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
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
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
                                    mainAxisSize: MainAxisSize.min,
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
                    if (!incomeReady && _view != _CycleView.previous) ...[
                      _EmptyCard(
                        colors: colors,
                        title: 'Plan your budget',
                        body:
                            'Add your monthly income first, then allocate money to Food, Grocery, and other categories.',
                        actionLabel: 'Set monthly income',
                        onAction: () => showIncomeSheet(
                          context,
                          onSavedWithCategories: () {
                            final cats = listedBudgetsForWindow(
                              BudgetStore.instance.budgets,
                              getCurrentCycleDayBounds(
                                AppSettingsStore.instance.cycleStartDay,
                              ),
                              includeUndated: true,
                            );
                            if (cats.isEmpty) return;
                            showAllocateBudgetSheet(
                              context,
                              budgets: cats,
                              pool: AppSettingsStore.instance.monthlyIncome,
                            );
                          },
                        ),
                      ),
                    ] else if (listedBudgets.isEmpty)
                      _EmptyCard(
                        colors: colors,
                        title: _view == _CycleView.previous
                            ? 'No last-cycle categories'
                            : _view == _CycleView.next
                                ? 'No next-cycle plan yet'
                                : currentBudgets.isEmpty
                                    ? 'No categories yet'
                                    : 'Nothing allocated yet',
                        body: _view == _CycleView.current
                            ? (currentBudgets.isEmpty
                                ? 'Tap + to add a category, then allocate income.'
                                : 'Allocate income to categories to show them here.')
                            : _view == _CycleView.next
                                ? 'Add categories in this cycle, then plan next.'
                                : 'No saved categories for last cycle.',
                        actionLabel: canEdit
                            ? (currentBudgets.isEmpty
                                ? 'Add category'
                                : 'Allocate to categories')
                            : null,
                        onAction: canEdit
                            ? () {
                                if (currentBudgets.isEmpty) {
                                  showBudgetFormSheet(context);
                                } else {
                                  showAllocateBudgetSheet(
                                    context,
                                    budgets: currentBudgets,
                                    pool: settings.monthlyIncome,
                                  );
                                }
                              }
                            : null,
                      )
                    else ...[
                      BudgetCharts(
                        budgets: listedBudgets,
                        transactions: txs,
                        monthlyIncome:
                            viewIncome > 0 ? viewIncome : allocated,
                        cycleStartDay: cycleDay,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Categories',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final lastMonth = previousCalendarMonth();
                          final lastMonthShort =
                              lastMonth.label.split(' ').first;
                          final compactFmt =
                              CurrencyController.instance.compact;
                          final showLastMonth =
                              _view == _CycleView.current;
                          final spentLabel = _view == _CycleView.next
                              ? 'Logged'
                              : 'Consumed';

                          return LayoutBuilder(
                            builder: (context, constraints) {
                              const gap = 10.0;
                              final tileW =
                                  (constraints.maxWidth - gap) / 2;
                              return Wrap(
                                spacing: gap,
                                runSpacing: gap,
                                children: [
                                  for (final b in listedBudgets)
                                    SizedBox(
                                      width: tileW,
                                      child: _BudgetTile(
                                        key: ValueKey(
                                          '${_view.name}-${b.id}-${b.limit}',
                                        ),
                                        budget: b,
                                        spent: spentForBudget(
                                          b,
                                          txs,
                                          cycleStartDay: cycleDay,
                                        ),
                                        lastMonthSpent: showLastMonth
                                            ? spentInCalendarMonth(
                                                b.category,
                                                txs,
                                                lastMonth.year,
                                                lastMonth.monthIndex,
                                              )
                                            : null,
                                        lastMonthShort: showLastMonth
                                            ? lastMonthShort
                                            : null,
                                        spentLabel: spentLabel,
                                        colors: colors,
                                        compact: compactFmt,
                                        editable: canEdit ||
                                            (_view == _CycleView.next &&
                                                !nextView.isPreview),
                                        onTap: () {
                                          if (_view ==
                                              _CycleView.previous) {
                                            return;
                                          }
                                          if (_view ==
                                                  _CycleView.next &&
                                              nextView.isPreview) {
                                            showNextCyclePlanSheet(
                                              context,
                                              currentCycleBudgets:
                                                  cycleBudgets,
                                            );
                                            return;
                                          }
                                          if (!canEdit &&
                                              _view !=
                                                  _CycleView.next) {
                                            return;
                                          }
                                          showBudgetFormSheet(
                                            context,
                                            budget: b,
                                          );
                                        },
                                      ),
                                    ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.accentMuted,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colors.accent.withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(
                  Icons.payments_outlined,
                  color: colors.accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
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
    required this.compact,
    required this.editable,
    required this.onTap,
    required this.spentLabel,
    this.lastMonthSpent,
    this.lastMonthShort,
  });

  final Budget budget;
  final double spent;
  final AppPalette colors;
  final String Function(double) compact;
  final bool editable;
  final VoidCallback onTap;
  final String spentLabel;
  final double? lastMonthSpent;
  final String? lastMonthShort;

  @override
  Widget build(BuildContext context) {
    final balance = (budget.limit - spent).clamp(0.0, double.infinity);
    final ratio =
        budget.limit > 0 ? (spent / budget.limit).clamp(0.0, 1.0) : 0.0;
    final over = spent > budget.limit && budget.limit > 0;
    final accent = categoryColorFromHex(budget.color);
    final lastAllocated = budget.limit;
    final lastUsed = lastMonthSpent ?? 0;
    final lastOver = lastAllocated > 0 && lastUsed > lastAllocated;
    final showLast = lastMonthShort != null && lastMonthSpent != null;

    return Material(
      color: colors.surfaceHover.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: editable ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Icon(
                      categoryIconData(budget.icon),
                      size: 13,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      budget.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: budget.limit > 0 ? ratio.clamp(0.02, 1) : 0,
                  minHeight: 8,
                  backgroundColor: colors.surfaceElevated,
                  color: over ? colors.error : colors.accent,
                ),
              ),
              const SizedBox(height: 8),
              _StatRow(
                label: spentLabel,
                value: compact(spent),
                valueColor: over ? colors.error : colors.accent,
                colors: colors,
              ),
              _StatRow(
                label: 'Allocated',
                value: compact(budget.limit),
                colors: colors,
              ),
              _StatRow(
                label: 'Balance',
                value: over ? 'Over' : compact(balance),
                valueColor: over ? colors.error : colors.textPrimary,
                colors: colors,
              ),
              if (showLast) ...[
                _StatRow(
                  label: '$lastMonthShort allocated',
                  value: compact(lastAllocated),
                  colors: colors,
                ),
                _StatRow(
                  label: '$lastMonthShort consumed',
                  value: compact(lastUsed),
                  valueColor: lastOver ? colors.error : colors.textPrimary,
                  colors: colors,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    required this.colors,
    this.valueColor,
  });

  final String label;
  final String value;
  final AppPalette colors;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: colors.textMuted,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: valueColor ?? colors.textPrimary,
            ),
          ),
        ],
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
