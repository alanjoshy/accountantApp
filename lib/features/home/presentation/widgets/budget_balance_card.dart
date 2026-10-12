// Budget balance — live category tiles (web BudgetBalance).

import 'package:flutter/material.dart';

import '../../../../app/currency/currency_controller.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../activity/domain/cycle.dart';
import '../../../budgets/data/budget_store.dart';
import '../../../budgets/domain/budget_logic.dart';
import '../../../settings/data/app_settings_store.dart';
import '../../../transactions/data/transaction_store.dart';

const _dotColors = <Color>[
  Color(0xFF3B82F6),
  Color(0xFF22C55E),
  Color(0xFFF59E0B),
  Color(0xFFEF4444),
  Color(0xFFA855F7),
  Color(0xFF06B6D4),
  Color(0xFFEC4899),
  Color(0xFF84CC16),
];

class BudgetBalanceCard extends StatelessWidget {
  const BudgetBalanceCard({super.key});

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
        final rows = buildBudgetBalanceRows(
          current,
          TransactionStore.instance.transactions,
          cycleStartDay: cycleDay,
        );
        if (rows.isEmpty) return const SizedBox.shrink();

        var totalBudget = 0.0;
        var totalLeft = 0.0;
        for (final r in rows) {
          totalBudget += r.limit;
          totalLeft += r.remaining;
        }
        final compact = CurrencyController.instance.compact;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
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
                            'Allocated, spent, and remaining per category',
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
                SizedBox(
                  height: 124,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, i) {
                      final row = rows[i];
                      return _BudgetTile(
                        key: ValueKey(row.id),
                        category: row.category,
                        spent: row.spent,
                        limit: row.limit,
                        color: _dotColors[i % _dotColors.length],
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

class _BudgetTile extends StatelessWidget {
  const _BudgetTile({
    super.key,
    required this.category,
    required this.spent,
    required this.limit,
    required this.color,
    required this.colors,
  });

  final String category;
  final double spent;
  final double limit;
  final Color color;
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
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
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
