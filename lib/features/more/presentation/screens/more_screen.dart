// More tab hub.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/currency/currency_controller.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/app_info.dart';
import '../../../../core/navigation/app_page_route.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../accounts/data/account_store.dart';
import '../../../accounts/presentation/screens/accounts_screen.dart';
import '../../../backup/presentation/screens/backup_screen.dart';
import '../../../debts/data/debt_store.dart';
import '../../../debts/domain/debt_logic.dart';
import '../../../debts/presentation/screens/debts_screen.dart';
import '../../../jars/presentation/screens/jar_screen.dart';
import '../../../planned/data/planned_reserve_store.dart';
import '../../../planned/presentation/screens/planned_reserves_screen.dart';
import '../../../scheduled/data/scheduled_payment_store.dart';
import '../../../scheduled/presentation/screens/scheduled_payments_screen.dart';
import 'settings_screen.dart';
import 'tags_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    final bottom = MediaQuery.paddingOf(context).bottom;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.lg + bottom,
      ),
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Money tools, tags, and app settings',
                  style: TextStyle(fontSize: 14, color: colors.textMuted),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'MONEY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    color: colors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                _MoreRow(
                  icon: Icons.archive_rounded,
                  title: 'Jar',
                  subtitle: 'Savings goals and auto-transfers',
                  colors: colors,
                  tint: colors.success,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    appPush(context, const JarScreen());
                  },
                ),
                const SizedBox(height: 10),
                ListenableBuilder(
                  listenable: Listenable.merge([
                    AccountStore.instance,
                    CurrencyController.instance,
                  ]),
                  builder: (context, _) {
                    final n = AccountStore.instance.accounts.length;
                    final subtitle = n > 0
                        ? '$n account${n == 1 ? '' : 's'} · ${CurrencyController.instance.format(AccountStore.instance.totalBalance)}'
                        : 'Banks, cash, balances, and transfers';
                    return _MoreRow(
                      icon: Icons.account_balance_rounded,
                      title: 'Accounts & payments',
                      subtitle: subtitle,
                      colors: colors,
                      tint: colors.accent,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        appPush(context, const AccountsScreen());
                      },
                    );
                  },
                ),
                const SizedBox(height: 10),
                ListenableBuilder(
                  listenable: Listenable.merge([
                    DebtStore.instance,
                    CurrencyController.instance,
                  ]),
                  builder: (context, _) {
                    final open = DebtStore.instance.open;
                    final total = open.fold<double>(
                      0,
                      (s, d) => s + debtRemaining(d),
                    );
                    final subtitle = open.isEmpty
                        ? 'Track money lent and borrowed'
                        : '${open.length} open · ${CurrencyController.instance.format(total)}';
                    return _MoreRow(
                      icon: Icons.handshake_outlined,
                      title: 'Lent & borrowed',
                      subtitle: subtitle,
                      colors: colors,
                      tint: const Color(0xFFD97706),
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        appPush(context, const DebtsScreen());
                      },
                    );
                  },
                ),
                const SizedBox(height: 10),
                ListenableBuilder(
                  listenable: ScheduledPaymentStore.instance,
                  builder: (context, _) {
                    final n = ScheduledPaymentStore.instance.pending.length;
                    final subtitle = n > 0
                        ? '$n upcoming'
                        : 'Investments, EMI, and bills by date';
                    return _MoreRow(
                      icon: Icons.event_repeat_rounded,
                      title: 'Scheduled payments',
                      subtitle: subtitle,
                      colors: colors,
                      tint: const Color(0xFF7C3AED),
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        appPush(context, const ScheduledPaymentsScreen());
                      },
                    );
                  },
                ),
                const SizedBox(height: 10),
                ListenableBuilder(
                  listenable: PlannedReserveStore.instance,
                  builder: (context, _) {
                    final n = PlannedReserveStore.instance.active.length;
                    final subtitle = n > 0
                        ? '$n planned'
                        : 'Reserve budget for future costs';
                    return _MoreRow(
                      icon: Icons.savings_outlined,
                      title: 'Planned reserves',
                      subtitle: subtitle,
                      colors: colors,
                      tint: const Color(0xFF0D9488),
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        appPush(context, const PlannedReservesScreen());
                      },
                    );
                  },
                ),
                const SizedBox(height: 10),
                _MoreRow(
                  icon: Icons.sell_outlined,
                  title: 'Tags',
                  subtitle: 'Labels for Activity and transactions',
                  colors: colors,
                  tint: const Color(0xFF64748B),
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    appPush(context, const TagsScreen());
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'APP',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    color: colors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                _MoreRow(
                  icon: Icons.settings_rounded,
                  title: 'Settings',
                  subtitle: 'Theme, currency, pay cycle, and add defaults',
                  colors: colors,
                  tint: colors.accent,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    appPush(context, const SettingsScreen());
                  },
                ),
                const SizedBox(height: 10),
                _MoreRow(
                  icon: Icons.cloud_upload_outlined,
                  title: 'Backup & restore',
                  subtitle: 'Export or upload Accountant JSON (web compatible)',
                  colors: colors,
                  tint: const Color(0xFF0284C7),
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    appPush(context, const BackupScreen());
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'DEVELOPER',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    color: colors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                const _DeveloperCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DeveloperCard extends StatelessWidget {
  const _DeveloperCard();

  Future<void> _open(BuildContext context, String url) async {
    HapticFeedback.lightImpact();
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      AppToast.show(
        context,
        "Couldn't open link.",
        tone: AppToastTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

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
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.accentMuted,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.accent.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    size: 18,
                    color: colors.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppInfo.authorName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Made by · ${AppInfo.name}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _LinkChip(
                    icon: Icons.work_outline_rounded,
                    label: 'LinkedIn',
                    colors: colors,
                    onTap: () => _open(context, AppInfo.linkedInUrl),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _LinkChip(
                    icon: Icons.language_rounded,
                    label: 'Website',
                    colors: colors,
                    onTap: () => _open(context, AppInfo.websiteUrl),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkChip extends StatelessWidget {
  const _LinkChip({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final AppPalette colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.surfaceHover,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: colors.accent),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.accent,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.open_in_new_rounded,
                size: 12,
                color: colors.accent.withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreRow extends StatelessWidget {
  const _MoreRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.onTap,
    this.tint,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final AppPalette colors;
  final VoidCallback onTap;
  /// Behavior tint for the leading icon chip (defaults to accent).
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final chip = tint ?? colors.accent;
    return Material(
      color: colors.surfaceElevated,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: chip.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: chip.withValues(alpha: 0.22),
                  ),
                ),
                child: Icon(icon, size: 18, color: chip),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
