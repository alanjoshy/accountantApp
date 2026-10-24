// Month pulse — category bars + spending heatmap (web MonthActivityStreak).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/currency/currency_controller.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../activity/domain/cycle.dart';
import '../../../budgets/data/budget_store.dart';
import '../../../budgets/data/category_style.dart';
import '../../../budgets/domain/budget_logic.dart';
import '../../../settings/data/app_settings_store.dart';
import '../../../transactions/data/transaction_store.dart';
import '../../domain/home_logic.dart';

class MonthPulseCard extends StatefulWidget {
  const MonthPulseCard({super.key, this.paymentStreak});

  final int? paymentStreak;

  @override
  State<MonthPulseCard> createState() => _MonthPulseCardState();
}

class _MonthPulseCardState extends State<MonthPulseCard> {
  static const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  late DateTime _cursor;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _cursor = DateTime(now.year, now.month);
  }

  void _shift(int delta, MonthPulseSnapshot snap) {
    if (delta < 0 && !snap.canGoPrev) return;
    if (delta > 0 && !snap.canGoNext) return;
    HapticFeedback.selectionClick();
    setState(() {
      _cursor = DateTime(_cursor.year, _cursor.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([
        TransactionStore.instance,
        BudgetStore.instance,
        AppSettingsStore.instance,
        CurrencyController.instance,
      ]),
      builder: (context, _) {
        final cycleDay = AppSettingsStore.instance.cycleStartDay;
        final txs = TransactionStore.instance.transactions;
        final budgets = BudgetStore.instance.budgets;
        final snap = buildMonthPulseSnapshot(
          transactions: txs,
          budgets: budgets,
          cycleStartDay: cycleDay,
          monthlyIncome: AppSettingsStore.instance.monthlyIncome,
          viewYear: _cursor.year,
          viewMonthIndex: _cursor.month - 1,
          cycleBalanceRows: buildBudgetBalanceRows(
            listedBudgetsForWindow(
              budgets,
              getCurrentCycleDayBounds(cycleDay),
              includeUndated: true,
            ),
            txs,
            cycleStartDay: cycleDay,
          ),
          paymentStreak: widget.paymentStreak,
        );

        final categories = snap.categories;
        final maxLimit = categories.fold<double>(
          0,
          (m, c) => c.limit > m ? c.limit : m,
        );

        return DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
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
                            'Month pulse',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            snap.cycleHint,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _NavChip(
                      icon: Icons.chevron_left_rounded,
                      colors: colors,
                      enabled: snap.canGoPrev,
                      onTap: () => _shift(-1, snap),
                    ),
                    SizedBox(
                      width: 64,
                      child: Text(
                        snap.monthLabel,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    _NavChip(
                      icon: Icons.chevron_right_rounded,
                      colors: colors,
                      enabled: snap.canGoNext,
                      onTap: () => _shift(1, snap),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    const gap = 8.0;
                    const heatPad = 6.0;
                    const heatGap = 3.0;
                    const cols = 7;
                    const rows = 6;
                    const weekdayH = 14.0;
                    const headerH = 18.0;
                    const headerGap = 6.0;

                    final stack = constraints.maxWidth < 340;
                    final colW = stack
                        ? constraints.maxWidth
                        : (constraints.maxWidth - gap) / 2;
                    final innerW = (colW - heatPad * 2).clamp(0.0, double.infinity);
                    final cell = ((innerW - (cols - 1) * heatGap) / cols)
                        .clamp(8.0, double.infinity);
                    final heatGridH =
                        weekdayH + rows * cell + (rows - 1) * heatGap;
                    // Both bordered panels share this height.
                    final panelH = heatPad * 2 + heatGridH;
                    final colH = headerH + headerGap + panelH;

                    Widget section({
                      required Widget header,
                      required Widget panelChild,
                    }) {
                      return SizedBox(
                        height: colH,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(height: headerH, child: header),
                            const SizedBox(height: headerGap),
                            SizedBox(
                              height: panelH,
                              child: _Panel(
                                colors: colors,
                                fill: true,
                                padding: const EdgeInsets.all(heatPad),
                                child: panelChild,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final cats = section(
                      header: _CategoriesHeader(colors: colors),
                      panelChild: _CategoriesChart(
                        categories: categories,
                        maxLimit: maxLimit,
                        colors: colors,
                      ),
                    );
                    final spend = section(
                      header: _SpendingHeader(colors: colors),
                      panelChild: _SpendingHeatGrid(
                        weekdays: _weekdays,
                        cells: snap.heat,
                        colors: colors,
                      ),
                    );

                    if (stack) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          cats,
                          const SizedBox(height: 10),
                          spend,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: cats),
                        const SizedBox(width: gap),
                        Expanded(child: spend),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  '${snap.activeDays}/${snap.daysInMonth} days with activity',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: colors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Divider(height: 1, thickness: 1, color: colors.border),
                const SizedBox(height: 10),
                Builder(
                  builder: (context) {
                    final format = CurrencyController.instance.format;
                    final story = snap.story;
                    return Column(
                      children: [
                        if (story.topSpendKey != null && story.topSpend > 0)
                          _StoryBullet(
                            bulletColor: const Color(0xFFF97316),
                            colors: colors,
                            title: 'Most spend day',
                            detail:
                                '${formatPulseDayKey(story.topSpendKey!)} · ${format(story.topSpend)}',
                          )
                        else
                          _StoryBullet(
                            bulletColor: colors.textMuted,
                            colors: colors,
                            title: 'No spend logged this month yet',
                            detail: '',
                            muted: true,
                          ),
                        const SizedBox(height: 6),
                        if (story.topIncomeKey != null &&
                            story.topIncome > 0)
                          _StoryBullet(
                            bulletColor: const Color(0xFF10B981),
                            colors: colors,
                            title: 'Most income day',
                            detail:
                                '${formatPulseDayKey(story.topIncomeKey!)} · ${format(story.topIncome)}',
                          )
                        else
                          _StoryBullet(
                            bulletColor: colors.textMuted,
                            colors: colors,
                            title: 'No income logged this month yet',
                            detail: '',
                            muted: true,
                          ),
                        if (snap.paymentStreak > 0) ...[
                          const SizedBox(height: 6),
                          _StoryBullet(
                            bulletColor: const Color(0xFFF97316),
                            colors: colors,
                            title: 'Daily streak',
                            detail:
                                '${snap.paymentStreak} day${snap.paymentStreak == 1 ? '' : 's'} logging payments in a row',
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StoryBullet extends StatelessWidget {
  const _StoryBullet({
    required this.bulletColor,
    required this.colors,
    required this.title,
    required this.detail,
    this.muted = false,
  });

  final Color bulletColor;
  final AppPalette colors;
  final String title;
  final String detail;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    if (muted) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '•',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.35,
              color: bulletColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 11,
                height: 1.35,
                color: colors.textMuted,
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '•',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 1.35,
            color: bulletColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: TextStyle(
                fontSize: 11,
                height: 1.35,
                color: colors.textSecondary,
              ),
              children: [
                TextSpan(
                  text: title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                if (detail.isNotEmpty) TextSpan(text: ' · $detail'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NavChip extends StatelessWidget {
  const _NavChip({
    required this.icon,
    required this.colors,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final AppPalette colors;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.3,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 28,
            height: 28,
            child: Icon(icon, size: 16, color: colors.textMuted),
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.colors,
    required this.child,
    this.fill = false,
    this.padding,
  });

  final AppPalette colors;
  final Widget child;
  final bool fill;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: padding ??
            (fill
                ? const EdgeInsets.fromLTRB(10, 10, 10, 8)
                : const EdgeInsets.all(8)),
        child: fill ? SizedBox.expand(child: child) : child,
      ),
    );
  }
}

class _CategoriesHeader extends StatelessWidget {
  const _CategoriesHeader({required this.colors});

  final AppPalette colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'CATEGORIES',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Grey left · red over',
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 9, color: colors.textMuted),
          ),
        ),
      ],
    );
  }
}

class _SpendingHeader extends StatelessWidget {
  const _SpendingHeader({required this.colors});

  final AppPalette colors;

  static Color _levelColor(AppPalette colors, int level) {
    return switch (level) {
      1 => const Color(0x8C34D399),
      2 => const Color(0x99FACC15),
      3 => const Color(0xBFF97316),
      _ => const Color(0xFFEF4444),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'SPENDING',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Low',
                  style: TextStyle(fontSize: 9, color: colors.textMuted),
                ),
                const SizedBox(width: 4),
                for (final level in [1, 2, 3, 4])
                  Container(
                    width: 9,
                    height: 9,
                    margin: const EdgeInsets.only(right: 3),
                    decoration: BoxDecoration(
                      color: _levelColor(colors, level),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                Text(
                  'High',
                  style: TextStyle(fontSize: 9, color: colors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoriesChart extends StatelessWidget {
  const _CategoriesChart({
    required this.categories,
    required this.maxLimit,
    required this.colors,
  });

  final List<MonthPulseCategoryBar> categories;
  final double maxLimit;
  final AppPalette colors;

  @override
  Widget build(BuildContext context) {
    final remain = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF3F3F46)
        : const Color(0xFFD1D5DB);

    if (categories.isEmpty) {
      return Center(
        child: Text(
          'Allocate budgets to see categories',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: colors.textMuted),
        ),
      );
    }

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: categories.length,
      separatorBuilder: (_, _) => const SizedBox(width: 6),
      itemBuilder: (context, i) {
        final c = categories[i];
        final h =
            maxLimit <= 0 ? 0.0 : (c.limit / maxLimit).clamp(0.14, 1.0);
        final over = c.spent > c.limit;
        final left = (c.limit - c.spent).clamp(0.0, c.limit);
        final topLabel = over
            ? '+${((c.spent - c.limit) / 1000).toStringAsFixed(1)}k'
            : left >= 1000
                ? '${(left / 1000).toStringAsFixed(1)}k'
                : left.round().toString();
        final barColor = categoryColorFromHex(c.colorHex);

        return SizedBox(
          width: 40,
          child: LayoutBuilder(
            builder: (context, box) {
              final barMax = (box.maxHeight - 28).clamp(24.0, 200.0);
              final barH = (barMax * h).clamp(16.0, barMax);
              final spentH = barH *
                  (over
                      ? 1.0
                      : (c.limit <= 0
                          ? 0.0
                          : (c.spent / c.limit).clamp(0.0, 1.0)));
              return FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.bottomCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      topLabel,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        color: over ? colors.error : colors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      width: 22,
                      height: barH,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            ColoredBox(
                              color: remain,
                              child: const SizedBox.expand(),
                            ),
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: ColoredBox(
                                color: over ? colors.error : barColor,
                                child: SizedBox(width: 22, height: spentH),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      c.label.length > 6
                          ? c.label.substring(0, 6)
                          : c.label,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _SpendingHeatGrid extends StatelessWidget {
  const _SpendingHeatGrid({
    required this.weekdays,
    required this.cells,
    required this.colors,
  });

  final List<String> weekdays;
  final List<int> cells;
  final AppPalette colors;

  static const _gap = 3.0;
  static const _cols = 7;
  static const _rows = 6;
  static const _weekdayH = 14.0;

  Color _levelColor(int level) {
    return switch (level) {
      -1 => Colors.transparent,
      0 => colors.surfaceHover,
      1 => const Color(0x8C34D399),
      2 => const Color(0x99FACC15),
      3 => const Color(0xBFF97316),
      _ => const Color(0xFFEF4444),
    };
  }

  Widget _cell(double size, int level) {
    if (level < 0) return SizedBox(width: size, height: size);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _levelColor(level),
        borderRadius: BorderRadius.circular(3),
        border: level == 0
            ? Border.all(color: colors.border.withValues(alpha: 0.6))
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Fill the container width with equal squares (no L/R empty band).
        final size =
            ((constraints.maxWidth - (_cols - 1) * _gap) / _cols).clamp(
          8.0,
          double.infinity,
        );
        final gridH = _weekdayH + _rows * size + (_rows - 1) * _gap;

        return SizedBox(
          width: double.infinity,
          height: gridH,
          child: Column(
            children: [
              SizedBox(
                height: _weekdayH - 2,
                child: Row(
                  children: [
                    for (var i = 0; i < weekdays.length; i++) ...[
                      if (i > 0) const SizedBox(width: _gap),
                      SizedBox(
                        width: size,
                        child: Text(
                          weekdays[i],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            height: 1,
                            color: colors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 2),
              for (var r = 0; r < _rows; r++) ...[
                if (r > 0) const SizedBox(height: _gap),
                Row(
                  children: [
                    for (var c = 0; c < _cols; c++) ...[
                      if (c > 0) const SizedBox(width: _gap),
                      _cell(
                        size,
                        r * _cols + c < cells.length
                            ? cells[r * _cols + c]
                            : -1,
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
