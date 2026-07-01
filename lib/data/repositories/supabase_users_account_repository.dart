import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseUsersAccountRepository {
  final SupabaseClient _client;

  SupabaseUsersAccountRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<Map<String, dynamic>?> fetchUserProfile() async {
  final user = _client.auth.currentUser;
  if (user == null) return null;
  return {
    'Email': user.email ?? '',
  };
}


  Future<Map<String, dynamic>?> fetchAccountStatus() async {
  final userId = currentUserId;
  if (userId == null || userId.isEmpty) return null;

  try {
    final raw = await _client
        .from('account')
        .select('id, name, role, phone')           
        .eq('id', userId)        
        .maybeSingle();
    return raw;
  } catch (e) {
    return null;
  }
}

  /// Menggabungkan hasil `fetchUserProfile` + `fetchAccountStatus`.
  Future<Map<String, dynamic>?> fetchMeWithStatus() async {
    final userProfile = await fetchUserProfile();
    final accountStatus = await fetchAccountStatus();
    if (userProfile == null && accountStatus == null) return null;
    return {
      'user': userProfile,
      'account': accountStatus,
    };
  }

  /// FUNGSI BARU: Untuk menyimpan perubahan Profil ke Database
  Future<void> updateUserProfile({
    required String name,
    required String phone,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('User not logged in');

    // Update ke tabel `account` (bukan tabel `public.users`, karena yang ada di Supabase adalah auth.users)
    await _client
        .from('account')
        .update({'name': name, 'phone': phone})
        .eq('id', userId);
  }
}