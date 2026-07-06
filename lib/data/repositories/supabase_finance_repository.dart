import 'package:supabase_flutter/supabase_flutter.dart';

enum TransactionType { income, expense }

extension TransactionTypeX on TransactionType {
  String get value => this == TransactionType.income ? 'income' : 'expense';

  static TransactionType fromValue(String? raw) {
    switch (raw) {
      case 'income':
        return TransactionType.income;
      case 'expense':
        return TransactionType.expense;
      default:
        throw ArgumentError.value(raw, 'raw', 'type transaksi tidak dikenal');
    }
  }
}


class TransactionEntity {
  final String id;
  final String kosId;
  final String roomId;
  final DateTime date;
  final String description;
  final double amount;
  final TransactionType type;
  final String category;
  final DateTime? createdAt;

  const TransactionEntity({
    required this.id,
    required this.kosId,
    this.roomId = '',
    required this.date,
    required this.description,
    required this.amount,
    required this.type,
    this.category = 'Lainnya',
    this.createdAt,
  });

  factory TransactionEntity.fromMap(Map<String, dynamic> map) {
    return TransactionEntity(
      id: map['id'].toString(),
      kosId: (map['kos_id'] ?? '').toString(),
      date: DateTime.parse(map['date'].toString()),
      description: (map['description'] ?? '').toString(),
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      type: TransactionTypeX.fromValue(map['type']?.toString()),
      category: (map['category'] ?? 'Lainnya').toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toInsertMap({required String ownerId}) => {
        'kos_id': kosId,
        'owner_id': ownerId,
        'date': date.toIso8601String(),
        'description': description,
        'amount': amount,
        'type': type.value,
        'category': category,
      };
}

class SupabaseFinanceRepository {
  final SupabaseClient _client;
  static const _table = 'transactions';

  SupabaseFinanceRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  String? get currentUserId => _client.auth.currentUser?.id;

  String _requireOwnerId() {
    final id = currentUserId;
    if (id == null || id.isEmpty) {
      throw StateError('User belum login.');
    }
    return id;
  }

 
  Future<List<TransactionEntity>> fetchTransactions({
    required String kosId,
    DateTime? from,
    DateTime? to,
  }) async {
    var query = _client
        .from(_table)
        .select()
        .eq('kos_id', kosId);

    if (from != null) {
      query = query.gte('date', from.toIso8601String());
    }
    if (to != null) {
      query = query.lte('date', to.toIso8601String());
    }

    final res = await query.order('date', ascending: false);
    final list = (res as List?) ?? const [];
    return list
        .map((e) => TransactionEntity.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

 
  Future<TransactionEntity> createTransaction({
    required String kosId,
    required DateTime date,
    required String description,
    required double amount,
    required TransactionType type,
    String category = 'Lainnya',
  }) async {
    if (description.trim().isEmpty) {
      throw ArgumentError('description tidak boleh kosong');
    }
    if (amount <= 0) {
      throw ArgumentError('amount harus lebih besar dari 0');
    }

    final ownerId = _requireOwnerId();

    final draft = TransactionEntity(
      id: '',
      kosId: kosId,
      date: date,
      description: description.trim(),
      amount: amount,
      type: type,
      category: category,
    );

    final res = await _client
        .from(_table)
        .insert(draft.toInsertMap(ownerId: ownerId))
        .select()
        .maybeSingle();

    if (res == null) {
      throw StateError('Insert transaksi gagal (no row returned).');
    }

    return TransactionEntity.fromMap(Map<String, dynamic>.from(res));
  }

  
  Future<void> updateTransaction({
    required String id,
    DateTime? date,
    String? description,
    double? amount,
    TransactionType? type,
    String? category,
  }) async {
    final payload = <String, dynamic>{
      if (date != null) 'date': date.toIso8601String(),
      if (description != null) 'description': description.trim(),
      if (amount != null) 'amount': amount,
      if (type != null) 'type': type.value,
      if (category != null) 'category': category,
    };

    if (payload.isEmpty) return;

    await _client.from(_table).update(payload).eq('id', id);
  }

  
  Future<void> deleteTransaction({required String id}) async {
    await _client.from(_table).delete().eq('id', id);
  }

  
  Future<({double income, double expense})> fetchSummary({
    required String kosId,
    DateTime? from,
    DateTime? to,
  }) async {
    final entries = await fetchTransactions(kosId: kosId, from: from, to: to);
    double income = 0;
    double expense = 0;
    for (final e in entries) {
      if (e.type == TransactionType.income) {
        income += e.amount;
      } else {
        expense += e.amount;
      }
    }
    return (income: income, expense: expense);
  }
}