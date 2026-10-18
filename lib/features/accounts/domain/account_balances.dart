// Account balance apply/reverse (web account-balances.ts).

import '../../transactions/data/transaction.dart';
import '../data/account.dart';

double roundMoney(double amount) => (amount * 100).round() / 100;

double totalAccountBalance(Iterable<MoneyAccount> accounts) {
  return roundMoney(
    accounts.fold<double>(0, (sum, a) => sum + a.balance),
  );
}

/// Tally adjustments skip automatic sync (balances updated at source).
bool affectsAccountBalances(MoneyTransaction t) {
  if (t.type == TransactionType.transfer) {
    return t.category != 'Adjustment';
  }
  return t.type == TransactionType.income || t.type == TransactionType.expense;
}

class AccountBalanceDelta {
  const AccountBalanceDelta(this.accountId, this.delta);
  final String accountId;
  final double delta;
}

List<AccountBalanceDelta> balanceDeltasFor(
  MoneyTransaction t, {
  required bool reverse,
}) {
  if (!affectsAccountBalances(t)) return const [];
  final sign = reverse ? -1.0 : 1.0;
  final deltas = <AccountBalanceDelta>[];

  if (t.type == TransactionType.income && t.accountId != null) {
    deltas.add(AccountBalanceDelta(t.accountId!, sign * t.amount));
  } else if (t.type == TransactionType.expense && t.accountId != null) {
    deltas.add(AccountBalanceDelta(t.accountId!, -sign * t.amount));
  } else if (t.type == TransactionType.transfer) {
    if (t.accountId != null) {
      deltas.add(AccountBalanceDelta(t.accountId!, -sign * t.amount));
    }
    if (t.toAccountId != null) {
      deltas.add(AccountBalanceDelta(t.toAccountId!, sign * t.amount));
    }
  }
  return deltas;
}

/// Apply deltas to a copy of accounts. Throws if expense/transfer would go negative.
List<MoneyAccount> applyDeltasToAccounts(
  List<MoneyAccount> accounts,
  List<AccountBalanceDelta> deltas, {
  bool allowNegative = false,
  String? updatedAt,
}) {
  if (deltas.isEmpty) return accounts;
  final at = updatedAt ?? DateTime.now().toUtc().toIso8601String();
  final byId = {for (final a in accounts) a.id: a};

  for (final d in deltas) {
    final account = byId[d.accountId];
    if (account == null) continue;
    final next = roundMoney(account.balance + d.delta);
    if (!allowNegative && next < -0.0001) {
      throw StateError(
        'Not enough balance in ${account.name}. Available ${account.balance}.',
      );
    }
    byId[d.accountId] = account.copyWith(
      balance: next < 0 && allowNegative ? next : (next < 0 ? 0 : next),
      updatedAt: at,
    );
  }

  return [for (final a in accounts) byId[a.id] ?? a];
}

List<MoneyAccount> applyTransactionToAccounts(
  List<MoneyAccount> accounts,
  MoneyTransaction t, {
  bool reverse = false,
  bool allowNegative = false,
}) {
  return applyDeltasToAccounts(
    accounts,
    balanceDeltasFor(t, reverse: reverse),
    allowNegative: allowNegative,
  );
}
