import 'package:kos_app/domain/entities/payment_entity.dart';
import 'package:kos_app/domain/entities/overdue_entity.dart';

class KosOverviewEntity {
  final int occupiedRooms;
  final int availableRooms;
  final num income;
  final num expense;
  final num unpaidAmount;
  final List<PaymentEntity> latestPayments;
  final List<OverdueEntity> overdues;

  const KosOverviewEntity({
    required this.occupiedRooms,
    required this.availableRooms,
    required this.income,
    required this.expense,
    required this.unpaidAmount,
    required this.latestPayments,
    required this.overdues,
  });
}

