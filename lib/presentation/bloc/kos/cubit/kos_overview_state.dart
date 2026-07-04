
part of 'kos_overview_cubit.dart';

abstract class KosOverviewState {
  const KosOverviewState();
}

class KosOverviewInitial extends KosOverviewState {
  const KosOverviewInitial();
}

class KosOverviewLoading extends KosOverviewState {
  const KosOverviewLoading();
}

class KosOverviewLoaded extends KosOverviewState {
  final int occupiedRooms;
  final int availableRooms;
  final String incomeFormatted;
  final String expenseFormatted;
  final String unpaidAmountFormatted;
  final num income;
  final num expense;
  final num unpaidAmount;
  final List<dynamic>? upcomingPayments;
  final List<PaymentEntity> latestPayments;
  final List<OverdueEntity> overdues;
  final List<ActivityEntity> recentActivities;
  final List<FlSpot> chartSpots;

  const KosOverviewLoaded({
    required this.occupiedRooms,
    required this.availableRooms,
    required this.incomeFormatted,
    required this.expenseFormatted,
    required this.unpaidAmountFormatted,
    required this.income,
    required this.expense,
    required this.unpaidAmount,
    this.upcomingPayments,
    required this.latestPayments,
    required this.overdues,
    this.recentActivities = const [],
    this.chartSpots = const [],
  });
}

class KosOverviewError extends KosOverviewState {
  final String message;

  const KosOverviewError({required this.message});
}