import 'package:kos_app/domain/entities/payment_context.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/occupancy_entity.dart';
import 'occupancy_repository.dart';

class SupabaseOccupancyRepository implements OccupancyRepository {
  final SupabaseClient _client;

  SupabaseOccupancyRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  @override
  Future<List<OccupancyEntity>> fetchOccupiedOccupancies({
    required String kosId,
  }) async {
    final raw = await _client
        .from('occupancies')
        .select(
          'id, room_id, kos_id, status, tenant_id, start_date, end_date, '
          'created_at, price, rent_type, payment_status, paid_amount',
        )
        .eq('kos_id', kosId)
        .eq('status', 'occupied')
        .order('created_at', ascending: false);

    final rows = (raw as List?)?.cast<Map<String, dynamic>>() ?? [];
    return rows.map(_mapToEntity).toList();
  }

  @override
  Future<Set<String>> fetchOccupiedRoomIds({required String kosId}) async {
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
        .select(
          'id, room_id, kos_id, status, tenant_id, start_date, end_date, created_at',
        )
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
        .select(
          'id, room_id, kos_id, status, tenant_id, start_date, end_date, created_at',
        )
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
    String? price,
    String? rentType,
    String? paymentStatus,
    String? paymentMethod,
    String? paidAmount,
    String? notes,
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
      if (price != null) 'price': price,
      if (rentType != null) 'rent_type': rentType,
      if (paymentStatus != null) 'payment_status': paymentStatus,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (paidAmount != null) 'paid_amount': paidAmount,
      if (notes != null) 'notes': notes,
    };

    final res = await _client
        .from('occupancies')
        .insert(payload)
        .select(
          'id, room_id, kos_id, status, tenant_id, start_date, end_date, created_at',
        )
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

    await _client.from('occupancies').update(payload).eq('id', occupancyId);
  }

  @override
  Future<void> updatePaymentStatus({
    required String occupancyId,
    required String paymentStatus,
    String? paidAmount,
  }) async {
    final payload = <String, dynamic>{
      'payment_status': paymentStatus,
      if (paidAmount != null) 'paid_amount': paidAmount,
    };
    await _client.from('occupancies').update(payload).eq('id', occupancyId);
  }

  @override
  Future<void> deleteOccupanciesByRoom({required String roomId}) async {
    await _client.from('occupancies').delete().eq('room_id', roomId);
  }

  @override
  Future<void> deleteOccupancyById({required String occupancyId}) async {
    await _client.from('occupancies').delete().eq('id', occupancyId);
  }


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
      price: r['price']?.toString(),
      rentType: r['rent_type']?.toString(),
      paymentStatus: r['payment_status']?.toString(),
      paidAmount: r['paid_amount']?.toString(),
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

  Future<OccupancyEntity?> fetchActiveOccupancyByTenant(String tenantId) async {
  final raw = await _client
      .from('occupancies')
      .select(
        'id, room_id, kos_id, status, tenant_id, start_date, end_date, created_at, '
        'price, rent_type, payment_status, paid_amount'
      )
      .eq('tenant_id', tenantId)
      .eq('status', 'occupied')
      .maybeSingle();
print('fetchActiveOccupancyByTenant raw: $raw');
  if (raw == null) return null;
  return _mapToEntity(raw as Map<String, dynamic>);
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
  Future<void> extendOccupancy({
    required String occupancyId,
    required DateTime newEndDate,
    String? price,
    String? rentType,
  }) async {
    final payload = <String, dynamic>{
      'end_date': newEndDate.toIso8601String(),
      if (price != null) 'price': price,
      if (rentType != null) 'rent_type': rentType,
      'payment_status' :'pending','paid_amount':null,
    };
    await _client
    .from('occupancies')
    .update(payload)
    .eq ('id', occupancyId);
  }
  Future<void> extendOccupancyWithPayment({
  required String occupancyId,
  required DateTime newEndDate,
  required double price,
  String? rentType,
  required PaymentStatus paymentStatus,
  double? paidAmount,
  String? paymentMethod,
  String? notes,
}) async {
  final payload = <String, dynamic>{
    'end_date': newEndDate.toIso8601String(),
    'price': price.toString(),
    if (rentType != null) 'rent_type': rentType,
    'payment_status': _paymentStatusToString(paymentStatus),
    if (paidAmount != null) 'paid_amount': paidAmount.toString(),
    if (paymentMethod != null) 'payment_method': paymentMethod,
    if (notes != null) 'notes': notes,
    'updated_at': DateTime.now().toIso8601String(),
  };

  await _client
      .from('occupancies')
      .update(payload)
      .eq('id', occupancyId);
}

/// Catat pembayaran partial/cicilan
Future<void> recordPartialPayment({
  required String occupancyId,
  required double amount,
  required String method,
  String? note,
}) async {
  // 1. Ambil data occupancy saat ini
  final current = await _client
      .from('occupancies')
      .select('price, paid_amount, payment_status')
      .eq('id', occupancyId)
      .single();

  final totalPrice = double.tryParse(current['price']?.toString() ?? '0') ?? 0;
  final currentPaid = double.tryParse(current['paid_amount']?.toString() ?? '0') ?? 0;
  final newPaid = currentPaid + amount;

  // 2. Update status berdasarkan pembayaran
  String newStatus;
  if (newPaid >= totalPrice) {
    newStatus = 'lunas';
  } else if (newPaid > 0) {
    newStatus = 'dicicil';
  } else {
    newStatus = 'pending';
  }

  // 3. Update occupancy
  await _client.from('occupancies').update({
    'paid_amount': newPaid.toString(),
    'payment_status': newStatus,
    'payment_method': method,
    'updated_at': DateTime.now().toIso8601String(),
  }).eq('id', occupancyId);

  // 4. Simpan history pembayaran (jika ada tabel payment_history)
  // await _client.from('payment_history').insert({
  //   'occupancy_id': occupancyId,
  //   'amount': amount,
  //   'method': method,
  //   'note': note,
  //   'created_at': DateTime.now().toIso8601String(),
  // });
}

/// Get payment summary untuk tenant
Future<({double totalDue, double totalPaid, double remaining, String status, int? daysOverdue})> 
  getPaymentSummary(String occupancyId) async {
  
  final data = await _client
      .from('occupancies')
      .select('price, paid_amount, payment_status, end_date')
      .eq('id', occupancyId)
      .single();

  final price = double.tryParse(data['price']?.toString() ?? '0') ?? 0;
  final paid = double.tryParse(data['paid_amount']?.toString() ?? '0') ?? 0;
  final status = data['payment_status']?.toString() ?? 'pending';
  final endDate = _parseDate(data['end_date']);

  int? daysOverdue;
  if (endDate != null && endDate.isBefore(DateTime.now()) && status != 'lunas') {
    daysOverdue = DateTime.now().difference(endDate).inDays;
  }

  return (
    totalDue: price,
    totalPaid: paid,
    remaining: price - paid,
    status: status,
    daysOverdue: daysOverdue,
  );
}

String _paymentStatusToString(PaymentStatus status) {
  switch (status) {
    case PaymentStatus.pending: return 'pending';
    case PaymentStatus.partial: return 'dicicil';
    case PaymentStatus.paid: return 'lunas';
    case PaymentStatus.overdue: return 'overdue';
  }
}
}
