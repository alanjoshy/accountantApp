// Payment streak badge (web StreakFireBadge).

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

class StreakFireBadge extends StatelessWidget {
  const StreakFireBadge({super.key, this.streak = 0});

  final int streak;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final active = streak > 0;
    const orange = Color(0xFFF97316);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active ? orange.withValues(alpha: 0.15) : colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? orange.withValues(alpha: 0.25) : colors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            size: 13,
            color: active ? orange : colors.textMuted,
          ),
          const SizedBox(width: 4),
          Text(
            active ? '${streak}d streak' : '0d',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: active ? orange : colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
