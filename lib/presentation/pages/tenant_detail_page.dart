// lib/presentation/pages/tenant_detail_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/repositories/supabase_tenant_repository.dart';
import '../../data/repositories/supabase_occupancy_repository.dart';
import '../../domain/entities/tenant_entity.dart';
import '../../domain/entities/occupancy_entity.dart';
import '../../core/tenant_refresh_notifier.dart';
import 'tenant_form_page.dart';
import 'assign_room_page.dart';
import 'transaction_composer_page.dart';

class TenantDetailPage extends StatefulWidget {
  final String tenantId;

  const TenantDetailPage({super.key, required this.tenantId});

  @override
  State<TenantDetailPage> createState() => _TenantDetailPageState();
}

class _TenantDetailPageState extends State<TenantDetailPage> {
  final _tenantRepo = SupabaseTenantRepository();
  OccupancyEntity? _activeOccupancy;
  TenantEntity? _tenant;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final tenant = await _tenantRepo.fetchTenantById(widget.tenantId);
      if (tenant == null) throw Exception('Penghuni tidak ditemukan');
      _tenant = tenant;

      // Ambil okupansi aktif secara langsung
      if (tenant.id.isNotEmpty) {
        final active = await _occupancyRepo.fetchActiveOccupancyByTenant(tenant.id);
        _activeOccupancy = active;
        if (active != null) {
          // Update _tenant dengan data dari okupansi agar konsisten
          _tenant = TenantEntity(
            id: tenant.id,
            fullName: tenant.fullName,
            phone: tenant.phone,
            room: tenant.room,
            roomId: active.roomId, // ambil dari okupansi
            moveInDate: active.startDate,
            endDate: active.endDate,
            rentPrice: int.tryParse(active.price ?? '0'),
            rentType: active.rentType,
            paymentStatus: active.paymentStatus,
            emergencyContact: tenant.emergencyContact,
            address: tenant.address,
            idCardNumber: tenant.idCardNumber,
            tenantsUrl: tenant.tenantsUrl,
            idCardUrl: tenant.idCardUrl,
            notes: tenant.notes,
            checkOutDate: tenant.checkOutDate,
            createdAt: tenant.createdAt,
            occupancyId: active.id, // <-- pastikan ini terisi
          );
        }
      }

      setState(() {});
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Check-out Penghuni'),
        content: Text('Apakah Anda yakin ingin check-out ${_tenant!.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Check-out'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _tenantRepo.checkoutTenant(tenantId: _tenant!.id);
      TenantRefreshNotifier.instance.notifyTenantsChanged();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check-out berhasil')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal check-out: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _openEdit() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TenantFormPage(tenantId: _tenant!.id, initialName: _tenant!.fullName),
      ),
    ).then((_) => _loadData());
  }

  void _openRenewal() {
    if (_activeOccupancy == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Penghuni tidak memiliki okupansi aktif')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TransactionComposerPage(
          tenant: _tenant!,
          mode: ComposerMode.renewal,
        ),
      ),
    ).then((result) {
      if (result == true) _loadData();
    });
  }

  void _openRoomSwitch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AssignRoomPage(tenantId: _tenant!.id),
      ),
    ).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy', 'id_ID');

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF6D5EF6))),
      );
    }

    if (_error != null || _tenant == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error ?? 'Data tidak ditemukan'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadData,
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    final tenant = _tenant!;
    final initials = tenant.fullName.isNotEmpty ? tenant.fullName.trim().split(' ').map((l) => l[0]).take(2).join().toUpperCase() : '?';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF0F172A),
        title: Text(
          'Detail Penghuni',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Profil Ringkas
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: const Color(0xFF6D5EF6).withOpacity(0.1),
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Color(0xFF6D5EF6),
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tenant.fullName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tenant.room != null ? 'Kamar ${tenant.room}' : 'Belum Ada Kamar',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Section 1: Informasi Pribadi (Expandable)
              _buildExpandableSection(
                title: 'Informasi Pribadi',
                initiallyExpanded: false,
                children: [
                  _buildInfoRow('Nama', tenant.fullName),
                  _buildInfoRow('Telepon', tenant.phone ?? '-'),
                  _buildInfoRow('Alamat', tenant.address ?? '-'),
                  _buildInfoRow('No. KTP', tenant.idCardNumber ?? '-'),
                  _buildInfoRow('Kontak Darurat', tenant.emergencyContact ?? '-'),
                ],
              ),
              const SizedBox(height: 14),

              // Section 2: Detail Hunian (Expandable)
              _buildExpandableSection(
                title: 'Detail Hunian & Sewa',
                initiallyExpanded: false,
                children: [
                  _buildInfoRow('Kamar', tenant.room ?? '-'),
                  _buildInfoRow('Tipe Sewa', tenant.rentType ?? '-'),
                  _buildInfoRow(
                    'Harga Sewa',
                    tenant.rentPrice != null
                        ? 'Rp ${NumberFormat('#,###', 'id_ID').format(tenant.rentPrice)}'
                        : '-',
                  ),
                  _buildInfoRow(
                    'Tanggal Masuk',
                    tenant.moveInDate != null ? fmt.format(tenant.moveInDate!) : '-',
                  ),
                  _buildInfoRow(
                    'Tanggal Keluar',
                    tenant.endDate != null ? fmt.format(tenant.endDate!) : '-',
                  ),
                  _buildInfoRow(
                    'Status Pembayaran',
                    tenant.paymentStatus ?? 'Belum ada',
                    isStatus: true,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Section 3: Riwayat Pembayaran (Expandable)
              _buildExpandableSection(
                title: 'Riwayat Pembayaran',
                initiallyExpanded: false,
                children: [
                  _buildInfoRow('Status Terakhir', tenant.paymentStatus ?? 'Belum ada', isStatus: true),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: Color(0xFFE2E8F0)),
                  ),
                  const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF94A3B8)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Riwayat transaksi lengkap sedang dikembangkan.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Tombol Aksi Utama
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _openRenewal,
                      icon: const Icon(Icons.update_rounded, size: 20),
                      label: const Text('Perpanjang', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6D5EF6),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _checkout,
                      icon: const Icon(Icons.logout_rounded, size: 20),
                      label: const Text('Check-out', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFEE2E2),
                        foregroundColor: Colors.red,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openEdit,
                      icon: const Icon(Icons.edit_rounded, size: 20),
                      label: const Text('Edit Data', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6D5EF6),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openRoomSwitch,
                      icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                      label: const Text('Pindah Kamar', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6D5EF6),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableSection({
    required String title,
    required List<Widget> children,
    bool initiallyExpanded = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF1E293B),
            ),
          ),
          trailing: const Icon(Icons.expand_more_rounded, color: Color(0xFF94A3B8)),
          childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isStatus = false}) {
    Widget valueWidget = Text(
      value,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13,
        color: Color(0xFF1E293B),
      ),
    );

    // Styling khusus jika baris tersebut merepresentasikan badge status pembayaran
    if (isStatus) {
      final isPaid = value.toLowerCase().contains('lunas') || value.toLowerCase().contains('paid');
      valueWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
            color: isPaid ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Align(alignment: Alignment.centerLeft, child: valueWidget)),
        ],
      ),
    );
  }
}