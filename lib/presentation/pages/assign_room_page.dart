import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../data/repositories/supabase_tenant_repository.dart';
import '../../data/repositories/supabase_room_repository.dart';
import '../../data/repositories/supabase_occupancy_repository.dart';
import '../../domain/entities/room_entity.dart';
import '../../core/tenant_refresh_notifier.dart';

class AssignRoomPage extends StatefulWidget {
  final String? tenantId;
  const AssignRoomPage({super.key, this.tenantId});

  @override
  State<AssignRoomPage> createState() => _AssignRoomPageState();
}

class _AssignRoomPageState extends State<AssignRoomPage> {
  final _occupancyRepo = SupabaseOccupancyRepository();
  late final _repo = SupabaseRoomRepository(occupancyRepo: _occupancyRepo);
  final SupabaseTenantRepository _tenantRepo = SupabaseTenantRepository();
  List<RoomEntity> _rooms = [];
  List<dynamic> _tenants = [];

  bool _isLoading = true;
  bool _isSubmitting = false;

  // Form States
  String? _selectedTenantId;
  String? _selectedRoomId;
  DateTime? _startDate;
  DateTime? _endDate;
  String? get _currentKosId {
    final user = Supabase.instance.client.auth.currentUser;
    return user?.userMetadata?['kos_id']?.toString();
  }

  final _priceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _paymentMethod = 'Transfer Bank';

  // State untuk Tipe Sewa dan Status Pembayaran
  String _rentType = 'Bulanan'; // Default
  String _paymentStatus = 'Lunas'; // Default

  final List<String> _paymentMethods = [
    'Transfer Bank',
    'Tunai / Cash',
    'E-Wallet (Dana/Ovo/Gopay)',
    'Sistem QRIS'
  ];

  final List<String> _rentTypes = ['Harian', 'Mingguan', 'Bulanan', 'Tahunan'];
  final List<String> _paymentStatuses = ['Lunas', 'Dicicil'];

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now();
    _calculateCheckoutByRentType();
    if (widget.tenantId != null) _selectedTenantId = widget.tenantId;
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    await Future.wait([_loadTenants(), _loadRooms()]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadTenants() async {
    try {
      final tenants = await _tenantRepo.fetchTenants();
      if (!mounted) return;
      setState(() => _tenants = tenants);
    } catch (e) {
      _showSnackBar('Gagal mengambil data penghuni: $e', isError: true);
    }
  }

  Future<void> _loadRooms() async {
    try {
      final rooms = await _repo.fetchAvailableRooms();
      if (!mounted) return;
      setState(() => _rooms = rooms);
    } catch (e) {
      _showSnackBar('Gagal mengambil data kamar: $e', isError: true);
    }
  }

  void _calculateCheckoutByRentType() {
    if (_startDate == null) return;
    setState(() {
      if (_rentType == 'Harian') {
        _endDate = _startDate!.add(const Duration(days: 1));
      } else if (_rentType == 'Mingguan') {
        _endDate = _startDate!.add(const Duration(days: 7));
      } else if (_rentType == 'Bulanan') {
        _endDate = DateTime(_startDate!.year, _startDate!.month + 1, _startDate!.day);
      } else if (_rentType == 'Tahunan') {
        _endDate = DateTime(_startDate!.year + 1, _startDate!.month, _startDate!.day);
      }
    });
  }

  // ========== DATE PICKER DENGAN TEMA UNTUK TAMPAK LEBIH HIDUP ==========
  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6D5EF6),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked;
      _calculateCheckoutByRentType();
    });
  }

  Future<void> _pickEndDate() async {
    if (_startDate == null) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate!.add(const Duration(days: 30)),
      firstDate: _startDate!.add(const Duration(days: 1)),
      lastDate: _startDate!.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6D5EF6),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() => _endDate = picked);
  }

  Future<void> _confirm() async {
  if (_selectedTenantId == null) return _showSnackBar('Silakan pilih penghuni', isError: true);
  if (_selectedRoomId == null) return _showSnackBar('Silakan pilih kamar', isError: true);
  if (_priceCtrl.text.trim().isEmpty) return _showSnackBar('Harga sewa tidak boleh kosong', isError: true);

  final kosId = _currentKosId;
  if (kosId == null || kosId.isEmpty) {
    return _showSnackBar('Data kos tidak ditemukan. Pastikan akun sudah terhubung ke kos.', isError: true);
  }

  setState(() => _isSubmitting = true);
  try {
    final freshRooms = await _repo.fetchAvailableRooms();
    final stillAvailable = freshRooms.any((r) => r.id == _selectedRoomId);
    if (!stillAvailable) {
      _showSnackBar('Kamar baru saja dipesan orang lain.', isError: true);
      await _loadRooms();
      return;
    }

    await _occupancyRepo.createOccupancy(
      tenantId: _selectedTenantId!,
      roomId: _selectedRoomId!,
      startDate: _startDate,
      endDate: _endDate,
      kosId: kosId,
    );

    if (!mounted) return;
    _showSnackBar('Penghuni berhasil ditempatkan!');
    TenantRefreshNotifier.instance.notifyTenantsChanged(); // <-- tambahan baru

    final canPop = Navigator.of(context).canPop();
    if (canPop) {
      Navigator.of(context).pop(true);
    } else {
      // Dipakai sebagai tab (IndexedStack) — jangan pop, cukup reset & reload
      setState(() {
        _selectedTenantId = null;
        _selectedRoomId = null;
        _priceCtrl.clear();
        _notesCtrl.clear();
      });
      await _loadRooms();
      await _loadTenants();
    }
  } catch (e) {
    _showSnackBar('Gagal memproses: $e', isError: true);
  } finally {
    if (mounted) setState(() => _isSubmitting = false);
  }
}

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ========== WIDGET PEMBANTU DENGAN STYLING HALUS ==========
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Color(0xFF64748B),
        letterSpacing: 0.6,
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.015),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _buildDateTile(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF6D5EF6)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ========== DEKORASI INPUT YANG LEBIH ALAMI ==========
  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
      prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
      floatingLabelStyle: const TextStyle(
        color: Color(0xFF6D5EF6),
        fontWeight: FontWeight.bold,
      ),
      filled: true,
      fillColor: const Color(0xFFF1F5F9),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF6D5EF6), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
      ),
    );
  }

  // ========== BUILD ==========
  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy', 'id_ID');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Check-In Kamar',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6D5EF6)))
          : SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Informasi Utama'),
                    const SizedBox(height: 8),
                    _buildCard([
                      // Dropdown Penghuni
                      DropdownButtonFormField<String>(
                        value: _selectedTenantId,
                        hint: const Text('Pilih Nama Penghuni'),
                        items: _tenants.map<DropdownMenuItem<String>>((t) {
                          return DropdownMenuItem(
                            value: t.id.toString(),
                            child: Text(
                              t.fullName,
                              style: const TextStyle(color: Color(0xFF1E293B)),
                            ),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedTenantId = v),
                        icon: const Icon(Icons.expand_more, color: Color(0xFF94A3B8)),
                        dropdownColor: Colors.white,
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: _inputDecoration('Penghuni Kos', Icons.person_outline_rounded),
                      ),
                      const SizedBox(height: 16),
                      // Dropdown Kamar
                      DropdownButtonFormField<String>(
                        value: _selectedRoomId,
                        hint: const Text('Pilih Kamar'),
                        items: _rooms.map<DropdownMenuItem<String>>((r) {
                          return DropdownMenuItem(
                            value: r.id,
                            child: Text(
                              '${r.name} (Kapasitas: ${r.capacity})',
                              style: const TextStyle(color: Color(0xFF1E293B)),
                            ),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedRoomId = v),
                        icon: const Icon(Icons.expand_more, color: Color(0xFF94A3B8)),
                        dropdownColor: Colors.white,
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: _inputDecoration('Pilih Kamar', Icons.bed_outlined),
                      ),
                    ]),

                    const SizedBox(height: 20),
                    _buildSectionTitle('Detail Masa Sewa'),
                    const SizedBox(height: 8),
                    _buildCard([
                      // Dropdown Tipe Sewa
                      DropdownButtonFormField<String>(
                        value: _rentType,
                        items: _rentTypes.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(
                              type,
                              style: const TextStyle(color: Color(0xFF1E293B)),
                            ),
                          );
                        }).toList(),
                        onChanged: (v) {
                          setState(() {
                            _rentType = v ?? 'Bulanan';
                            _calculateCheckoutByRentType();
                          });
                        },
                        icon: const Icon(Icons.expand_more, color: Color(0xFF94A3B8)),
                        dropdownColor: Colors.white,
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: _inputDecoration('Rentang Waktu', Icons.av_timer_rounded),
                      ),
                      const SizedBox(height: 16),
                      // Row Tanggal
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _pickStartDate,
                              borderRadius: BorderRadius.circular(12),
                              splashColor: const Color(0xFF6D5EF6).withOpacity(0.1),
                              child: _buildDateTile('Tanggal Masuk', fmt.format(_startDate!), Icons.calendar_today_rounded),
                            ),
                          ),
                          Container(height: 40, width: 1, color: Colors.grey.shade200),
                          Expanded(
                            child: InkWell(
                              onTap: _pickEndDate,
                              borderRadius: BorderRadius.circular(12),
                              splashColor: const Color(0xFF6D5EF6).withOpacity(0.1),
                              child: _buildDateTile('Tanggal Keluar', fmt.format(_endDate!), Icons.logout_rounded),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Divider(color: Colors.grey.shade200, thickness: 1),
                      ),
                    ]),

                    const SizedBox(height: 20),
                    _buildSectionTitle('Transaksi'),
                    const SizedBox(height: 8),
                    _buildCard([
                      TextField(
                        controller: _priceCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                        decoration: _inputDecoration('Biaya Sewa Kos (Rp)', Icons.payments_outlined),
                      ),
                      const SizedBox(height: 16),
                      // Dropdown Status Pembayaran
                      DropdownButtonFormField<String>(
                        value: _paymentStatus,
                        items: _paymentStatuses.map((status) {
                          return DropdownMenuItem(
                            value: status,
                            child: Text(
                              status,
                              style: const TextStyle(color: Color(0xFF1E293B)),
                            ),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _paymentStatus = v ?? 'Lunas / Cash'),
                        icon: const Icon(Icons.expand_more, color: Color(0xFF94A3B8)),
                        dropdownColor: Colors.white,
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: _inputDecoration('Status Pembayaran', Icons.fact_check_outlined),
                      ),
                      const SizedBox(height: 16),
                      // Dropdown Metode Pembayaran
                      DropdownButtonFormField<String>(
                        value: _paymentMethod,
                        items: _paymentMethods.map((method) {
                          return DropdownMenuItem(
                            value: method,
                            child: Text(
                              method,
                              style: const TextStyle(color: Color(0xFF1E293B)),
                            ),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _paymentMethod = v ?? 'Transfer Bank'),
                        icon: const Icon(Icons.expand_more, color: Color(0xFF94A3B8)),
                        dropdownColor: Colors.white,
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: _inputDecoration('Metode Pembayaran', Icons.account_balance_wallet_outlined),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _notesCtrl,
                        maxLines: 2,
                        decoration: _inputDecoration('Catatan Tambahan', Icons.sticky_note_2_outlined),
                      ),
                    ]),

                    const SizedBox(height: 36),
                    SizedBox(
                      height: 54,
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6D5EF6),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _isSubmitting ? null : _confirm,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Konfirmasi & Simpan Transaksi',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}