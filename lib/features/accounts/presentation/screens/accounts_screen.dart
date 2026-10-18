// Accounts & payments (web /more/accounts).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/currency/currency_controller.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../auth/data/app_lock_store.dart';
import '../../../auth/domain/sensitive_access_session.dart';
import '../../../auth/presentation/widgets/unlock_sheet.dart';
import '../../../settings/data/app_settings_store.dart';
import '../../../transactions/data/transaction.dart';
import '../../../transactions/data/transaction_store.dart';
import '../../data/account.dart';
import '../../data/account_store.dart';
import '../../domain/account_style.dart';
import '../../domain/payments.dart';
import '../widgets/account_form_sheet.dart';
import '../widgets/tally_sheet.dart';
import '../widgets/transfer_sheet.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  Future<void> _toggleReveal(BuildContext context, bool revealed) async {
    HapticFeedback.selectionClick();
    if (revealed) {
      SensitiveAccessSession.instance.lock();
      return;
    }
    await ensureSensitiveAccess(context);
  }

  Future<bool> _requireReveal(BuildContext context) async {
    if (SensitiveAccessSession.instance.isRevealed) return true;
    return ensureSensitiveAccess(
      context,
      title: 'Unlock balances',
      subtitle: 'Confirm it’s you before changing account money.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Accounts & payments'),
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Transfer',
            onPressed: () async {
              HapticFeedback.selectionClick();
              if (AccountStore.instance.accounts.length < 2) {
                AppToast.warning(context, 'Add at least two accounts to transfer.');
                return;
              }
              if (!await _requireReveal(context)) return;
              if (!context.mounted) return;
              showTransferSheet(context);
            },
            icon: const Icon(Icons.swap_horiz_rounded),
          ),
          IconButton(
            tooltip: 'Add account',
            onPressed: () {
              HapticFeedback.mediumImpact();
              showAccountFormSheet(context);
            },
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          AccountStore.instance,
          AppSettingsStore.instance,
          TransactionStore.instance,
          CurrencyController.instance,
          AppLockStore.instance,
          SensitiveAccessSession.instance,
        ]),
        builder: (context, _) {
          final accounts = AccountStore.instance.accounts;
          final defaultId = AppSettingsStore.instance.defaultAccountId;
          final format = CurrencyController.instance.format;
          final total = AccountStore.instance.totalBalance;
          final stats = _paymentModeStats(TransactionStore.instance.transactions);
          final revealed = SensitiveAccessSession.instance.isRevealed;
          final protect = AppLockStore.instance.protectAccountBalances &&
              AppLockStore.instance.hasPin;
          String money(double v) => revealed ? format(v) : '•••••';

          return ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.lg + bottom,
            ),
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Total balance',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: colors.textMuted,
                              ),
                            ),
                          ),
                          if (protect)
                            IconButton(
                              tooltip: revealed ? 'Hide balances' : 'Show balances',
                              onPressed: () => _toggleReveal(context, revealed),
                              icon: Icon(
                                revealed
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        money(total),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${accounts.length} account${accounts.length == 1 ? '' : 's'}',
                        style: TextStyle(fontSize: 12, color: colors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'ACCOUNTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              if (accounts.isEmpty)
                Text(
                  'No accounts yet. Tap + to add a bank or cash account.',
                  style: TextStyle(fontSize: 13, color: colors.textMuted),
                )
              else
                for (final account in accounts) ...[
                  _AccountCard(
                    account: account,
                    isDefault: account.id == defaultId,
                    balanceLabel: money(account.balance),
                    colors: colors,
                    onSetDefault: () async {
                      HapticFeedback.selectionClick();
                      await AppSettingsStore.instance
                          .setDefaultAccountId(account.id);
                      if (context.mounted) {
                        AppToast.success(
                          context,
                          '${account.name} is your default debit account.',
                        );
                      }
                    },
                    onEdit: () async {
                      if (!await _requireReveal(context)) return;
                      if (!context.mounted) return;
                      showAccountFormSheet(context, account: account);
                    },
                    onTally: () async {
                      if (!await _requireReveal(context)) return;
                      if (!context.mounted) return;
                      showTallySheet(context, account);
                    },
                    onDelete: () async {
                      final ok = await AppToast.confirm(
                        context,
                        title: 'Delete ${account.name}?',
                        message:
                            'Transactions keep their history; this account is removed.',
                      );
                      if (ok != true) return;
                      if (defaultId == account.id) {
                        await AppSettingsStore.instance
                            .setDefaultAccountId(null);
                      }
                      await AccountStore.instance.deleteAccount(account.id);
                      if (context.mounted) {
                        AppToast.warning(context, 'Account deleted.');
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              const SizedBox(height: 8),
              Text(
                'PAYMENT MODES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Fixed ways money moves. Set the default in Settings.',
                style: TextStyle(fontSize: 12, color: colors.textMuted),
              ),
              const SizedBox(height: 10),
              for (final mode in paymentModes) ...[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(mode.icon, size: 20, color: colors.accent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mode.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ),
                              ),
                              Text(
                                mode.hint,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Out ${money(stats.paid[mode.id] ?? 0)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: colors.error,
                              ),
                            ),
                            Text(
                              'In ${money(stats.received[mode.id] ?? 0)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: colors.success,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
  }
}

({Map<PaymentMode, double> paid, Map<PaymentMode, double> received})
    _paymentModeStats(List<MoneyTransaction> txs) {
  final paid = {for (final m in PaymentMode.values) m: 0.0};
  final received = {for (final m in PaymentMode.values) m: 0.0};
  for (final t in txs) {
    if (t.type == TransactionType.transfer) continue;
    final mode = normalizePaymentMode(t.paymentMode);
    if (t.type == TransactionType.expense) {
      paid[mode] = (paid[mode] ?? 0) + t.amount;
    } else if (t.type == TransactionType.income) {
      received[mode] = (received[mode] ?? 0) + t.amount;
    }
  }
  return (paid: paid, received: received);
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.isDefault,
    required this.balanceLabel,
    required this.colors,
    required this.onSetDefault,
    required this.onEdit,
    required this.onTally,
    required this.onDelete,
  });

  final MoneyAccount account;
  final bool isDefault;
  final String balanceLabel;
  final AppPalette colors;
  final VoidCallback onSetDefault;
  final VoidCallback onEdit;
  final VoidCallback onTally;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tint = accountColorFromHex(account.color);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    accountIconData(account.icon),
                    color: tint,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              account.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                          if (isDefault) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.accentMuted,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Default',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: colors.accent,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        accountKindLabel(account.kind),
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  balanceLabel,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (!isDefault)
                  TextButton(
                    onPressed: onSetDefault,
                    child: const Text('Set default'),
                  ),
                TextButton(onPressed: onTally, child: const Text('Tally')),
                TextButton(onPressed: onEdit, child: const Text('Edit')),
                TextButton(
                  onPressed: onDelete,
                  style: TextButton.styleFrom(foregroundColor: colors.error),
                  child: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
