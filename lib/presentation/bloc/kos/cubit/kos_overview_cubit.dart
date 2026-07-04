import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:kos_app/data/repositories/kos_overview_repository.dart';
import 'package:kos_app/data/repositories/supabase_kos_overview_repository.dart';
import 'package:kos_app/data/repositories/occupancy_repository.dart';
import 'package:kos_app/data/repositories/supabase_occupancy_repository.dart';
import 'package:kos_app/domain/entities/payment_entity.dart';
import 'package:kos_app/domain/entities/overdue_entity.dart';
import 'package:kos_app/domain/entities/kos_overview_entity.dart';
import 'package:kos_app/domain/entities/activity_entity.dart';
import 'package:kos_app/data/repositories/supabase_finance_repository.dart';
import 'package:fl_chart/fl_chart.dart';
part 'kos_overview_state.dart';

class KosOverviewCubit extends Cubit<KosOverviewState> {
  KosOverviewCubit({
    KosOverviewRepository? repository,
    OccupancyRepository? occupancyRepo,
    SupabaseFinanceRepository? financeRepo,
  })  : _repo = repository ?? SupabaseKosOverviewRepository(),
        _occupancyRepo = occupancyRepo ?? SupabaseOccupancyRepository(),
        _financeRepo = financeRepo ?? SupabaseFinanceRepository(),
        super(const KosOverviewInitial());

  final KosOverviewRepository _repo;
  final OccupancyRepository _occupancyRepo;
  final SupabaseFinanceRepository _financeRepo;

  KosOverviewEntity? _lastOverview;
  String? _lastKosId;

  void load({required String kosId}) async {
    emit(const KosOverviewLoading());
    try {
      final overview = await _repo.fetchOverview(kosId: kosId);
      _lastOverview = overview;
      _lastKosId = kosId;

      // Ambil transaksi bulan ini
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final transactions = await _financeRepo.fetchTransactions(
        kosId: kosId,
        from: firstDayOfMonth,
        to: now,
      );

      // Kelompokkan per minggu (4 minggu)
      final spots = _groupTransactionsByWeek(transactions);

      emit(_toLoaded(overview, chartSpots: spots));
    } catch (e) {
      emit(KosOverviewError(message: 'Gagal memuat ringkasan kos: $e'));
    }
  }

  void settleOverdue(OverdueEntity item) async {
    final kosId = _lastKosId;
    if (kosId == null || item.occupancyId == null) return;

    emit(const KosOverviewLoading());
    try {
      await _occupancyRepo.updatePaymentStatus(
        occupancyId: item.occupancyId!,
        paymentStatus: 'Lunas',
      );
      final overview = await _repo.fetchOverview(kosId: kosId);
      _lastOverview = overview;
      emit(_toLoaded(overview));
    } catch (e) {
      emit(KosOverviewError(message: 'Gagal menandai lunas: $e'));
    }
  }

  List<FlSpot> _groupTransactionsByWeek(List<TransactionEntity> transactions) {
    // Filter hanya pemasukan (income)
    final incomes = transactions.where((t) => t.type == TransactionType.income).toList();
    if (incomes.isEmpty) {
      // Jika tidak ada pemasukan, berikan data dummy 0 untuk 4 minggu
      return List.generate(4, (i) => FlSpot(i.toDouble(), 0));
    }

    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    // Tentukan jumlah hari dalam bulan ini
    final lastDay = DateTime(now.year, now.month + 1, 0);
    final daysInMonth = lastDay.day;
    // Bagi menjadi 4 minggu (7 hari per minggu, sisa dimasukkan ke minggu terakhir)
    final weekSize = 7;
    final weeks = <double>[]; // total per minggu

    for (int week = 0; week < 4; week++) {
      final startDay = week * weekSize + 1;
      final endDay = (week == 3) ? daysInMonth : (startDay + weekSize - 1);
      double total = 0;
      for (final t in incomes) {
        final day = t.date.day;
        if (day >= startDay && day <= endDay) {
          total += t.amount;
        }
      }
      weeks.add(total);
    }

    return weeks.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList();
  }

  

  KosOverviewLoaded _toLoaded(KosOverviewEntity overview, {List<FlSpot>? chartSpots}) {
    return KosOverviewLoaded(
      occupiedRooms: overview.occupiedRooms,
      availableRooms: overview.availableRooms,
      incomeFormatted: _formatCurrency(overview.income),
      expenseFormatted: _formatCurrency(overview.expense),
      unpaidAmountFormatted: _formatCurrency(overview.unpaidAmount),
      income: overview.income,
      expense: overview.expense,
      unpaidAmount: overview.unpaidAmount,
      upcomingPayments: null,
      latestPayments: overview.latestPayments,
      overdues: overview.overdues,
      recentActivities: overview.recentActivities,
      chartSpots: chartSpots ?? const [], // baru
    );
  }

  String _formatCurrency(num value) {
    final format = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return format.format(value);
  }
}