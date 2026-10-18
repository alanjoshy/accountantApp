// Day-grouped activity list (web DayGroupedTransactions activity variant).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/currency/currency_controller.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../accounts/data/account_store.dart';
import '../../../accounts/domain/payments.dart';
import '../../../transactions/data/transaction.dart';
import '../../../transactions/presentation/widgets/transaction_detail_sheet.dart';
import '../../domain/activity_logic.dart';

class DayGroupedTransactions extends StatelessWidget {
  const DayGroupedTransactions({
    super.key,
    required this.transactions,
    this.emptyMessage = 'No transactions yet.',
    this.selectionMode = false,
    this.selectedIds = const {},
    this.onToggleSelect,
    this.onEnterSelection,
  });

  final List<MoneyTransaction> transactions;
  final String emptyMessage;
  final bool selectionMode;
  final Set<String> selectedIds;
  final ValueChanged<String>? onToggleSelect;
  final ValueChanged<String>? onEnterSelection;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final groups = groupTransactionsByDay(transactions);
    if (groups.isEmpty) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            emptyMessage,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: colors.textMuted),
          ),
        ),
      );
    }

    return ListenableBuilder(
      listenable: CurrencyController.instance,
      builder: (context, _) {
        final format = CurrencyController.instance.format;
        return Column(
          children: [
            for (final group in groups) ...[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceHover.withValues(alpha: 0.8),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(15),
                        ),
                        border: Border(
                          bottom: BorderSide(color: colors.border),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              group.heading,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                          if (group.credit > 0)
                            Text(
                              'Income ${format(group.credit)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: colors.success,
                              ),
                            ),
                          if (group.credit > 0 && group.debit > 0)
                            const SizedBox(width: 8),
                          if (group.debit > 0)
                            Text(
                              'Spent ${format(group.debit)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: colors.error,
                              ),
                            ),
                        ],
                      ),
                    ),
                    for (var i = 0; i < group.items.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: colors.border),
                      _TxRow(
                        key: ValueKey(group.items[i].id),
                        tx: group.items[i],
                        colors: colors,
                        format: format,
                        selectionMode: selectionMode,
                        selected: selectedIds.contains(group.items[i].id),
                        onToggle: onToggleSelect,
                        onEnterSelection: onEnterSelection,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class _TxRow extends StatelessWidget {
  const _TxRow({
    super.key,
    required this.tx,
    required this.colors,
    required this.format,
    required this.selectionMode,
    required this.selected,
    this.onToggle,
    this.onEnterSelection,
  });

  final MoneyTransaction tx;
  final AppPalette colors;
  final String Function(double) format;
  final bool selectionMode;
  final bool selected;
  final ValueChanged<String>? onToggle;
  final ValueChanged<String>? onEnterSelection;

  @override
  Widget build(BuildContext context) {
    final isIncome = tx.type == TransactionType.income;
    return Material(
      color: selected ? colors.accentMuted : Colors.transparent,
      child: InkWell(
        onTap: () {
          if (selectionMode) {
            onToggle?.call(tx.id);
            return;
          }
          showTransactionDetailSheet(context, tx);
        },
        onLongPress: () {
          HapticFeedback.mediumImpact();
          onEnterSelection?.call(tx.id);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              if (selectionMode) ...[
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  size: 20,
                  color: selected ? colors.accent : colors.textMuted,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        tx.category,
                        if (tx.paymentMode != null)
                          paymentModeLabel(tx.paymentMode),
                        if (tx.accountId != null)
                          AccountStore.instance.byId(tx.accountId)?.name,
                        if (tx.tags.isNotEmpty)
                          tx.tags
                              .map((t) => t.startsWith('#') ? t : '#$t')
                              .join(' '),
                      ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              Text(
                '${isIncome ? '+' : '-'}${format(tx.amount)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isIncome ? colors.success : colors.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
