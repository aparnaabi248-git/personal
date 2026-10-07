/// A selectable display currency.
///
/// The app stores money as a plain `double`; this class only controls how that
/// number is rendered, so switching currency never rewrites stored data.
class CurrencyOption {
  final String code;
  final String symbol;
  final String label;

  const CurrencyOption(this.code, this.symbol, this.label);

  static const List<CurrencyOption> all = <CurrencyOption>[
    CurrencyOption('INR', '₹', 'Indian Rupee (₹)'),
    CurrencyOption('USD', r'$', r'US Dollar ($)'),
    CurrencyOption('EUR', '€', 'Euro (€)'),
    CurrencyOption('GBP', '£', 'British Pound (£)'),
  ];

  /// Fall back to INR so an unknown stored code can never break rendering.
  static CurrencyOption fromCode(String? code) {
    return all.firstWhere(
      (c) => c.code == code,
      orElse: () => all.first,
    );
  }
}