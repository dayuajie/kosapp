import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app/b2_config.dart';
import '../../domain/entities/tenant_entity.dart';
import '../../data/repositories/supabase_occupancy_repository.dart';
import '../services/b2_signed_url_service.dart';
import 'b2_tenant_photo_repository.dart';

/// Repository untuk mengelola data penghuni (tenant) dan riwayat hunian menggunakan Supabase Client.
const _kUnset = '___UNSET___';
class SupabaseTenantRepository {
  final SupabaseClient _client;
  final SupabaseOccupancyRepository _occupancyRepo;

  SupabaseTenantRepository({
    SupabaseClient? client,
    SupabaseOccupancyRepository? occupancyRepo,
  })  : _client = client ?? Supabase.instance.client,
        _occupancyRepo = occupancyRepo ?? SupabaseOccupancyRepository();

  // Helper untuk mendapatkan kos_id dari metadata auth user aktif jika diperlukan
  String _requireCurrentKosId() {
    final kosId = _client.auth.currentUser?.userMetadata?['kos_id']?.toString();
    if (kosId == null || kosId.isEmpty) {
      throw StateError('kos_id tidak ditemukan di userMetadata auth.');
    }
    return kosId;
  }

  Future<TenantEntity?> fetchTenantById(String tenantId) async {
  final Map<String, dynamic>? rawTenant = await _client
      .from('tenants')
      .select(
        'id, full_name, phone, address, id_card_number, tenants_url, idcard_url, '
        'emergency_name, emergency_phone, created_at, kos_id, check_out, '
        'occupancies!left(room_id, start_date, end_date, status, price, rent_type, payment_status, paid_amount, rooms!room_id(name))',
      )
      .eq('id', tenantId)
      .maybeSingle();

    if (rawTenant == null) return null;

    return await _mapToTenantEntity(_flattenOccupancy(rawTenant));
  }

  Future<List<TenantEntity>> fetchTenants() async {
  final activeKosId = _requireCurrentKosId();
  final List<Map<String, dynamic>> rows = await _client
      .from('tenants')
      .select(
        'id, full_name, phone, address, id_card_number, tenants_url, idcard_url, '
        'emergency_name, emergency_phone, created_at, kos_id, check_out, '
        'occupancies!left(room_id, start_date, end_date, status, price, rent_type, payment_status, paid_amount, rooms!room_id(name))',
      )
      .eq('kos_id', activeKosId)
      .order('full_name');

      for (final r in rows) {

    }

    final signedTenants = await Future.wait(
      rows.map((r) => _mapToTenantEntity(_flattenOccupancy(r))),
    );

    return signedTenants;
  }

  Future<void> checkoutTenant({
  required String tenantId,
  DateTime? endDate,
}) async {
  final resolvedEndDate = endDate ?? DateTime.now();

  await _client
      .from('occupancies')
      .update({
        'status': 'checked_out',
        'check_out': resolvedEndDate.toIso8601String(),
      })
      .eq('tenant_id', tenantId)
      .eq('status', 'occupied');

  
  await _client
      .from('tenants')
      .update({'check_out': resolvedEndDate.toIso8601String()})
      .eq('id', tenantId);
}

  Map<String, dynamic> _flattenOccupancy(Map<String, dynamic> raw) {
  final result = Map<String, dynamic>.from(raw);
  final occupanciesRaw = raw['occupancies'];
  Map<String, dynamic>? occ;

  if (occupanciesRaw is List && occupanciesRaw.isNotEmpty) {
    final list = occupanciesRaw.cast<Map<String, dynamic>>();
    // Cari yang statusnya occupied
    final activeOnes = list.where((o) => (o['status'] ?? '') == 'occupied').toList();
    if (activeOnes.isNotEmpty) {
      occ = activeOnes.first;
    } else {
      // ambil yang terbaru berdasarkan start_date
      final sorted = [...list]..sort((a, b) {
        final da = DateTime.tryParse((a['start_date'] ?? '').toString());
        final db = DateTime.tryParse((b['start_date'] ?? '').toString());
        if (da == null || db == null) return 0;
        return db.compareTo(da);
      });
      occ = sorted.first;
    }
  } else if (occupanciesRaw is Map) {
    occ = occupanciesRaw.cast<String, dynamic>();
    // pastikan statusnya occupied, kalau tidak, mungkin abaikan?
  }

  if (occ != null) {
    result['start_date'] = occ['start_date'];
    result['end_date'] = occ['end_date'];
    result['price'] = occ['price'];
    result['rent_type'] = occ['rent_type'];
    result['occupancy_id'] = occ['id']; // <-- pastikan ini terisi
    result['room_id'] = occ['room_id'];
    result['payment_status'] = occ['payment_status'];
    result['paid_amount'] = occ['paid_amount'];

    final roomRaw = occ['rooms'];
    if (roomRaw is Map) {
      final room = roomRaw.cast<String, dynamic>();
      result['room_name'] = room['name'];
    }
  }

  return result;
}

  
  Future<void> createTenantAndOccupancy({
    required String fullName,
    required String phone,
    required String roomId,
    required String kosId,
    String? address,
    String? idNumber,
    String? tenantsUrl,
    String? idCardUrl,
    String? emergencyName,
    String? emergencyPhone,
    String? createdBy,
  }) async {
    final tenantInsertRes = await _client
        .from('tenants')
        .insert({
          'full_name': fullName,
          'phone': phone,
          'address': address,
          'emergency_name': emergencyName,
          'emergency_phone': emergencyPhone,
          'id_card_number': idNumber,
          'tenants_url': tenantsUrl,
          'idcard_url': idCardUrl,
          'created_by': createdBy,
          'kos_id': kosId,
        })
        .select('id')
        .single();

    final tenantId = tenantInsertRes['id'].toString();

    
    
  }

  
  Future<String> createTenant({
    required String fullName,
    required String phone,
    required String kosId,
    String? address,
    String? idNumber,
    String? emergencyName,
    String? emergencyPhone,
    String? tenantsUrl,
    String? idCardUrl,
  }) async {
    final payload = <String, dynamic>{
      'full_name': fullName,
      'phone': phone,
      'address': address,
      'id_card_number': idNumber,
      'emergency_name': emergencyName,
      'emergency_phone': emergencyPhone,
      'kos_id': kosId,
      'tenants_url': tenantsUrl,
      'idcard_url': idCardUrl,
    };

    payload.removeWhere((_, value) => value == null);

    final tenantInsertRes = await _client
        .from('tenants')
        .insert(payload)
        .select('id')
        .single();

    return tenantInsertRes['id'].toString();
  }

  /// Mengupload foto tenant ke Backblaze B2 (bucket: koskita-tenants)
  Future<String> uploadTenantPhoto({
    required String tenantId,
    required File file,
  }) async {
    return B2TenantPhotoRepository().tenantPhotoObjectPath(
      tenantId: tenantId,
      file: file,
    );
  }

  /// Mengupload foto KTP ke Backblaze B2 (bucket: koskita-idcard)
  Future<String> uploadIdCardPhoto({
    required String tenantId,
    required File file,
  }) async {
    return B2TenantPhotoRepository().idCardPhotoObjectPath(
      tenantId: tenantId,
      file: file,
    );
  }

  /// Memperbarui tautan URL gambar (Foto Profil / KTP) milik penghuni.
  Future<void> updateTenantPhotos({
    required String tenantId,
    String? tenantsUrl,
    bool clearTenantsUrl = false,
    String? idCardUrl,
    bool clearIdCardUrl = false,
  }) async {
    final payload = <String, dynamic>{};

    if (tenantsUrl != null) {
      payload['tenants_url'] = tenantsUrl;
    } else if (clearTenantsUrl) {
      payload['tenants_url'] = null;
    }
    if (idCardUrl != null) {
      payload['idcard_url'] = idCardUrl;
    } else if (clearIdCardUrl) {
      payload['idcard_url'] = null;
    }

    if (payload.isEmpty) return;

    await _client.from('tenants').update(payload).eq('id', tenantId);
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
      'payment_status': 'pending',
      'paid_amount': null,
    };

    await _client.from('occupancies').update(payload).eq('id', occupancyId);
  }

  /// Memperbarui informasi data teks dasar (non-gambar) milik penghuni.
  Future<void> updateTenantBasic({
    required String tenantId,
    String? fullName,
    bool clearFullName = false,
    String? phone,
    bool clearPhone = false,
    String? address,
    bool clearAddress = false,
    String? idNumber,
    bool clearIdNumber = false,
    String? emergencyName,
    bool clearEmergencyName = false,
    String? emergencyPhone,
    bool clearEmergencyPhone = false,
  }) async {
    final payload = <String, dynamic>{};

    if (fullName != null) {
      payload['full_name'] = fullName;
    } else if (clearFullName) {
      payload['full_name'] = null;
    }

    if (phone != null) {
      payload['phone'] = phone;
    } else if (clearPhone) {
      payload['phone'] = null;
    }

    if (address != null) {
      payload['address'] = address;
    } else if (clearAddress) {
      payload['address'] = null;
    }

    if (idNumber != null) {
      payload['id_card_number'] = idNumber;
    } else if (clearIdNumber) {
      payload['id_card_number'] = null;
    }

    if (emergencyName != null) {
      payload['emergency_name'] = emergencyName;
    } else if (clearEmergencyName) {
      payload['emergency_name'] = null;
    }

    if (emergencyPhone != null) {
      payload['emergency_phone'] = emergencyPhone;
    } else if (clearEmergencyPhone) {
      payload['emergency_phone'] = null;
    }

    if (payload.isEmpty) return;

    await _client.from('tenants').update(payload).eq('id', tenantId);
  }

  /// Menghapus data tenant beserta file foto terkait di B2 Cloud Storage.
  Future<void> deleteTenant({required String tenantId}) async {
    final tenant = await fetchTenantById(tenantId);
    if (tenant == null) return;

    final tenantPhotoObjectName = _extractB2ObjectName(tenant.tenantsUrl);
    final idCardPhotoObjectName = _extractB2ObjectName(tenant.idCardUrl);

    final photoRepo = B2TenantPhotoRepository();

    try {
      await photoRepo.deleteTenantPhotoByObjectPath(
        tenantsUrlPath: tenantPhotoObjectName,
      );
    } catch (_) {}

    try {
      await photoRepo.deleteIdCardPhotoByObjectPath(
        idCardUrlPath: idCardPhotoObjectName,
      );
    } catch (_) {}

    try {
      await _client.from('occupancies').delete().eq('tenant_id', tenantId);
    } catch (_) {}

    await _client.from('tenants').delete().eq('id', tenantId);
  }

 
  // ===========================================================================
  // REGION: HELPER UTILITIES (FUNGSI PEMBANTU PRIVAT)
  // ===========================================================================

  Future<TenantEntity> _mapToTenantEntity(Map<String, dynamic> r) async {
  final signedTenantsUrl = await _toSignedUrlIfNeeded(
    r['tenants_url']?.toString(),
    bucketName: B2Config.bucketTenantPhoto,
  );

  final signedIdCardUrl = await _toSignedUrlIfNeeded(
    r['idcard_url']?.toString(),
    bucketName: B2Config.bucketIdCardPhoto,
  );

  final emergencyContact = (() {
    final name = (r['emergency_name'] ?? '').toString().trim();
    final phone = (r['emergency_phone'] ?? '').toString().trim();
    if (name.isEmpty && phone.isEmpty) return null;
    if (name.isEmpty) return phone;
    if (phone.isEmpty) return name;
    return '$name/$phone';
  })();

  final room = r['room'] ?? r['room_name'] ?? r['room_id'];
  final roomId = r['room_id']?.toString();
  final moveIn = r['move_in_date'] ?? r['start_date'];
  final rentPrice = r['rent_price'] ?? r['price'] ?? r['monthly_price'];
  
  // 👇 AMBIL LANGSUNG DARI HASIL FLATTEN
  final paymentStatus = r['payment_status']?.toString();
  final rentType = r['rent_type']?.toString();
  final occupancyId = r['occupancy_id']?.toString();

  DateTime? parsedMoveIn;
  if (moveIn is String) {
    parsedMoveIn = DateTime.tryParse(moveIn);
  } else if (moveIn is DateTime) {
    parsedMoveIn = moveIn;
  }

  DateTime? parsedEndDate;
  final plannedEnd = r['end_date'];
  if (plannedEnd is String) {
    parsedEndDate = DateTime.tryParse(plannedEnd);
  } else if (plannedEnd is DateTime) {
    parsedEndDate = plannedEnd;
  }

  DateTime? parsedCheckOut;
  final actualCheckOut = r['check_out'];
  if (actualCheckOut is String) {
    parsedCheckOut = DateTime.tryParse(actualCheckOut);
  } else if (actualCheckOut is DateTime) {
    parsedCheckOut = actualCheckOut;
  }

  int? parsedRentPrice;
  if (rentPrice != null) {
    parsedRentPrice = int.tryParse(rentPrice.toString());
  }

  DateTime? parsedCreatedAt;
  final createdAtRaw = r['created_at'];
  if (createdAtRaw is String) {
    parsedCreatedAt = DateTime.tryParse(createdAtRaw);
  } else if (createdAtRaw is DateTime) {
    parsedCreatedAt = createdAtRaw;
  }

  return TenantEntity(
    id: r['id'].toString(),
    fullName: (r['full_name'] ?? '').toString(),
    phone: r['phone']?.toString(),
    room: room?.toString(),
    roomId:roomId,
    moveInDate: parsedMoveIn,
    endDate: parsedEndDate,
    checkOutDate: parsedCheckOut,
    rentPrice: parsedRentPrice,
    rentType: rentType,             
    paymentStatus: paymentStatus,
    emergencyContact: emergencyContact,
    address: r['address']?.toString(),
    idCardNumber: r['id_card_number']?.toString(),
    tenantsUrl: signedTenantsUrl,
    idCardUrl: signedIdCardUrl,
    occupancyId: occupancyId,
  );
}

DateTime? _parseDynamicDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString());
}

  Future<String?> _toSignedUrlIfNeeded(
    String? storedUrlOrPath, {
    required String bucketName,
  }) async {
    if (storedUrlOrPath == null) return null;
    final v = storedUrlOrPath.trim();
    if (v.isEmpty) return v;

    if (v.contains('Authorization=')) return v;

    final uri = Uri.tryParse(v);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      final objectName = uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;
      return B2SignedUrlService.instance.getSignedDownloadUrl(
        bucketName: bucketName,
        objectName: objectName,
      );
    }

    return B2SignedUrlService.instance.getSignedDownloadUrl(
      bucketName: bucketName,
      objectName: v,
    );
  }

  String? _extractB2ObjectName(String? storedUrlOrPath) {
    final v = (storedUrlOrPath ?? '').trim();
    if (v.isEmpty) return null;

    final uri = Uri.tryParse(v);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      return uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;
    }

    return v;
  }
}