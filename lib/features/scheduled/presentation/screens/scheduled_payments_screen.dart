// Scheduled payments — upcoming + history (web /more/scheduled).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/currency/currency_controller.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../accounts/data/account_store.dart';
import '../../../accounts/domain/payments.dart';
import '../../../budgets/data/budget_store.dart';
import '../../../transactions/presentation/widgets/category_option_chip.dart';
import '../../data/scheduled_payment.dart';
import '../../data/scheduled_payment_store.dart';
import '../../domain/scheduled_logic.dart';
import '../widgets/scheduled_form_sheet.dart';

class ScheduledPaymentsScreen extends StatelessWidget {
  const ScheduledPaymentsScreen({super.key});

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
          'Scheduled payments',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Schedule payment',
            onPressed: () {
              HapticFeedback.mediumImpact();
              showScheduledFormSheet(context);
            },
            icon: Icon(Icons.add_circle_outline_rounded, color: colors.accent),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          ScheduledPaymentStore.instance,
          AccountStore.instance,
          BudgetStore.instance,
          CurrencyController.instance,
        ]),
        builder: (context, _) {
          final store = ScheduledPaymentStore.instance;
          final format = CurrencyController.instance.format;
          final upcoming = store.pending;
          final history = store.history;

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
                        'Investments, EMI, bills — deducted from account + budget',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'UPCOMING',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                          color: colors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (upcoming.isEmpty)
                        _EmptyCard(
                          colors: colors,
                          message: 'No upcoming payments. Tap + to schedule one.',
                        )
                      else
                        for (final item in upcoming) ...[
                          _PaymentCard(
                            item: item,
                            format: format,
                            colors: colors,
                            upcoming: true,
                          ),
                          const SizedBox(height: 10),
                        ],
                      const SizedBox(height: 18),
                      Text(
                        'HISTORY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                          color: colors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (history.isEmpty)
                        _EmptyCard(
                          colors: colors,
                          message:
                              'Paid, skipped, and cancelled payments show here.',
                        )
                      else
                        for (final item in history) ...[
                          _PaymentCard(
                            item: item,
                            format: format,
                            colors: colors,
                            upcoming: false,
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
        borderRadius: BorderRadius.circular(16),
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

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.item,
    required this.format,
    required this.colors,
    required this.upcoming,
  });

  final ScheduledPayment item;
  final String Function(double) format;
  final AppPalette colors;
  final bool upcoming;

  String get _statusLabel => switch (item.status) {
        ScheduleStatus.pending =>
          isDueOrOverdue(item.dueDate) ? 'Due' : 'Upcoming',
        ScheduleStatus.paid => 'Paid',
        ScheduleStatus.skipped => 'Skipped',
        ScheduleStatus.cancelled => 'Cancelled',
      };

  Color get _statusColor => switch (item.status) {
        ScheduleStatus.pending =>
          isDueOrOverdue(item.dueDate) ? colors.error : colors.accent,
        ScheduleStatus.paid => colors.success,
        ScheduleStatus.skipped => colors.textMuted,
        ScheduleStatus.cancelled => colors.textMuted,
      };

  Future<void> _pay(BuildContext context) async {
    try {
      final paid = await ScheduledPaymentStore.instance.payNow(item.id);
      if (!context.mounted) return;
      AppToast.show(
        context,
        'Paid ${paid.title} · ${format(paid.amount)} deducted.',
        tone: AppToastTone.success,
      );
    } catch (e) {
      if (!context.mounted) return;
      AppToast.show(
        context,
        e is StateError ? e.message : "Couldn't mark as paid.",
        tone: AppToastTone.error,
      );
    }
  }

  Future<void> _skip(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Skip this payment?'),
        content: Text('“${item.title}” will be skipped for this date.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Skip'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ScheduledPaymentStore.instance.skip(item.id);
      if (!context.mounted) return;
      AppToast.show(context, 'Payment skipped.', tone: AppToastTone.warning);
    } catch (e) {
      if (!context.mounted) return;
      AppToast.show(
        context,
        e is StateError ? e.message : "Couldn't skip.",
        tone: AppToastTone.error,
      );
    }
  }

  Future<void> _cancel(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel schedule?'),
        content: Text(
          '“${item.title}” will be cancelled and kept in history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Cancel schedule', style: TextStyle(color: colors.error)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ScheduledPaymentStore.instance.cancel(item.id);
      if (!context.mounted) return;
      AppToast.show(
        context,
        'Schedule cancelled.',
        tone: AppToastTone.info,
      );
    } catch (e) {
      if (!context.mounted) return;
      AppToast.show(
        context,
        e is StateError ? e.message : "Couldn't cancel.",
        tone: AppToastTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = AccountStore.instance.byId(item.accountId);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  format(item.amount),
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                ),
                Text(
                  '·',
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                ),
                CategoryNameChip(
                  category: item.category,
                  budgets: BudgetStore.instance.budgets,
                ),
                Text(
                  '· ${repeatLabel(item.repeat)}',
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${formatDueHeading(item.dueDate)}'
              '${account != null ? ' · ${account.name}' : ''}'
              ' · ${paymentModeLabel(item.paymentMode)}'
              '${item.tags.isNotEmpty ? ' · ${item.tags.map((t) => '#$t').join(' ')}' : ''}',
              style: TextStyle(fontSize: 12, color: colors.textMuted),
            ),
            if (upcoming) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        _pay(context);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('Pay now'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _skip(context);
                    },
                    child: const Text('Skip'),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Cancel schedule',
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _cancel(context);
                    },
                    icon: Icon(Icons.close_rounded, color: colors.textMuted),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
