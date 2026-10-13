import 'package:intl/intl.dart';

class Fmt {
  static String money(double amount, {String currency = 'TZS'}) {
    final n = NumberFormat('#,###', 'en_US').format(amount.round());
    return '$currency $n';
  }

  static String num(double n, {int decimals = 0}) =>
      NumberFormat('#,##0.${'0' * decimals}', 'en_US').format(n);

  static String date(DateTime dt) => DateFormat('dd MMM yyyy').format(dt);
  static String time(DateTime dt) => DateFormat('HH:mm').format(dt);
  static String dateTime(DateTime dt) => DateFormat('dd MMM · HH:mm').format(dt);

  static String shortMoney(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000)    return '${(amount / 1000).toStringAsFixed(0)}K';
    return amount.round().toString();
  }

  static String payMethod(String method) {
    const labels = {
      'cash': 'Cash', 'mpesa': 'M-Pesa', 'tigo': 'Tigo Pesa',
      'airtel': 'Airtel Money', 'bank': 'Bank Transfer',
      'credit': 'Credit', 'wallet': 'Wallet',
    };
    return labels[method] ?? method.toUpperCase();
  }
}
