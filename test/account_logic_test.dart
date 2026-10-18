import 'package:flutter_test/flutter_test.dart';

import 'package:accountant/features/accounts/data/account.dart';
import 'package:accountant/features/accounts/domain/account_balances.dart';
import 'package:accountant/features/accounts/domain/account_style.dart';
import 'package:accountant/features/accounts/domain/payments.dart';
import 'package:accountant/features/activity/domain/activity_logic.dart';
import 'package:accountant/features/home/domain/remember_tips.dart';
import 'package:accountant/features/transactions/data/transaction.dart';

MoneyTransaction _tx({
  required String id,
  required TransactionType type,
  required double amount,
  String date = '2026-10-10',
  String category = 'Food',
  PaymentMode? paymentMode,
  String? accountId,
  String? toAccountId,
}) {
  return MoneyTransaction(
    id: id,
    title: id,
    amount: amount,
    type: type,
    category: category,
    date: date,
    createdAt: date,
    paymentMode: paymentMode,
    accountId: accountId,
    toAccountId: toAccountId,
  );
}

MoneyAccount _account({
  required String id,
  double balance = 1000,
  AccountKind kind = AccountKind.bank,
}) {
  return MoneyAccount(
    id: id,
    name: id,
    kind: kind,
    balance: balance,
    createdAt: '2026-01-01',
    updatedAt: '2026-01-01',
  );
}

void main() {
  test('normalizePaymentMode defaults to upi', () {
    expect(normalizePaymentMode('card'), PaymentMode.card);
    expect(normalizePaymentMode('nope'), PaymentMode.upi);
  });

  test('applyTransactionToAccounts expense and income', () {
    final accounts = [_account(id: 'a1', balance: 1000)];
    final spent = applyTransactionToAccounts(
      accounts,
      _tx(
        id: '1',
        type: TransactionType.expense,
        amount: 200,
        accountId: 'a1',
      ),
    );
    expect(spent.single.balance, 800);

    final received = applyTransactionToAccounts(
      spent,
      _tx(
        id: '2',
        type: TransactionType.income,
        amount: 50,
        accountId: 'a1',
      ),
    );
    expect(received.single.balance, 850);
  });

  test('applyTransactionToAccounts rejects overspend', () {
    final accounts = [_account(id: 'a1', balance: 100)];
    expect(
      () => applyTransactionToAccounts(
        accounts,
        _tx(
          id: '1',
          type: TransactionType.expense,
          amount: 150,
          accountId: 'a1',
        ),
      ),
      throwsStateError,
    );
  });

  test('transfer moves between accounts; adjustment skips sync', () {
    final accounts = [
      _account(id: 'from', balance: 500),
      _account(id: 'to', balance: 0, kind: AccountKind.cash),
    ];
    final next = applyTransactionToAccounts(
      accounts,
      _tx(
        id: 't',
        type: TransactionType.transfer,
        amount: 100,
        category: 'Transfer',
        accountId: 'from',
        toAccountId: 'to',
      ),
    );
    expect(next.firstWhere((a) => a.id == 'from').balance, 400);
    expect(next.firstWhere((a) => a.id == 'to').balance, 100);

    final tally = applyTransactionToAccounts(
      next,
      _tx(
        id: 'adj',
        type: TransactionType.transfer,
        amount: 20,
        category: 'Adjustment',
        accountId: 'from',
      ),
    );
    expect(tally.firstWhere((a) => a.id == 'from').balance, 400);
  });

  test('filterActivityTransactions filters account and payment mode', () {
    final txs = [
      _tx(
        id: '1',
        type: TransactionType.expense,
        amount: 10,
        accountId: 'a1',
        paymentMode: PaymentMode.upi,
      ),
      _tx(
        id: '2',
        type: TransactionType.expense,
        amount: 20,
        accountId: 'a2',
        paymentMode: PaymentMode.cash,
      ),
    ];
    final byAccount = filterActivityTransactions(
      txs,
      type: ActivityTypeFilter.all,
      period: ActivityPeriodFilter.all,
      accountId: 'a1',
    );
    expect(byAccount.map((t) => t.id), ['1']);

    final byMode = filterActivityTransactions(
      txs,
      type: ActivityTypeFilter.all,
      period: ActivityPeriodFilter.all,
      paymentMode: 'cash',
    );
    expect(byMode.map((t) => t.id), ['2']);
  });

  test('buildAccountTips low balance and empty', () {
    final empty = buildAccountTips(
      accounts: const [],
      defaultAccountId: null,
      lowBalanceEnabled: true,
      lowBalanceThreshold: 500,
      formatMoney: (v) => '₹$v',
    );
    expect(empty.single.id, 'accounts-empty');

    final low = buildAccountTips(
      accounts: [_account(id: 'bank', balance: 100)],
      defaultAccountId: 'bank',
      lowBalanceEnabled: true,
      lowBalanceThreshold: 500,
      formatMoney: (v) => '₹$v',
    );
    expect(low.any((t) => t.id.startsWith('low-balance-')), isTrue);

    final masked = buildAccountTips(
      accounts: [_account(id: 'bank', balance: 100)],
      defaultAccountId: 'bank',
      lowBalanceEnabled: true,
      lowBalanceThreshold: 500,
      formatMoney: (v) => '₹$v',
      revealBalances: false,
    );
    expect(
      masked.singleWhere((t) => t.id.startsWith('low-balance-')).body,
      contains('Unlock balances'),
    );
  });
}
