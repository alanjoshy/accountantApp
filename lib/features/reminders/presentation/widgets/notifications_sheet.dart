// Bell inbox sheet.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/navigation/app_page_route.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../../accounts/presentation/screens/accounts_screen.dart';
import '../../../budgets/presentation/screens/budgets_screen.dart';
import '../../../debts/presentation/screens/debts_screen.dart';
import '../../../more/presentation/screens/settings_screen.dart';
import '../../../planned/presentation/screens/planned_reserves_screen.dart';
import '../../../scheduled/presentation/screens/scheduled_payments_screen.dart';
import '../../../transactions/presentation/widgets/add_transaction_sheet.dart';
import '../../data/notification_inbox_store.dart';
import '../../domain/reminder_item.dart';
import '../../../home/presentation/data/static_remember_tips.dart';

Future<void> showNotificationsSheet(BuildContext context) {
  return showAppSheet<void>(
    context: context,
    builder: (ctx) => const _NotificationsSheetBody(),
  );
}

Future<void> openReminderDeepLink(
  BuildContext context,
  ReminderDeepLink link,
) async {
  switch (link) {
    case ReminderDeepLink.budgets:
      await appPush(context, const BudgetsScreen());
    case ReminderDeepLink.debts:
      await appPush(context, const DebtsScreen());
    case ReminderDeepLink.scheduled:
      await appPush(context, const ScheduledPaymentsScreen());
    case ReminderDeepLink.plannedReserves:
      await appPush(context, const PlannedReservesScreen());
    case ReminderDeepLink.accounts:
      await appPush(context, const AccountsScreen());
    case ReminderDeepLink.settings:
      await appPush(context, const SettingsScreen());
    case ReminderDeepLink.addTransaction:
      await showAddTransactionSheet(context);
    case ReminderDeepLink.none:
      break;
  }
}

class _NotificationsSheetBody extends StatelessWidget {
  const _NotificationsSheetBody();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return ListenableBuilder(
      listenable: NotificationInboxStore.instance,
      builder: (context, _) {
        final items = NotificationInboxStore.instance.items;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.lg + bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  if (items.any((e) => !e.read))
                    TextButton(
                      onPressed: () async {
                        HapticFeedback.selectionClick();
                        await NotificationInboxStore.instance.markAllRead();
                      },
                      child: const Text('Mark all read'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No reminders right now. You’re all caught up.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: colors.textMuted),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.55,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: colors.border),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          item.tone == RememberTone.warning
                              ? Icons.warning_amber_rounded
                              : item.tone == RememberTone.success
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.notifications_none_rounded,
                          color: item.tone == RememberTone.warning
                              ? colors.error
                              : colors.accent,
                        ),
                        title: Text(
                          item.title,
                          style: TextStyle(
                            fontWeight:
                                item.read ? FontWeight.w500 : FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          item.body,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textMuted,
                          ),
                        ),
                        onTap: () async {
                          HapticFeedback.selectionClick();
                          await NotificationInboxStore.instance
                              .markRead(item.id);
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                          await openReminderDeepLink(context, item.deepLink);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
