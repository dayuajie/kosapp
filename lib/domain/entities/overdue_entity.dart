import 'package:intl/intl.dart';

class OverdueEntity {
  final String tenantName;
  final String room;
  final num amount;
  final DateTime dueDate;
  final String? occupancyId;

  const OverdueEntity({
    required this.tenantName,
    required this.room,
    required this.amount,
    required this.dueDate,
    this.occupancyId,
  });

  int get daysOverdue => DateTime.now().difference(dueDate).inDays;

  String get amountFormatted {
    final format = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return format.format(amount);
  }
}
