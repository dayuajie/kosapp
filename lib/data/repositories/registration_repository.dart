import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_kos_repository.dart';

/// Repository untuk kebutuhan proses registrasi user baru + provisioning data awal.

///
/// Catatan:
/// - Supabase auth (signUp) dilakukan oleh LoginPage.
/// - Repo ini fokus ke langkah setelah user ada.
class RegistrationRepository {
  final SupabaseClient _client;

  RegistrationRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  // Helper util owner_id
  String _requireOwnerId() {
    final id = _client.auth.currentUser?.id;
    if (id == null || id.isEmpty) {
      throw StateError('owner_id/user belum login.');
    }
    return id;
  }

  /// Membuat kos pertama untuk user yang sedang login, lalu menyetel metadata `kos_id`.
  Future<String> createFirstKosAndSetActive({
    required String nameKos,
    required String address,
    required String phone,
    required int capacity,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw StateError('User belum login.');
    }

    final kosRepo = SupabaseKosRepository(client: _client);
    final kosId = await kosRepo.createKos(
      name: nameKos,
      address: address,
      phone: phone,
      capacities: capacity.toString(),
      ownerId: userId,
    );

    // set kos aktif ke user metadata
    await _client.auth.updateUser(UserAttributes(data: {'kos_id': kosId}));

    return kosId;
  }

  /// Simpan data akun bank / e-wallet milik owner ke tabel `bank_info`.
  ///
  /// Tabel:
  /// `bank_info (id, bank_name, bank_number, bank_account_name, owner_id, bank_type)`
  Future<String> createBankAccount({
    required String bankName,
    required String bankNumber,
    required String bankAccountName,
    required String bankType, // 'Bank' atau 'E-Wallet'
  }) async {
    if (bankType != 'Bank' && bankType != 'E-Wallet') {
      throw ArgumentError.value(
        bankType,
        'bankType',
        "Harus 'Bank' atau 'E-Wallet'",
      );
    }

    // Pastikan input dari UI sudah benar: nama bank/e-wallet + nomor + atas nama
    // (Minimal validation agar error lebih jelas sebelum insert)
    if (bankName.trim().isEmpty) {
      throw ArgumentError('bankName tidak boleh kosong');
    }
    if (bankNumber.trim().isEmpty) {
      throw ArgumentError('bankNumber tidak boleh kosong');
    }
    if (bankAccountName.trim().isEmpty) {
      throw ArgumentError('bankAccountName tidak boleh kosong');
    }

    final ownerId = _client.auth.currentUser?.id ?? _requireOwnerId();

    final payload = <String, dynamic>{
      'bank_name': bankName.trim(),
      'bank_number': bankNumber.trim(),
      'bank_account_name': bankAccountName.trim(),
      'owner_id': ownerId,
      'bank_type': bankType,
    };

    final res = await _client
        .from('bank_info')
        .insert(payload)
        .select('id')
        .maybeSingle();

    if (res == null) {
      // Supabase SDK kadang bisa return null tanpa error jelas.
      // Payload disertakan supaya bisa dicek di tabel.
      throw StateError(
        'Insert bank_info gagal (no row returned). Payload: $payload',
      );
    }

    final id = res['id']?.toString();
    if (id == null || id.isEmpty) {
      throw StateError(
        'Insert bank_info gagal (id kosong). Payload: $payload, res: $res',
      );
    }

    return id;
  }

  /// Fetch semua akun bank / e-wallet milik owner saat ini.
  ///
  /// Hasil mapping diarahkan untuk UI (bisa diedit per item).
  Future<List<Map<String, dynamic>>> fetchBankAccountsByOwner() async {
    final ownerId = _client.auth.currentUser?.id ?? _requireOwnerId();

    final res = await _client
        .from('bank_info')
        .select('id, bank_name, bank_number, bank_account_name, bank_type')
        .eq('owner_id', ownerId)
        .order('created_at', ascending: true);

    final list = (res as List?) ?? const [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Update 1 baris `bank_info` berdasarkan id.
  Future<void> updateBankAccount({
    required String id,
    required String bankName,
    required String bankNumber,
    required String bankAccountName,
    required String bankType,
  }) async {
    if (bankType != 'Bank' && bankType != 'E-Wallet') {
      throw ArgumentError.value(
        bankType,
        'bankType',
        "Harus 'Bank' atau 'E-Wallet'",
      );
    }

    final trimmedName = bankName.trim();
    final trimmedNumber = bankNumber.trim();
    final trimmedHolder = bankAccountName.trim();

    if (trimmedName.isEmpty) {
      throw ArgumentError('bankName tidak boleh kosong');
    }
    if (trimmedNumber.isEmpty) {
      throw ArgumentError('bankNumber tidak boleh kosong');
    }
    if (trimmedHolder.isEmpty) {
      throw ArgumentError('bankAccountName tidak boleh kosong');
    }

    final payload = <String, dynamic>{
      'bank_name': trimmedName,
      'bank_number': trimmedNumber,
      'bank_account_name': trimmedHolder,
      'bank_type': bankType,
    };

    await _client.from('bank_info').update(payload).eq('id', id);
  }

  /// Hapus 1 baris `bank_info` berdasarkan id.
  Future<void> deleteBankAccount({required String id}) async {
    await _client.from('bank_info').delete().eq('id', id);
  }
}
