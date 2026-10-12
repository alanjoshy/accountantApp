// Glass savings jar with liquid fill tinted by jar color.

import 'package:flutter/material.dart';

class GlassJar extends StatelessWidget {
  const GlassJar({
    super.key,
    required this.progress,
    this.compact = true,
    this.fillColor = const Color(0xFF22C55E),
  });

  /// 0–100
  final double progress;
  final bool compact;

  /// Liquid / glow color (matches jar label accent).
  final Color fillColor;

  @override
  Widget build(BuildContext context) {
    final pct = progress.clamp(0, 100).round();
    final done = pct >= 100;
    final height = compact ? 128.0 : 176.0;
    final width = compact ? 92.0 : 124.0;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final border = dark
        ? Colors.white.withValues(alpha: 0.35)
        : Colors.white.withValues(alpha: 0.60);

    final deep = Color.lerp(fillColor, Colors.black, 0.28)!;
    final mid = fillColor;
    final light = Color.lerp(fillColor, Colors.white, 0.35)!;
    final surface = Color.lerp(fillColor, Colors.white, 0.55)!;

    return SizedBox(
      width: width,
      height: height + (compact ? 7 : 9),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            top: 0,
            child: Container(
              width: compact ? 38 : 52,
              height: compact ? 14 : 18,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                border: Border(
                  top: BorderSide(color: border, width: 2),
                  left: BorderSide(color: border, width: 2),
                  right: BorderSide(color: border, width: 2),
                ),
              ),
            ),
          ),
          Positioned(
            top: compact ? 7 : 9,
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(compact ? 20 : 26),
                  bottom: Radius.circular(compact ? 26 : 34),
                ),
                border: Border.all(color: border, width: 3),
                boxShadow: done
                    ? [
                        BoxShadow(
                          color: fillColor.withValues(alpha: 0.35),
                          blurRadius: 16,
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(compact ? 17 : 23),
                  bottom: Radius.circular(compact ? 23 : 31),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: pct / 100),
                        duration: reduce
                            ? Duration.zero
                            : const Duration(milliseconds: 900),
                        curve: const Cubic(0.22, 1, 0.36, 1),
                        builder: (context, t, child) {
                          return FractionallySizedBox(
                            heightFactor: t.clamp(0.0, 1.0),
                            widthFactor: 1,
                            alignment: Alignment.bottomCenter,
                            child: child,
                          );
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [deep, mid, light],
                                  stops: const [0, 0.55, 1],
                                ),
                              ),
                            ),
                            if (pct > 1 && pct < 100)
                              Positioned(
                                top: compact ? -7 : -9,
                                left: width * -0.05,
                                right: width * -0.05,
                                child: Container(
                                  height: compact ? 14 : 18,
                                  decoration: BoxDecoration(
                                    color: surface,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      bottom: 10,
                      left: 6,
                      child: Container(
                        width: 6,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        '$pct%',
                        style: TextStyle(
                          fontSize: compact ? 15 : 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          shadows: const [
                            Shadow(
                              color: Color(0xA6000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
