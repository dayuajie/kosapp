import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum ActivityType {
  transactionIncome,
  transactionExpense,
  tenantAdded,
  tenantCheckedIn,
  tenantCheckedOut,
  roomAdded,
  roomUpdated,
  occupancyCreated,
  paymentOverdue,
}

class ActivityEntity {
  final String id;
  final ActivityType type;
  final String title;
  final String? subtitle;
  final DateTime timestamp;
  final num? amount;
  final bool isPositive;

  const ActivityEntity({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
    required this.timestamp,
    this.amount,
    this.isPositive = true,
  });

  String get formattedTime {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inHours < 1) return '${diff.inMinutes}m lalu';
    if (diff.inDays < 1) return '${diff.inHours}j lalu';
    if (diff.inDays < 7) return '${diff.inDays}h lalu';
    return DateFormat('dd MMM', 'id_ID').format(timestamp);
  }

  String? get amountFormatted {
    if (amount == null) return null;
    final format = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return format.format(amount);
  }

  IconData get icon {
    switch (type) {
      case ActivityType.transactionIncome:
        return Icons.arrow_downward_rounded;
      case ActivityType.transactionExpense:
        return Icons.arrow_upward_rounded;
      case ActivityType.tenantAdded:
        return Icons.person_add_alt_1_rounded;
      case ActivityType.tenantCheckedIn:
        return Icons.login_rounded;
      case ActivityType.tenantCheckedOut:
        return Icons.logout_rounded;
      case ActivityType.roomAdded:
        return Icons.meeting_room_rounded;
      case ActivityType.roomUpdated:
        return Icons.edit_location_alt_rounded;
      case ActivityType.occupancyCreated:
        return Icons.bed_rounded;
      case ActivityType.paymentOverdue:
        return Icons.warning_amber_rounded;
    }
  }

  Color get iconColor {
    switch (type) {
      case ActivityType.transactionIncome:
        return const Color(0xFF10B981);
      case ActivityType.transactionExpense:
        return const Color(0xFFEF4444);
      case ActivityType.tenantAdded:
      case ActivityType.tenantCheckedIn:
        return const Color(0xFF6D5EF6);
      case ActivityType.tenantCheckedOut:
        return const Color(0xFF64748B);
      case ActivityType.roomAdded:
      case ActivityType.roomUpdated:
        return const Color(0xFF2563EB);
      case ActivityType.occupancyCreated:
        return const Color(0xFF0D9488);
      case ActivityType.paymentOverdue:
        return const Color(0xFFF59E0B);
    }
  }

  Color get bgColor {
    switch (type) {
      case ActivityType.transactionIncome:
        return const Color(0xFFF0FDF4);
      case ActivityType.transactionExpense:
        return const Color(0xFFFEF2F2);
      case ActivityType.tenantAdded:
      case ActivityType.tenantCheckedIn:
        return const Color(0xFFF5F3FF);
      case ActivityType.tenantCheckedOut:
        return const Color(0xFFF8FAFC);
      case ActivityType.roomAdded:
      case ActivityType.roomUpdated:
        return const Color(0xFFEFF6FF);
      case ActivityType.occupancyCreated:
        return const Color(0xFFF0FDFA);
      case ActivityType.paymentOverdue:
        return const Color(0xFFFFFBEB);
    }
  }
}