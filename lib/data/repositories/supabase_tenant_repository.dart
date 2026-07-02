import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app/b2_config.dart';
import '../../domain/entities/tenant_entity.dart';
import '../../data/repositories/supabase_occupancy_repository.dart';
import '../services/b2_signed_url_service.dart';
import 'b2_tenant_photo_repository.dart';

/// Repository untuk mengelola data penghuni (tenant) dan riwayat hunian menggunakan Supabase Client.
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

  // ===========================================================================
  // REGION: TENANTS (PENGHUNI)
  // ===========================================================================

  /// Mengambil data satu profil penghuni berdasarkan ID.
  /// Termasuk join occupancies -> rooms untuk data kamar aktif.
  Future<TenantEntity?> fetchTenantById(String tenantId) async {
  final Map<String, dynamic>? rawTenant = await _client
      .from('tenants')
      .select(
        'id, full_name, phone, address, id_card_number, idcard_url, tenants_url, '
        'emergency_name, emergency_phone,check_out, '
        'occupancies!left(room_id, start_date, end_date, status, price, rent_type, '
        'rooms!room_id(name))',
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
        'occupancies!left(room_id, start_date, end_date, status, price, rent_type, '
        'rooms!room_id(name))',
      )
      .eq('kos_id', activeKosId)
      .order('full_name');

      for (final r in rows) {
      // ignore: avoid_print
      print('[TenantRepo] ${r['full_name']} -> occupancies=${r['occupancies']}');
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

  // Simpan tanggal checkout permanen di tabel tenants
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
    final activeOnes = list.where((o) => (o['status'] ?? '') == 'occupied');
    if (activeOnes.isNotEmpty) {
      occ = activeOnes.first;
    } else {
      final sorted = [...list]
        ..sort((a, b) {
          final da = DateTime.tryParse((a['start_date'] ?? '').toString());
          final db = DateTime.tryParse((b['start_date'] ?? '').toString());
          if (da == null || db == null) return 0;
          return db.compareTo(da);
        });
      occ = sorted.first;
    }
  } else if (occupanciesRaw is Map) {
    occ = occupanciesRaw.cast<String, dynamic>();
  }

  if (occ != null) {
    result['start_date'] = occ['start_date'];
    result['end_date'] = occ['end_date'];
    result['payment_status'] = occ['status'];
    result['rent_price'] = occ['price'];
    result['rent_type'] = occ['rent_type'];

    final roomRaw = occ['rooms'];
    if (roomRaw is Map) {
      final room = roomRaw.cast<String, dynamic>();
      result['room_name'] = room['name'];
    }
  }

  return result;
}

  /// Membuat data penghuni baru sekaligus mendaftarkannya ke dalam kamar tertentu.
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

  /// Membuat record data penghuni saja tanpa langsung memasukkannya ke kamar.
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
    String? idCardUrl,
  }) async {
    final payload = <String, dynamic>{
      'tenants_url': tenantsUrl,
      'idcard_url': idCardUrl,
    };

    payload.removeWhere((_, value) => value == null);
    if (payload.isEmpty) return;

    await _client.from('tenants').update(payload).eq('id', tenantId);
  }

  /// Memperbarui informasi data teks dasar (non-gambar) milik penghuni.
  Future<void> updateTenantBasic({
    required String tenantId,
    String? fullName,
    String? phone,
    String? address,
    String? idNumber,
    String? emergencyName,
    String? emergencyPhone,
  }) async {
    final payload = <String, dynamic>{
      'address': address,
      'full_name': fullName,
      'phone': phone,
      'id_card_number': idNumber,
      'emergency_name': emergencyName,
      'emergency_phone': emergencyPhone,
    };

    payload.removeWhere((_, value) => value == null);
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
  // REGION: OCCUPANIES (RIWAYAT HUNI)
  // ===========================================================================

  /// Membuat riwayat penempatan kamar (`occupancy`) baru untuk penghuni yang sudah ada.
  

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
final moveIn = r['move_in_date'] ?? r['start_date'];
final rentPrice = r['rent_price'] ?? r['price'] ?? r['monthly_price'];
final paymentStatus = r['payment_status'] ?? r['status'];
final plannedEnd = r['end_date'];      // tanggal rencana keluar sewa (dari occupancy)
final actualCheckOut = r['check_out']; // checkout aktual (dari tenants.check_out)

DateTime? parsedMoveIn;
if (moveIn is String) {
  parsedMoveIn = DateTime.tryParse(moveIn);
} else if (moveIn is DateTime) {
  parsedMoveIn = moveIn;
}

DateTime? parsedEndDate;
if (plannedEnd is String) {
  parsedEndDate = DateTime.tryParse(plannedEnd);
} else if (plannedEnd is DateTime) {
  parsedEndDate = plannedEnd;
}

DateTime? parsedCheckOut;
if (actualCheckOut is String) {
  parsedCheckOut = DateTime.tryParse(actualCheckOut);
} else if (actualCheckOut is DateTime) {
  parsedCheckOut = actualCheckOut;
}

int? parsedRentPrice;
if (rentPrice != null) {
  parsedRentPrice = int.tryParse(rentPrice.toString());
}

return TenantEntity(
  id: r['id'].toString(),
  fullName: (r['full_name'] ?? '').toString(),
  phone: r['phone']?.toString(),
  room: room?.toString(),
  moveInDate: parsedMoveIn,
  endDate: parsedEndDate,        // <-- tambahkan ini
  checkOutDate: parsedCheckOut,  // <-- sekarang benar dari tenants.check_out
  rentPrice: parsedRentPrice,
  paymentStatus: paymentStatus?.toString(),
  emergencyContact: emergencyContact,
  address: r['address']?.toString(),
  idCardNumber: r['id_card_number']?.toString(),
  tenantsUrl: signedTenantsUrl,
  idCardUrl: signedIdCardUrl,
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
      return B2SignedUrlService().getSignedDownloadUrl(
        bucketName: bucketName,
        objectName: objectName,
      );
    }

    return B2SignedUrlService().getSignedDownloadUrl(
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