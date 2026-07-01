
class OccupancyEntity {
  final String id;
  final String roomId;
  final String kosId;
  final String status;
  final String? tenantId;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  const OccupancyEntity({
    required this.id,
    required this.roomId,
    required this.kosId,
    required this.status,
    this.tenantId,
    this.startDate,
    this.endDate,
    this.createdAt,
    this.updatedAt,
  });

  bool get isOccupied => status == 'occupied';
  bool get isVacant => status == 'vacant';
  bool get isReserved => status == 'reserved';
  OccupancyEntity copyWith({
    String? id,
    String? roomId,
    String? kosId,
    String? status,
    String? tenantId,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OccupancyEntity(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      kosId: kosId ?? this.kosId,
      status: status ?? this.status,
      tenantId: tenantId ?? this.tenantId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'OccupancyEntity(id: $id, roomId: $roomId, status: $status, tenantId: $tenantId)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OccupancyEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}