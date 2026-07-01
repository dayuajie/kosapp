import 'package:intl/intl.dart';

class PaymentEntity {
  final String title;
  final DateTime date;
  final num amount;
  final bool isPositive; // true: pemasukan, false: pengeluaran

  const PaymentEntity({
    required this.title,
    required this.date,
    required this.amount,
    required this.isPositive,
  });

  bool get isPaid => isPositive;

  String get statusLabel => isPositive ? 'Berhasil' : 'Pengeluaran';

  String get amountFormatted {
    final format = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return format.format(amount);
  }

  String get dateFormatted {
    final format = DateFormat('dd MMM yyyy', 'id_ID');
    return format.format(date);
  }
}

