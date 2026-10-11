// Supported display currencies.

enum AppCurrency {
  usd,
  eur,
  gbp,
  aed,
  sar,
  kwd,
  bhd,
  inr;

  String get code => switch (this) {
        AppCurrency.usd => 'USD',
        AppCurrency.eur => 'EUR',
        AppCurrency.gbp => 'GBP',
        AppCurrency.aed => 'AED',
        AppCurrency.sar => 'SAR',
        AppCurrency.kwd => 'KWD',
        AppCurrency.bhd => 'BHD',
        AppCurrency.inr => 'INR',
      };

  String get symbol => switch (this) {
        AppCurrency.usd => r'$',
        AppCurrency.eur => '€',
        AppCurrency.gbp => '£',
        AppCurrency.aed => 'د.إ',
        AppCurrency.sar => '﷼',
        AppCurrency.kwd => 'د.ك',
        AppCurrency.bhd => 'د.ب',
        AppCurrency.inr => '₹',
      };

  String get label => switch (this) {
        AppCurrency.usd => 'Dollar',
        AppCurrency.eur => 'Euro',
        AppCurrency.gbp => 'Pound',
        AppCurrency.aed => 'Dirham',
        AppCurrency.sar => 'Riyal',
        AppCurrency.kwd => 'Dinar',
        AppCurrency.bhd => 'Bahrain Dinar',
        AppCurrency.inr => 'Indian Rupee',
      };

  String get country => switch (this) {
        AppCurrency.usd => 'United States',
        AppCurrency.eur => 'European Union',
        AppCurrency.gbp => 'United Kingdom',
        AppCurrency.aed => 'United Arab Emirates',
        AppCurrency.sar => 'Saudi Arabia',
        AppCurrency.kwd => 'Kuwait',
        AppCurrency.bhd => 'Bahrain',
        AppCurrency.inr => 'India',
      };

  /// Regional flag emoji for the picker.
  String get flag => switch (this) {
        AppCurrency.usd => '🇺🇸',
        AppCurrency.eur => '🇪🇺',
        AppCurrency.gbp => '🇬🇧',
        AppCurrency.aed => '🇦🇪',
        AppCurrency.sar => '🇸🇦',
        AppCurrency.kwd => '🇰🇼',
        AppCurrency.bhd => '🇧🇭',
        AppCurrency.inr => '🇮🇳',
      };

  static AppCurrency fromCode(String? raw) {
    for (final currency in AppCurrency.values) {
      if (currency.code == raw) return currency;
    }
    return AppCurrency.inr;
  }
}
