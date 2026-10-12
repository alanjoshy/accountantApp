// Home tab body.

import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../transactions/data/transaction_store.dart';
import '../widgets/balance_card.dart';
import '../widgets/budget_balance_card.dart';
import '../widgets/home_stats_row.dart';
import '../widgets/month_pulse_card.dart';
import '../widgets/remember_section.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
            // Web order: stats → Things to remember → Month pulse → Budget balance
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BalanceCard(),
                const SizedBox(height: 12),
                ListenableBuilder(
                  listenable: TransactionStore.instance,
                  builder: (context, _) {
                    final store = TransactionStore.instance;
                    return HomeStatsRow(
                      transactions: store.count,
                      incomeEntries: store.incomeEntryCount,
                    );
                  },
                ),
                const SizedBox(height: 12),
                const RememberSection(),
                const SizedBox(height: 12),
                const MonthPulseCard(),
                const SizedBox(height: 12),
                const BudgetBalanceCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
