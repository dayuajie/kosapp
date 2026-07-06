
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/repositories/supabase_tenant_repository.dart';
import '../../domain/entities/tenant_entity.dart';
import '../../core/tenant_refresh_notifier.dart';
import 'tenant_detail_page.dart';
import 'transaction_composer_page.dart';

class _T {
  static const primary = Color(0xFF6D5EF6);
  static const bg = Color(0xFFF8FAFC);
  static const border = Color(0xFFE2E8F0);
  static const textMain = Color(0xFF0F172A);
  static const textSub = Color(0xFF64748B);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
}

class TenantsPage extends StatefulWidget {
  const TenantsPage({super.key});

  @override
  State<TenantsPage> createState() => _TenantsPageState();
}

class _TenantsPageState extends State<TenantsPage> {
  final _repo = SupabaseTenantRepository();
  List<TenantEntity> _tenants = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTenants();
    TenantRefreshNotifier.instance.addListener(_onTenantChanged);
  }

  @override
  void dispose() {
    TenantRefreshNotifier.instance.removeListener(_onTenantChanged);
    super.dispose();
  }

  void _onTenantChanged() {
    if (!mounted) return;
    _loadTenants();
  }

  Future<void> _loadTenants() async {
    setState(() => _isLoading = true);
    try {
      final list = await _repo.fetchTenants();
      if (!mounted) return;
      setState(() {
        _tenants = list;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat data: $e';
        _isLoading = false;
      });
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? _T.danger : _T.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _checkoutTenant(TenantEntity tenant) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Konfirmasi Check-out', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Yakin ingin check-out ${tenant.fullName} dari ${tenant.room ?? 'kamar'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: _T.textSub)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _T.danger),
            child: const Text('Check-out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _repo.checkoutTenant(tenantId: tenant.id);
      TenantRefreshNotifier.instance.notifyTenantsChanged();
      if (!mounted) return;
      _showSnack('Check-out berhasil', isError: false);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Gagal check-out: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.bg,
      appBar: AppBar(
        backgroundColor: _T.bg,
        elevation: 0,
        title: const Text(
          'Daftar Penghuni',
          style: TextStyle(fontWeight: FontWeight.bold, color: _T.textMain),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _T.textSub),
            onPressed: _loadTenants,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _T.primary))
            : _error != null
                ? _buildErrorState()
                : _tenants.isEmpty
                    ? _buildEmptyState()
                    : _buildTenantList(),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadTenants,
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Belum ada penghuni',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTenantList() {
  return ListView.separated(
    padding: const EdgeInsets.all(16),
    itemCount: _tenants.length,
    separatorBuilder: (_, __) => const SizedBox(height: 12),
    itemBuilder: (context, index) {
      final tenant = _tenants[index];
      return _TenantCard(
        tenant: tenant,
        onTap: () => _openTenantDetail(tenant),
      );
    },
  );
}
void _openTenantDetail(TenantEntity tenant) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => TenantDetailPage(tenantId: tenant.id),
    ),
  ).then((_) => _loadTenants());
}

  // ═════════════════════════════════════════════════════════════════
  //  INI TEMPATNYA - Method untuk membuka Transaction Composer
  // ═════════════════════════════════════════════════════════════════
  Future<void> _openRenewal(TenantEntity tenant) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TransactionComposerPage(
          tenant: tenant,
          mode: ComposerMode.renewal,
        ),
      ),
    );

    // Refresh jika perpanjangan berhasil
    if (result == true && mounted) {
      _showSnack('Perpanjangan berhasil disimpan');
      _loadTenants();
    }
  }
}

// ═════════════════════════════════════════════════════════════════
//  WIDGET CARD PENGHUNI - Tempat tombol perpanjangan diletakkan
// ═════════════════════════════════════════════════════════════════
class _TenantCard extends StatelessWidget {
  final TenantEntity tenant;
  final VoidCallback onTap;   // ← Callback check-out

  const _TenantCard({
    required this.tenant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy', 'id_ID');
    final isOverdue = _isOverdue(tenant.endDate);

    return GestureDetector(
      onTap: onTap,
      child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _T.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header dengan info utama ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6D5EF6), Color(0xFF8B7FF8)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      tenant.initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tenant.fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: _T.textMain,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.bed_rounded, size: 14, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(
                            tenant.room ?? '-',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isOverdue
                        ? _T.danger.withOpacity(0.1)
                        : _T.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isOverdue
                          ? _T.danger.withOpacity(0.3)
                          : _T.success.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    isOverdue ? 'Tunggakan' : 'Aktif',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isOverdue ? _T.danger : _T.success,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Detail info ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                _buildInfoRow(
                  Icons.calendar_today_rounded,
                  'Masa Sewa',
                  tenant.moveInDate != null && tenant.endDate != null
                      ? '${fmt.format(tenant.moveInDate!)} - ${fmt.format(tenant.endDate!)}'
                      : '-',
                  isOverdue ? _T.danger : null,
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.payments_rounded,
                  'Harga Sewa',
                  tenant.rentPrice != null
                      ? 'Rp ${NumberFormat('#,###', 'id_ID').format(tenant.rentPrice)} / ${tenant.rentType ?? 'bulan'}'
                      : '-',
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.payment_rounded,
                  'Status Bayar',
                  tenant.paymentStatus ?? '-',
                  _getPaymentStatusColor(tenant.paymentStatus),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, [Color? valueColor]) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade400),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: valueColor ?? _T.textMain,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  bool _isOverdue(DateTime? endDate) {
    if (endDate == null) return false;
    return endDate.isBefore(DateTime.now());
  }

  Color? _getPaymentStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'lunas':
        return _T.success;
      case 'pending':
        return _T.warning;
      case 'dicicil':
        return Colors.blue;
      default:
        return null;
    }
  }
}