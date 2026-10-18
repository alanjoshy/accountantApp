// Persisted money accounts (web useAccounts).

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/storage/local_storage.dart';
import '../domain/account_balances.dart';
import '../domain/account_style.dart';
import 'account.dart';

class AccountStore extends ChangeNotifier {
  AccountStore();

  static final AccountStore instance = AccountStore();

  List<MoneyAccount> _items = const [];

  List<MoneyAccount> get accounts => _items;

  MoneyAccount? byId(String? id) {
    if (id == null) return null;
    for (final a in _items) {
      if (a.id == id) return a;
    }
    return null;
  }

  double get totalBalance => totalAccountBalance(_items);

  void load() {
    final raw = LocalStorage.getString(AppConstants.accountsKey);
    if (raw == null || raw.isEmpty) {
      _items = const [];
      return;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _items = [
        for (final item in list)
          MoneyAccount.fromJson(Map<String, dynamic>.from(item as Map)),
      ];
      _sort();
    } catch (_) {
      _items = const [];
    }
  }

  Future<void> ensureSeeded() async {
    final seeded = LocalStorage.getBool(AppConstants.accountsSeededKey) ?? false;
    if (seeded) return;
    if (_items.isNotEmpty) {
      await LocalStorage.setBool(AppConstants.accountsSeededKey, true);
      return;
    }
    final now = _now();
    _items = [
      MoneyAccount(
        id: _newId(),
        name: 'In-hand cash',
        kind: AccountKind.cash,
        balance: 0,
        icon: defaultIconForKind(AccountKind.cash),
        color: defaultColorForKind(AccountKind.cash),
        createdAt: now,
        updatedAt: now,
      ),
      MoneyAccount(
        id: _newId(),
        name: 'Primary bank',
        kind: AccountKind.bank,
        balance: 0,
        icon: defaultIconForKind(AccountKind.bank),
        color: defaultColorForKind(AccountKind.bank),
        createdAt: now,
        updatedAt: now,
      ),
    ];
    _sort();
    notifyListeners();
    await _persist();
    await LocalStorage.setBool(AppConstants.accountsSeededKey, true);
  }

  Future<void> _persist() async {
    await LocalStorage.setString(
      AppConstants.accountsKey,
      jsonEncode(_items.map((a) => a.toJson()).toList()),
    );
  }

  void _sort() {
    _items = [..._items]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  String _now() => DateTime.now().toUtc().toIso8601String();

  Future<MoneyAccount> addAccount({
    required String name,
    required AccountKind kind,
    double balance = 0,
    String? icon,
    String? color,
  }) async {
    final now = _now();
    final account = MoneyAccount(
      id: _newId(),
      name: name.trim(),
      kind: kind,
      balance: balance.isFinite && balance >= 0 ? roundMoney(balance) : 0,
      icon: icon ?? defaultIconForKind(kind),
      color: color ?? defaultColorForKind(kind),
      createdAt: now,
      updatedAt: now,
    );
    _items = [account, ..._items];
    _sort();
    notifyListeners();
    await _persist();
    return account;
  }

  Future<void> updateAccount(MoneyAccount account) async {
    final i = _items.indexWhere((a) => a.id == account.id);
    if (i < 0) throw StateError('Account not found');
    _items = [..._items]..[i] = account.copyWith(updatedAt: _now());
    _sort();
    notifyListeners();
    await _persist();
  }

  Future<void> replaceAll(List<MoneyAccount> next) async {
    _items = next;
    _sort();
    notifyListeners();
    await _persist();
  }

  Future<void> deleteAccount(String id) async {
    _items = [for (final a in _items) if (a.id != id) a];
    notifyListeners();
    await _persist();
  }

  Future<void> applyBalances(List<MoneyAccount> next) async {
    await replaceAll(next);
  }
}
