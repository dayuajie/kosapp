import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/occupancy_entity.dart';
import 'occupancy_repository.dart';

class SupabaseOccupancyRepository implements OccupancyRepository {
  final SupabaseClient _client;

  SupabaseOccupancyRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  // ===========================================================================
  // REGION: READ
  // ===========================================================================

  @override
  Future<List<OccupancyEntity>> fetchOccupiedOccupancies({
    required String kosId,
  }) async {
    final raw = await _client
        .from('occupancies')
        .select('id, room_id, kos_id, status, tenant_id, start_date, end_date, created_at')
        .eq('kos_id', kosId)
        .eq('status', 'occupied')
        .order('created_at', ascending: false);


    final rows = (raw as List?)?.cast<Map<String, dynamic>>() ?? [];
    return rows.map(_mapToEntity).toList();
  }

  @override
  Future<Set<String>> fetchOccupiedRoomIds({
    required String kosId,
  }) async {
    final raw = await _client
        .from('occupancies')
        .select('room_id')
        .eq('kos_id', kosId)
        .eq('status', 'occupied');

    final rows = (raw as List?)?.cast<Map<String, dynamic>>() ?? [];
    return rows
        .map((r) => r['room_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  @override
  Future<OccupancyEntity?> fetchActiveOccupancyByRoom({
    required String roomId,
    required String kosId,
  }) async {
    final raw = await _client
        .from('occupancies')
        .select('id, room_id, kos_id, status, tenant_id, start_date, end_date, created_at')
        .eq('room_id', roomId)
        .eq('kos_id', kosId)
        .eq('status', 'occupied')
        .maybeSingle();

    if (raw == null) return null;
    return _mapToEntity(raw as Map<String, dynamic>);
  }

  @override
  Future<List<OccupancyEntity>> fetchOccupanciesByTenant({
    required String tenantId,
    required String kosId,
  }) async {
    final raw = await _client
        .from('occupancies')
        .select('id, room_id, kos_id, status, tenant_id, start_date, end_date, created_at')
        .eq('tenant_id', tenantId)
        .eq('kos_id', kosId)
        .order('start_date', ascending: false);

    final rows = (raw as List?)?.cast<Map<String, dynamic>>() ?? [];
    return rows.map(_mapToEntity).toList();
  }

  @override
  Future<OccupancyEntity> createOccupancy({
    required String roomId,
    required String kosId,
    required String tenantId,
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    // Guard: pastikan kamar belum terisi
    final existing = await fetchActiveOccupancyByRoom(
      roomId: roomId,
      kosId: kosId,
    );
    if (existing != null) {
      throw StateError(
        'Kamar $roomId sudah berstatus occupied (occupancy id: ${existing.id}). '
        'Selesaikan penghunian sebelumnya terlebih dahulu.',
      );
    }

    final payload = <String, dynamic>{
      'room_id': roomId,
      'kos_id': kosId,
      'tenant_id': tenantId,
      'status': 'occupied',
      'start_date': startDate.toIso8601String(),
      if (endDate != null) 'end_date': endDate.toIso8601String(),
    };

    final res = await _client
        .from('occupancies')
        .insert(payload)
        .select('id, room_id, kos_id, status, tenant_id, start_date, end_date, created_at')
        .single();

    return _mapToEntity(res as Map<String, dynamic>);
  }

  @override
  Future<void> updateOccupancyStatus({
    required String occupancyId,
    required String status,
    DateTime? endDate,
  }) async {
    _assertValidStatus(status);

    final payload = <String, dynamic>{
      'status': status,
      if (endDate != null) 'end_date': endDate.toIso8601String(),
    };

    await _client
        .from('occupancies')
        .update(payload)
        .eq('id', occupancyId);
  }

  @override
  Future<void> deleteOccupanciesByRoom({
    required String roomId,
  }) async {
    await _client
        .from('occupancies')
        .delete()
        .eq('room_id', roomId);
  }

  @override
  Future<void> deleteOccupancyById({
    required String occupancyId,
  }) async {
    await _client
        .from('occupancies')
        .delete()
        .eq('id', occupancyId);
  }

  // ===========================================================================
  // REGION: PRIVATE HELPERS
  // ===========================================================================

  /// Mapping dari raw Supabase row ke [OccupancyEntity].
  OccupancyEntity _mapToEntity(Map<String, dynamic> r) {
    return OccupancyEntity(
      id: r['id'].toString(),
      roomId: r['room_id'].toString(),
      kosId: r['kos_id'].toString(),
      status: (r['status'] ?? 'vacant').toString(),
      tenantId: r['tenant_id']?.toString(),
      startDate: _parseDate(r['start_date']),
      endDate: _parseDate(r['end_date']),
      createdAt: _parseDate(r['created_at']),
      updatedAt: _parseDate(r['updated_at']),
    );
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw.toString());
  }

  void _assertValidStatus(String status) {
    const validStatuses = {'occupied', 'vacant', 'reserved'};
    if (!validStatuses.contains(status)) {
      throw ArgumentError(
        'Status "$status" tidak valid. Gunakan salah satu dari: ${validStatuses.join(', ')}.',
      );
    }
  }
  @
Future<void> createOccupancy({
  required String tenantId,
  required String roomId,
  required String kosId,
  DateTime? startDate,
  DateTime? endDate,
  String status = 'occupied',
}) async {
  final data = <String, dynamic>{
    'tenant_id': tenantId,
    'room_id': roomId,
    'status': status,
    'kos_id': kosId,
  };

  if (startDate != null) data['start_date'] = startDate.toIso8601String();
  if (endDate != null) data['end_date'] = endDate.toIso8601String();

  await _client.from('occupancies').insert(data);
}
Future<bool> checkoutByTenantId({
  required String tenantId,
  DateTime? endDate,
}) async {
  final resolvedEndDate = endDate ?? DateTime.now();

  final updated = await _client
      .from('occupancies')
      .update({
        'status': 'checked_out',
        'check_out': resolvedEndDate.toIso8601String(),
      })
      .eq('tenant_id', tenantId)
      .eq('status', 'occupied')
      .select('id');

  return updated.isNotEmpty;
}
Future<void> deleteAllForTenant(String tenantId) async {
  await _client.from('occupancies').delete().eq('tenant_id', tenantId);
}
}