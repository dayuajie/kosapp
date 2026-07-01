
import 'package:supabase_flutter/supabase_flutter.dart';




class SupabaseKosRepository {
  final SupabaseClient _client;
  SupabaseKosRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;
  String? get currentUserId => _client.auth.currentUser?.id;
  // ===========================================================================
  // REGION: HELPERS SESSION (KOS ID)
  // ===========================================================================
  String? get currentKosId =>
      _client.auth.currentUser?.userMetadata?['kos_id']?.toString();

  String requireCurrentKosId() {
    final v = currentKosId;
    if (v == null || v.isEmpty) {
      throw StateError('kos_id tidak ditemukan di userMetadata auth.');
    }
    return v;
  }
  Future<List<Map<String, dynamic>>> fetchKosByOwner(String ownerId) async {
    return await _client
        .from('kos')
        .select('id, name, phone, address, capacities, owner_id, created_at')
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false);
  }

  /// Membuat record kos baru ke tabel `kos`.
  Future<String> createKos({
    required String name,
    required String address,
    required String phone,
    required String capacities,
    required String ownerId,
  }) async {
    final payload = {
      'name': name,
      'address': address,
      'phone': phone,
      'capacities': capacities,
      'owner_id': ownerId,
    };

    final res = await _client
        .from('kos')
        .insert(payload)
        .select('id')
        .single();

    return res['id'].toString();
  }
}