// Pure money formatting (no Flutter / ChangeNotifier dependency).

String formatMoney(double value, String symbol) {
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

String formatMoneyCompact(double amount, String symbol, String Function(double) full) {
  final n = amount.abs();
  final sign = amount < 0 ? '-' : '';
  if (n >= 10000000) {
    return '$sign$symbol${(n / 10000000).toStringAsFixed(1)}Cr';
  }
  if (n >= 100000) {
    return '$sign$symbol${(n / 100000).toStringAsFixed(1)}L';
  }
  if (n >= 10000) return '$sign$symbol${(n / 1000).round()}k';
  if (n >= 1000) {
    return '$sign$symbol${(n / 1000).toStringAsFixed(1)}k';
  }
  return full(amount);
}
