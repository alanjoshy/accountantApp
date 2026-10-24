// Daily spend bars — same layout language as Home month-pulse categories.

import 'package:flutter/material.dart';

import '../../../../app/currency/currency_controller.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/activity_logic.dart';

class DailySpendBarChart extends StatelessWidget {
  const DailySpendBarChart({
    super.key,
    required this.points,
    this.dailyAllowance = 0,
    this.compact = true,
  });

  final List<DailySpendPoint> points;
  final double dailyAllowance;
  final bool compact;

  static const _heat = <Color>[
    Color(0x8C34D399),
    Color(0x99FACC15),
    Color(0xBFF97316),
    Color(0xFFEF4444),
  ];

  Color _fillColor(DailySpendBar bar, AppPalette colors) {
    if (bar.over) return colors.error;
    if (bar.heatLevel <= 0) return colors.surfaceHover;
    return _heat[(bar.heatLevel - 1).clamp(0, _heat.length - 1)];
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final format = CurrencyController.instance.format;
    final bars = buildDailySpendBars(points, dailyAllowance: dailyAllowance);
    final remain = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF3F3F46)
        : const Color(0xFFD1D5DB);
    // Tall track so bars read larger; card chrome stays the same.
    final panelH = compact ? 200.0 : 228.0;
    final hint = dailyAllowance > 0
        ? 'Grey left · red over'
        : 'Low green · high red';

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
            Text(
              'Daily spending',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            Text(
              dailyAllowance > 0
                  ? 'Allowance ${format(dailyAllowance)}/day'
                  : 'Expenses by day',
              style: TextStyle(fontSize: 10, color: colors.textMuted),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'DAILY',
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
                    hint,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 9, color: colors.textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.border),
              ),
              child: SizedBox(
                height: panelH,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: bars.isEmpty
                      ? Center(
                          child: Text(
                            'No data',
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        )
                      : ListView.separated(
                          primary: false,
                          scrollDirection: Axis.horizontal,
                          itemCount: bars.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(width: 6),
                          itemBuilder: (context, i) {
                            final bar = bars[i];
                            return SizedBox(
                              width: 40,
                              child: LayoutBuilder(
                                builder: (context, box) {
                                  // Reserve little for labels so the column fills height.
                                  const labelBudget = 22.0;
                                  final barMax = (box.maxHeight - labelBudget)
                                      .clamp(48.0, 280.0);
                                  final barH = (barMax * bar.heightRatio)
                                      .clamp(28.0, barMax);
                                  final spentH = barH * bar.fillRatio;
                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        bar.topLabel,
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w600,
                                          color: bar.over
                                              ? colors.error
                                              : colors.textMuted,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      SizedBox(
                                        width: 22,
                                        height: barH,
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(5),
                                          child: Stack(
                                            alignment: Alignment.bottomCenter,
                                            children: [
                                              ColoredBox(
                                                color: remain,
                                                child: const SizedBox.expand(),
                                              ),
                                              Align(
                                                alignment:
                                                    Alignment.bottomCenter,
                                                child: ColoredBox(
                                                  color: _fillColor(
                                                    bar,
                                                    colors,
                                                  ),
                                                  child: SizedBox(
                                                    width: 22,
                                                    height: spentH,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        bar.shortLabel,
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w500,
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
