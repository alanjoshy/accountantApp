// Home tab body.

import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../accounts/data/account_store.dart';
import '../../../accounts/domain/account_balances.dart';
import '../../../activity/domain/cycle.dart';
import '../../../budgets/data/budget_store.dart';
import '../../../budgets/domain/budget_logic.dart';
import '../../../settings/data/app_settings_store.dart';
import '../../../transactions/data/transaction_store.dart';
import '../../domain/home_logic.dart';
import '../widgets/balance_card.dart';
import '../widgets/budget_balance_card.dart';
import '../widgets/home_stats_row.dart';
import '../widgets/month_pulse_card.dart';
import '../widgets/remember_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Stable merge — recreating [Listenable.merge] each build can drop listeners.
  late final Listenable _homeListenable = Listenable.merge([
    TransactionStore.instance,
    AccountStore.instance,
    BudgetStore.instance,
    AppSettingsStore.instance,
  ]);

  @override
  Widget build(BuildContext context) {
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
            // Web order: balance → stats → Things to remember → Month pulse → Budget balance
            child: ListenableBuilder(
              listenable: _homeListenable,
              builder: (context, _) {
                final txs = TransactionStore.instance.transactions;
                final budgets = BudgetStore.instance.budgets;
                final accounts = AccountStore.instance.accounts;
                final cycleDay = AppSettingsStore.instance.cycleStartDay;
                final incomeSetting =
                    AppSettingsStore.instance.monthlyIncome;
                final totals = homeCardTotals(
                  transactions: txs,
                  cycleStartDay: cycleDay,
                );
                // Web: hero is always the sum of account balances when any exist.
                final heroBalance = accounts.isNotEmpty
                    ? totalAccountBalance(accounts)
                    : totals.balance;
                final streak = computePaymentStreak(txs);
                final cycleBounds = getCurrentCycleDayBounds(cycleDay);
                final capacity = batteryCapacity(
                  monthlyIncome: incomeSetting,
                  loggedIncome: totals.income,
                  budgets: listedBudgetsForWindow(
                    budgets,
                    cycleBounds,
                    includeUndated: true,
                  ),
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BalanceCard(
                      balance: heroBalance,
                      income: totals.income,
                      expense: totals.expense,
                      paymentStreak: streak,
                      batteryCapacity: capacity > 0 ? capacity : null,
                      cycleRangeLabel: formatBoundsLabel(cycleBounds),
                    ),
                    const SizedBox(height: 12),
                    HomeStatsRow(
                      transactions: TransactionStore.instance.count,
                      incomeEntries:
                          TransactionStore.instance.incomeEntryCount,
                    ),
                    const SizedBox(height: 12),
                    const RememberSection(),
                    const SizedBox(height: 12),
                    MonthPulseCard(paymentStreak: streak),
                    const SizedBox(height: 12),
                    const BudgetBalanceCard(),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
