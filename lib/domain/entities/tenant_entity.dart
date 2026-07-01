class TenantEntity {
  final String id;
  final String fullName;
  final String? phone;
  final String? room;
  final DateTime? moveInDate;
  final int? rentPrice;
  final String? paymentStatus; // 'lunas' | 'belum_bayar'
  final String? emergencyContact;
  final String? address;
  final String? idCardNumber;
  final String? tenantsUrl;
  final String? idCardUrl;
  final String? notes;
  final DateTime? checkOutDate;


  const TenantEntity({
    required this.id,
    required this.fullName,
    this.phone,
    this.room,
    this.moveInDate,
    this.rentPrice,
    this.paymentStatus,
    this.emergencyContact,
    this.address,
    this.idCardNumber,
    this.tenantsUrl,
    this.idCardUrl,
    this.notes,
    this.checkOutDate,
  });


  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return fullName.substring(0, fullName.length >= 2 ? 2 : 1).toUpperCase();
  }
}