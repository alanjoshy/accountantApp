import 'package:accountant/features/backup/domain/backup_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseBackupJson accepts web-shaped numeric ids', () {
    const json = '''
{
  "formatVersion": 1,
  "app": "accountant",
  "exportedAt": "2026-10-18T12:00:00.000Z",
  "data": {
    "transactions": [
      {
        "id": 1,
        "title": "Coffee",
        "amount": 40,
        "type": "expense",
        "category": "Food",
        "date": "2026-10-10",
        "createdAt": "2026-10-10T08:00:00.000Z",
        "accountId": 2,
        "paymentMode": "upi"
      }
    ],
    "budgets": [
      {
        "id": 9,
        "category": "Food",
        "limit": 5000,
        "period": "monthly",
        "createdAt": "2026-10-01T00:00:00.000Z"
      }
    ],
    "jars": [],
    "settings": [
      {
        "id": "app",
        "cycleStartDay": 1,
        "tags": ["Personal"],
        "monthlyIncome": 50000,
        "defaultAccountId": 2,
        "updatedAt": "2026-10-01T00:00:00.000Z"
      }
    ],
    "accounts": [
      {
        "id": 2,
        "name": "Primary bank",
        "kind": "bank",
        "balance": 1000,
        "createdAt": "2026-10-01T00:00:00.000Z",
        "updatedAt": "2026-10-01T00:00:00.000Z"
      }
    ],
    "scheduledPayments": [],
    "debts": []
  }
}
''';
    final snap = parseBackupJson(json);
    expect(snap.transactions.single.id, '1');
    expect(snap.transactions.single.accountId, '2');
    expect(snap.accounts.single.name, 'Primary bank');
    expect(snap.budgets.single.limit, 5000);
    expect(snap.settings.first['monthlyIncome'], 50000);
  });

  test('rejects non-accountant JSON', () {
    expect(
      () => parseBackupJson('{"formatVersion":1,"app":"other","exportedAt":"x","data":{"transactions":[],"budgets":[],"jars":[],"settings":[]}}'),
      throwsStateError,
    );
  });
}
