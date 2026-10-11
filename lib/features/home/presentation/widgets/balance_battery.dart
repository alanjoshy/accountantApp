// Month-pool ring (web BalanceBattery).

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

enum BatteryTone { green, orange, yellow, red }

BatteryTone batteryToneForPct(int pct) {
  if (pct >= 70) return BatteryTone.green;
  if (pct >= 45) return BatteryTone.orange;
  if (pct >= 20) return BatteryTone.yellow;
  return BatteryTone.red;
}

class BalanceBattery extends StatelessWidget {
  const BalanceBattery({
    super.key,
    required this.balance,
    required this.capacity,
    this.amountsVisible = true,
    this.formatAmount,
  });

  final double balance;
  final double capacity;
  final bool amountsVisible;
  final String Function(double value)? formatAmount;

  static const _size = 56.0;
  static const _stroke = 5.5;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final safeCap = capacity > 0 ? capacity : 0.0;
    if (safeCap <= 0) return const SizedBox.shrink();

    final rawPct = ((balance / safeCap) * 100).round().clamp(0, 100);
    final pct = balance <= 0 ? 0 : rawPct;
    final tone = batteryToneForPct(pct);
    final fill = _fill(tone);
    final textColor = amountsVisible ? fill : colors.textMuted;
    final amount = formatAmount ?? (v) => v.round().toString();

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: fill.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fill.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: _size,
            height: _size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(_size, _size),
                  painter: _RingPainter(
                    progress: amountsVisible ? pct / 100 : 0,
                    fill: fill,
                    track: fill.withValues(alpha: 0.18),
                    stroke: _stroke,
                  ),
                ),
                Text(
                  amountsVisible ? '$pct%' : '••',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 76),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'LEFT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: colors.textMuted,
                  ),
                ),
                Text(
                  amountsVisible
                      ? amount(math.max(0, balance))
                      : '•••••',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: textColor,
                  ),
                ),
                Text(
                  'of ${amountsVisible ? amount(safeCap) : '•••••'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _fill(BatteryTone tone) {
    return switch (tone) {
      BatteryTone.green => const Color(0xFF22C55E),
      BatteryTone.orange => const Color(0xFFF97316),
      BatteryTone.yellow => const Color(0xFFEAB308),
      BatteryTone.red => const Color(0xFFEF4444),
    };
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.fill,
    required this.track,
    required this.stroke,
  });

  final double progress;
  final Color fill;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - stroke) / 2;
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..color = fill
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);
    if (progress <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.fill != fill ||
        oldDelegate.track != track ||
        oldDelegate.stroke != stroke;
  }
}
