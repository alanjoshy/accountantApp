// Lent & borrowed — collect / repay tracker.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/currency/currency_controller.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../data/debt.dart';
import '../../data/debt_store.dart';
import '../../domain/debt_logic.dart';
import '../widgets/debt_form_sheet.dart';
import '../widgets/debt_pay_sheet.dart';

class DebtsScreen extends StatelessWidget {
  const DebtsScreen({super.key});

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
          'Lent & borrowed',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Add entry',
            onPressed: () {
              HapticFeedback.mediumImpact();
              showDebtFormSheet(context);
            },
            icon: Icon(Icons.add_circle_outline_rounded, color: colors.accent),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          DebtStore.instance,
          CurrencyController.instance,
        ]),
        builder: (context, _) {
          final store = DebtStore.instance;
          final format = CurrencyController.instance.format;
          final openLend = store.openLend;
          final openBorrow = store.openBorrow;
          final settled = store.settled;
          final totalCollect = openLend.fold<double>(
            0,
            (s, d) => s + debtRemaining(d),
          );
          final totalRepay = openBorrow.fold<double>(
            0,
            (s, d) => s + debtRemaining(d),
          );
          final personNets = personNetBalances(store.open);
          final dualNets = [
            for (final p in personNets)
              if (p.lendRemaining > 0 && p.borrowRemaining > 0) p,
          ];
          final netByPerson = {
            for (final p in personNets) normalizePersonKey(p.name): p,
          };

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
                        'Collect what you lent, repay what you borrowed',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _SummaryCard(
                              colors: colors,
                              label: 'To collect',
                              value: format(totalCollect),
                              meta: '${openLend.length} open',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _SummaryCard(
                              colors: colors,
                              label: 'To repay',
                              value: format(totalRepay),
                              meta: '${openBorrow.length} open',
                            ),
                          ),
                        ],
                      ),
                      if (dualNets.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Text(
                          'Net by person',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final p in dualNets) ...[
                          _NetCard(person: p, colors: colors, format: format),
                          const SizedBox(height: 8),
                        ],
                      ],
                      const SizedBox(height: 12),
                      Text(
                        'Home reminders start 5 days before each due date. '
                        'Record part payments anytime — the rest stays open.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: colors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _SectionHeader(
                        title: 'To collect',
                        action: '+ Lent',
                        colors: colors,
                        onAction: () =>
                            showDebtFormSheet(context, initialKind: DebtKind.lend),
                      ),
                      const SizedBox(height: 8),
                      if (openLend.isEmpty)
                        _EmptyCard(
                          colors: colors,
                          body:
                              'Nothing to collect. Add money you lent to a friend.',
                        )
                      else
                        for (final d in openLend) ...[
                          _DebtCard(
                            debt: d,
                            colors: colors,
                            format: format,
                            personNet: netByPerson[normalizePersonKey(d.personName)],
                            onPay: () => showDebtPaySheet(context, d),
                            onDelete: () => _confirmDelete(context, d),
                          ),
                          const SizedBox(height: 10),
                        ],
                      const SizedBox(height: 10),
                      _SectionHeader(
                        title: 'To repay',
                        action: '+ Borrowed',
                        colors: colors,
                        onAction: () => showDebtFormSheet(
                          context,
                          initialKind: DebtKind.borrow,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (openBorrow.isEmpty)
                        _EmptyCard(
                          colors: colors,
                          body:
                              'Nothing to repay. Add money you borrowed from someone.',
                        )
                      else
                        for (final d in openBorrow) ...[
                          _DebtCard(
                            debt: d,
                            colors: colors,
                            format: format,
                            personNet: netByPerson[normalizePersonKey(d.personName)],
                            onPay: () => showDebtPaySheet(context, d),
                            onDelete: () => _confirmDelete(context, d),
                          ),
                          const SizedBox(height: 10),
                        ],
                      if (settled.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Settled',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final d in settled) ...[
                          _SettledCard(
                            debt: d,
                            colors: colors,
                            format: format,
                            onDelete: () => _confirmDelete(context, d),
                          ),
                          const SizedBox(height: 8),
                        ],
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

  Future<void> _confirmDelete(BuildContext context, Debt debt) async {
    final format = CurrencyController.instance.format;
    final isBorrow = debtKind(debt) == DebtKind.borrow;
    final remaining = debtRemaining(debt);
    final ok = await AppToast.confirm(
      context,
      title: 'Delete this entry?',
      message: isBorrow
          ? 'Remove ${format(remaining)} you owe ${debt.personName}?'
          : 'Remove ${format(remaining)} owed by ${debt.personName}?',
    );
    if (ok != true || !context.mounted) return;
    await DebtStore.instance.deleteDebt(debt.id);
    if (!context.mounted) return;
    AppToast.warning(context, 'Removed.');
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.colors,
    required this.label,
    required this.value,
    required this.meta,
  });

  final AppPalette colors;
  final String label;
  final String value;
  final String meta;

  @override
  Widget build(BuildContext context) {
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
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              meta,
              style: TextStyle(fontSize: 11, color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _NetCard extends StatelessWidget {
  const _NetCard({
    required this.person,
    required this.colors,
    required this.format,
  });

  final PersonNet person;
  final AppPalette colors;
  final String Function(double) format;

  @override
  Widget build(BuildContext context) {
    final netLabel = person.net > 0
        ? 'They owe you ${format(person.net)}'
        : person.net < 0
            ? 'You owe ${format(person.net.abs())}'
            : 'Settled between you';
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
            Text(
              person.name,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Lent ${format(person.lendRemaining)} · borrowed ${format(person.borrowRemaining)}',
              style: TextStyle(fontSize: 12, color: colors.textMuted),
            ),
            const SizedBox(height: 4),
            Text(
              netLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: colors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.action,
    required this.colors,
    required this.onAction,
  });

  final String title;
  final String action;
  final AppPalette colors;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            HapticFeedback.selectionClick();
            onAction();
          },
          child: Text(
            action,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colors.accent,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.colors, required this.body});

  final AppPalette colors;
  final String body;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          body,
          style: TextStyle(fontSize: 13, color: colors.textMuted),
        ),
      ),
    );
  }
}

class _DebtCard extends StatelessWidget {
  const _DebtCard({
    required this.debt,
    required this.colors,
    required this.format,
    required this.onPay,
    required this.onDelete,
    this.personNet,
  });

  final Debt debt;
  final AppPalette colors;
  final String Function(double) format;
  final VoidCallback onPay;
  final VoidCallback onDelete;
  final PersonNet? personNet;

  @override
  Widget build(BuildContext context) {
    final isBorrow = debtKind(debt) == DebtKind.borrow;
    final paid = debtPaid(debt);
    final remaining = debtRemaining(debt);
    final hint = dueHint(debt.dueDate);
    final showNet = personNet != null &&
        personNet!.lendRemaining > 0 &&
        personNet!.borrowRemaining > 0;
    final accent = isBorrow ? const Color(0xFFEAB308) : colors.accent;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accent.withValues(alpha: 0.25)),
                  ),
                  child: Icon(
                    isBorrow
                        ? Icons.north_east_rounded
                        : Icons.south_west_rounded,
                    size: 18,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        debt.personName,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: format(remaining),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: colors.textPrimary,
                              ),
                            ),
                            TextSpan(
                              text: ' left',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: colors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (showNet) ...[
                        const SizedBox(height: 2),
                        Text(
                          personNet!.net > 0
                              ? 'Net · they owe you ${format(personNet!.net)}'
                              : personNet!.net < 0
                                  ? 'Net · you owe ${format(personNet!.net.abs())}'
                                  : 'Net · settled between you',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.accent,
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        paid > 0
                            ? '${format(paid)} of ${format(debt.amount)} ${isBorrow ? 'repaid' : 'collected'}'
                            : 'of ${format(debt.amount)} total',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${isBorrow ? 'Borrowed' : 'Lent'} ${formatDebtDay(debt.lentDate)}',
                        style: TextStyle(fontSize: 12, color: colors.textMuted),
                      ),
                      Text(
                        '${isBorrow ? 'Repay by' : 'Collect by'} · ${hint.text}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: hint.urgent
                              ? const Color(0xFFEAB308)
                              : colors.textSecondary,
                        ),
                      ),
                      if (debt.note != null && debt.note!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          debt.note!,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      onPay();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: Text(
                      isBorrow ? 'Record repayment' : 'Record collection',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline_rounded, color: colors.error),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SettledCard extends StatelessWidget {
  const _SettledCard({
    required this.debt,
    required this.colors,
    required this.format,
    required this.onDelete,
  });

  final Debt debt;
  final AppPalette colors;
  final String Function(double) format;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isBorrow = debtKind(debt) == DebtKind.borrow;
    return Opacity(
      opacity: 0.85,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      debt.personName,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      '${format(debt.amount)} · ${isBorrow ? 'repaid' : 'collected'}',
                      style: TextStyle(fontSize: 12, color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: colors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
