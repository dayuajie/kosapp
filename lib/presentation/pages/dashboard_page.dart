import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kos_app/data/repositories/supabase_kos_repository.dart';
import 'package:kos_app/presentation/bloc/kos/cubit/kos_overview_cubit.dart';
import 'package:kos_app/presentation/widgets/section_header.dart';
import 'package:kos_app/presentation/pages/rooms_page.dart';
import 'package:kos_app/presentation/pages/finance/user_finance/finance_page.dart';
import 'package:kos_app/core/tenant_refresh_notifier.dart';
import '../../core/transaction_refresh_notifier.dart';
import '../../domain/entities/activity_entity.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  // ── Animation ─────────────────────────────────────────────────────────────
  late AnimationController _animationController;

  // ── UI state ──────────────────────────────────────────────────────────────
  int _selectedTimeRange = 1; // 0: Minggu, 1: Bulan, 2: Tahun
  bool _showAmount = true;

  // ── Kos state ─────────────────────────────────────────────────────────────
  late final SupabaseKosRepository _kosRepo;
  late final KosOverviewCubit _overviewCubit;
  List<Map<String, dynamic>> _kosList = const [];
  bool _isLoadingKos = false;
  bool _isSubmittingKos = false;
  Map<String, dynamic>? _activeKos;

  // ── Kos form controllers ──────────────────────────────────────────────────
  final _kosNameCtrl     = TextEditingController();
  final _kosAddressCtrl  = TextEditingController();
  final _kosCapacityCtrl = TextEditingController();
  final _kosPhoneCtrl    = TextEditingController();

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _kosRepo = SupabaseKosRepository();
    _overviewCubit = KosOverviewCubit();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _loadKos();
    TenantRefreshNotifier.instance.addListener(_onDataChanged);
    TransactionRefreshNotifier.instance.addListener(_onTransactionChanged);
  }

    void _onDataChanged() { 
    if (!mounted) return;
    final kosId = _activeKos?['id']?.toString();
    if (kosId != null) _overviewCubit.load(kosId: kosId);
  }

  void _onTransactionChanged() {
    if (!mounted) return;
    final kosId = _activeKos?['id']?.toString();
    if (kosId != null) {
      _overviewCubit.load(kosId: kosId);
    }
  }


  @override
  void dispose() {
    TransactionRefreshNotifier.instance.removeListener(_onTransactionChanged);
    TenantRefreshNotifier.instance.removeListener(_onDataChanged);
    _animationController.dispose();
    _overviewCubit.close();
    _kosNameCtrl.dispose();
    _kosAddressCtrl.dispose();
    _kosCapacityCtrl.dispose();
    _kosPhoneCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat pagi';
    if (hour < 15) return 'Selamat siang';
    if (hour < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  String _calculateNetProfit(num income, num expense) =>
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0)
          .format(income - expense);

  void _showSnack(String msg, {required bool isSuccess}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(
            isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(msg)),
        ]),
        backgroundColor:
            isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Kos logic ─────────────────────────────────────────────────────────────
  Future<void> _loadKos() async {
  final ownerId = _kosRepo.currentUserId;
  if (ownerId == null || ownerId.isEmpty) return;

  setState(() => _isLoadingKos = true);
  try {
    final list = await _kosRepo.fetchKosByOwner(ownerId);
    if (!mounted) return;

    final metaKosId = _kosRepo.currentKosId; // ganti akses langsung userMetadata

    setState(() {
      _kosList = list;
      if (list.isNotEmpty) {
        _activeKos = list.firstWhere(
          (k) => k['id'].toString() == metaKosId,
          orElse: () => list.first,
        );
      } else {
        _activeKos = null;
      }
    });

    if (_activeKos != null) {
      _overviewCubit.load(kosId: _activeKos!['id'].toString());
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openKosBottomSheet();
      });
    }
  } catch (_) {
    if (!mounted) return;
    setState(() => _kosList = const []);
  } finally {
    if (mounted) setState(() => _isLoadingKos = false);
  }
}

  Future<void> _switchKos(Map<String, dynamic> kos) async {
  final kosId = kos['id'].toString();
  await Supabase.instance.client.auth.updateUser(
    UserAttributes(data: {'kos_id': kosId}),
  );
  setState(() => _activeKos = kos);
  _overviewCubit.load(kosId: kosId);
}

  Future<void> _saveKos() async {
    final name    = _kosNameCtrl.text.trim();
    final address = _kosAddressCtrl.text.trim();
    final phone   = _kosPhoneCtrl.text.trim();
    final capRaw  = _kosCapacityCtrl.text.trim();

    if (name.isEmpty || address.isEmpty || phone.isEmpty || capRaw.isEmpty) {
      _showSnack('Semua field wajib diisi', isSuccess: false);
      return;
    }
    final capacity = int.tryParse(capRaw);
    if (capacity == null || capacity <= 0) {
      _showSnack('Jumlah kamar tidak valid', isSuccess: false);
      return;
    }
    final ownerId = _kosRepo.currentUserId;
    if (ownerId == null || ownerId.isEmpty) {
      _showSnack('Belum login', isSuccess: false);
      return;
    }

    setState(() => _isSubmittingKos = true);
    try {
      final kosId = await _kosRepo.createKos(
        name: name,
        address: address,
        phone: phone,
        capacities: capRaw,
        ownerId: ownerId,
      );
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'kos_id': kosId}),
      );
      await _loadKos();
      if (!mounted) return;
      Navigator.pop(context);
      _kosNameCtrl.clear();
      _kosAddressCtrl.clear();
      _kosCapacityCtrl.clear();
      _kosPhoneCtrl.clear();
      _showSnack('Kos berhasil didaftarkan', isSuccess: true);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Gagal: $e', isSuccess: false);
    } finally {
      if (mounted) setState(() => _isSubmittingKos = false);
    }
  }

  // ── Kos Switcher Sheet ────────────────────────────────────────────────────
  void _showKosSwitcherSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const Text(
              'Pilih Kos Aktif',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Semua data akan berubah sesuai kos yang dipilih',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            ..._kosList.map((kos) {
              final isActive =
                  kos['id'].toString() == _activeKos?['id']?.toString();
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _switchKos(kos);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFFF5F3FF)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isActive
                          ? const Color(0xFF6D5EF6)
                          : const Color(0xFFE2E8F0),
                      width: isActive ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.home_rounded,
                        color: isActive
                            ? const Color(0xFF6D5EF6)
                            : const Color(0xFF94A3B8),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              kos['name']?.toString() ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isActive
                                    ? const Color(0xFF6D5EF6)
                                    : const Color(0xFF1E293B),
                              ),
                            ),
                            if ((kos['address'] ?? '').toString().isNotEmpty)
                              Text(
                                kos['address'].toString(),
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      if (isActive)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF6D5EF6),
                          size: 20,
                        ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _openKosBottomSheet();
              },
              icon: const Icon(Icons.add_rounded, size: 18, color: Color(0xFF6D5EF6)),
              label: const Text(
                'Daftarkan Kos Baru',
                style: TextStyle(color: Color(0xFF6D5EF6), fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: const BorderSide(color: Color(0xFF6D5EF6), width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Kos Registration Sheet ────────────────────────────────────────────────
  void _openKosBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            top: 12,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.add_home_work_rounded,
                          color: Color(0xFF6D5EF6), size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daftarkan Kos Baru',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Isi detail properti kos Anda',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildField(
                  controller: _kosNameCtrl,
                  label: 'Nama Kos',
                  hint: 'Kos Ananda Jaya',
                  icon: Icons.home_work_rounded,
                ),
                const SizedBox(height: 14),
                _buildField(
                  controller: _kosAddressCtrl,
                  label: 'Alamat Lengkap',
                  hint: 'Jl. Ngesrep Timur V No.12, Banyumanik...',
                  icon: Icons.location_on_rounded,
                  maxLines: 3,
                ),
                const SizedBox(height: 14),
                _buildField(
                  controller: _kosPhoneCtrl,
                  label: 'Nomor Telepon',
                  hint: '08xxxxxxxxxx',
                  icon: Icons.phone_outlined,
                  inputType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 14),
                _buildField(
                  controller: _kosCapacityCtrl,
                  label: 'Jumlah Kamar',
                  hint: 'Contoh: 12',
                  icon: Icons.meeting_room_rounded,
                  inputType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Batal',
                            style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isSubmittingKos
                            ? null
                            : () async {
                                setSheet(() => _isSubmittingKos = true);
                                await _saveKos();
                                setSheet(() => _isSubmittingKos = false);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6D5EF6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isSubmittingKos
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'Daftarkan Kos',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? hint,
    required IconData icon,
    bool readOnly = false,
    int maxLines = 1,
    TextInputType inputType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      maxLines: maxLines,
      keyboardType: inputType,
      inputFormatters: inputFormatters,
      style: TextStyle(
        fontSize: 14,
        color: readOnly ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Color(0xFF64748B)),
        prefixIcon: Icon(icon,
            size: 20,
            color: readOnly
                ? const Color(0xFF94A3B8)
                : const Color(0xFF64748B)),
        filled: readOnly,
        fillColor: readOnly ? const Color(0xFFF8FAFC) : null,
        alignLabelWithHint: maxLines > 1,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFF6D5EF6), width: 1.5),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      // Di bagian Scaffold, gunakan AppBar biasa (bukan SliverAppBar):

appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: const Text(
          'KOSKITA',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          // Notifikasi saja, tanpa icon yang tidak perlu
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: Color(0xFF64748B),
                  size: 22,
                ),
                onPressed: () {},
              ),
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF43F5E),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFF8FAFC),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      backgroundColor: const Color(
        0xFFF8FAFC,
      ), 
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF6D5EF6),
                          Color(0xFF7C6EFA),
                          Color(0xFF48B3FF),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6D5EF6).withOpacity(0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Stack(
                        children: [
                          // Decorative circles
                          Positioned(
                            right: -40,
                            top: -40,
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.06),
                              ),
                            ),
                          ),
                          Positioned(
                            left: -20,
                            bottom: -30,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.04),
                              ),
                            ),
                          ),
                          // Content
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Properti aktif chip
                                GestureDetector(
                                  onTap: _kosList.isEmpty
                                      ? _openKosBottomSheet
                                      : _showKosSwitcherSheet,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.18),
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(5),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.2,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.home_work_rounded,
                                            color: Colors.white,
                                            size: 12,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        _isLoadingKos
                                            ? const SizedBox(
                                                width: 12,
                                                height: 12,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 1.5,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : Text(
                                                _activeKos?['name']
                                                        ?.toString() ??
                                                    'Tambah Kos',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          color: Colors.white.withOpacity(0.7),
                                          size: 16,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                // Greeting
                                Text(
                                  '${_greeting()},',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.75),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Pengelola Properti',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.8,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Berikut adalah rangkuman performa operasional kos Anda.',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── MAIN CONTENT ──────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  BlocBuilder<KosOverviewCubit, KosOverviewState>(
                    bloc: _overviewCubit,
                    builder: (context, state) {
                      if (state is KosOverviewLoading ||
                          state is KosOverviewInitial) {
                        return _buildSkeletonLoading();
                      }
                      if (state is KosOverviewError) {
                        return _buildErrorState(context, state, textTheme);
                      }
                      if (state is! KosOverviewLoaded) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 60),
                            child: Text('Tidak dapat memuat data'),
                          ),
                        );
                      }

                      final s = state;
                      final totalRooms = s.occupiedRooms + s.availableRooms;
                      final occupancyRate = totalRooms == 0 ? 0.0 : s.occupiedRooms / totalRooms;

                      return FadeTransition(
                        opacity: _animationController,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            
                            const SizedBox(height: 20),
                            _buildOccupancyCard(s, totalRooms, occupancyRate),
                            const SizedBox(height: 20),
                            _buildFinancialChart(s),
                            const SizedBox(height: 16),
                            // ── REFINED SUMMARY CARDS (CLEAN FINTECH STYLE) ──
                            Row(
                              children: [
                                Expanded(
                                  child: _buildEnhancedSummaryCard(
                                    title: 'Total Pemasukan',
                                    value: _showAmount ? s.incomeFormatted : 'Rp ••••••',
                                    icon: Icons.trending_up_rounded,
                                    accentColor: const Color(0xFF10B981),
                                    bgColor: const Color(0xFFF0FDF4),
                                    subValue: '+8.2%',
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildEnhancedSummaryCard(
                                    title: 'Total Pengeluaran',
                                    value: _showAmount ? s.expenseFormatted : 'Rp ••••••',
                                    icon: Icons.trending_down_rounded,
                                    accentColor: const Color(0xFFEF4444),
                                    bgColor: const Color(0xFFFEF2F2),
                                    subValue: '-3.1%',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildNetProfitCard(s, textTheme),
                            const SizedBox(height: 24),
                            if (s.overdues.isNotEmpty) ...[
                              _buildOverdueSection(s, textTheme),
                              const SizedBox(height: 16),
                            ],
                            _buildQuickActionsSection(),
                            const SizedBox(height: 28),
                            _buildActivityFeedSection(s, textTheme),
                          ],
                        ),
                      );
                    },
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  WIDGET BUILDERS
  // ══════════════════════════════════════════════════════════════════════════

  

  Widget _buildOccupancyCard(KosOverviewLoaded s, int totalRooms, double occupancyRate) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.02),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            height: 84,
            child: Stack(
              alignment: Alignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: occupancyRate),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return SizedBox(
                      width: 84,
                      height: 84,
                      child: CircularProgressIndicator(
                        value: value,
                        strokeWidth: 7,
                        backgroundColor: const Color(0xFFF1F5F9),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6D5EF6)),
                      ),
                    );
                  },
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(occupancyRate * 100).toInt()}%',
                      style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5),
                    ),
                    const Text(
                      'Rasio Hunian',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              children: [
                _buildStatRow('Total Kamar', '$totalRooms', Icons.meeting_room_rounded, const Color(0xFF6D5EF6)),
                const SizedBox(height: 10),
                _buildStatRow('Kamar Terisi', '${s.occupiedRooms}', Icons.bed_rounded, const Color(0xFF10B981)),
                const SizedBox(height: 10),
                _buildStatRow('Kamar Kosong', '${s.availableRooms}', Icons.door_back_door_outlined, const Color(0xFFF59E0B)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialChart(KosOverviewLoaded s) {
    final List<FlSpot> spots = _selectedTimeRange == 0
        ? [const FlSpot(0, 2), const FlSpot(1, 3), const FlSpot(2, 2.5), const FlSpot(3, 4)]
        : _selectedTimeRange == 1
            ? [const FlSpot(0, 3), const FlSpot(1, 4), const FlSpot(2, 3.5), const FlSpot(3, 5), const FlSpot(4, 4.5), const FlSpot(5, 6)]
            : [const FlSpot(0, 1), const FlSpot(1, 3), const FlSpot(2, 5), const FlSpot(3, 4), const FlSpot(4, 6), const FlSpot(5, 7)];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.02),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Bulan ini',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.trending_up_rounded, size: 12, color: Color(0xFF10B981)),
                    SizedBox(width: 4),
                    Text('+12.5%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 150,
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF0F172A),
                    tooltipRoundedRadius: 12,
                    getTooltipItems: (spots) => spots
                        .map((s) => LineTooltipItem(
                              'Periode ${s.x.toInt()}\nRp ${(s.y * 1000).toInt()}k',
                              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                            ))
                        .toList(),
                  ),
                ),
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    gradient: const LinearGradient(colors: [Color(0xFF6D5EF6), Color(0xFF48B3FF)]),
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF6D5EF6).withOpacity(0.1),
                          const Color(0xFF6D5EF6).withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  

  Widget _buildEnhancedSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
    required String subValue,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: accentColor, size: 18),
              ),
              Text(subValue, style: TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              value,
              key: ValueKey<String>(value),
              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: -0.5),
            ),
          ),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildNetProfitCard(KosOverviewLoaded s, TextTheme textTheme) {
    final netProfit = s.income - s.expense;
    final isProfit  = netProfit >= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF6D5EF6), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Laba Bersih (Net)',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 1),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    _showAmount ? _calculateNetProfit(s.income, s.expense) : 'Rp ••••••',
                    key: ValueKey<bool>(_showAmount),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isProfit ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    ),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _showAmount = !_showAmount),
            child: Icon(
              _showAmount ? Icons.visibility_rounded : Icons.visibility_off_rounded,
              size: 20,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  

  Widget _buildOverdueSection(KosOverviewLoaded s, TextTheme textTheme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 18),
          ),
          title: const Text('Notifikasi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
          subtitle: Text('${s.overdues.length} penyewa melewati batas waktu', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
          children: [
            const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 16, endIndent: 16),
            ...s.overdues.map((o) => _buildOverdueItem(o)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildOverdueItem(dynamic o) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFEE2E2)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(o.tenantName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF991B1B))),
                  Text('Kamar ${o.room} • Terlambat ${o.daysOverdue} Hari', style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(
                    _showAmount ? o.amountFormatted : 'Rp ••••••',
                    style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _showSettleDialog(o),
              icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 24),
              tooltip: 'Tandai Lunas',
            ),
          ],
        ),
      ),
    );
  }

  void _showSettleDialog(dynamic o) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Konfirmasi Pelunasan', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Apakah ${o.tenantName} telah melunasi tunggakan sebesar ${o.amountFormatted}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B)))),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Ya, Lunas', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981)))),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      _overviewCubit.settleOverdue(o);
}
  }

  Widget _buildQuickActionsSection() {
    final actions = [
      
      {
        'icon': Icons.meeting_room_outlined,
        'label': 'Buat\nKamar',
        'color': const Color(0xFF10B981),
        'bgColor': const Color(0xFFF0FDF4),
        'onTap': () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RoomsPage())),
      },
      
    
      {
        'icon': Icons.receipt_long_outlined,
        'label': 'Lihat\nTransaksi',
        'color': const Color(0xFFEF4444),
        'bgColor': const Color(0xFFFEF2F2),
        'onTap': () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const FinancePage()))
            .then((_) {
              TransactionRefreshNotifier.instance.notifyTransactionsChanged();
            }),
      },
      {
        'icon': Icons.bar_chart_rounded,
        'label': 'Nanti\nGanti',
        'color': const Color(0xFFF59E0B),
        'bgColor': const Color(0xFFFFFBEB),
        'onTap': () {},
      },
      {
        'icon': Icons.view_headline,
        'label': 'Lihat\nlainnya',
        'color': const Color(0xFFEF4444),
        'bgColor': const Color(0xFFFEF2F2),
        'onTap': () {},
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Aksi Cepat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: actions.map((action) {
            return InkWell(
              onTap: action['onTap'] as VoidCallback,
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 72,
                child: Column(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: action['bgColor'] as Color,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: (action['color'] as Color).withOpacity(0.05)),
                      ),
                      child: Icon(action['icon'] as IconData, color: action['color'] as Color, size: 22),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      action['label'] as String,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569), letterSpacing: -0.3),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

Widget _buildActivityFeedSection(KosOverviewLoaded s, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Aktivitas Terkini',
          subtitle: '5 aktivitas terbaru',
          rightText: 'Lihat Semua',
          onRightTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FinancePage()),
            );
          },
        ),
        const SizedBox(height: 12),
        if (s.recentActivities.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 40,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 8),
                Text(
                  'Belum ada aktivitas',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: s.recentActivities.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final activity = s.recentActivities[index];
              return _ActivityCard(activity: activity);
            },
          ),
      ],
    );
  }
  Widget _buildStatRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: color.withOpacity(0.08), shape: BoxShape.circle),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Color(0xFF475569), fontSize: 13, fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(value, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildSkeletonLoading() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE2E8F0),
      highlightColor: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          Container(height: 130, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24))),
          const SizedBox(height: 16),
          Container(height: 170, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24))),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, KosOverviewError state, TextTheme textTheme) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 44, color: Color(0xFFEF4444)),
          const SizedBox(height: 12),
          Text(state.message, style: const TextStyle(color: Color(0xFF475569), fontSize: 14)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              final kosId = _activeKos?['id']?.toString();
              if (kosId != null) _overviewCubit.load(kosId: kosId);
            },
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    ),
  );
}
}

Widget _buildFinancialChart(KosOverviewLoaded s) {
  final spots = s.chartSpots; // sudah diolah per minggu

  return Container(
    // ... decorasi
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Bulan ini',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
            ),
            // Hapus label "+12.5%" karena tidak relevan
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 150,
          child: LineChart(
            LineChartData(
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => const Color(0xFF0F172A),
                  tooltipRoundedRadius: 12,
                  getTooltipItems: (spots) => spots
                      .map((s) => LineTooltipItem(
                            'Minggu ${s.x.toInt() + 1}\nRp ${s.y.toStringAsFixed(0)}',
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                          ))
                      .toList(),
                ),
              ),
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.35,
                  gradient: const LinearGradient(colors: [Color(0xFF6D5EF6), Color(0xFF48B3FF)]),
                  barWidth: 4,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF6D5EF6).withOpacity(0.1),
                        const Color(0xFF6D5EF6).withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _ActivityCard extends StatelessWidget {
  final ActivityEntity activity;
  const _ActivityCard({required this.activity, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: activity.bgColor, 
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              activity.icon, 
              color: activity.iconColor, 
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                if (activity.subtitle != null)
                  Text(
                    activity.subtitle!,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (activity.amount != null)
                Text(
                  activity.amountFormatted!,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: activity.isPositive ? Colors.green : Colors.red,
                  ),
                ),
              Text(
                activity.formattedTime,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}



