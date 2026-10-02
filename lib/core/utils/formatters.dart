import 'package:intl/intl.dart';

class Formatters {
  static String currency(double amount, {String symbol = '₹'}) {
    final formatter = NumberFormat.currency(symbol: symbol, decimalDigits: 0);
    return formatter.format(amount);
  }

  static String date(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('yyyy-MM-dd').format(date);
  }

  static String displayDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('MMM dd, yyyy').format(date);
  }

  static DateTime? parseDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return null;
    try {
      return DateTime.parse(dateStr.trim());
    } catch (_) {
      return null;
    }
  }

  static String daysRemainingText(int? days) {
    if (days == null) return 'Unknown';
    if (days < 0) return 'Expired (${days.abs()}d ago)';
    if (days == 0) return 'Expires today';
    return '$days days left';
  }
}

class AppFormatters {
  static String currency(double amount, {String symbol = '₹'}) {
    return Formatters.currency(amount, symbol: symbol);
  }

  static String date(DateTime? date) {
    return Formatters.displayDate(date);
  }

  static String daysRemaining(int? days) {
    return Formatters.daysRemainingText(days);
  }
}
