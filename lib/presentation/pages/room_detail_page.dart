import 'package:flutter/material.dart';
import '../../data/repositories/supabase_room_repository.dart';
import '../../data/repositories/supabase_occupancy_repository.dart';
import '../../data/repositories/supabase_tenant_repository.dart';
import '../../domain/entities/room_entity.dart';
import 'room_form_page.dart';
import '../../app/supabase_client_wrapper.dart';


class RoomDetailPage extends StatefulWidget {

  final String roomId;
  final VoidCallback? onDelete;
  const RoomDetailPage({super.key, required this.roomId, this.onDelete});
  @override
  State<RoomDetailPage> createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends State<RoomDetailPage> {
  final _occupancyRepo = SupabaseOccupancyRepository();
  late final _repo = SupabaseRoomRepository(occupancyRepo: _occupancyRepo);
  int _currentPhotoIndex = 0;
  bool _isLoading = true;
  String? _error;

  RoomEntity? _room;
  List<String> _photoUrls = const [];

  String _accessUnitLabel = 'Pemilik & Penghuni';


  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Pastikan badge occupancy detail kamar sinkron dengan RoomsPage.
      // RoomsPage menggunakan fetchAllRoomsWithOccupancyStatus() yang menghitung occupancy dari tabel `occupancies`.
      // Di detail sebelumnya, kita memakai fetchRoomById() yang tidak mengisi `isOccupied`.
      final allRooms = await _repo.fetchAllRoomsWithOccupancyStatus(
        activeKosId: SupabaseClientWrapper.getKosId(),
      );
      final room = allRooms.where((r) => r.id == widget.roomId).cast<RoomEntity?>().firstOrNull;

      if (!mounted) return;

      if (room == null) {
        setState(() {
          _room = null;
          _photoUrls = const [];
          _accessUnitLabel = 'owner';
          _error = 'Room tidak ditemukan.';
          _isLoading = false;
        });
        return;
      }

      // Hitung label akses unit: tenant jika terisi, owner jika kosong.
      final kosId = SupabaseClientWrapper.getKosId();
      String accessLabel = 'owner';
      if (kosId != null && kosId.isNotEmpty) {
        final active = await _occupancyRepo.fetchActiveOccupancyByRoom(
          roomId: widget.roomId,
          kosId: kosId,
        );

        if (active?.tenantId != null && (active!.tenantId ?? '').isNotEmpty) {
          final tenantRepo = SupabaseTenantRepository();
          final tenant = await tenantRepo.fetchTenantById(active.tenantId!);
          final tenantName = (tenant?.fullName ?? '').trim();
          if (tenantName.isNotEmpty) {
            accessLabel = tenantName;
          }
        }
      }

      final signedUrls = await _repo.fetchRoomPhotoSignedUrls(roomId: widget.roomId);
      if (!mounted) return;

      setState(() {
        _room = room;
        _photoUrls = signedUrls;
        _currentPhotoIndex = 0;
        _accessUnitLabel = accessLabel;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat detail unit: $e';
        _isLoading = false;
        _accessUnitLabel = 'owner';
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Warna background clean & premium
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 18),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: const Text(
          'Detail Unit Kamar',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
            onPressed: _load,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF6D5EF6)))
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 44, color: Colors.redAccent),
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Muat Ulang'),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6D5EF6), foregroundColor: Colors.white),
                          )
                        ],
                      ),
                    ),
                  )
                : _room == null
                    ? const SizedBox.shrink()
                    : ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        children: [
                          // 1. ===== LIVE PHOTO SLIDER HERO =====
                          Stack(
                            children: [
                              Container(
                                height: 260,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF1E293B).withOpacity(0.04),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: _photoUrls.isEmpty
                                    ? Container(
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                        ),
                                        child: const Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.bed_rounded, color: Color(0xFF94A3B8), size: 48),
                                              SizedBox(height: 8),
                                              Text(
                                                'Belum ada foto unit',
                                                style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                    : PageView.builder(
                                        itemCount: _photoUrls.length,
                                        onPageChanged: (index) => setState(() => _currentPhotoIndex = index),
                                        itemBuilder: (context, index) {
                                          return Image.network(
                                            _photoUrls[index],
                                            fit: BoxFit.cover,
                                            loadingBuilder: (context, child, loadingProgress) {
                                              if (loadingProgress == null) return child;
                                              return Container(
                                                color: const Color(0xFFF8FAFC),
                                                child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6D5EF6))),
                                              );
                                            },
                                            errorBuilder: (_, __, ___) => Container(
                                              color: const Color(0xFFF1F5F9),
                                              child: const Center(
                                                child: Icon(Icons.broken_image_outlined, color: Color(0xFF94A3B8), size: 32),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ),

                              // Gradient overlay tipis di bagian bawah foto
                              if (_photoUrls.isNotEmpty)
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  height: 60,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [Colors.transparent, Colors.black.withOpacity(0.35)],
                                      ),
                                    ),
                                  ),
                                ),

                              // Floating Badge Jumlah Foto Modern (Style Premium)
                              if (_photoUrls.isNotEmpty)
                                Positioned(
                                  bottom: 16,
                                  right: 16,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    child: Text(
                                      '${_currentPhotoIndex + 1} / ${_photoUrls.length} Foto',
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 2. ===== INFO UTAMA & IDENTITAS KAMAR =====
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(color: const Color(0xFF1E293B).withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _room!.name,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F172A),
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ),
                                    
                                    // Status Badge dengan Glowing Dot (Sinkron dengan halaman Rooms)
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _room!.isOccupied ? const Color(0xFFFFF7ED) : const Color(0xFFF0FDF4),
                                        borderRadius: BorderRadius.circular(30),
                                        border: Border.all(
                                          color: _room!.isOccupied ? const Color(0xFFFFEDD5) : const Color(0xFFDCFCE7),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: _room!.isOccupied ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _room!.isOccupied ? 'Terisi' : 'Kosong',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: _room!.isOccupied ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 16),
                                const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                                const SizedBox(height: 16),

                                // Grid Spesifikasi Kamar (Membuat UI tampak padat & informatif tanpa price)
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildSpecCard(
                                        icon: Icons.people_alt_rounded,
                                        title: 'Kapasitas',
                                        value: 'Maks. ${_room!.capacity} Orang',
                                        iconColor: const Color(0xFF2563EB),
                                        bgColor: const Color(0xFFEFF6FF),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildSpecCard(
                                        icon: Icons.vpn_key_rounded,
                                        title: 'Akses Unit',
                                        value: _accessUnitLabel,
                                        iconColor: const Color(0xFF0D9488),
                                        bgColor: const Color(0xFFF0FDFA),
                                      ),

                                    ),
                                  ],
                                ),
                                
                                // 💡 TIPS HARGA: Karena data 'price' tidak ada di DB, kita buat card info statis yang elegan 
                                // agar space visual di bawah nama kamar tidak kosong.
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF64748B)),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Pengaturan harga sewa bulanan diatur via menu Keuangan / Kontrak Penghuni.',
                                          style: TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.4),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 3. ===== SECTION FASILITAS UNIT =====
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(color: const Color(0xFF1E293B).withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEEF2F6),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.star_rounded, color: Color(0xFF6D5EF6), size: 18),
                                    ),
                                    const SizedBox(width: 10),
                                    const Text(
                                      'Fasilitas',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                if (_room!.facilities.isEmpty)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 24),
                                    child: Center(
                                      child: Column(
                                        children: [
                                          Icon(Icons.layers_clear_outlined, color: Colors.grey.shade300, size: 36),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Belum ada fasilitas di kamar ini.',
                                            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _room!.facilities.map((f) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF6D5EF6)),
                                            const SizedBox(width: 8),
                                            Text(
                                              f,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                                color: Color(0xFF334155),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // 4. ===== EDIT ACTION =====
                          if (_room != null)
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFDBEAFE), width: 1),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(color: Color(0xFFDBEAFE), shape: BoxShape.circle),
                                  child: const Icon(Icons.edit_outlined, color: Color(0xFF2563EB), size: 22),
                                ),
                                title: const Text(
                                  'Edit Kamar',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8), fontSize: 14),
                                ),
                                subtitle: const Text(
                                  'Perbarui data unit & galeri foto.',
                                  style: TextStyle(color: Color(0xFF3B82F6), fontSize: 12),
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF2563EB), size: 12),
                                onTap: () async {
                                  final result = await Navigator.of(context).push<bool>(
                                    MaterialPageRoute(
                                      builder: (_) => RoomFormPage(initial: _room),
                                    ),
                                  );

                                  if (result == true && mounted) {
                                    _load();
                                  }
                                },
                              ),
                            ),

                          const SizedBox(height: 12),

                          // 5. ===== DANGER ZONE =====
                          if (widget.onDelete != null)
                            Container(

                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFFEE2E2), width: 1),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(color: Color(0xFFFEE2E2), shape: BoxShape.circle),
                                  child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 22),
                                ),
                                title: const Text(
                                  'Hapus Unit Kamar',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF991B1B), fontSize: 14),
                                ),
                                subtitle: const Text(
                                  'Data kamar & riwayat foto akan dihapus permanen',
                                  style: TextStyle(color: Color(0xFFDC2626), fontSize: 12),
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFEF4444), size: 12),
                                onTap: widget.onDelete,
                              ),
                            ),
                        ],
                      ),
      ),
    );
  }

  // Helper Widget membuat Item Grid Spesifikasi Kamar
  Widget _buildSpecCard({
    required IconData icon,
    required String title,
    required String value,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}