import '../../domain/entities/tenant_entity.dart';

enum PaymentTrigger {
  assignRoom,      // Check-in baru
  renewal,         // Perpanjangan sewa
  partialPayment,  // Cicilan tambahan
  overduePayment,  // Pelunasan tunggakan
  settlement,      // Penyelesaian sisa
}

enum PaymentStatus {
  pending,    // Belum dibayar sama sekali
  partial,    // Sudah dicicil, masih ada sisa
  paid,       // Lunas
  overdue,    // Lewat jatuh tempo
}

class PaymentRecord {
  final double amount;
  final String method;
  final DateTime date;
  final String? note;
  final String? recordedBy;

  const PaymentRecord({
    required this.amount,
    required this.method,
    required this.date,
    this.note,
    this.recordedBy,
  });

  Map<String, dynamic> toMap() => {
    'amount': amount,
    'method': method,
    'date': date.toIso8601String(),
    'note': note,
    'recorded_by': recordedBy,
  };

  factory PaymentRecord.fromMap(Map<String, dynamic> map) => PaymentRecord(
    amount: (map['amount'] as num).toDouble(),
    method: map['method']?.toString() ?? 'Tunai',
    date: DateTime.parse(map['date'].toString()),
    note: map['note']?.toString(),
    recordedBy: map['recorded_by']?.toString(),
  );
}

/// Konteks lengkap untuk transaksi pembayaran
class PaymentContext {
  final String tenantId;
  final String tenantName;
  final String roomId;
  final String roomName;
  final String? occupancyId;
  
  final PaymentTrigger trigger;
  final PaymentStatus status;
  
  final double totalAmount;       // Total yang harus dibayar
  final double totalPaid;         // Total sudah dibayar
  final double remaining;         // Sisa yang belum dibayar
  
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final DateTime? dueDate;        // Jatuh tempo pembayaran
  
  final List<PaymentRecord> paymentHistory;
  final double? lateFee;          // Denda keterlambatan
  final int? daysOverdue;         // Hari keterlambatan

  const PaymentContext({
    required this.tenantId,
    required this.tenantName,
    required this.roomId,
    required this.roomName,
    required this.trigger,
    required this.status,
    required this.totalAmount,
    required this.totalPaid,
    required this.remaining,
    this.occupancyId,
    this.periodStart,
    this.periodEnd,
    this.dueDate,
    this.paymentHistory = const [],
    this.lateFee,
    this.daysOverdue,
  });

  /// Factory untuk perpanjangan
  factory PaymentContext.forRenewal({
    required TenantEntity tenant,
    required double newPrice,
    required DateTime newEndDate,
  }) => PaymentContext(
    tenantId: tenant.id,
    tenantName: tenant.fullName,
    roomId: tenant.roomId ?? '',
    roomName: tenant.room ?? '-',
    occupancyId: tenant.occupancyId,
    trigger: PaymentTrigger.renewal,
    status: PaymentStatus.pending,
    totalAmount: newPrice,
    totalPaid: 0,
    remaining: newPrice,
    periodStart: tenant.endDate,
    periodEnd: newEndDate,
    dueDate: tenant.endDate,
  );

  /// Factory untuk pelunasan tunggakan
  factory PaymentContext.forOverdue({
    required TenantEntity tenant,
    required double totalDue,
    required int daysLate,
  }) => PaymentContext(
    tenantId: tenant.id,
    tenantName: tenant.fullName,
    roomId: tenant.roomId ?? '',
    roomName: tenant.room ?? '-',
    occupancyId: tenant.occupancyId,
    trigger: PaymentTrigger.overduePayment,
    status: PaymentStatus.overdue,
    totalAmount: totalDue,
    totalPaid: tenant.rentPrice?.toDouble() ?? 0,
    remaining: totalDue,
    daysOverdue: daysLate,
    dueDate: tenant.endDate,
  );

  bool get isFullyPaid => remaining <= 0;
  bool get hasPartialPayment => totalPaid > 0 && remaining > 0;
  bool get isOverdue => status == PaymentStatus.overdue || 
                       (dueDate != null && dueDate!.isBefore(DateTime.now()) && !isFullyPaid);
}