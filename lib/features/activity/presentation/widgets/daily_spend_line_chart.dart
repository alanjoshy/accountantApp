// Daily expense line + allowance (web DailySpendLineChart).

import 'package:flutter/material.dart';

import '../../../../app/currency/currency_controller.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/activity_logic.dart';

class DailySpendLineChart extends StatelessWidget {
  const DailySpendLineChart({
    super.key,
    required this.points,
    this.dailyAllowance = 0,
    this.compact = true,
  });

  final List<DailySpendPoint> points;
  final double dailyAllowance;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final format = CurrencyController.instance.format;
    final maxY = [
      ...points.map((p) => p.amount),
      if (dailyAllowance > 0) dailyAllowance,
      1.0,
    ].reduce((a, b) => a > b ? a : b);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
              style: TextStyle(fontSize: 11, color: colors.textMuted),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: compact ? 96 : 140,
              width: double.infinity,
              child: points.isEmpty
                  ? Center(
                      child: Text(
                        'No data',
                        style: TextStyle(color: colors.textMuted, fontSize: 12),
                      ),
                    )
                  : CustomPaint(
                      painter: _LinePainter(
                        points: points,
                        maxY: maxY,
                        allowance: dailyAllowance,
                        lineColor: colors.accent,
                        gridColor: colors.border,
                        allowColor: colors.textMuted,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.points,
    required this.maxY,
    required this.allowance,
    required this.lineColor,
    required this.gridColor,
    required this.allowColor,
  });

  final List<DailySpendPoint> points;
  final double maxY;
  final double allowance;
  final Color lineColor;
  final Color gridColor;
  final Color allowColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final padL = 4.0;
    final padR = 4.0;
    final padT = 8.0;
    final padB = 8.0;
    final w = size.width - padL - padR;
    final h = size.height - padT - padB;

    Offset at(int i, double amount) {
      final x = padL +
          (points.length == 1 ? w / 2 : w * i / (points.length - 1));
      final y = padT + h * (1 - (amount / maxY).clamp(0.0, 1.0));
      return Offset(x, y);
    }

    if (allowance > 0) {
      final y = at(0, allowance).dy;
      final paint = Paint()
        ..color = allowColor.withValues(alpha: 0.7)
        ..strokeWidth = 1;
      const dash = 4.0;
      var x = padL;
      while (x < padL + w) {
        canvas.drawLine(Offset(x, y), Offset(x + dash, y), paint);
        x += dash * 2;
      }
    }

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final p = at(i, points[i].amount);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
    final fill = Path.from(path)
      ..lineTo(at(points.length - 1, 0).dx, padT + h)
      ..lineTo(at(0, 0).dx, padT + h)
      ..close();
    canvas.drawPath(
      fill,
      Paint()..color = lineColor.withValues(alpha: 0.12),
    );
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.maxY != maxY ||
      oldDelegate.allowance != allowance;
}
