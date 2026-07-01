import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kos_app/data/repositories/supabase_occupancy_repository.dart';
import 'package:kos_app/data/repositories/supabase_room_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/room_entity.dart';
import '../../data/services/b2_signed_url_service.dart';
import '../../app/b2_config.dart';

class RoomFormPage extends StatefulWidget {
  final RoomEntity? initial;
  const RoomFormPage({super.key, this.initial});

  @override
  State<RoomFormPage> createState() => _RoomFormPageState();
}

class _RoomFormPageState extends State<RoomFormPage> {
  final _nameCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  final _facilityCtrl = TextEditingController();
  final _occupancyRepo = SupabaseOccupancyRepository();
  late final _repo = SupabaseRoomRepository(occupancyRepo: _occupancyRepo);
  bool _isSubmitting = false;
  bool _isLoadingKos = true;
  String? _kosId;

  List<String> _facilities=[];
  final List<File> _selectedPhotoFiles = [];
  List<String> _initialPhotoObjectPaths = [];
  List<String> _initialPhotoSignedUrls = [];
  static const _maxPhotos = 8;

  @override
  void initState() {
    super.initState();
    _loadKosId();

    final init = widget.initial;
    if (init != null) {
      _nameCtrl.text = init.name;
      _capacityCtrl.text = init.capacity.toString();
      _facilities = [...init.facilities];
      _initialPhotoObjectPaths = [...init.photoAssetPaths];
      // Signed URLs akan dihitung setelah frame pertama agar bisa akses context & setState aman.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureInitialSignedUrls();
      });
    } else {
      _capacityCtrl.text = '2';
      _facilities = [];
      _initialPhotoObjectPaths = const [];
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _capacityCtrl.dispose();
    _facilityCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadKosId() async {
    try {
      final metaKosId = Supabase
          .instance
          .client
          .auth
          .currentUser
          ?.userMetadata?['kos_id']
          ?.toString();
      if (metaKosId != null && metaKosId.isNotEmpty) {
        if (mounted) {
          setState(() {
            _kosId = metaKosId;
            _isLoadingKos = false;
          });
        }
        return;
      }

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => _isLoadingKos = false);
        return;
      }

      final data = await Supabase.instance.client
          .from('kos')
          .select('id')
          .eq('owner_id', userId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _kosId = data?['id']?.toString();
          _isLoadingKos = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingKos = false);
    }
  }

  InputDecoration _inputDecoration(String label, {String? hint, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: Colors.grey.shade600,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
      prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF6D5EF6), size: 20) : null,
      filled: true,
      fillColor: const Color(0xFFF8F9FC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF6D5EF6), width: 1.5),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 14,
        color: Colors.grey.shade800,
      ),
    );
  }

  void _addFacility() {
    final value = _facilityCtrl.text.trim();
    if (value.isEmpty) return;
    if (_facilities.contains(value)) {
      _facilityCtrl.clear();
      return;
    }
    setState(() {
      _facilities.add(value);
      _facilityCtrl.clear();
    });
  }

  void _removeFacility(String value) {
    setState(() => _facilities.remove(value));
  }

  Future<void> _pickFrom(ImageSource source) async {
    final remaining = _maxPhotos - (_selectedPhotoFiles.length + _initialPhotoObjectPaths.length);
    if (remaining <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maksimal foto sudah tercapai')),
      );
      return;
    }

    final ImagePicker picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: source,
      maxWidth: 1600,
    );

    if (picked == null) return;

    final file = File(picked.path);
    if (!await file.exists()) return;

    setState(() {
      _selectedPhotoFiles.add(file);
    });
  }

  Future<String> _objectNameToSignedUrl(String objectName) {
    return B2SignedUrlService().getSignedDownloadUrl(
      bucketName: B2Config.bucketRoomPhoto,
      objectName: objectName,
      validFor: const Duration(minutes: 10),
    );
  }

  Future<void> _ensureInitialSignedUrls() async {
    if (_initialPhotoSignedUrls.isNotEmpty) return;
    if (_initialPhotoObjectPaths.isEmpty) return;

    final urls = await Future.wait(
      _initialPhotoObjectPaths.map((obj) => _objectNameToSignedUrl(obj)).toList(),
    );

    if (!mounted) return;
    setState(() => _initialPhotoSignedUrls = urls);
  }

  void _showImagePreview({String? networkUrl, File? localFile}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.75),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: FadeTransition(
            opacity: anim1,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: InteractiveViewer(
                      clipBehavior: Clip.none,
                      maxScale: 4.0,
                      child: networkUrl != null
                          ? Image.network(
                              networkUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.broken_image_rounded,
                                color: Colors.white,
                                size: 48,
                              ),
                            )
                          : Image.file(
                              localFile!,
                              fit: BoxFit.contain,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openPhotoSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Tambah Foto Kamar',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Pilih media visual untuk memperbarui galeri unit ini.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _buildModernSheetItem(
                        icon: Icons.camera_alt_rounded,
                        label: 'Kamera',
                        iconColor: const Color(0xFF6D5EF6),
                        bgColor: const Color(0xFF6D5EF6).withOpacity(0.06),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _pickFrom(ImageSource.camera);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildModernSheetItem(
                        icon: Icons.photo_library_rounded,
                        label: 'Galeri',
                        iconColor: const Color(0xFF10B981),
                        bgColor: const Color(0xFF10B981).withOpacity(0.06),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _pickFrom(ImageSource.gallery);
                        },
                      ),
                    ),
                  ],
                ),
                if (_selectedPhotoFiles.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () {
                      Navigator.of(ctx).pop();
                      setState(() => _selectedPhotoFiles.clear());
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFEE2E2), width: 1),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Hapus semua foto baru',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernSheetItem({
    required IconData icon,
    required String label,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final capacity = int.tryParse(_capacityCtrl.text.trim()) ?? 1;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan masukkan nomor/nama kamar dahulu')),
      );
      return;
    }

    final isEdit = widget.initial != null;
    if (!isEdit && _kosId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data kos tidak ditemukan. Coba login ulang.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // ignore: avoid_print
      print('[RoomFormPage] submit isEdit=$isEdit name=$name capacity=$capacity kosId=$_kosId selectedPhotos=${_selectedPhotoFiles.length}');
      final roomId = isEdit ? widget.initial!.id : null;


      if (!isEdit) {
        await _repo.createRoom(
          name: name,
          capacity: capacity,
          facilities: _facilities,
          kosId: _kosId!,
          photoObjectPaths: const [],
          createdBy: Supabase.instance.client.auth.currentUser?.id,
        );

        final created = await Supabase.instance.client
            .from('rooms')
            .select('id')
            .eq('kos_id', _kosId!)
            .eq('name', name)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        final createdRoomId = created?['id']?.toString();
        if (createdRoomId == null || createdRoomId.isEmpty) {
          throw StateError('Room created but roomId not found.');
        }

        if (_selectedPhotoFiles.isNotEmpty) {
          final photoObjectPaths = await _repo.uploadRoomPhotos(
            roomId: createdRoomId,
            files: _selectedPhotoFiles,
          );
          await _repo.updateRoomPhotos(
            roomId: createdRoomId,
            photoObjectPaths: photoObjectPaths,
          );
        }
      } else {
        await _repo.updateRoomBasic(
          roomId: roomId!,
          name: name,
          capacity: capacity,
          facilities: _facilities,
        );

        if (_selectedPhotoFiles.isNotEmpty) {
          final newPhotoObjectPaths = await _repo.uploadRoomPhotos(
            roomId: roomId,
            files: _selectedPhotoFiles,
          );
          final merged = <String>[
            ..._initialPhotoObjectPaths,
            ...newPhotoObjectPaths,
          ];

          await _repo.updateRoomPhotos(
            roomId: roomId,
            photoObjectPaths: merged,
          );
        }
      }

      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pop(true);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan kamar: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FC),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.grey.shade800, size: 20),
          onPressed: () => Navigator.of(context).pop(true),
        ),
        title: Text(
          isEdit ? 'Edit Kamar' : 'Tambah Unit Kamar',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.grey.shade900,
              ),
        ),
        actions: [
          if (_isLoadingKos)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF6D5EF6),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_isLoadingKos && _kosId == null && !isEdit)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Data kos tidak ditemukan. Pastikan akun sudah terdaftar sebagai pemilik kos.',
                          style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              _buildSectionHeader('Informasi Dasar'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _nameCtrl,
                      style: const TextStyle(fontSize: 14),
                      decoration: _inputDecoration(
                        'Nama / Nomor Kamar',
                        hint: 'Contoh: Kamar 04',
                        icon: Icons.meeting_room_outlined,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _capacityCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 14),
                      decoration: _inputDecoration(
                        'Kapasitas Maksimal (Orang)',
                        icon: Icons.people_alt_rounded,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildSectionHeader('Fasilitas Pendukung'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _facilityCtrl,
                            style: const TextStyle(fontSize: 14),
                            decoration: _inputDecoration(
                              'Masukkan item fasilitas',
                              hint: 'Contoh: WiFi, AC, Kamar Mandi Dalam',
                              icon: Icons.star_border_rounded,
                            ),
                            onSubmitted: (_) => _addFacility(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: _addFacility,
                          child: Container(
                            height: 46,
                            width: 46,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6D5EF6),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6D5EF6).withOpacity(0.15),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                          ),
                        ),
                      ],
                    ),
                    if (_facilities.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _facilities.map((f) {
                          return Container(
                            padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6D5EF6).withOpacity(0.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF6D5EF6).withOpacity(0.1)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  f,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Color(0xFF6D5EF6),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => _removeFacility(f),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: const Color(0xFF6D5EF6).withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      Text(
                        'Belum ada fasilitas khusus unit ini.',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildSectionHeader('Galeri Media Foto'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: _openPhotoSourceSheet,
                          style: TextButton.styleFrom(foregroundColor: const Color(0xFF6D5EF6)),
                          icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                          label: const Text('Tambah Foto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                        Text(
                          '${_initialPhotoObjectPaths.length + _selectedPhotoFiles.length} foto',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_initialPhotoObjectPaths.isEmpty && _selectedPhotoFiles.isEmpty)
                      Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.photo_size_select_actual_outlined,
                              color: Colors.grey,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Text(
                              'Belum ada foto visual kamar.',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      SizedBox(
                        height: 80,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _initialPhotoObjectPaths.length + _selectedPhotoFiles.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, i) {
                            final isInitialPhoto = i < _initialPhotoObjectPaths.length;
                            final networkImageUrl = isInitialPhoto
                                ? (_initialPhotoSignedUrls.isNotEmpty
                                    ? _initialPhotoSignedUrls[i]
                                    : null)
                                : null;
                                
                            final localFile = !isInitialPhoto
                                ? _selectedPhotoFiles[i - _initialPhotoObjectPaths.length]
                                : null;

                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                GestureDetector(
                                  onTap: () => _showImagePreview(
                                    networkUrl: networkImageUrl,
                                    localFile: localFile,
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.04),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: isInitialPhoto
                                          ? (networkImageUrl == null)
                                              ? Container(
                                                  width: 80,
                                                  height: 80,
                                                  color: Colors.grey.shade100,
                                                  child: const Center(
                                                    child: SizedBox(
                                                      width: 18,
                                                      height: 18,
                                                      child: CircularProgressIndicator(strokeWidth: 2),
                                                    ),
                                                  ),
                                                )
                                              : Image.network(
                                                  networkImageUrl,
                                                  width: 80,
                                                  height: 80,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (ctx, _, __) => Container(
                                                    width: 80,
                                                    height: 80,
                                                    color: Colors.grey.shade200,
                                                    child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
                                                  ),
                                                )
                                          : Image.file(
                                              localFile!,
                                              width: 80,
                                              height: 80,
                                              fit: BoxFit.cover,
                                            ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: -4,
                                  right: -4,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        if (isInitialPhoto) {
                                          _initialPhotoObjectPaths.removeAt(i);
                                          if (_initialPhotoSignedUrls.isNotEmpty) {
                                            _initialPhotoSignedUrls.removeAt(i);
                                          }
                                        } else {
                                          _selectedPhotoFiles.removeAt(i - _initialPhotoObjectPaths.length);
                                        }
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFEF4444),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 50,
                child: GestureDetector(
                  onTap: (_isSubmitting || _isLoadingKos) ? null : _submit,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: (_isLoadingKos || (!isEdit && _kosId == null))
                            ? [Colors.grey.shade300, Colors.grey.shade400]
                            : const [Color(0xFF6D5EF6), Color(0xFF8B7FF8)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6D5EF6).withOpacity(0.24),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  isEdit ? 'Simpan Perubahan' : 'Tambah Kamar Baru',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}