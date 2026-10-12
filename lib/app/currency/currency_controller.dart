// Persisted currency preference.

import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../core/storage/local_storage.dart';
import 'app_currency.dart';
import 'money_format.dart';

class CurrencyController extends ChangeNotifier {
  CurrencyController();

  static final CurrencyController instance = CurrencyController();

  AppCurrency _currency = AppCurrency.inr;

  AppCurrency get currency => _currency;

  String get symbol => _currency.symbol;

  void load() {
    _currency = AppCurrency.fromCode(
      LocalStorage.getString(AppConstants.currencyCodeKey),
    );
  }

  Future<void> setCurrency(AppCurrency currency) async {
    if (_currency == currency) return;
    _currency = currency;
    notifyListeners();
    await LocalStorage.setString(AppConstants.currencyCodeKey, currency.code);
  }

  String format(double value) => formatMoney(value, symbol);

  String compact(double value) =>
      formatMoneyCompact(value, symbol, format);
}
