// Daily spend bars — same layout language as Home month-pulse categories.

import 'dart:math' as math;

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
    // Compact fits beside CategorySpendPie; full height for standalone.
    final panelH = compact ? 108.0 : 228.0;
    final barWidth = compact ? 28.0 : 40.0;
    final stemW = compact ? 16.0 : 22.0;
    final hint = dailyAllowance > 0
        ? 'Grey left · red over'
        : 'Low green · high red';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(compact ? 14 : 16),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 8 : 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Daily spending',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            Text(
              dailyAllowance > 0
                  ? 'Allowance ${format(dailyAllowance)}/day'
                  : 'Expenses by day',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: colors.textMuted),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  'DAILY',
                  style: TextStyle(
                    fontSize: compact ? 9 : 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    hint,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 8 : 9,
                      color: colors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 4 : 6),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(compact ? 12 : 14),
                border: Border.all(color: colors.border),
              ),
              child: SizedBox(
                height: panelH,
                child: Padding(
                  padding: EdgeInsets.all(compact ? 4 : 6),
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
                              SizedBox(width: compact ? 4 : 6),
                          itemBuilder: (context, i) {
                            final bar = bars[i];
                            return SizedBox(
                              width: barWidth,
                              child: LayoutBuilder(
                                builder: (context, box) {
                                  final labelBudget = compact ? 26.0 : 22.0;
                                  final minBar = compact ? 10.0 : 28.0;
                                  final barMax = math.max(
                                    minBar,
                                    box.maxHeight - labelBudget,
                                  );
                                  final barH = (barMax * bar.heightRatio)
                                      .clamp(minBar, barMax);
                                  final spentH = barH * bar.fillRatio;
                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Text(
                                        bar.topLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.clip,
                                        style: TextStyle(
                                          fontSize: compact ? 7 : 8,
                                          height: 1.0,
                                          fontWeight: FontWeight.w600,
                                          color: bar.over
                                              ? colors.error
                                              : colors.textMuted,
                                        ),
                                      ),
                                      SizedBox(height: compact ? 1 : 2),
                                      SizedBox(
                                        width: stemW,
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
                                                    width: stemW,
                                                    height: spentH,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: compact ? 1 : 2),
                                      Text(
                                        bar.shortLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.clip,
                                        style: TextStyle(
                                          fontSize: compact ? 7 : 8,
                                          height: 1.0,
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
