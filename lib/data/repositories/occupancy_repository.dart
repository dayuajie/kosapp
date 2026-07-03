import '../../domain/entities/occupancy_entity.dart';
abstract class OccupancyRepository {
  Future<List<OccupancyEntity>> fetchOccupiedOccupancies({
    required String kosId,
  });
  Future<Set<String>> fetchOccupiedRoomIds({
    required String kosId,
  });
  Future<OccupancyEntity?> fetchActiveOccupancyByRoom({
    required String roomId,
    required String kosId,
  });

  Future<List<OccupancyEntity>> fetchOccupanciesByTenant({
    required String tenantId,
    required String kosId,
  });
  Future<OccupancyEntity> createOccupancy({
  required String roomId,
  required String kosId,
  required String tenantId,
  required DateTime startDate,
  DateTime? endDate,
  String? price,
  String? rentType,
  String? paymentStatus,
  String? paymentMethod,
  String? paidAmount,
  String? notes,
});
  Future<void> updateOccupancyStatus({
    required String occupancyId,
    required String status,
    DateTime? endDate,
  });

  Future<void> updatePaymentStatus({
    required String occupancyId,
    required String paymentStatus,
    String? paidAmount,
  });

  Future<void> deleteOccupanciesByRoom({
    required String roomId,
  });

  Future<void> deleteOccupancyById({
    required String occupancyId,
  });
}