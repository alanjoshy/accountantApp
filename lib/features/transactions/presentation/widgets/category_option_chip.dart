// Selectable category chip with icon / optional budget usage.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../budgets/data/budget.dart';
import '../../../budgets/data/category_style.dart';

/// Resolves icon + tint from a matching budget, else category defaults.
({IconData icon, Color color}) resolveCategoryStyle(
  String category, {
  Iterable<Budget> budgets = const [],
}) {
  final key = category.trim().toLowerCase();
  for (final b in budgets) {
    if (b.category.trim().toLowerCase() == key) {
      return (
        icon: categoryIconData(b.icon),
        color: categoryColorFromHex(b.color),
      );
    }
  }
  return (
    icon: categoryIconData(defaultIconForCategory(category)),
    color: categoryColorFromHex(defaultColorForCategory(category)),
  );
}

class CategoryOptionChip extends StatelessWidget {
  const CategoryOptionChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.usagePct,
    this.icon,
    this.accentColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double? usagePct;
  final IconData? icon;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final over = usagePct != null && usagePct! > 100;
    final tint = accentColor ?? colors.accent;
    final iconData = icon ?? Icons.category_rounded;

    return Material(
      color: selected ? colors.accent : colors.surfaceHover,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? colors.accent : colors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    iconData,
                    size: 16,
                    color: selected ? Colors.white : tint,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : colors.textPrimary,
                    ),
                  ),
                ],
              ),
              if (usagePct != null) ...[
                const SizedBox(height: 2),
                Text(
                  '${usagePct!.round()}% used',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? Colors.white.withValues(alpha: 0.8)
                        : over
                            ? colors.error
                            : colors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
