class UserAccountStatusEntity {
  final String? userId;
  final String? name;
  final String? email;
  final String? phone;

  /// Role/status dari tabel `account` (atau tabel otorisasi lain).
  final String? role;
  const UserAccountStatusEntity({
    required this.userId,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    
  });
}

