// Things to remember — tip cards (web RememberSection).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/currency/currency_controller.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../accounts/data/account_store.dart';
import '../../../auth/data/app_lock_store.dart';
import '../../../auth/domain/sensitive_access_session.dart';
import '../../../budgets/data/budget_store.dart';
import '../../../debts/data/debt_store.dart';
import '../../../reminders/domain/reminder_engine.dart';
import '../../../reminders/domain/reminder_item.dart';
import '../../../reminders/presentation/widgets/notifications_sheet.dart';
import '../../../planned/data/planned_reserve_store.dart';
import '../../../scheduled/data/scheduled_payment_store.dart';
import '../../../settings/data/app_settings_store.dart';
import '../../../transactions/data/transaction_store.dart';
import '../data/static_remember_tips.dart';

class RememberSection extends StatefulWidget {
  const RememberSection({super.key, this.tips});

  /// When null, tips are built from live transactions / budgets / debts.
  final List<StaticRememberTip>? tips;

  @override
  State<RememberSection> createState() => _RememberSectionState();
}

class _RememberSectionState extends State<RememberSection> {
  static const _visibleCap = 4;
  final _dismissed = <String>{};

  List<StaticRememberTip> _resolveTips(BuildContext context) {
    if (widget.tips != null) return widget.tips!;

    final settings = AppSettingsStore.instance;
    final lock = AppLockStore.instance;
    final items = ReminderEngine.evaluateActive(
      settings: settings.settings,
      transactions: TransactionStore.instance.transactions,
      budgets: BudgetStore.instance.budgets,
      debts: DebtStore.instance.open,
      scheduledPayments: ScheduledPaymentStore.instance.all,
      accounts: AccountStore.instance.accounts,
      plannedReserves: PlannedReserveStore.instance.active,
      formatMoney: CurrencyController.instance.format,
      hasPin: lock.hasPin,
      protectAccountBalances: lock.protectAccountBalances,
      revealBalances: SensitiveAccessSession.instance.isRevealed,
    );

    return [
      for (final item in items.take(6))
        item.toTip(
          onOpen: item.deepLink == ReminderDeepLink.none
              ? null
              : () async {
                  HapticFeedback.selectionClick();
                  await openReminderDeepLink(context, item.deepLink);
                },
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        TransactionStore.instance,
        ScheduledPaymentStore.instance,
        PlannedReserveStore.instance,
        AccountStore.instance,
        BudgetStore.instance,
        DebtStore.instance,
        AppSettingsStore.instance,
        AppLockStore.instance,
        SensitiveAccessSession.instance,
        CurrencyController.instance,
      ]),
      builder: (context, _) {
        final colors = AppColors.of(context);
        final tips = _resolveTips(context);
        final visible = tips
            .where((t) => !_dismissed.contains(t.id))
            .take(_visibleCap)
            .toList();
        if (visible.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Things to remember',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < visible.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _TipCard(
                key: ValueKey(visible[i].id),
                tip: visible[i],
                colors: colors,
                onDismiss: () {
                  setState(() => _dismissed.add(visible[i].id));
                },
              ),
            ],
          ],
        );
      },
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({
    super.key,
    required this.tip,
    required this.colors,
    required this.onDismiss,
  });

  final StaticRememberTip tip;
  final AppPalette colors;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final (bg, border, iconColor) = switch (tip.tone) {
      RememberTone.info => (
          colors.accentMuted,
          colors.border,
          colors.accent,
        ),
      RememberTone.warning => (
          colors.error.withValues(alpha: 0.08),
          colors.error.withValues(alpha: 0.25),
          colors.error,
        ),
      RememberTone.success => (
          colors.success.withValues(alpha: 0.1),
          colors.success.withValues(alpha: 0.25),
          colors.success,
        ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              tip.tone == RememberTone.warning
                  ? Icons.warning_amber_rounded
                  : tip.tone == RememberTone.success
                      ? Icons.check_circle_outline_rounded
                      : Icons.lightbulb_outline_rounded,
              size: 20,
              color: iconColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tip.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tip.body,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: colors.textSecondary,
                    ),
                  ),
                  if (tip.hrefLabel != null && tip.onOpen != null) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: tip.onOpen,
                      child: Text(
                        tip.hrefLabel!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colors.accent,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onDismiss,
              icon: Icon(
                Icons.close_rounded,
                size: 18,
                color: colors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
