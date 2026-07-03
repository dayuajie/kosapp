import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:kos_app/data/repositories/kos_overview_repository.dart';
import 'package:kos_app/data/repositories/supabase_kos_overview_repository.dart';
import 'package:kos_app/data/repositories/occupancy_repository.dart';
import 'package:kos_app/data/repositories/supabase_occupancy_repository.dart';
import 'package:kos_app/domain/entities/payment_entity.dart';
import 'package:kos_app/domain/entities/overdue_entity.dart';
import 'package:kos_app/domain/entities/kos_overview_entity.dart';

part 'kos_overview_state.dart';

class KosOverviewCubit extends Cubit<KosOverviewState> {
  KosOverviewCubit({
    KosOverviewRepository? repository,
    OccupancyRepository? occupancyRepo,
  })  : _repo = repository ?? SupabaseKosOverviewRepository(),
        _occupancyRepo = occupancyRepo ?? SupabaseOccupancyRepository(),
        super(const KosOverviewInitial());

  final KosOverviewRepository _repo;
  final OccupancyRepository _occupancyRepo;

  KosOverviewEntity? _lastOverview;
  String? _lastKosId;

  void load({required String kosId}) async {
    emit(const KosOverviewLoading());
    try {
      final overview = await _repo.fetchOverview(kosId: kosId);
      _lastOverview = overview;
      _lastKosId = kosId;
      emit(_toLoaded(overview));
    } catch (e) {
      emit(KosOverviewError(message: 'Gagal memuat ringkasan kos: $e'));
    }
  }

  /// Tandai satu tunggakan sebagai lunas. Ini aksi nyata ke DB
  /// (bukan lagi mock lokal), lalu reload overview dari kosId terakhir.
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

  KosOverviewLoaded _toLoaded(KosOverviewEntity overview) {
    return KosOverviewLoaded(
      occupiedRooms: overview.occupiedRooms,
      availableRooms: overview.availableRooms,
      incomeFormatted: _formatCurrency(overview.income),
      expenseFormatted: _formatCurrency(overview.expense),
      unpaidAmountFormatted: _formatCurrency(overview.unpaidAmount),
      income: overview.income,
      expense: overview.expense,
      unpaidAmount: overview.unpaidAmount,
      upcomingPayments: null, // lihat catatan di SupabaseKosOverviewRepository
      latestPayments: overview.latestPayments,
      overdues: overview.overdues,
    );
  }

  String _formatCurrency(num value) {
    final format = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return format.format(value);
  }
}