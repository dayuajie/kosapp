// tenants_page.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kos_app/data/repositories/supabase_kos_repository.dart';
import 'package:kos_app/data/repositories/supabase_tenant_repository.dart';
import '../../domain/entities/tenant_entity.dart';
import '../../core/tenant_refresh_notifier.dart';
import 'tenant_form_page.dart';

// ============================================================================
// MAIN PAGE
// ============================================================================

class TenantsPage extends StatefulWidget {
  const TenantsPage({super.key});

  @override
  State<TenantsPage> createState() => _TenantsPageState();
}

class _TenantsPageState extends State<TenantsPage> {
  final _repo = SupabaseKosRepository();
  final _tenantRepo = SupabaseTenantRepository();
  final _searchCtrl = TextEditingController();

  List<TenantEntity> _tenants = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadTenants();
    TenantRefreshNotifier.instance.addListener(_onTenantsChanged);
  }
  void _onTenantsChanged() {
    if (!mounted) return;
    _loadTenants();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    TenantRefreshNotifier.instance.removeListener(_onTenantsChanged);
    super.dispose();
  }

  List<TenantEntity> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _tenants;
    return _tenants.where((t) {
      return t.fullName.toLowerCase().contains(q) ||
          (t.room ?? '').toLowerCase().contains(q) ||
          (t.phone ?? '').toLowerCase().contains(q);
    }).toList();
  }

  int get _lateCount => _tenants.where((t) => t.paymentStatus == 'belum_bayar').length;

  Future<void> _loadTenants() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final tenants = await _tenantRepo.fetchTenants();
      if (!mounted) return;
      setState(() => _tenants = tenants);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _showDetailSheet(BuildContext context, TenantEntity t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TenantDetailSheet(
        tenant: t,
        onEdit: () {
          Navigator.of(context).pop();
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (_) => TenantFormPage(
                    tenantId: t.id,
                    initialName: t.fullName,
                  ),
                ),
              )
              .then((_) {
            if (!mounted) return;
            _loadTenants();
          });
        },
        onDelete: () {
          Navigator.of(context).pop();
          _showDeleteDialog(context, t);
        },
        onCheckout: () {
          Navigator.of(context).pop();
          _showCheckoutDialog(context, t);
        },
      ),
    );
  }

  void _showCheckoutDialog(BuildContext context, TenantEntity t) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        bool isProcessing = false;
        return StatefulBuilder(
          builder: (ctx2, setStateDialog) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Checkout Penghuni', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Text(
              'Keluarkan "${t.fullName}" dari kamar "${t.room ?? '-'}"? Kamar akan kembali berstatus tersedia.',
            ),
            actions: [
              TextButton(
                onPressed: isProcessing ? null : () => Navigator.of(ctx2).pop(),
                child: Text('Batal', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isProcessing
                    ? null
                    : () async {
                        setStateDialog(() => isProcessing = true);
                        try {
                          await _tenantRepo.checkoutTenant(tenantId: t.id);
                          if (!mounted) return;
                          Navigator.of(ctx2).pop();
                          await _loadTenants();
                          TenantRefreshNotifier.instance.notifyTenantsChanged();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('"${t.fullName}" berhasil checkout')),
                            );
                          }
                        } catch (e) {
                          setStateDialog(() => isProcessing = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Gagal checkout: $e')),
                            );
                          }
                        }
                      },
                child: isProcessing
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Checkout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteDialog(BuildContext context, TenantEntity t) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        bool isDeleting = false;
        return StatefulBuilder(
          builder: (ctx2, setStateDialog) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              'Hapus Penghuni',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Apakah Anda yakin ingin menghapus data "${t.fullName}"? Tindakan ini tidak dapat dibatalkan.',
            ),
            actions: [
              TextButton(
                onPressed: isDeleting ? null : () => Navigator.of(ctx2).pop(),
                child: Text(
                  'Batal',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: isDeleting
                    ? null
                    : () async {
                        setStateDialog(() => isDeleting = true);
                        try {
                          await _tenantRepo.deleteTenant(tenantId: t.id);
                          if (!mounted) return;
                          Navigator.of(ctx2).pop();
                          await _loadTenants();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('"${t.fullName}" berhasil dihapus'),
                              ),
                            );
                          }
                        } catch (e) {
                          setStateDialog(() => isDeleting = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Gagal menghapus: $e')),
                            );
                          }
                        }
                      },
                child: isDeleting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Hapus',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daftar Penghuni',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: const Color(0xFF1E293B),
              ),
            ),
            Text(
              'Kost Mutiara Jaya · Diperbarui hari ini',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // SEARCH & ADD
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withOpacity(0.03),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search_rounded,
                              color: Colors.grey.shade400,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _searchCtrl,
                                onChanged: (v) => setState(() => _query = v),
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF1E293B),
                                ),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  hintText: 'Cari nama atau nomor kamar...',
                                  border: InputBorder.none,
                                  hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                                ),
                              ),
                            ),
                            if (_query.trim().isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  _searchCtrl.clear();
                                  setState(() => _query = '');
                                },
                                child: Icon(
                                  Icons.cancel_rounded,
                                  color: Colors.grey.shade400,
                                  size: 18,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const TenantFormPage(),
                          ),
                        );
                        if (!mounted) return;
                        _loadTenants();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6D5EF6), Color(0xFF5546E6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6D5EF6).withOpacity(0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // LOADING
            if (_isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),

            // ERROR
            if (_errorMessage != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 16),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 48,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(height: 8),
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadTenants,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Coba lagi'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // SUCCESS
            if (!_isLoading && _errorMessage == null) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Row(
                    children: [
                      _StatCard(
                        label: 'Total kamar',
                        value: '12',
                        dotColor: const Color(0xFF6D5EF6),
                      ),
                      const SizedBox(width: 8),
                      _StatCard(
                        label: 'Terisi',
                        value: '${_tenants.length}',
                        dotColor: const Color(0xFF16A34A),
                      ),
                      const SizedBox(width: 8),
                      _StatCard(
                        label: 'Tempo',
                        value: '$_lateCount',
                        dotColor: const Color(0xFFF59E0B),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Text(
                    'SEMUA PENGHUNI',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList.separated(
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final t = _filtered[index];
                    return _TenantCard(
                      tenant: t,
                      onTap: () => _showDetailSheet(context, t),
                      onEdit: () async {
                        final didChange = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => TenantFormPage(
                              tenantId: t.id,
                              initialName: t.fullName,
                            ),
                          ),
                        );
                        if (didChange == true && mounted) _loadTenants();
                      },
                      onRemove: () => _showDeleteDialog(context, t),
                    );
                  },
                ),
              ),
              if (_filtered.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 80),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _EmptyStateIcon(),
                          SizedBox(height: 16),
                          Text(
                            'Pencarian tidak ditemukan',
                            style: TextStyle(
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Coba periksa kembali kata kunci Anda',
                            style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// WIDGETS
// ============================================================================

class _EmptyStateIcon extends StatelessWidget {
  const _EmptyStateIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.person_search_rounded,
        size: 40,
        color: Color(0xFF94A3B8),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color dotColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TenantCard extends StatelessWidget {
  final TenantEntity tenant;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _TenantCard({
    required this.tenant,
    required this.onTap,
    required this.onEdit,
    required this.onRemove,
  });

  bool get _hasProfilePhoto => (tenant.tenantsUrl ?? '').trim().isNotEmpty;
  bool get _isCheckedOut => tenant.checkOutDate != null;

  Color get _avatarColor {
    const colors = [
      Color(0xFF6D5EF6),
      Color(0xFFDC2626),
      Color(0xFF16A34A),
      Color(0xFFD97706),
      Color(0xFF0284C7),
    ];
    return colors[tenant.fullName.length % colors.length];
  }

  bool get _isLate => tenant.paymentStatus == 'belum_bayar';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                _buildAvatar(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tenant.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_iphone_rounded,
                            size: 13,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            tenant.phone ?? '-',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isCheckedOut
                            ? Colors.grey.shade100
                            : _avatarColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _isCheckedOut ? 'Checkout' : (tenant.room ?? '-'),
                        style: TextStyle(
                          color: _isCheckedOut ? Colors.grey.shade500 : _avatarColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _isCheckedOut
                                ? Colors.grey.shade100
                                : (_isLate ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _isCheckedOut ? 'Non-aktif' : (_isLate ? 'Belum bayar' : 'Lunas'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _isCheckedOut
                                  ? Colors.grey.shade500
                                  : (_isLate ? const Color(0xFFD97706) : const Color(0xFF16A34A)),
                            ),
                          ),
                        ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.only(top: 10),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Color(0xFFF1F5F9),
                    width: 1,
                  ),
                ),
              ),
              child: const Row(
                children: [
                  _FooterMeta(
                    icon: Icons.calendar_today_rounded,
                    label: 'Masuk 1 Jan 2024',
                  ),
                  SizedBox(width: 14),
                  _FooterMeta(
                    icon: Icons.access_time_rounded,
                    label: '6 bulan',
                  ),
                  Spacer(),
                  _FooterMeta(
                    icon: Icons.payments_outlined,
                    label: 'Rp 750rb',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _avatarColor.withOpacity(0.08),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: ClipOval(
        child: _hasProfilePhoto
            ? CachedNetworkImage(
                imageUrl: tenant.tenantsUrl!,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                memCacheWidth: 132,
                memCacheHeight: 132,
                placeholder: (_, __) => Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _avatarColor,
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Center(
                  child: Text(
                    tenant.initials,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _avatarColor,
                      fontSize: 14,
                    ),
                  ),
                ),
              )
            : Center(
                child: Text(
                  tenant.initials,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _avatarColor,
                    fontSize: 14,
                  ),
                ),
              ),
      ),
    );
  }
}

class _FooterMeta extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FooterMeta({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.grey.shade400),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ],
    );
  }
}

// ============================================================================
// DETAIL SHEET
// ============================================================================

class _TenantDetailSheet extends StatelessWidget {
  static const Color _primaryColor = Color(0xFF6D5EF6);
  static const Color _slateDark = Color(0xFF0F172A);
  static const Color _slateLight = Color(0xFF1E293B);
  static const Color _dangerColor = Color(0xFFEF4444);

  final TenantEntity tenant;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onCheckout;

  const _TenantDetailSheet({
    required this.tenant,
    required this.onEdit,
    required this.onDelete,
    required this.onCheckout,
  });

  String _formatDuration(DateTime start, DateTime? end) {
    final endDate = end ?? DateTime.now();
    final months = (endDate.year - start.year) * 12 + (endDate.month - start.month);
    if (months <= 0) return '< 1 bulan';
    return '$months bulan';
  }

  bool get _isLate => tenant.paymentStatus == 'belum_bayar';
  bool get _hasRoom => (tenant.room ?? '').trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: SingleChildScrollView(
          controller: scrollController,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDragHandle(),
              const SizedBox(height: 20),
              _buildAvatarSection(),
              const SizedBox(height: 10),
              _buildIdentityHeader(),
              const SizedBox(height: 8),
              _buildStatusBadge(),
              const SizedBox(height: 24),
              _buildTenantInfoSection(context),
              _buildRoomInfoSection(context),
              _buildPaymentHistorySection(),
              const SizedBox(height: 24),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _primaryColor.withOpacity(0.08),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipOval(
        child: (tenant.tenantsUrl ?? '').trim().isNotEmpty
            ? CachedNetworkImage(
                imageUrl: tenant.tenantsUrl!,
                width: 84,
                height: 84,
                fit: BoxFit.cover,
                memCacheWidth: 252,
                memCacheHeight: 252,
                placeholder: (_, __) => const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _primaryColor,
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => _buildAvatarInitials(),
              )
            : _buildAvatarInitials(),
      ),
    );
  }

  Widget _buildAvatarInitials() {
    return Center(
      child: Text(
        tenant.initials,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: _primaryColor,
        ),
      ),
    );
  }

  Widget _buildIdentityHeader() {
  final isCheckedOut = tenant.checkOutDate != null;
  return Column(
    children: [
      Text(
        tenant.fullName,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: _slateLight,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        isCheckedOut ? 'Sudah checkout' : (tenant.room ?? '-'),
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade500,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}

  Widget _buildStatusBadge() {
  final isCheckedOut = tenant.checkOutDate != null;

  final String label;
  final Color bg;
  final Color fg;

  if (isCheckedOut) {
    label = 'Sudah checkout';
    bg = Colors.grey.shade200;
    fg = Colors.grey.shade600;
  } else if (_isLate) {
    label = 'Belum bayar bulan ini';
    bg = const Color(0xFFFEF3C7);
    fg = const Color(0xFFD97706);
  } else {
    label = 'Pembayaran lunas';
    bg = const Color(0xFFDCFCE7);
    fg = const Color(0xFF16A34A);
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(100),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
    ),
  );
}

  Widget _customExpansionTile({
    required String title,
    required String subtitle,
    required List<Widget> children,
    bool initiallyExpanded = false,
  }) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      initiallyExpanded: initiallyExpanded,
      shape: const Border(),
      collapsedShape: const Border(),
      title: _sectionHeader(title, subtitle: subtitle),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 12),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, {required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            color: _slateDark,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTenantInfoSection(BuildContext context) {
    return _customExpansionTile(
      title: 'Tenant information',
      subtitle: 'Kontak & identitas',
      initiallyExpanded: true,
      children: [
        Row(
          children: [
            Expanded(
              child: _InfoTile(
                icon: Icons.phone_iphone_rounded,
                label: 'No. telepon',
                value: tenant.phone ?? '-',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _InfoTile(
                icon: Icons.calendar_today_rounded,
                label: 'Tanggal masuk',
                value: tenant.moveInDate == null ? '-' : DateFormat('dd MMM yyyy', 'id_ID').format(tenant.moveInDate!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _InfoTile(
          icon: Icons.emergency_outlined,
          label: 'Kontak darurat',
          value: tenant.emergencyContact ?? '-',
          fullWidth: true,
        ),
        if ((tenant.address ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          _InfoTile(
            icon: Icons.location_on_rounded,
            label: 'Alamat',
            value: tenant.address!,
            fullWidth: true,
            muted: true,
          ),
        ],
        if ((tenant.idCardNumber ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          _InfoTile(
            icon: Icons.badge_rounded,
            label: 'ID Card Number',
            value: tenant.idCardNumber!,
            fullWidth: true,
          ),
          const SizedBox(height: 8),
          _buildIdCardThumbnail(context),
        ],
      ],
    );
  }

  Widget _buildIdCardThumbnail(BuildContext context) {
    final idCardUrl = (tenant.idCardUrl ?? '').trim();
    if (idCardUrl.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        showDialog<void>(
          context: context,
          builder: (ctx) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  color: Colors.black,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: SizedBox(
                          width: double.infinity,
                          child: InteractiveViewer(
                            minScale: 1,
                            maxScale: 4,
                            child: CachedNetworkImage(
                              imageUrl: idCardUrl,
                              fit: BoxFit.contain,
                              placeholder: (_, __) => const Center(
                                child: SizedBox(
                                  width: 26,
                                  height: 26,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              errorWidget: (_, __, ___) => const Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(color: Colors.black),
                        child: Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () {
                                  // Implementasi download jika diperlukan
                                },
                                icon: const Icon(Icons.download_rounded, size: 18),
                                label: const Text('Download'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: _primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              icon: const Icon(Icons.close_rounded, color: Colors.white),
                              tooltip: 'Tutup',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: idCardUrl,
                width: 64,
                height: 48,
                fit: BoxFit.cover,
                memCacheHeight: 96,
                placeholder: (_, __) => const SizedBox(
                  width: 64,
                  height: 48,
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => const SizedBox(
                  width: 64,
                  height: 48,
                  child: Center(child: Icon(Icons.broken_image_outlined, size: 18)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ID Card',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap untuk lihat & download',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomInfoSection(BuildContext context) {
  final isCheckedOut = tenant.checkOutDate != null;

  return _customExpansionTile(
    title: 'Room information',
    subtitle: isCheckedOut ? 'Riwayat kamar' : 'Data kamar & masa sewa',
    children: [
      if (isCheckedOut)
        _buildCheckedOutRoomInfo()
      else if (_hasRoom)
        _buildActiveRoomInfo(context)
      else
        _buildEmptyState('Tenant belum ditempatkan di kamar manapun.'),
    ],
  );
}

Widget _buildCheckedOutRoomInfo() {
  return Row(
    children: [
      Expanded(
        child: _InfoTile(
          icon: Icons.bed_rounded,
          label: 'Room name',
          value: tenant.room ?? '-',
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _InfoTile(
          icon: Icons.event_busy_rounded,
          label: 'Checkout date',
          value: DateFormat('dd MMM yyyy', 'id_ID').format(tenant.checkOutDate!),
        ),
      ),
    ],
  );
}

Widget _buildActiveRoomInfo(BuildContext context) {
  return Column(
    children: [
      Row(
        children: [
          Expanded(
            child: _InfoTile(
              icon: Icons.bed_rounded,
              label: 'Room name',
              value: tenant.room ?? '-',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _InfoTile(
              icon: Icons.calendar_today_rounded,
              label: 'Tanggal masuk',
              value: tenant.moveInDate == null
                  ? '-'
                  : DateFormat('dd MMM yyyy', 'id_ID').format(tenant.moveInDate!),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _InfoTile(
              icon: Icons.event_rounded,
              label: 'Referensi tanggal keluar',
              value: tenant.endDate == null
                  ? '-'
                  : DateFormat('dd MMM yyyy', 'id_ID').format(tenant.endDate!),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _InfoTile(
              icon: Icons.access_time_rounded,
              label: 'Lama tinggal',
              value: tenant.moveInDate == null
                  ? '-'
                  : _formatDuration(tenant.moveInDate!, null),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _InfoTile(
              icon: Icons.payments_outlined,
              label: 'Harga sewa',
              value: tenant.rentPrice == null ? '-' : 'Rp ${tenant.rentPrice}',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _InfoTile(
              icon: Icons.repeat_rounded,
              label: 'Tipe sewa',
              value: tenant.rentType ?? '-',
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onCheckout,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                side: const BorderSide(color: _dangerColor),
                foregroundColor: _dangerColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Checkout',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _dangerColor)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fitur switch room belum tersedia')),
                );
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                side: const BorderSide(color: Colors.blue),
                foregroundColor: Colors.blue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Switch Room',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.blue)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                side: BorderSide(color: _primaryColor.withOpacity(0.9)),
                foregroundColor: _primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Perpanjang',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _primaryColor)),
            ),
          ),
        ],
      ),
    ],
  );
}

  Widget _buildPaymentHistorySection() {
    return _customExpansionTile(
      title: 'Payment history',
      subtitle: 'Riwayat pembayaran',
      children: [_buildEmptyState('Belum ada data payment history untuk saat ini.')],
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade500,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Ubah data'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _slateLight,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Hapus'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFEE2E2),
              foregroundColor: _dangerColor,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// INFO TILE
// ============================================================================

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool fullWidth;
  final bool muted;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.fullWidth = false,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: muted ? FontWeight.w400 : FontWeight.w600,
              color: muted ? Colors.grey.shade500 : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }
}