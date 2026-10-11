// Persisted currency preference.

import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../core/storage/local_storage.dart';
import 'app_currency.dart';

class CurrencyController extends ChangeNotifier {
  CurrencyController._();

  static final CurrencyController instance = CurrencyController._();

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

  String format(double value) {
    final whole = value.round().abs();
    final digits = whole.toString();
    final buf = StringBuffer(symbol);
    if (value < 0) buf.write('-');
    for (var i = 0; i < digits.length; i++) {
      final fromEnd = digits.length - i;
      if (i > 0 && fromEnd % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return buf.toString();
  }
}
