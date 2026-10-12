// Home count tiles (web Transactions / Income entries).

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

class HomeStatsRow extends StatelessWidget {
  const HomeStatsRow({
    super.key,
    this.transactions = 0,
    this.incomeEntries = 0,
  });

  final int transactions;
  final int incomeEntries;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Transactions',
            value: transactions,
            colors: colors,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Income entries',
            value: incomeEntries,
            colors: colors,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.colors,
  });

  final String label;
  final int value;
  final AppPalette colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$value',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                height: 1.1,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
