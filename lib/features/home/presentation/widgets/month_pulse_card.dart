// Month pulse — category bars + spending heatmap (web MonthActivityStreak).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/currency/currency_controller.dart';
import '../../../../app/theme/app_colors.dart';

class MonthPulseCard extends StatefulWidget {
  const MonthPulseCard({super.key});

  @override
  State<MonthPulseCard> createState() => _MonthPulseCardState();
}

class _MonthPulseCardState extends State<MonthPulseCard> {
  static const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  static const _barColors = <Color>[
    Color(0xFF3B82F6),
    Color(0xFF22C55E),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFFA855F7),
    Color(0xFF06B6D4),
  ];

  static const _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  late DateTime _cursor;
  late List<_CategoryBar> _categories;
  late List<int> _heat;
  late _MonthStory _story;
  late double _maxLimit;
  late int _activeDays;
  late int _daysInMonth;
  late String _monthLabel;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _cursor = DateTime(now.year, now.month);
    _recompute();
  }

  void _shift(int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      _cursor = DateTime(_cursor.year, _cursor.month + delta);
      _recompute();
    });
  }

  void _recompute() {
    final seed = _cursor.year * 12 + _cursor.month;
    final base = <(String, double, double)>[
      ('Food', 4200, 6000),
      ('Rent', 15000, 15000),
      ('Travel', 2800, 4000),
      ('Bills', 1900, 3000),
      ('Fun', 900, 2000),
    ];
    _categories = [
      for (var i = 0; i < base.length; i++)
        _CategoryBar(
          label: base[i].$1,
          spent: base[i].$2 + (seed % 3) * 80.0 * (i + 1),
          limit: base[i].$3,
          color: _barColors[i % _barColors.length],
        ),
    ];
    _maxLimit = _categories.fold<double>(
      0,
      (m, c) => c.limit > m ? c.limit : m,
    );

    final year = _cursor.year;
    final month = _cursor.month;
    _daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday;
    final leading = firstWeekday - 1;
    const weeks = 6;
    _heat = List<int>.filled(weeks * 7, -1);
    for (var day = 1; day <= _daysInMonth; day++) {
      final n = (seed * 17 + day * 13) % 11;
      final level = n < 3
          ? 0
          : n < 5
              ? 1
              : n < 7
                  ? 2
                  : n < 9
                      ? 3
                      : 4;
      _heat[leading + day - 1] = level;
    }
    _activeDays = _heat.where((l) => l > 0).length;

    final spendDay = ((seed * 7) % _daysInMonth) + 1;
    final incomeDay = ((seed * 3) % _daysInMonth) + 1;
    final label = _monthNames[_cursor.month - 1];
    _story = _MonthStory(
      spendLabel: '$spendDay $label',
      spendAmount: 1800.0 + (seed % 5) * 420,
      incomeLabel: '$incomeDay $label',
      incomeAmount: 35000.0 + (seed % 4) * 2500,
      dailyAverage: 900.0 + (seed % 6) * 80,
    );
    _monthLabel = '$label ${_cursor.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final categories = _categories;
    final maxLimit = _maxLimit;
    final heat = _heat;
    final activeDays = _activeDays;
    final daysInMonth = _daysInMonth;
    final story = _story;

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
                        'Calendar month',
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
                  onTap: () => _shift(-1),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    _monthLabel,
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
                  onTap: () => _shift(1),
                ),
              ],
            ),
            const SizedBox(height: 4),
            LayoutBuilder(
              builder: (context, constraints) {
                final stack = constraints.maxWidth < 320;
                // Match Categories content height so Spending can expand into
                // the same panel without growing the outer Month pulse card.
                const panelH = 136.0;
                final cats = _Panel(
                  colors: colors,
                  fill: true,
                  child: _CategoriesChart(
                    categories: categories,
                    maxLimit: maxLimit,
                    colors: colors,
                  ),
                );
                final spend = _Panel(
                  colors: colors,
                  fill: true,
                  child: _SpendingHeat(
                    weekdays: _weekdays,
                    cells: heat,
                    colors: colors,
                  ),
                );

                if (stack) {
                  return Column(
                    children: [
                      SizedBox(height: panelH, child: cats),
                      const SizedBox(height: 4),
                      SizedBox(height: panelH, child: spend),
                    ],
                  );
                }

                return SizedBox(
                  height: panelH,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: cats),
                      const SizedBox(width: 4),
                      Expanded(child: spend),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            Text(
              '$activeDays/$daysInMonth days with activity',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Divider(height: 1, thickness: 1, color: colors.border),
            const SizedBox(height: 10),
            ListenableBuilder(
              listenable: CurrencyController.instance,
              builder: (context, _) {
                final format = CurrencyController.instance.format;
                return Column(
                  children: [
                    _StoryBullet(
                      // web: text-orange-500
                      bulletColor: const Color(0xFFF97316),
                      colors: colors,
                      title: 'Most spend day',
                      detail:
                          '${story.spendLabel} · ${format(story.spendAmount)}',
                    ),
                    const SizedBox(height: 6),
                    _StoryBullet(
                      // web: text-emerald-500
                      bulletColor: const Color(0xFF10B981),
                      colors: colors,
                      title: 'Most income day',
                      detail:
                          '${story.incomeLabel} · ${format(story.incomeAmount)}',
                    ),
                    const SizedBox(height: 6),
                    _StoryBullet(
                      bulletColor: const Color(0xFFF97316),
                      colors: colors,
                      title: 'Daily average spending',
                      detail: '${format(story.dailyAverage)} per day',
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthStory {
  const _MonthStory({
    required this.spendLabel,
    required this.spendAmount,
    required this.incomeLabel,
    required this.incomeAmount,
    required this.dailyAverage,
  });

  final String spendLabel;
  final double spendAmount;
  final String incomeLabel;
  final double incomeAmount;
  final double dailyAverage;
}

class _StoryBullet extends StatelessWidget {
  const _StoryBullet({
    required this.bulletColor,
    required this.colors,
    required this.title,
    required this.detail,
  });

  final Color bulletColor;
  final AppPalette colors;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
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
                TextSpan(text: ' · $detail'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryBar {
  const _CategoryBar({
    required this.label,
    required this.spent,
    required this.limit,
    required this.color,
  });

  final String label;
  final double spent;
  final double limit;
  final Color color;
}

class _NavChip extends StatelessWidget {
  const _NavChip({
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final AppPalette colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(icon, size: 16, color: colors.textMuted),
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
  });

  final AppPalette colors;
  final Widget child;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: fill
            ? const EdgeInsets.all(3)
            : const EdgeInsets.fromLTRB(2, 3, 2, 3),
        child: fill ? SizedBox.expand(child: child) : child,
      ),
    );
  }
}

class _CategoriesChart extends StatelessWidget {
  const _CategoriesChart({
    required this.categories,
    required this.maxLimit,
    required this.colors,
  });

  final List<_CategoryBar> categories;
  final double maxLimit;
  final AppPalette colors;

  @override
  Widget build(BuildContext context) {
    final remain = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF3F3F46)
        : const Color(0xFFD1D5DB);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CATEGORIES',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: ListView.separated(
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

              return SizedBox(
                width: 34,
                child: LayoutBuilder(
                  builder: (context, box) {
                    final barMax = (box.maxHeight - 28).clamp(10.0, 80.0);
                    final barH = (barMax * h).clamp(10.0, barMax);
                    final spentH = barH *
                        (over ? 1.0 : (c.spent / c.limit).clamp(0.0, 1.0));
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
                            width: 18,
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
                                      color: over ? colors.error : c.color,
                                      child:
                                          SizedBox(width: 18, height: spentH),
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
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Grey left · red over',
          style: TextStyle(fontSize: 9, color: colors.textMuted),
        ),
      ],
    );
  }
}

class _SpendingHeat extends StatelessWidget {
  const _SpendingHeat({
    required this.weekdays,
    required this.cells,
    required this.colors,
  });

  final List<String> weekdays;
  final List<int> cells;
  final AppPalette colors;

  static const _gap = 1.5;
  static const _cols = 7;
  static const _rows = 6;

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

  Widget _legend() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Low',
          style: TextStyle(fontSize: 8, color: colors.textMuted),
        ),
        const SizedBox(width: 3),
        for (final level in [1, 2, 3, 4])
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(right: 2),
            decoration: BoxDecoration(
              color: _levelColor(level),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        Text(
          'High',
          style: TextStyle(fontSize: 8, color: colors.textMuted),
        ),
      ],
    );
  }

  Widget _cell(double size, int level) {
    if (level < 0) return SizedBox(width: size, height: size);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _levelColor(level),
        borderRadius: BorderRadius.circular(2.5),
        border: level == 0
            ? Border.all(color: colors.border.withValues(alpha: 0.6))
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Title + legend on one row; square cells sized to fit the remaining area.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'SPENDING',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: _legend(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const weekdayH = 9.0;
              final byWidth =
                  (constraints.maxWidth - (_cols - 1) * _gap) / _cols;
              final byHeight = (constraints.maxHeight -
                      weekdayH -
                      (_rows - 1) * _gap) /
                  _rows;
              final size =
                  (byWidth < byHeight ? byWidth : byHeight).clamp(1.0, 48.0);
              final gridW = _cols * size + (_cols - 1) * _gap;

              return Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: gridW,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: weekdayH - 1,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            for (final d in weekdays)
                              SizedBox(
                                width: size,
                                child: Text(
                                  d,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 7,
                                    fontWeight: FontWeight.w500,
                                    height: 1,
                                    color: colors.textMuted,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 1),
                      for (var r = 0; r < _rows; r++) ...[
                        if (r > 0) const SizedBox(height: _gap),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            for (var c = 0; c < _cols; c++)
                              _cell(
                                size,
                                r * _cols + c < cells.length
                                    ? cells[r * _cols + c]
                                    : -1,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
