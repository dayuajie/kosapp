import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:kos_app/data/repositories/mock_kos_repository.dart';
import 'package:kos_app/domain/entities/payment_entity.dart';
import 'package:kos_app/domain/entities/overdue_entity.dart';
import 'package:kos_app/domain/entities/kos_overview_entity.dart';

part 'kos_overview_state.dart';

class KosOverviewCubit extends Cubit<KosOverviewState> {
  KosOverviewCubit() : super(KosOverviewInitial());

  final _repo = MockKosRepository();
  // keep the last fetched overview so we can modify it locally (mock behavior)
  KosOverviewEntity? _lastOverview;

  void load() async {
    emit(const KosOverviewLoading());
    try {
      final overview = await _repo.fetchKosOverview();
      _lastOverview = overview;

      emit(
        KosOverviewLoaded(
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
        ),
      );
    } catch (e) {
      emit(KosOverviewError(message: e.toString()));
    }
  }


  /// Mark an overdue item as paid (local/mock update): remove from overdues and adjust unpaid amount
  void settleOverdue(OverdueEntity item) async {
    final current = _lastOverview;
    if (current == null) return;

    emit(const KosOverviewLoading());

    try {
      // remove matched overdue by identity of tenantName+room+dueDate
      final newOverdues = current.overdues
          .where((o) => !(o.tenantName == item.tenantName && o.room == item.room && o.dueDate == item.dueDate))
          .toList();

      final newUnpaid = (current.unpaidAmount - item.amount) < 0 ? 0 : (current.unpaidAmount - item.amount);

      final updated = KosOverviewEntity(
        occupiedRooms: current.occupiedRooms,
        availableRooms: current.availableRooms,
        income: current.income,
        expense: current.expense,
        unpaidAmount: newUnpaid,
        latestPayments: current.latestPayments,
        overdues: newOverdues,
      );

      // store updated overview
      _lastOverview = updated;

      // simulate small delay (as if saving to repo)
      await Future.delayed(const Duration(milliseconds: 200));

      emit(
        KosOverviewLoaded(
          occupiedRooms: updated.occupiedRooms,
          availableRooms: updated.availableRooms,
          incomeFormatted: _formatCurrency(updated.income),
          expenseFormatted: _formatCurrency(updated.expense),
          unpaidAmountFormatted: _formatCurrency(updated.unpaidAmount),
          income: updated.income,
          expense: updated.expense,
          unpaidAmount: updated.unpaidAmount,
          upcomingPayments: null,
          latestPayments: updated.latestPayments,
          overdues: updated.overdues,
        ),
      );
    } catch (e) {
      emit(KosOverviewError(message: e.toString()));
    }
  }


  String _formatCurrency(num value) {
    final format = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return format.format(value);
  }
}

