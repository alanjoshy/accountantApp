// Selectable category chip with icon / allocated-month remaining.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/currency/currency_controller.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../budgets/data/budget.dart';
import '../../../budgets/data/category_style.dart';
import '../../../budgets/domain/budget_logic.dart';

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
    this.usage,
    this.icon,
    this.accentColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final CategoryCycleUsage? usage;
  final IconData? icon;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final usage = this.usage;
    final over = usage?.over ?? false;
    final tint = accentColor ?? colors.accent;
    final iconData = icon ?? Icons.category_rounded;
    final remainingLabel = usage == null
        ? null
        : over
            ? 'Over'
            : '${CurrencyController.instance.compact(usage.remaining)} left';

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
          width: 112,
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
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
                children: [
                  Icon(
                    iconData,
                    size: 16,
                    color: selected ? Colors.white : tint,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              if (usage != null) ...[
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: usage.limit > 0
                        ? usage.ratio.clamp(0.04, 1)
                        : 0,
                    minHeight: 4,
                    backgroundColor: selected
                        ? Colors.white.withValues(alpha: 0.28)
                        : colors.border,
                    color: selected
                        ? Colors.white
                        : over
                            ? colors.error
                            : tint,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  remainingLabel!,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? Colors.white.withValues(alpha: 0.85)
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
