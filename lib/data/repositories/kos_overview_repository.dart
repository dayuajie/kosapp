import '../../domain/entities/kos_overview_entity.dart';

abstract class KosOverviewRepository {
  Future<KosOverviewEntity> fetchOverview({
    required String kosId,
    DateTime? from,
    DateTime? to,
  });
}