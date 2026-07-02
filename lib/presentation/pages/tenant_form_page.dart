import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kos_app/data/repositories/supabase_kos_repository.dart';
import 'package:kos_app/data/repositories/supabase_tenant_repository.dart';
import 'package:permission_handler/permission_handler.dart';
import 'assign_room_page.dart';

class TenantFormPage extends StatefulWidget {
  final String? tenantId;
  final String? initialName;

  const TenantFormPage({
    super.key,
    this.tenantId,
    this.initialName,
  });

  @override
  State<TenantFormPage> createState() => _TenantFormPageState();
}

class _TenantFormPageState extends State<TenantFormPage> {
  // ── CONTROLLERS ────────────────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _idNumberCtrl = TextEditingController();
  final _emergencyNameCtrl = TextEditingController();
  final _emergencyPhoneCtrl = TextEditingController();

  // ── STATE ──────────────────────────────────────────────────────────────────
  bool _isLoadingData = false;
  bool _isSubmitting = false;

  File? _profilePhoto;
  File? _idCardPhoto;
  String? _profilePhotoUrl;
  String? _idCardPhotoUrl;

  // ── REPOSITORY ─────────────────────────────────────────────────────────────
  final _repo = SupabaseKosRepository();
  final _tenantRepo = SupabaseTenantRepository();

  // ── LIFECYCLE ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.initialName ?? '';
    _initEdit();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _idNumberCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    super.dispose();
  }

  // ── DATA LOADING ───────────────────────────────────────────────────────────
  Future<void> _initEdit() async {
    if (widget.tenantId == null) return;
    setState(() => _isLoadingData = true);

    try {
      final tenant = await _tenantRepo.fetchTenantById(widget.tenantId!);
      if (!mounted || tenant == null) return;

      final parts = (tenant.emergencyContact ?? '').split('/');

      setState(() {
        _nameCtrl.text = tenant.fullName;
        _phoneCtrl.text = tenant.phone ?? '';
        _addressCtrl.text = tenant.address ?? '';
        _idNumberCtrl.text = tenant.idCardNumber ?? '';
        _profilePhotoUrl = tenant.tenantsUrl;
        _idCardPhotoUrl = tenant.idCardUrl;
        _emergencyNameCtrl.text = parts.isNotEmpty ? parts.first.trim() : '';
        _emergencyPhoneCtrl.text = parts.length > 1 ? parts[1].trim() : '';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat data: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  // ── PERMISSION & IMAGE PICKING ─────────────────────────────────────────────
  Future<bool> _ensurePermission(Permission permission) async {
    try {
      final status = await permission.request();
      if (status.isGranted) return true;

      if (!mounted) return false;

      final message = status.isPermanentlyDenied
          ? 'Izin tidak tersedia. Silakan aktifkan izin di Settings.'
          : 'Izin ${permission.toString()} ditolak';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return false;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal request izin: $e')),
        );
      }
      return false;
    }
  }

  Future<void> _pickImage(ImageSource source, bool isProfile) async {
    final permission =
        source == ImageSource.camera ? Permission.camera : Permission.storage;

    final ok = await _ensurePermission(permission);
    if (!ok) return;

    final XFile? picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1200,
    );
    if (picked == null) return;

    try {
      final localFile = await _resolveFile(picked);
      setState(() {
        if (isProfile) {
          _profilePhoto = localFile;
        } else {
          _idCardPhoto = localFile;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memproses foto: $e')),
      );
    }
  }

  Future<File> _resolveFile(XFile picked) async {
    final original = File(picked.path);
    if (await original.exists()) {
      try {
        await original.length();
        return original;
      } catch (_) {}
    }
    return _copyToTemp(picked);
  }

  Future<File> _copyToTemp(XFile picked) async {
    final bytes = await picked.readAsBytes();
    final ext = picked.name.contains('.') ? picked.name.split('.').last : 'jpg';
    final path =
        '${Directory.systemTemp.path}/kos_app_${DateTime.now().millisecondsSinceEpoch}.$ext';
    return File(path)..writeAsBytesSync(bytes, flush: true);
  }

  // ── SUBMIT ─────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    if (name.isEmpty) {
      _showSnack('Nama penghuni wajib diisi');
      return;
    }
    if (phone.isEmpty) {
      _showSnack('Nomor HP wajib diisi');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final isEdit = widget.tenantId != null && widget.tenantId!.isNotEmpty;
      isEdit ? await _updateTenant(name, phone) : await _createTenant(name, phone);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Gagal menyimpan data: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _updateTenant(String name, String phone) async {
    final tenantId = widget.tenantId!;
    await _tenantRepo.updateTenantBasic(
      tenantId: tenantId,
      fullName: name,
      phone: phone,
      address: _valueOrNull(_addressCtrl),
      idNumber: _valueOrNull(_idNumberCtrl),
      emergencyName: _valueOrNull(_emergencyNameCtrl),
      emergencyPhone: _valueOrNull(_emergencyPhoneCtrl),
    );

    String? photoUrl = _profilePhotoUrl;
    String? idCardUrl = _idCardPhotoUrl;

    if (_profilePhoto != null) {
      photoUrl = await _tenantRepo.uploadTenantPhoto(
        tenantId: tenantId,
        file: _profilePhoto!,
      );
    } else {
      photoUrl = null;
    }

    if (_idCardPhoto != null) {
      idCardUrl = await _tenantRepo.uploadIdCardPhoto(
        tenantId: tenantId,
        file: _idCardPhoto!,
      );
    } else {
      idCardUrl = null;
    }

    await _tenantRepo.updateTenantPhotos(
      tenantId: tenantId,
      tenantsUrl: photoUrl,
      idCardUrl: idCardUrl,
    );

    if (!mounted) return;
    _showSnack('Penghuni "$name" berhasil diperbarui');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pop(true);
    });
  }

  Future<void> _createTenant(String name, String phone) async {
    final kosId = _repo.requireCurrentKosId();

    final tenantId = await _tenantRepo.createTenant(
      fullName: name,
      phone: phone,
      address: _valueOrNull(_addressCtrl),
      idNumber: _valueOrNull(_idNumberCtrl),
      emergencyName: _valueOrNull(_emergencyNameCtrl),
      emergencyPhone: _valueOrNull(_emergencyPhoneCtrl),
      kosId: kosId,
    );

    String? photoUrl;
    String? idCardUrl;

    if (_profilePhoto != null) {
      photoUrl = await _tenantRepo.uploadTenantPhoto(tenantId: tenantId, file: _profilePhoto!);
    }
    if (_idCardPhoto != null) {
      idCardUrl = await _tenantRepo.uploadIdCardPhoto(tenantId: tenantId, file: _idCardPhoto!);
    }

    await _tenantRepo.updateTenantPhotos(tenantId: tenantId, tenantsUrl: photoUrl, idCardUrl: idCardUrl);

    if (!mounted) return;
    _showSnack('Penghuni "$name" berhasil didaftarkan');

    // Tanya apakah langsung mau assign kamar
    final assignNow = await showDialog<bool>(
  context: context,
  barrierDismissible: false, // Menghindari dialog tertutup tidak sengaja jika diklik luarnya
  builder: (ctx) => Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    elevation: 0,
    backgroundColor: Colors.transparent,
    child: Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20.0,
            offset: Offset(0.0, 10.0),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Agar tinggi dialog menyesuaikan konten
        children: [
          // 1. Bagian Ikon/Visual di Atas
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF6D5EF6).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              size: 54,
              color: Color(0xFF6D5EF6),
            ),
          ),
          const SizedBox(height: 20),

          // 2. Judul
          const Text(
            'Berhasil Didaftarkan!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),

          // 3. Deskripsi / Pertanyaan
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.4),
              children: [
                const TextSpan(text: 'Penghuni '),
                TextSpan(
                  text: '"$name" ',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const TextSpan(text: 'sudah terdata.\nApakah Anda ingin langsung menempatkannya ke kamar?'),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // 4. Tombol Aksi (Dibuat vertikal agar lebih leluasa dan modern)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6D5EF6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(
                'Ya, Tempatkan Kamar',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(
                'Nanti Saja',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);

    if (!mounted) return;

    if (assignNow == true) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AssignRoomPage(tenantId: tenantId)),
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
}

  // ── HELPERS ────────────────────────────────────────────────────────────────
  String? _valueOrNull(TextEditingController ctrl) {
    final v = ctrl.text.trim();
    return v.isEmpty ? null : v;
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── BOTTOM SHEET ───────────────────────────────────────────────────────────
  void _showPhotoSourceSheet({required bool isProfile}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final hasCurrent = isProfile ? _profilePhoto != null : _idCardPhoto != null;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isProfile ? 'Pilih Foto Penghuni' : 'Pilih Foto KTP / ID',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: _sheetIcon(Icons.camera_alt_rounded, const Color(0xFF6D5EF6)),
                  title: const Text(
                    'Ambil dari Kamera',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _pickImage(ImageSource.camera, isProfile);
                  },
                ),
                ListTile(
                  leading: _sheetIcon(Icons.photo_library_rounded, const Color(0xFF22C55E)),
                  title: const Text(
                    'Pilih dari Galeri',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _pickImage(ImageSource.gallery, isProfile);
                  },
                ),
                if (hasCurrent)
                  ListTile(
                    leading: _sheetIcon(Icons.delete_outline_rounded, Colors.redAccent),
                    title: const Text(
                      'Hapus Foto',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.redAccent,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      setState(() {
                        if (isProfile) {
                          _profilePhoto = null;
                        } else {
                          _idCardPhoto = null;
                        }
                      });
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sheetIcon(IconData icon, Color color) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color),
    );
  }

  // ── REUSABLE UI BUILDERS ───────────────────────────────────────────────────
  InputDecoration _inputDecoration(String label, {IconData? icon, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null
          ? Icon(icon, color: const Color(0xFF6D5EF6), size: 22)
          : null,
      filled: true,
      fillColor: const Color(0xFFF8F9FD),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Color(0xFF6D5EF6), width: 1.5),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8, top: 16),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  // ── PROFILE PHOTO WIDGET ───────────────────────────────────────────────────
  Widget _buildProfilePhoto() {
    Widget photoContent;

    if (_profilePhoto != null) {
      photoContent = Image.file(
        _profilePhoto!,
        width: 110,
        height: 110,
        fit: BoxFit.cover,
      );
    } else if (_profilePhotoUrl != null && _profilePhotoUrl!.trim().isNotEmpty) {
      photoContent = CachedNetworkImage(
        imageUrl: _profilePhotoUrl!,
        width: 110,
        height: 110,
        fit: BoxFit.cover,
        memCacheWidth: 330, // 110 * 3 dpr
        memCacheHeight: 330,
        placeholder: (_, __) =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorWidget: (_, __, ___) =>
            const Icon(Icons.person_rounded, size: 54, color: Color(0xFFBFC3D9)),
      );
    } else {
      photoContent =
          const Icon(Icons.person_rounded, size: 54, color: Color(0xFFBFC3D9));
    }

    return Center(
      child: GestureDetector(
        onTap: () => _showPhotoSourceSheet(isProfile: true),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipOval(child: photoContent),
                ),
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF6D5EF6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _profilePhoto == null ? 'Tambah Foto Profil' : 'Ubah Foto Profil',
              style: const TextStyle(
                color: Colors.black45,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── ID CARD PHOTO WIDGET ───────────────────────────────────────────────────
  Widget _buildIdCardPhoto() {
    Widget? overlay;

    if (_idCardPhoto != null) {
      overlay = Image.file(
        _idCardPhoto!,
        width: double.infinity,
        height: 130,
        fit: BoxFit.cover,
      );
    } else if (_idCardPhotoUrl != null && _idCardPhotoUrl!.trim().isNotEmpty) {
      overlay = CachedNetworkImage(
        imageUrl: _idCardPhotoUrl!,
        width: double.infinity,
        height: 130,
        fit: BoxFit.cover,
        memCacheHeight: 390, // 130 * 3 dpr scale down
        placeholder: (_, __) =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorWidget: (_, __, ___) =>
            const Icon(Icons.broken_image_rounded, color: Colors.black26),
      );
    }

    return GestureDetector(
      onTap: () => _showPhotoSourceSheet(isProfile: false),
      child: Container(
        width: double.infinity,
        height: 130,
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FD),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
        ),
        clipBehavior: Clip.antiAlias,
        child: overlay ??
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_photo_alternate_rounded,
                  size: 36,
                  color: const Color(0xFF6D5EF6).withOpacity(0.6),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Unggah Foto KTP',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
      ),
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.tenantId != null && widget.tenantId!.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F6FA),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Text(
          isEditMode ? 'Ubah Data Penghuni' : 'Tambah Penghuni',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: Colors.black87,
              ),
        ),
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildProfilePhoto(),
                    const SizedBox(height: 4),
                    _sectionCard(
                      title: 'Data Pribadi',
                      children: [
                        TextField(
                          controller: _nameCtrl,
                          decoration: _inputDecoration(
                            'Nama Lengkap',
                            hint: 'Contoh: Budi Santoso',
                            icon: Icons.person_rounded,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: _inputDecoration(
                            'Nomor HP',
                            hint: 'Contoh: 08xxxxxxxxxx',
                            icon: Icons.phone_rounded,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _addressCtrl,
                          decoration: _inputDecoration(
                            'Alamat Rumah KTP',
                            hint: 'Sesuai KTP (Opsional)',
                            icon: Icons.home_rounded,
                          ),
                        ),
                      ],
                    ),
                    _sectionCard(
                      title: 'Identitas Resmi (KTP)',
                      children: [
                        TextField(
                          controller: _idNumberCtrl,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration(
                            'No. KTP / ID Card',
                            hint: '16 Digit No. KTP (Opsional)',
                            icon: Icons.badge_rounded,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildIdCardPhoto(),
                      ],
                    ),
                    _sectionCard(
                      title: 'Kontak Darurat (Kerabat)',
                      children: [
                        TextField(
                          controller: _emergencyNameCtrl,
                          decoration: _inputDecoration(
                            'Nama Penjamin / Kerabat',
                            hint: 'Contoh: Siti Aminah (Ibu)',
                            icon: Icons.assignment_ind_rounded,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _emergencyPhoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: _inputDecoration(
                            'No. HP Kerabat',
                            hint: 'Contoh: 08xxxxxxxxxx',
                            icon: Icons.contact_phone_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6D5EF6),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline_rounded, size: 20),
                        label: Text(
                          _isSubmitting
                              ? 'Memproses...'
                              : isEditMode
                                  ? 'Update Data Penghuni'
                                  : 'Daftarkan Penghuni',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
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