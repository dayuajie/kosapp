import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/supabase_kos_repository.dart';
import '../../data/repositories/supabase_users_account_repository.dart';
import '../../data/repositories/registration_repository.dart';
import '../../core/kos_refresh_notifier.dart';


class _T {
  
  static const primary = Color(0xFF6D5EF6);
  static const primaryLight = Color(0xFFEEECFE);
  static const surface = Color(0xFFFFFFFF);
  static const bg = Color(0xFFF4F6FB);
  static const border = Color(0xFFE4E8F0);
  static const textMain = Color(0xFF1A1D23);
  static const textSub = Color(0xFF6B7280);
  static const textMuted = Color(0xFF9CA3AF);
  static const success = Color(0xFF22C55E);
  static const danger = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);

  // Radius
  static const r8 = BorderRadius.all(Radius.circular(8));
  static const r12 = BorderRadius.all(Radius.circular(12));
  static const r16 = BorderRadius.all(Radius.circular(16));
  static const r20 = BorderRadius.all(Radius.circular(20));
  static const r24 = BorderRadius.all(Radius.circular(24));

  // Shadow
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
}

// ═════════════════════════════════════════════════════════════════════════════
//  PAGE
// ═════════════════════════════════════════════════════════════════════════════
class EditAccountPage extends StatefulWidget {
  const EditAccountPage({super.key});

  @override
  State<EditAccountPage> createState() => _EditAccountPageState();
}

class _EditAccountPageState extends State<EditAccountPage>
    with SingleTickerProviderStateMixin {
  // ── Kos list state ────────────────────────────────────────────────────
  late final SupabaseKosRepository _kosRepo;
  bool _isLoadingKos = false;
  List<Map<String, dynamic>> _kosList = const [];

  bool _didShowInitialKosRegister = false;

  Future<void> _maybeShowInitialKosRegister() async {
    if (_didShowInitialKosRegister) return;
    _didShowInitialKosRegister = true;

    // Cek langsung dari DB biar akurat (menghindari race condition dengan _kosList).
    final ownerId = _kosRepo.currentUserId;
    if (ownerId == null || ownerId.isEmpty) return;

    try {
      final list = await _kosRepo.fetchKosByOwner(ownerId);
      if (!mounted) return;

      if (list.isEmpty) {
        _openKosBottomSheet();
      }
    } catch (_) {
      // ignore
    }
  }

  // ── Controllers ──────────────────────────────────────────────────────────
  final _nameCtrl = TextEditingController(text: '');
  final _emailCtrl = TextEditingController(text: 'user@example.com');
  final _phoneCtrl = TextEditingController(text: '');
  final _statusCtrl = TextEditingController(text: '');
  final _igCtrl = TextEditingController(text: '');
  final _waCtrl = TextEditingController(text: '');
  final _bankNameCtrl = TextEditingController(text: '');
  final _bankAccountCtrl = TextEditingController(text: '');
  final _bankHolderCtrl = TextEditingController(text: '');

  // Kos sheet controllers
  final _kosNameCtrl = TextEditingController();
  final _kosAddressCtrl = TextEditingController();
  final _kosCapacityCtrl = TextEditingController();
  final _kosPhoneCtrl = TextEditingController();

  // ── State ─────────────────────────────────────────────────────────────────
  bool _isSubmittingProfile = false;
  bool _isSubmittingKos = false;

  // bank_info
  bool _isLoadingBankInfo = false;
  List<Map<String, dynamic>> _bankInfoList = const [];
  bool _notifEmail = true;
  bool _notifSms = false;
  bool _notifPush = true;


  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;
  @override
  void initState() {
    super.initState();
    _kosRepo = SupabaseKosRepository();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _loadKos();
    _loadUserAndAccountStatus();
    _loadBankInfo();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowInitialKosRegister();
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    for (final c in [
      _nameCtrl,
      _emailCtrl,
      _phoneCtrl,
      _igCtrl,
      _waCtrl,
      _statusCtrl,
      _bankNameCtrl,
      _bankAccountCtrl,
      _bankHolderCtrl,
      _kosNameCtrl,
      _kosAddressCtrl,
      _kosCapacityCtrl,
      _kosPhoneCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Ambil Data dari DB ─────────────────────────────────────────────────────
  Future<void> _loadBankInfo() async {
    final repo = RegistrationRepository();
    setState(() => _isLoadingBankInfo = true);
    try {
      final list = await repo.fetchBankAccountsByOwner();
      if (!mounted) return;
      setState(() {
        _bankInfoList = list;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _bankInfoList = const [];
      });
    } finally {
      if (!mounted) return;
      setState(() => _isLoadingBankInfo = false);
    }
  }

  Future<void> _loadUserAndAccountStatus() async {
    final repo = SupabaseUsersAccountRepository();
    final me = await repo.fetchMeWithStatus();
    if (me == null) return;

    final user = me['user'] as Map<String, dynamic>?;
    final account = me['account'] as Map<String, dynamic>?;
    final email = (user?['Email'] ?? user?['email'] ?? '').toString();
    final name = (account?['name'] ?? '').toString();
    final phone = (account?['phone'] ?? '').toString();
    final role = (account?['role'] ?? '').toString();
    final displayStatus = role.isNotEmpty ? role : 'owner';

    if (!mounted) return;
    setState(() {
      _nameCtrl.text = name;
      _emailCtrl.text = email;
      _phoneCtrl.text = phone;
      _statusCtrl.text = displayStatus;
    });
  }

  Future<void> _saveProfile() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      _showSnack('Nama dan nomor telepon tidak boleh kosong', isSuccess: false);
      return;
    }

    setState(() => _isSubmittingProfile = true);

    try {
      final repo = SupabaseUsersAccountRepository();
      await repo.updateUserProfile(name: name, phone: phone);
      await _loadUserAndAccountStatus();
      if (!mounted) return;
      _showSnack('Profil berhasil diperbarui', isSuccess: true);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Gagal memperbarui profil: $e', isSuccess: false);
    } finally {
      if (mounted) setState(() => _isSubmittingProfile = false);
    }
  }

  Future<void> _loadKos() async {
    final ownerId = _kosRepo.currentUserId;
    if (ownerId == null || ownerId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoadingKos = false;
        _kosList = const [];
      });
      return;
    }

    setState(() {
      _isLoadingKos = true;
    });

    try {
     
      final list = await _kosRepo.fetchKosByOwner(ownerId);


      if (!mounted) return;
      setState(() {
        _kosList = list;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _kosList = const [];
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingKos = false;
      });
    }
  }

  Future<void> _saveKos() async {
    final name = _kosNameCtrl.text.trim();

    final address = _kosAddressCtrl.text.trim();
    final phone = _kosPhoneCtrl.text.trim();
    final capacitiesRaw = _kosCapacityCtrl.text.trim();

    if (name.isEmpty ||
        address.isEmpty ||
        capacitiesRaw.isEmpty ||
        phone.isEmpty) {
      _showSnack('Nama, alamat, dan telepon wajib diisi', isSuccess: false);
      return;
    }

    final capacity = int.tryParse(capacitiesRaw);
    if (capacity == null || capacity <= 0) {
      _showSnack('Jumlah kamar tidak valid', isSuccess: false);
      return;
    }

    // NOTE: tabel `kos` butuh owner_id. Saat ini owner_id kita ambil dari auth user.
    final repo = SupabaseKosRepository();
    final ownerId = repo.currentUserId;
    if (ownerId == null || ownerId.isEmpty) {
      _showSnack('Anda belum login. Silakan login ulang.', isSuccess: false);
      return;
    }

    setState(() => _isSubmittingKos = true);
    try {
      // 1) Create Kos
      final kosId = await repo.createKos(
        name: name,
        address: address,
        phone: phone,
        capacities: capacitiesRaw,
        ownerId: ownerId,
      );

      // 2) Simpan kos_id ke auth userMetadata supaya dipakai halaman tenant.
      // Supabase Flutter mengizinkan update user metadata via auth.updateUser.
      final supabase = Supabase.instance.client;
      await supabase.auth.updateUser(UserAttributes(data: {'kos_id': kosId}));
      KosRefreshNotifier.instance.notifyKosChanged();
      await _loadKos();

      if (!mounted) return;
      Navigator.pop(context);

      _kosNameCtrl.clear();
      _kosAddressCtrl.clear();
      _kosCapacityCtrl.clear();
      _kosPhoneCtrl.clear();

      _showSnack('Kos baru berhasil didaftarkan', isSuccess: true);
    } catch (e) {
     

      if (!mounted) return;
      _showSnack('Gagal mendaftarkan kos', isSuccess: false);
      // Jika butuh detail, bisa tampilkan $e juga, tapi saat ini kita simpan dulu ke console.
    } finally {
      if (mounted) setState(() => _isSubmittingKos = false);
    }
  }

  void _showSnack(String msg, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: isSuccess ? _T.success : _T.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BOTTOM SHEET – Daftarkan Kos
  // ═══════════════════════════════════════════════════════════════════════════
  void _openKosBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          decoration: const BoxDecoration(
            color: _T.surface,
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
                // Pill handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: _T.border,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                // Header icon + title
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _T.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.add_home_work_rounded,
                        color: _T.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daftarkan Kos Baru',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Isi detail properti kos Anda',
                          style: TextStyle(fontSize: 12, color: _T.textSub),
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
                          side: const BorderSide(color: _T.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Batal',
                          style: TextStyle(color: _T.textSub),
                        ),
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
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _T.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSubmittingKos
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Daftarkan Kos',
                                style: TextStyle(fontWeight: FontWeight.w600),
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

  // ═══════════════════════════════════════════════════════════════════════════
  //  SHARED WIDGET HELPERS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? hint,
    required IconData icon,
    bool readOnly = false,
    int maxLines = 1,
    TextInputType inputType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? suffixText,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      maxLines: maxLines,
      keyboardType: inputType,
      inputFormatters: inputFormatters,
      style: TextStyle(
        fontSize: 14,
        color: readOnly ? _T.textMuted : _T.textMain,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffixText,
        prefixIcon: Icon(
          icon,
          size: 20,
          color: readOnly ? _T.textMuted : _T.textSub,
        ),
        filled: readOnly,
        fillColor: readOnly ? const Color(0xFFF1F5F9) : null,
        alignLabelWithHint: maxLines > 1,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _T.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _T.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _T.primary, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _T.border),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: _T.textMuted,
        letterSpacing: 1.1,
      ),
    ),
  );

  Widget _buildCard({required Widget child, EdgeInsets? padding}) => Container(
    width: double.infinity,
    padding: padding ?? const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _T.surface,
      borderRadius: _T.r16,
      border: Border.all(color: _T.border),
      boxShadow: _T.cardShadow,
    ),
    child: child,
  );

  Widget _buildToggleRow({
    required String label,
    required String sub,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _T.textMain,
              ),
            ),
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(fontSize: 12, color: _T.textSub)),
          ],
        ),
      ),
      Switch(value: value, onChanged: onChanged, activeColor: _T.primary),
    ],
  );

  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.bg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          slivers: [
            // ── App Bar ───────────────────────────────────────────────────
            SliverAppBar(
              pinned: true,
              expandedHeight: 40,
              backgroundColor: _T.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              title: const Text(
                'Edit Akun',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),

            // ── Body ──────────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // 1. Informasi Pribadi
                  _buildSectionLabel('Informasi Pribadi'),
                  _buildCard(
                    child: Column(
                      children: [
                        _buildField(
                          controller: _emailCtrl,
                          label: 'Email',
                          icon: Icons.email_outlined,
                          readOnly: true,
                        ),
                        const SizedBox(height: 14),
                        _buildField(
                          controller: _nameCtrl,
                          label: 'Nama Lengkap',
                          hint: 'Masukkan nama lengkap',
                          icon: Icons.person_outline,
                        ),
                        const SizedBox(height: 14),
                        _buildField(
                          controller: _phoneCtrl,
                          label: 'Nomor Telepon',
                          hint: '08xxxxxxxxxx',
                          icon: Icons.phone_outlined,
                          inputType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                        const SizedBox(height: 14),
                        _buildField(
                          controller: _statusCtrl,
                          label: 'Status',
                          icon: Icons.badge_rounded,
                          readOnly: true,
                        ),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  // Informasi Pembayaran
                  _buildSectionLabel('Informasi Pembayaran'),
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rekening ini akan ditampilkan kepada penyewa sebagai metode transfer pembayaran.',
                          style: TextStyle(
                            fontSize: 12,
                            color: _T.textSub,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _isLoadingBankInfo
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              )
                            : _bankInfoList.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  'Belum ada informasi pembayaran.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _T.textSub,
                                  ),
                                ),
                              )
                            : Column(
                                children: _bankInfoList
                                    .map((b) => _buildBankInfoItem(b))
                                    .toList(growable: false),
                              ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _openAddBankInfoDialog,
                          icon: const Icon(
                            Icons.add_rounded,
                            size: 18,
                            color: _T.primary,
                          ),
                          label: const Text(
                            'Tambah Rekening',
                            style: TextStyle(color: _T.primary),
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(42),
                            side: const BorderSide(color: _T.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 4. Manajemen Properti
                  _buildSectionLabel('Manajemen Properti'),
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: _T.primaryLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.add_home_work_rounded,
                                color: _T.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tambah Kos',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    'Daftarkan satu atau lebih alamat properti kos.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _T.textSub,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: _T.border, height: 1),
                        const SizedBox(height: 16),
                        // Kos list
                        _isLoadingKos
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              )
                            : _kosList.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  'Belum ada kos yang terdaftar.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _T.textSub,
                                  ),
                                ),
                              )
                            : Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Column(
                                  children: _kosList
                                      .map((k) => _buildKosPreviewItem(k))
                                      .toList(growable: false),
                                ),
                              ),

                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _openKosBottomSheet,
                          icon: const Icon(
                            Icons.add_rounded,
                            size: 18,
                            color: _T.primary,
                          ),
                          label: const Text(
                            'Daftarkan Kos Baru',
                            style: TextStyle(color: _T.primary),
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(46),
                            side: const BorderSide(color: _T.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 5. Notifikasi
                  _buildSectionLabel('Notifikasi'),
                  _buildCard(
                    child: Column(
                      children: [
                        _buildToggleRow(
                          label: 'Email',
                          sub: 'Pengingat & laporan via email',
                          value: _notifEmail,
                          onChanged: (v) => setState(() => _notifEmail = v),
                        ),
                        const Divider(height: 24, color: _T.border),
                        _buildToggleRow(
                          label: 'SMS',
                          sub: 'Notifikasi transaksi via SMS',
                          value: _notifSms,
                          onChanged: (v) => setState(() => _notifSms = v),
                        ),
                        const Divider(height: 24, color: _T.border),
                        _buildToggleRow(
                          label: 'Push Notification',
                          sub: 'Pengingat real-time di perangkat ini',
                          value: _notifPush,
                          onChanged: (v) => setState(() => _notifPush = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Save button
                  ElevatedButton(
                    onPressed: _isSubmittingProfile ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _T.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSubmittingProfile
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Simpan Perubahan',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  

  // ── Bank Info UI helpers ───────────────────────────────────────────────
  String _bankTypeToDb(String selected) {
    return selected.trim() == 'Rekening Bank' ? 'Bank' : 'E-Wallet';
  }

  String _bankTypeToUi(String dbValue) {
    return dbValue == 'Bank' ? 'Rekening Bank' : 'Dompet Digital';
  }

  Widget _buildBankInfoItem(Map<String, dynamic> b) {
    final id = b['id']?.toString() ?? '';
    final bankName = b['bank_name']?.toString() ?? '-';
    final bankNumber = b['bank_number']?.toString() ?? '-';
    final holder = b['bank_account_name']?.toString() ?? '-';
    final bankTypeDb = b['bank_type']?.toString() ?? 'Bank';
    final bankTypeUi = _bankTypeToUi(bankTypeDb);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _T.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _T.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  bankTypeDb == 'Bank'
                      ? Icons.account_balance_rounded
                      : Icons.wallet_rounded,
                  size: 16,
                  color: _T.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$bankName ($bankTypeUi)',
                        style: const TextStyle(
                          fontSize: 13,
                          color: _T.textMain,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'No: $bankNumber',
                        style: const TextStyle(fontSize: 12, color: _T.textSub),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Atas Nama: $holder',
                        style: const TextStyle(
                          fontSize: 12,
                          color: _T.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openEditBankInfoDialog(b),
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: _T.primary,
                    ),
                    label: const Text(
                      'Edit',
                      style: TextStyle(color: _T.primary),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: const BorderSide(color: _T.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _deleteBankInfo(id),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: _T.danger,
                    ),
                    label: const Text(
                      'Hapus',
                      style: TextStyle(color: _T.danger),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: const BorderSide(color: _T.danger),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
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

  Future<void> _openAddBankInfoDialog() async {
    final bankNameCtrl = TextEditingController();
    final bankNumberCtrl = TextEditingController();
    final holderCtrl = TextEditingController();
    String selectedType = 'Rekening Bank';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Tambah Rekening'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Tipe'),
                  items: ['Rekening Bank', 'Dompet Digital']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setStateDialog(() => selectedType = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bankNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Bank / Platform',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bankNumberCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nomor Rekening / Akun',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: holderCtrl,
                  decoration: const InputDecoration(labelText: 'Atas Nama'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = bankNameCtrl.text.trim();
                final no = bankNumberCtrl.text.trim();
                final holder = holderCtrl.text.trim();

                if (name.isEmpty || no.isEmpty || holder.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Semua field wajib diisi')),
                  );
                  return;
                }

                final repo = RegistrationRepository();
                await repo.createBankAccount(
                  bankName: name,
                  bankNumber: no,
                  bankAccountName: holder,
                  bankType: _bankTypeToDb(selectedType),
                );

                Navigator.pop(ctx, true);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && mounted) {
      await _loadBankInfo();
    }
  }

  Future<void> _openEditBankInfoDialog(Map<String, dynamic> b) async {
    final id = b['id']?.toString() ?? '';
    final bankNameInit = b['bank_name']?.toString() ?? '';
    final bankNumberInit = b['bank_number']?.toString() ?? '';
    final holderInit = b['bank_account_name']?.toString() ?? '';
    String selectedType = _bankTypeToUi(b['bank_type']?.toString() ?? 'Bank');

    final bankNameCtrl = TextEditingController(text: bankNameInit);
    final bankNumberCtrl = TextEditingController(text: bankNumberInit);
    final holderCtrl = TextEditingController(text: holderInit);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Edit Rekening'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Tipe'),
                  items: ['Rekening Bank', 'Dompet Digital']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setStateDialog(() => selectedType = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bankNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Bank / Platform',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bankNumberCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nomor Rekening / Akun',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: holderCtrl,
                  decoration: const InputDecoration(labelText: 'Atas Nama'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = bankNameCtrl.text.trim();
                final no = bankNumberCtrl.text.trim();
                final holder = holderCtrl.text.trim();

                if (id.isEmpty ||
                    name.isEmpty ||
                    no.isEmpty ||
                    holder.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Validasi gagal')),
                  );
                  return;
                }

                final repo = RegistrationRepository();
                await repo.updateBankAccount(
                  id: id,
                  bankName: name,
                  bankNumber: no,
                  bankAccountName: holder,
                  bankType: _bankTypeToDb(selectedType),
                );

                Navigator.pop(ctx, true);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && mounted) {
      await _loadBankInfo();
    }
  }

  Future<void> _deleteBankInfo(String id) async {
    if (id.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Rekening?'),
        content: const Text('Data rekening ini akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _T.danger),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoadingBankInfo = true);
    try {
      final repo = RegistrationRepository();
      await repo.deleteBankAccount(id: id);
      if (!mounted) return;
      await _loadBankInfo();
      _showSnack('Rekening berhasil dihapus', isSuccess: true);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Gagal menghapus rekening', isSuccess: false);
    } finally {
      if (mounted) setState(() => _isLoadingBankInfo = false);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  Widget _buildKosPreviewItem(Map<String, dynamic> kos) {
    final name = (kos['name'] ?? '').toString();
    final address = (kos['address'] ?? '').toString();
    final phone = (kos['phone'] ?? '').toString();
    final capacities = (kos['capacities'] ?? '').toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _T.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _T.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.home_rounded, size: 16, color: _T.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 13,
                      color: _T.textMain,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address,
                    style: const TextStyle(fontSize: 11, color: _T.textSub),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Telepon: $phone · Kapasitas: $capacities',
                    style: const TextStyle(fontSize: 11, color: _T.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}
