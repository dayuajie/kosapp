import '../entities/user_account_status_entity.dart';
import '../entities/user_profile_entity.dart';

/// Kontrak repository akses user & account.
abstract class UsersAccountRepository {
  String? get currentUserId;

  Future<UserProfileEntity?> fetchUserProfile();

  /// Ambil role/status user dari tabel `account` (atau tabel otorisasi terkait).
  Future<UserAccountStatusEntity?> fetchAccountStatus();

  Future<UserAccountStatusEntity?> fetchMeWithStatus();
}

