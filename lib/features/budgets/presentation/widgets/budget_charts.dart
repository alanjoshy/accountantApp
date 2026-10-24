// Allocation pie + usage radar + balance strip (web BudgetCharts).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/currency/currency_controller.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../transactions/data/transaction.dart';
import '../../data/budget.dart';
import '../../data/category_style.dart';
import '../../domain/budget_logic.dart';
import '../../domain/budget_week.dart';

class BudgetChartRow {
  const BudgetChartRow({
    required this.id,
    required this.category,
    required this.limit,
    required this.spent,
    required this.color,
    required this.icon,
  });

  final String id;
  final String category;
  final double limit;
  final double spent;
  final Color color;
  final IconData icon;
}

List<BudgetChartRow> buildBudgetChartRows(
  List<Budget> budgets,
  List<MoneyTransaction> transactions, {
  int cycleStartDay = 1,
}) {
  final balance = buildBudgetBalanceRows(
    budgets,
    transactions,
    cycleStartDay: cycleStartDay,
  );
  final byId = {for (final b in budgets) b.id: b};
  return [
    for (var i = 0; i < balance.length; i++)
      BudgetChartRow(
        id: balance[i].id,
        category: balance[i].category,
        limit: balance[i].limit,
        spent: balance[i].spent,
        color: categoryColorFromHex(
          byId[balance[i].id]?.color ??
              defaultColorForCategory(balance[i].category, i),
        ),
        icon: categoryIconData(
          byId[balance[i].id]?.icon ??
              defaultIconForCategory(balance[i].category),
        ),
      ),
  ];
}

class BudgetCharts extends StatelessWidget {
  const BudgetCharts({
    super.key,
    required this.budgets,
    required this.transactions,
    required this.monthlyIncome,
    this.cycleStartDay = 1,
  });

  final List<Budget> budgets;
  final List<MoneyTransaction> transactions;
  final double monthlyIncome;
  final int cycleStartDay;

  @override
  Widget build(BuildContext context) {
    final rows = buildBudgetChartRows(
      budgets,
      transactions,
      cycleStartDay: cycleStartDay,
    );
    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _AllocationPie(
                rows: rows,
                monthlyIncome: monthlyIncome,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _UsagePanel(rows: rows),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _BudgetBalanceStrip(
          monthlyRows: rows,
          transactions: transactions,
        ),
      ],
    );
  }
}

class _AllocationPie extends StatefulWidget {
  const _AllocationPie({
    required this.rows,
    required this.monthlyIncome,
  });

  final List<BudgetChartRow> rows;
  final double monthlyIncome;

  @override
  State<_AllocationPie> createState() => _AllocationPieState();
}

class _AllocationPieState extends State<_AllocationPie> {
  String? _active;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final compact = CurrencyController.instance.compact;

    final allocated = widget.rows.fold<double>(0, (s, r) => s + r.limit);
    final leftover = widget.monthlyIncome > allocated
        ? widget.monthlyIncome - allocated
        : 0.0;

    final slices = <({
      String key,
      String label,
      double amount,
      Color color,
      IconData? icon,
    })>[
      for (final r in widget.rows)
        (
          key: r.id,
          label: r.category,
          amount: r.limit,
          color: r.color,
          icon: r.icon,
        ),
      if (leftover > 0.009)
        (
          key: '__left__',
          label: 'Unallocated',
          amount: leftover,
          color: const Color(0xFF94A3B8),
          icon: Icons.more_horiz_rounded,
        ),
    ];

    final total = slices.fold<double>(0, (s, r) => s + r.amount);
    final safeTotal = total > 0 ? total : 1.0;
    final painted = [
      for (final s in slices)
        (
          key: s.key,
          label: s.label,
          amount: s.amount,
          color: s.color,
          icon: s.icon,
          share: s.amount / safeTotal,
        ),
    ];

    ({
      String key,
      String label,
      double amount,
      Color color,
      IconData? icon,
      double share,
    })? active;
    for (final s in painted) {
      if (s.key == _active) {
        active = s;
        break;
      }
    }

    const size = 96.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Allocation',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              leftover > 0.009
                  ? '${compact(leftover)} left'
                  : 'Income split',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: colors.textMuted),
            ),
            const SizedBox(height: 6),
            Center(
              child: SizedBox(
                width: size,
                height: size,
                child: GestureDetector(
                  onTapDown: (d) {
                    final key = _hitSlice(
                      d.localPosition,
                      size,
                      painted.map((s) => (key: s.key, share: s.share)).toList(),
                    );
                    if (key == null) return;
                    HapticFeedback.selectionClick();
                    setState(() => _active = _active == key ? null : key);
                  },
                  child: CustomPaint(
                    painter: _DonutPainter(
                      slices: [
                        for (final s in painted)
                          (
                            share: s.share,
                            color: s.color,
                            dimmed: _active != null && _active != s.key,
                          ),
                      ],
                    ),
                    child: Center(
                      child: SizedBox(
                        width: size * 0.42,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              active?.label ?? 'Total',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 8,
                                color: colors.textMuted,
                              ),
                            ),
                            Text(
                              active == null
                                  ? compact(allocated)
                                  : '${(active.share * 100).round()}%',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: active == null ? 11 : 14,
                                fontWeight: FontWeight.w800,
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            for (final s in painted.take(4))
              InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _active = _active == s.key ? null : s.key);
                },
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      _ColorIconMark(color: s.color, icon: s.icon, compact: true),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          s.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                      Text(
                        '${(s.share * 100).round()}%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (painted.length > 4)
              Text(
                '+${painted.length - 4} more',
                style: TextStyle(fontSize: 9, color: colors.textMuted),
              ),
          ],
        ),
      ),
    );
  }

  String? _hitSlice(
    Offset local,
    double size,
    List<({String key, double share})> slices,
  ) {
    final cx = size / 2;
    final cy = size / 2;
    final dx = local.dx - cx;
    final dy = local.dy - cy;
    final r = math.sqrt(dx * dx + dy * dy);
    final outer = size / 2 - 2;
    final inner = outer * 0.7;
    if (r < inner || r > outer) return null;
    var angle = math.atan2(dy, dx);
    // Convert from math coords to start-at-top clockwise-ish matching painter.
    angle = (angle + math.pi / 2 + 2 * math.pi) % (2 * math.pi);
    var cursor = 0.0;
    for (final s in slices) {
      final sweep = s.share * 2 * math.pi;
      if (angle >= cursor && angle < cursor + sweep) return s.key;
      cursor += sweep;
    }
    return slices.isEmpty ? null : slices.last.key;
  }
}

class _UsagePanel extends StatelessWidget {
  const _UsagePanel({required this.rows});

  final List<BudgetChartRow> rows;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Usage',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              rows.length < 2 ? 'Spent vs allocated' : 'Spider · vs budget',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: colors.textMuted),
            ),
            const SizedBox(height: 6),
            if (rows.length < 2)
              _UsageBars(rows: rows)
            else ...[
              Center(
                child: SizedBox(
                  width: 100,
                  height: 100,
                  child: CustomPaint(
                    painter: _RadarPainter(rows: rows, colors: colors),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 10,
                    height: 1.5,
                    color: colors.accent.withValues(alpha: 0.55),
                  ),
                  Text(
                    ' 100%  ',
                    style: TextStyle(fontSize: 9, color: colors.textMuted),
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.3),
                      border: Border.all(color: colors.accent, width: 0.8),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(
                    ' Spent',
                    style: TextStyle(fontSize: 9, color: colors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Divider(height: 1, color: colors.border),
              const SizedBox(height: 4),
              for (final r in rows.take(4))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      _ColorIconMark(
                        color: r.color,
                        icon: r.icon,
                        compact: true,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          r.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                      Text(
                        '${r.limit > 0 ? ((r.spent / r.limit) * 100).round() : 0}%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: r.limit > 0 && r.spent > r.limit
                              ? colors.error
                              : colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              if (rows.length > 4)
                Text(
                  '+${rows.length - 4} more',
                  style: TextStyle(fontSize: 9, color: colors.textMuted),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UsageBars extends StatelessWidget {
  const _UsageBars({required this.rows});

  final List<BudgetChartRow> rows;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final format = CurrencyController.instance.format;

    if (rows.isEmpty) {
      return Text(
        'No allocated categories yet.',
        style: TextStyle(fontSize: 12, color: colors.textMuted),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final r in rows) ...[
          Row(
            children: [
              _ColorIconMark(color: r.color, icon: r.icon),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  r.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${format(r.spent)} / ${format(r.limit)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: r.spent > r.limit && r.limit > 0
                  ? colors.error
                  : colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: r.limit > 0
                  ? (r.spent / r.limit).clamp(0.0, 1.0)
                  : 0,
              minHeight: 8,
              backgroundColor: colors.surfaceHover,
              color: r.spent > r.limit && r.limit > 0
                  ? colors.error
                  : colors.accent,
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

enum _BalanceMode { monthly, weekly }

class _BudgetBalanceStrip extends StatefulWidget {
  const _BudgetBalanceStrip({
    required this.monthlyRows,
    required this.transactions,
  });

  final List<BudgetChartRow> monthlyRows;
  final List<MoneyTransaction> transactions;

  @override
  State<_BudgetBalanceStrip> createState() => _BudgetBalanceStripState();
}

class _BudgetBalanceStripState extends State<_BudgetBalanceStrip> {
  _BalanceMode _mode = _BalanceMode.monthly;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final compact = CurrencyController.instance.compact;
    final week = currentWeekInMonth();

    final monthlyBalance = [
      for (final r in widget.monthlyRows)
        BudgetBalanceRow(
          id: r.id,
          category: r.category,
          limit: r.limit,
          spent: r.spent,
        ),
    ];
    final List<BudgetChartRow> rows;
    if (_mode == _BalanceMode.weekly) {
      final weekly = buildWeeklyBudgetBalanceRows(
        monthlyBalance,
        widget.transactions,
      );
      final byId = {for (final m in widget.monthlyRows) m.id: m};
      rows = [
        for (final r in weekly)
          BudgetChartRow(
            id: r.id,
            category: r.category,
            limit: r.limit,
            spent: r.spent,
            color: byId[r.id]?.color ??
                categoryColorFromHex(defaultColorForCategory(r.category)),
            icon: byId[r.id]?.icon ??
                categoryIconData(defaultIconForCategory(r.category)),
          ),
      ];
    } else {
      rows = widget.monthlyRows;
    }

    var totalBudget = 0.0;
    var totalLeft = 0.0;
    for (final r in rows) {
      totalBudget += r.limit;
      totalLeft += math.max(0.0, r.limit - r.spent);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Budget balance',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _mode == _BalanceMode.weekly
                            ? 'This week · ${weekRangeLabel(week)}'
                            : 'Allocated, spent, and remaining per category',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    _BalanceTile(row: rows[i], colors: colors),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
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

class _BalanceTile extends StatelessWidget {
  const _BalanceTile({required this.row, required this.colors});

  final BudgetChartRow row;
  final AppPalette colors;

  @override
  Widget build(BuildContext context) {
    final compact = CurrencyController.instance.compact;
    final remaining = math.max(0.0, row.limit - row.spent);
    final over = row.limit > 0 && row.spent > row.limit;
    final spentPct =
        row.limit > 0 ? (row.spent / row.limit).clamp(0.0, 1.0) : 0.0;

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _ColorIconMark(color: row.color, icon: row.icon),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      row.category,
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
                  Text(
                    compact(row.limit),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: spentPct,
                  minHeight: 10,
                  backgroundColor: colors.surfaceElevated,
                  color: over ? colors.error : colors.accent,
                ),
              ),
              const SizedBox(height: 8),
              _Metric(
                label: 'Spent',
                value: compact(row.spent),
                valueColor: over ? colors.error : colors.accent,
                colors: colors,
              ),
              const SizedBox(height: 2),
              _Metric(
                label: 'Remaining',
                value: over ? 'Over' : compact(remaining),
                valueColor: over ? colors.error : colors.textPrimary,
                colors: colors,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.colors,
  });

  final String label;
  final String value;
  final Color valueColor;
  final AppPalette colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 10, color: colors.textMuted),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _ColorIconMark extends StatelessWidget {
  const _ColorIconMark({
    required this.color,
    this.icon,
    this.compact = false,
  });

  final Color color;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 14.0 : 18.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(compact ? 4 : 6),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: icon == null
          ? Center(
              child: Container(
                width: compact ? 5 : 6,
                height: compact ? 5 : 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            )
          : Icon(icon, size: compact ? 9 : 11, color: color),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.slices});

  final List<({double share, Color color, bool dimmed})> slices;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final outer = size.shortestSide / 2 - 2;
    final inner = outer * 0.7;
    var angle = -math.pi / 2;
    for (final s in slices) {
      final sweep = s.share * 2 * math.pi;
      if (sweep <= 0.001) continue;
      final path = Path()
        ..moveTo(cx + outer * math.cos(angle), cy + outer * math.sin(angle))
        ..arcTo(
          Rect.fromCircle(center: Offset(cx, cy), radius: outer),
          angle,
          sweep,
          false,
        )
        ..lineTo(
          cx + inner * math.cos(angle + sweep),
          cy + inner * math.sin(angle + sweep),
        )
        ..arcTo(
          Rect.fromCircle(center: Offset(cx, cy), radius: inner),
          angle + sweep,
          -sweep,
          false,
        )
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = s.color.withValues(alpha: s.dimmed ? 0.4 : 1),
      );
      angle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.slices != slices;
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.rows, required this.colors});

  final List<BudgetChartRow> rows;
  final AppPalette colors;

  Offset _polar(double cx, double cy, double r, double angleDeg) {
    final rad = (angleDeg - 90) * math.pi / 180;
    return Offset(cx + r * math.cos(rad), cy + r * math.sin(rad));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = rows.length;
    if (n < 2) return;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final pad = size.shortestSide < 120 ? 16.0 : 22.0;
    final maxR = math.min(size.width, size.height) / 2 - pad;

    final grid = Paint()
      ..color = colors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final t in [0.25, 0.5, 0.75, 1.0]) {
      final path = Path();
      for (var i = 0; i < n; i++) {
        final p = _polar(cx, cy, maxR * t, (360 / n) * i);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, grid);
    }

    for (var i = 0; i < n; i++) {
      final tip = _polar(cx, cy, maxR, (360 / n) * i);
      canvas.drawLine(Offset(cx, cy), tip, grid);
    }

    // 100% budget ring (dashed-ish via short segments)
    final budgetPaint = Paint()
      ..color = colors.accent.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final budgetPath = Path();
    final budgetR = maxR * (1 / 1.25);
    for (var i = 0; i < n; i++) {
      final p = _polar(cx, cy, budgetR, (360 / n) * i);
      if (i == 0) {
        budgetPath.moveTo(p.dx, p.dy);
      } else {
        budgetPath.lineTo(p.dx, p.dy);
      }
    }
    budgetPath.close();
    canvas.drawPath(budgetPath, budgetPaint);

    final spentPath = Path();
    final points = <Offset>[];
    for (var i = 0; i < n; i++) {
      final r = rows[i];
      final usage = r.limit > 0 ? r.spent / r.limit : 0.0;
      final capped = math.min(usage, 1.25);
      final p = _polar(cx, cy, maxR * (capped / 1.25), (360 / n) * i);
      points.add(p);
      if (i == 0) {
        spentPath.moveTo(p.dx, p.dy);
      } else {
        spentPath.lineTo(p.dx, p.dy);
      }
    }
    spentPath.close();
    canvas.drawPath(
      spentPath,
      Paint()..color = const Color(0xFF3B82F6).withValues(alpha: 0.22),
    );
    canvas.drawPath(
      spentPath,
      Paint()
        ..color = const Color(0xFF3B82F6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );

    final compactChart = size.shortestSide < 120;
    final labelStyle = TextStyle(
      fontSize: compactChart ? 7 : 9,
      fontWeight: FontWeight.w600,
      color: colors.textMuted,
    );
    final dotR = compactChart ? 2.5 : 3.5;
    for (var i = 0; i < n; i++) {
      final r = rows[i];
      final usage = r.limit > 0 ? r.spent / r.limit : 0.0;
      final p = points[i];
      canvas.drawCircle(
        p,
        dotR,
        Paint()..color = usage > 1 ? colors.error : r.color,
      );
      canvas.drawCircle(
        p,
        dotR,
        Paint()
          ..color = colors.surfaceElevated
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );

      final labelPos =
          _polar(cx, cy, maxR + (compactChart ? 10 : 14), (360 / n) * i);
      final maxChars = compactChart ? 5 : 8;
      final label = r.category.length > maxChars
          ? '${r.category.substring(0, maxChars - 1)}…'
          : r.category;
      final tp = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      tp.paint(
        canvas,
        Offset(labelPos.dx - tp.width / 2, labelPos.dy - tp.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.rows != rows || oldDelegate.colors != colors;
}
