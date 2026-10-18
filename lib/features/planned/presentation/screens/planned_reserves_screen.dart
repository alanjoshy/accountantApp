// Planned budget reserves — future costs to reserve in category limits.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/currency/currency_controller.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../activity/domain/cycle.dart';
import '../../../settings/data/app_settings_store.dart';
import '../../data/planned_reserve.dart';
import '../../data/planned_reserve_store.dart';
import '../../domain/planned_logic.dart';
import '../widgets/planned_form_sheet.dart';

class PlannedReservesScreen extends StatelessWidget {
  const PlannedReservesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Planned reserves',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Add planned reserve',
            onPressed: () {
              HapticFeedback.mediumImpact();
              showPlannedFormSheet(context);
            },
            icon: Icon(Icons.add_circle_outline_rounded, color: colors.accent),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          PlannedReserveStore.instance,
          AppSettingsStore.instance,
          CurrencyController.instance,
        ]),
        builder: (context, _) {
          final format = CurrencyController.instance.format;
          final cycleDay = AppSettingsStore.instance.cycleStartDay;
          final enabled = AppSettingsStore.instance.plannedReservesEnabled;
          final active = PlannedReserveStore.instance.active;
          final next = reservesForNextCycle(active, cycleDay);
          final later = [
            for (final r in active)
              if (!next.any((n) => n.id == r.id)) r,
          ];

          return ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.lg + bottom,
            ),
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Reserve category budget for future costs (insurance, school fees). '
                        'No payment is created — only next-cycle planning.',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textMuted,
                        ),
                      ),
                      if (!enabled) ...[
                        const SizedBox(height: 10),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.surfaceHover,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colors.border),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'Planned reserves are off in Settings. Items stay saved but won’t remind or allocate.',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'NEXT CYCLE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                          color: colors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatBoundsLabel(getNextCycleDayBounds(cycleDay)),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.accent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (next.isEmpty)
                        _EmptyCard(
                          colors: colors,
                          message:
                              'Nothing due next cycle. Tap + to plan an expense.',
                        )
                      else
                        for (final item in next) ...[
                          _ReserveCard(
                            item: item,
                            format: format,
                            colors: colors,
                          ),
                          const SizedBox(height: 10),
                        ],
                      const SizedBox(height: 18),
                      Text(
                        'LATER',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                          color: colors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (later.isEmpty)
                        _EmptyCard(
                          colors: colors,
                          message: 'No later reserves.',
                        )
                      else
                        for (final item in later) ...[
                          _ReserveCard(
                            item: item,
                            format: format,
                            colors: colors,
                          ),
                          const SizedBox(height: 10),
                        ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.colors, required this.message});

  final AppPalette colors;
  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          style: TextStyle(fontSize: 13, color: colors.textMuted),
        ),
      ),
    );
  }
}

class _ReserveCard extends StatelessWidget {
  const _ReserveCard({
    required this.item,
    required this.format,
    required this.colors,
  });

  final PlannedReserve item;
  final String Function(double) format;
  final AppPalette colors;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.surfaceElevated,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.selectionClick();
          showPlannedFormSheet(context, existing: item);
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.category} · ${item.dueDate}'
                      '${item.appliedCycleStart != null ? ' · reserved' : ''}',
                      style: TextStyle(fontSize: 12, color: colors.textMuted),
                    ),
                    if (item.note != null && item.note!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.note!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: colors.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                format(item.amount),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                onPressed: () async {
                  HapticFeedback.mediumImpact();
                  await PlannedReserveStore.instance.softDelete(item.id);
                  if (!context.mounted) return;
                  AppToast.success(context, 'Removed.');
                },
                icon: Icon(Icons.delete_outline_rounded,
                    color: colors.textMuted, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
