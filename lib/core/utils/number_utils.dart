import 'package:intl/intl.dart';

class NumberUtils {
  NumberUtils._();

  static String currency(num value) => NumberFormat.currency(symbol: '₹').format(value);

  static String decimal(num value, {int digits = 2}) =>
      NumberFormat.decimalPatternDigits(decimalDigits: digits).format(value);
}
