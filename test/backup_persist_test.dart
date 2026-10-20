import 'package:accountant/app/bootstrap.dart';
import 'package:accountant/core/constants/app_constants.dart';
import 'package:accountant/core/storage/local_storage.dart';
import 'package:accountant/features/backup/domain/backup_service.dart';
import 'package:accountant/features/transactions/data/transaction_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _backupJson = '''
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
    "budgets": [],
    "jars": [],
    "settings": [{"id": "app", "cycleStartDay": 1}],
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LocalStorage.resetForTest();
    TransactionStore.instance.unloadForTest();
    await bootstrap();
  });

  test('getBool accepts the legacy string seed flag written by restore', () async {
    await LocalStorage.setString(AppConstants.accountsSeededKey, '1');
    expect(LocalStorage.getBool(AppConstants.accountsSeededKey), isTrue);
  });

  test('restore writes accounts seed as a bool, not the string 1', () async {
    await BackupService.restoreFromJsonText(_backupJson);
    expect(LocalStorage.getBool(AppConstants.accountsSeededKey), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(AppConstants.accountsSeededKey), isTrue);
  });

  test('imported transactions survive a cold restart', () async {
    await BackupService.restoreFromJsonText(_backupJson);
    expect(TransactionStore.instance.transactions, hasLength(1));

    // Process death: singletons keep the class, but RAM is gone.
    TransactionStore.instance.unloadForTest();
    expect(TransactionStore.instance.transactions, isEmpty);

    LocalStorage.resetForTest();
    await bootstrap();

    expect(TransactionStore.instance.transactions, hasLength(1));
    expect(TransactionStore.instance.transactions.single.title, 'Coffee');
  });

  test('legacy string seed flag does not skip transaction load', () async {
    await BackupService.restoreFromJsonText(_backupJson);
    await LocalStorage.setString(AppConstants.accountsSeededKey, '1');

    TransactionStore.instance.unloadForTest();
    LocalStorage.resetForTest();
    await bootstrap();

    expect(TransactionStore.instance.transactions.single.title, 'Coffee');
  });
}
