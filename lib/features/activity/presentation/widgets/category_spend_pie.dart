// Category expense donut (web CategorySpendPie).

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/currency/currency_controller.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/activity_logic.dart';

const _pieColors = <Color>[
  Color(0xFF3B82F6),
  Color(0xFF22C55E),
  Color(0xFFF59E0B),
  Color(0xFFEF4444),
  Color(0xFFA855F7),
  Color(0xFF06B6D4),
  Color(0xFFEC4899),
  Color(0xFF84CC16),
  Color(0xFFF97316),
  Color(0xFF6366F1),
];

class CategorySpendPie extends StatelessWidget {
  const CategorySpendPie({
    super.key,
    required this.rows,
    required this.income,
    required this.expense,
    this.compact = false,
  });

  final List<BreakdownRow> rows;
  final double income;
  final double expense;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final format = CurrencyController.instance.format;
    final balance = income - expense;

    final top = rows.take(7).toList();
    final rest = rows.skip(7);
    final other = rest.fold<double>(0, (s, r) => s + r.amount);
    final list = [
      ...top,
      if (other > 0)
        BreakdownRow(
          key: '__other__',
          label: 'Other',
          amount: other,
          count: 0,
          share: 0,
        ),
    ];
    final total = list.fold<double>(0, (s, r) => s + r.amount);
    final slices = [
      for (var i = 0; i < list.length; i++)
        (
          share: total > 0 ? list[i].amount / total : 0.0,
          color: _pieColors[i % _pieColors.length],
          label: list[i].label,
        ),
    ];

    final size = compact ? 96.0 : 160.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(compact ? 14 : 16),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 8 : 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Category spending',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            Text(
              compact
                  ? 'Share of expenses'
                  : 'Share of expenses · balance ${format(balance)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 10 : 11,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            if (rows.isEmpty || expense <= 0)
              Text(
                'No expenses in this period to chart.',
                style: TextStyle(
                  fontSize: compact ? 11 : 12,
                  color: colors.textMuted,
                ),
              )
            else
              Center(
                child: SizedBox(
                  width: size,
                  height: size,
                  child: CustomPaint(
                    painter: _DonutPainter(slices: slices),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Spent',
                            style: TextStyle(
                              fontSize: compact ? 9 : 10,
                              color: colors.textMuted,
                            ),
                          ),
                          Text(
                            format(expense),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: compact ? 11 : 12,
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
          ],
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.slices});

  final List<({double share, Color color, String label})> slices;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final outer = size.shortestSide / 2 - 2;
    final inner = outer * 0.62;
    var angle = -math.pi / 2;
    for (final s in slices) {
      final sweep = s.share * 2 * math.pi;
      if (sweep <= 0.001) continue;
      final path = Path()
        ..moveTo(
          cx + outer * math.cos(angle),
          cy + outer * math.sin(angle),
        )
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
      canvas.drawPath(path, Paint()..color = s.color);
      angle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.slices != slices;
}
