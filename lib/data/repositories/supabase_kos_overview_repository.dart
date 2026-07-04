import '../../domain/entities/kos_overview_entity.dart';
import '../../domain/entities/payment_entity.dart';
import '../../domain/entities/overdue_entity.dart';
import 'kos_overview_repository.dart';
import 'occupancy_repository.dart';
import 'room_repository.dart';
import 'supabase_finance_repository.dart';
import 'supabase_occupancy_repository.dart';
import 'supabase_room_repository.dart';
import 'supabase_tenant_repository.dart';
import '../../domain/entities/activity_entity.dart';

class SupabaseKosOverviewRepository implements KosOverviewRepository {
  final OccupancyRepository _occupancyRepo;
  final RoomRepository _roomRepo;
  final SupabaseFinanceRepository _financeRepo;
  final SupabaseTenantRepository _tenantRepo;

  SupabaseKosOverviewRepository({
    OccupancyRepository? occupancyRepo,
    RoomRepository? roomRepo,
    SupabaseFinanceRepository? financeRepo,
    SupabaseTenantRepository? tenantRepo,
  })  : _occupancyRepo = occupancyRepo ?? SupabaseOccupancyRepository(),
        _financeRepo = financeRepo ?? SupabaseFinanceRepository(),
        _tenantRepo = tenantRepo ?? SupabaseTenantRepository(),
        _roomRepo = roomRepo ??
            SupabaseRoomRepository(
              occupancyRepo: occupancyRepo ?? SupabaseOccupancyRepository(),
            );

  @override
  Future<KosOverviewEntity> fetchOverview({
    required String kosId,
    DateTime? from,
    DateTime? to,
  }) async {
    final results = await Future.wait([
      _roomRepo.fetchAllRoomsWithOccupancyStatus(activeKosId: kosId),
      _financeRepo.fetchTransactions(kosId: kosId, from: from, to: to),
      _occupancyRepo.fetchOccupiedOccupancies(kosId: kosId),
      _tenantRepo.fetchTenants(),
    ]);

    final rooms = results[0] as List;
    final transactions = results[1] as List;
    final occupiedOccupancies = results[2] as List;
    final tenants = results[3] as List;

    final occupiedRooms = rooms.where((r) => r.isOccupied == true).length;
    final availableRooms = rooms.length - occupiedRooms;

    double income = 0;
    double expense = 0;
    for (final t in transactions) {
      if (t.type.toString().contains('income')) {
        income += t.amount as double;
      } else {
        expense += t.amount as double;
      }
    }

    final latestPayments = transactions.take(5).map((t) {
      return PaymentEntity(
        title: t.description as String,
        date: t.date as DateTime,
        amount: t.amount as num,
        isPositive: t.type.toString().contains('income'),
      );
    }).toList();

    final roomNameById = {
      for (final r in rooms) r.id as String: r.name as String,
    };
    final tenantNameById = {
      for (final t in tenants) t.id as String: t.fullName as String,
    };

    final now = DateTime.now();
    final overdues = <OverdueEntity>[];
    for (final occ in occupiedOccupancies) {
      final paymentStatus = (occ.paymentStatus ?? '').toString().toLowerCase();
      final endDate = occ.endDate as DateTime?;
      final isUnpaid = paymentStatus.isNotEmpty && paymentStatus != 'lunas';
      final isPastDue = endDate != null && endDate.isBefore(now);

      if (isUnpaid && isPastDue) {
        final tenantName = tenantNameById[occ.tenantId] ?? 'Penyewa';
        final roomName = roomNameById[occ.roomId] ?? '-';
        final amount = num.tryParse((occ.price ?? '0').toString()) ?? 0;

        overdues.add(OverdueEntity(
          tenantName: tenantName,
          room: roomName,
          amount: amount,
          dueDate: endDate,
          occupancyId: occ.id as String,
        ));
      }
    }

    final unpaidAmount = overdues.fold<num>(0, (s, o) => s + o.amount);

    final recentActivities = await _fetchRecentActivities(
    kosId: kosId,
    transactions: transactions,
    rooms: rooms,
    tenants: tenants,
    occupiedOccupancies: occupiedOccupancies,
  );

  return KosOverviewEntity(
    occupiedRooms: occupiedRooms,
    availableRooms: availableRooms,
    income: income,
    expense: expense,
    unpaidAmount: unpaidAmount,
    latestPayments: latestPayments,
    overdues: overdues,
    recentActivities: recentActivities, // BARU
  );
}

// BARU: Method untuk menggabungkan aktivitas dari berbagai sumber
Future<List<ActivityEntity>> _fetchRecentActivities({
  required String kosId,
  required List transactions,
  required List rooms,
  required List tenants,
  required List occupiedOccupancies,
}) async {
  final activities = <ActivityEntity>[];
  final roomNameById = {
    for (final r in rooms) r.id: r.name,
  };
  final tenantNameById = {
    for (final t in tenants) t.id: t.fullName,
  };
  // 1. Transaksi → Activity
  for (final t in transactions.take(10)) {
    final isIncome = t.type.toString().contains('income');
    activities.add(ActivityEntity(
      id: 'tx_${t.id}',
      type: isIncome ? ActivityType.transactionIncome : ActivityType.transactionExpense,
      title: t.description as String,
      subtitle: isIncome ? 'Pemasukan' : 'Pengeluaran',
      timestamp: t.date as DateTime,
      amount: t.amount as num,
      isPositive: isIncome,
    ));
  }

  // 2. Tenant baru (30 hari terakhir)
  final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
  for (final t in tenants.where((t) {
    final createdAt = t.createdAt;
    return createdAt != null && createdAt.isAfter(thirtyDaysAgo);
  }).take(5)) {
    activities.add(ActivityEntity(
      id: 'tenant_${t.id}',
      type: ActivityType.tenantAdded,
      title: 'Penghuni baru: ${t.fullName}',
      subtitle: 'Telah terdaftar',
      timestamp: t.createdAt!,
    ));
  }
  for (final occ in occupiedOccupancies.where((o) {
    final start = o.startDate;
    return start != null && start.isAfter(thirtyDaysAgo);
  }).take(5)) {
    final tenantName = tenantNameById[occ.tenantId] ?? 'Penghuni';
    final roomName = roomNameById[occ.roomId] ?? 'Kamar';
    activities.add(ActivityEntity(
      id: 'occ_${occ.id}',
      type: ActivityType.occupancyCreated,
      title: '$tenantName check-in',
      subtitle: roomName,
      timestamp: occ.startDate!,
    ));
  }

  // Urutkan: terbaru di atas
  activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));

  // Ambil 5 teratas
  return activities.take(5).toList();
}

  
}