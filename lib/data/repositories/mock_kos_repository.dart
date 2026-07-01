import 'package:kos_app/domain/entities/kos_overview_entity.dart';
import 'package:kos_app/domain/entities/payment_entity.dart';
import 'package:kos_app/domain/entities/overdue_entity.dart';

class MockKosRepository {
  Future<KosOverviewEntity> fetchKosOverview() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));

    final now = DateTime.now();

    return KosOverviewEntity(
      occupiedRooms: 18,
      availableRooms: 7,
      income: 12500000,
      expense: 3200000,
      unpaidAmount: 4500000,
      latestPayments: [
        PaymentEntity(
          title: 'Pembayaran Kos - Kamar 03',
          date: now.subtract(const Duration(days: 1)),
          amount: 1250000,
          isPositive: true,
        ),
        PaymentEntity(
          title: 'Pembayaran Kos - Kamar 09',
          date: now.subtract(const Duration(days: 2)),
          amount: 1500000,
          isPositive: true,
        ),
        PaymentEntity(
          title: 'Pembayaran Kos - Kamar 11',
          date: now.subtract(const Duration(days: 3)),
          amount: 1000000,
          isPositive: true,
        ),
        PaymentEntity(
          title: 'Pengeluaran - Listrik & Internet',
          date: now.subtract(const Duration(days: 4)),
          amount: 750000,
          isPositive: false,
        ),
      ],
      overdues: [
        // sample tunggakan
        // tenantName, room, amount, dueDate
        // dueDate in the past to indicate overdue days
        OverdueEntity(
          tenantName: 'Andi Saputra',
          room: 'Kamar 03',
          amount: 1250000,
          dueDate: now.subtract(const Duration(days: 12)),
        ),
        OverdueEntity(
          tenantName: 'Siti Nur',
          room: 'Kamar 07',
          amount: 900000,
          dueDate: now.subtract(const Duration(days: 5)),
        ),
      ],
    );
  }
}

