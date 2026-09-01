import 'package:intl/intl.dart';

class AppDateUtils {
  AppDateUtils._();

  static String display(DateTime value) => DateFormat('dd MMM yyyy').format(value);

  static String api(DateTime value) => DateFormat('yyyy-MM-dd').format(value);
}
