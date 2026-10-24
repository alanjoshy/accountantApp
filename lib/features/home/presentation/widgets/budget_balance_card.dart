// Budget balance — live category tiles (web BudgetBalance + weekly toggle).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/currency/currency_controller.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../activity/domain/cycle.dart';
import '../../../budgets/data/budget_store.dart';
import '../../../budgets/data/category_style.dart';
import '../../../budgets/domain/budget_logic.dart';
import '../../../budgets/domain/budget_week.dart';
import '../../../settings/data/app_settings_store.dart';
import '../../../transactions/data/transaction_store.dart';

enum _BalanceMode { weekly, monthly }

class BudgetBalanceCard extends StatefulWidget {
  const BudgetBalanceCard({super.key});

  @override
  State<BudgetBalanceCard> createState() => _BudgetBalanceCardState();
}

class _BudgetBalanceCardState extends State<BudgetBalanceCard> {
  _BalanceMode _mode = _BalanceMode.weekly;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([
        BudgetStore.instance,
        TransactionStore.instance,
        AppSettingsStore.instance,
        CurrencyController.instance,
      ]),
      builder: (context, _) {
        final cycleDay = AppSettingsStore.instance.cycleStartDay;
        final bounds = getCurrentCycleDayBounds(cycleDay);
        final current = listedBudgetsForWindow(
          BudgetStore.instance.budgets,
          bounds,
          includeUndated: true,
        );
        final monthlyRows = buildBudgetBalanceRows(
          current,
          TransactionStore.instance.transactions,
          cycleStartDay: cycleDay,
        );
        if (monthlyRows.isEmpty) return const SizedBox.shrink();

        final week = currentWeekInMonth();
        final rows = _mode == _BalanceMode.weekly
            ? buildWeeklyBudgetBalanceRows(
                monthlyRows,
                TransactionStore.instance.transactions,
              )
            : monthlyRows;
        final byId = {for (final b in current) b.id: b};

        var totalBudget = 0.0;
        var totalLeft = 0.0;
        for (final r in rows) {
          totalBudget += r.limit;
          totalLeft += r.remaining;
        }
        final compact = CurrencyController.instance.compact;
        final subtitle = _mode == _BalanceMode.weekly
            ? 'This week · ${weekRangeLabel(week)}'
            : 'Allocated, spent, and remaining per category';

        return DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Budget balance',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.25,
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'TOTAL',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.4,
                            color: colors.textMuted,
                          ),
                        ),
                        Text(
                          compact(totalBudget),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${compact(totalLeft)} left',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surfaceHover,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final mode in _BalanceMode.values)
                            _ModeChip(
                              label: mode == _BalanceMode.weekly
                                  ? 'Weekly'
                                  : 'Monthly',
                              active: _mode == mode,
                              colors: colors,
                              onTap: () {
                                if (_mode == mode) return;
                                HapticFeedback.selectionClick();
                                setState(() => _mode = mode);
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 124,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, i) {
                      final row = rows[i];
                      final budget = byId[row.id];
                      return _BudgetTile(
                        key: ValueKey('${_mode.name}-${row.id}'),
                        category: row.category,
                        spent: row.spent,
                        limit: row.limit,
                        color: categoryColorFromHex(
                          budget?.color ??
                              defaultColorForCategory(row.category, i),
                        ),
                        icon: categoryIconData(budget?.icon ?? 'more'),
                        colors: colors,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
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
      color: active ? colors.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: active ? Border.all(color: colors.border) : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: active ? colors.textPrimary : colors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _BudgetTile extends StatelessWidget {
  const _BudgetTile({
    super.key,
    required this.category,
    required this.spent,
    required this.limit,
    required this.color,
    required this.icon,
    required this.colors,
  });

  final String category;
  final double spent;
  final double limit;
  final Color color;
  final IconData icon;
  final AppPalette colors;

  @override
  Widget build(BuildContext context) {
    final remaining = (limit - spent).clamp(0.0, limit);
    final over = limit > 0 && spent > limit;
    final spentPct = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
    final compact = CurrencyController.instance.compact;

    return SizedBox(
      width: 152,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceHover.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 132,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 14, color: color),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            compact(limit),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: SizedBox(
                      height: 10,
                      child: Stack(
                        children: [
                          ColoredBox(
                            color: colors.surfaceElevated,
                            child: const SizedBox.expand(),
                          ),
                          FractionallySizedBox(
                            widthFactor: spentPct,
                            child: ColoredBox(
                              color: over ? colors.error : colors.accent,
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _MetricRow(
                    label: 'Spent',
                    value: compact(spent),
                    labelColor: colors.textMuted,
                    valueColor: over ? colors.error : colors.accent,
                  ),
                  const SizedBox(height: 2),
                  _MetricRow(
                    label: 'Remaining',
                    value: over ? 'Over' : compact(remaining),
                    labelColor: colors.textMuted,
                    valueColor: over ? colors.error : colors.textPrimary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    required this.labelColor,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color labelColor;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: labelColor),
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
