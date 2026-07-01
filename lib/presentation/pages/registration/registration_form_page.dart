import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/repositories/registration_repository.dart';


// ═════════════════════════════════════════════════════════════════════════════
//  DESIGN TOKENS
// ═════════════════════════════════════════════════════════════════════════════
class _T {
  static const primary    = Color(0xFF6D5EF6);
  static const surface    = Color(0xFFFFFFFF);
  static const bg         = Color(0xFFF8FAFC);
  static const border     = Color(0xFFE2E8F0);
  static const textMain   = Color(0xFF0F172A);
  static const textSub    = Color(0xFF64748B);
  static const textMuted  = Color(0xFF94A3B8);
  static const success    = Color(0xFF10B981);
  static const danger     = Color(0xFFEF4444);

  static List<BoxShadow> get cardShadow => [
    BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4)),
  ];

  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(color: primary.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 8)),
  ];
}

// ═════════════════════════════════════════════════════════════════════════════
//  REGISTRATION PAGE
// ═════════════════════════════════════════════════════════════════════════════
class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage>
    with TickerProviderStateMixin {

  // ── Step tracking ─────────────────────────────────────────────────────────
  int _currentStep = 0; // 0 = properti, 1 = rekening, 2 = selesai
  bool _step0Done  = false;
  bool _step1Done  = false;

  // ── Properti form controllers ─────────────────────────────────────────────
  final _namaKosCtrl     = TextEditingController();
  final _alamatKosCtrl   = TextEditingController();
  final _phoneKosCtrl    = TextEditingController();
  final _kapasitasCtrl   = TextEditingController();

  // ── Rekening form controllers ─────────────────────────────────────────────
  String _bankType       = 'Bank';
  final _namaBankCtrl    = TextEditingController();
  final _nomorRekeningCtrl = TextEditingController();
  final _namaRekeningCtrl  = TextEditingController();

  // ── Animation controllers ─────────────────────────────────────────────────
  late final AnimationController _headerAnim;
  late final AnimationController _step1Anim;
  late final AnimationController _step2Anim;

  late final Animation<double> _headerFade;
  late final Animation<Offset>  _step1Slide;
  late final Animation<double>  _step1Fade;
  late final Animation<Offset>  _step2Slide;
  late final Animation<double>  _step2Fade;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    _headerAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
    _headerFade = CurvedAnimation(parent: _headerAnim, curve: Curves.easeOut);

    _step1Anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _step1Slide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _step1Anim, curve: Curves.easeOutCubic));
    _step1Fade = CurvedAnimation(parent: _step1Anim, curve: Curves.easeOut);

    _step2Anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _step2Slide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _step2Anim, curve: Curves.easeOutCubic));
    _step2Fade = CurvedAnimation(parent: _step2Anim, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _headerAnim.dispose();
    _step1Anim.dispose();
    _step2Anim.dispose();
    for (final c in [
      _namaKosCtrl, _alamatKosCtrl, _phoneKosCtrl, _kapasitasCtrl,
      _namaBankCtrl, _nomorRekeningCtrl, _namaRekeningCtrl,
    ]) { c.dispose(); }
    super.dispose();
  }

  // ── Validation helpers ────────────────────────────────────────────────────
  bool _validateStep0() {
    if (_namaKosCtrl.text.trim().isEmpty) { _snack('Nama kos wajib diisi'); return false; }
    if (_alamatKosCtrl.text.trim().isEmpty) { _snack('Alamat wajib diisi'); return false; }
    if (_phoneKosCtrl.text.trim().isEmpty) { _snack('Nomor telepon wajib diisi'); return false; }
    if (_kapasitasCtrl.text.trim().isEmpty) { _snack('Jumlah kamar wajib diisi'); return false; }
    final cap = int.tryParse(_kapasitasCtrl.text.trim());
    if (cap == null || cap <= 0) { _snack('Jumlah kamar tidak valid'); return false; }
    return true;
  }

  bool _validateStep1() {
    if (_namaBankCtrl.text.trim().isEmpty) {
      _snack(_bankType == 'Bank' ? 'Nama bank wajib diisi' : 'Nama e-wallet wajib diisi');
      return false;
    }
    if (_nomorRekeningCtrl.text.trim().isEmpty) {
      _snack(_bankType == 'Bank' ? 'Nomor rekening wajib diisi' : 'Nomor akun / HP wajib diisi');
      return false;
    }
    if (_namaRekeningCtrl.text.trim().isEmpty) { _snack('Nama pemilik rekening wajib diisi'); return false; }
    return true;
  }


  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: _T.danger,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }

  void _nextFromStep0() {
    if (!_validateStep0()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _step0Done = true;
      _currentStep = 1;
    });
    _step1Anim.forward();
  }

  void _nextFromStep1() {
    if (!_validateStep1()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _step1Done = true;
      _currentStep = 2;
    });
    _step2Anim.forward();
  }

  Future<void> _submit() async {
    if (!mounted) return;

    setState(() => _isSubmitting = true);
    try {
      final repo = RegistrationRepository();

      final capRaw = _kapasitasCtrl.text.trim();
      final capacity = int.tryParse(capRaw);
      if (capacity == null || capacity <= 0) {
        _snack('Jumlah kamar tidak valid');
        return;
      }

      // 1) Buat Kos pertama + set kos_id active
      await repo.createFirstKosAndSetActive(
        nameKos: _namaKosCtrl.text.trim(),
        address: _alamatKosCtrl.text.trim(),
        phone: _phoneKosCtrl.text.trim(),
        capacity: capacity,
      );

      // 2) Simpan akun bank/e-wallet
      final bankType = _bankType; // 'Bank' atau 'E-Wallet'
      await repo.createBankAccount(
        bankName: _namaBankCtrl.text.trim(),
        bankNumber: _nomorRekeningCtrl.text.trim(),
        bankAccountName: _namaRekeningCtrl.text.trim(),
        bankType: bankType,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/dashboard');
    } catch (e) {
      if (!mounted) return;
      _snack('Gagal menyimpan: $e');
    } finally {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
    }
  }


  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Gradient Hero Header ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _headerFade,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6D5EF6), Color(0xFF7C6EFA), Color(0xFF48B3FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(36),
                    bottomRight: Radius.circular(36),
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Brand chip
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.home_work_rounded, color: Colors.white, size: 14),
                              SizedBox(width: 6),
                              Text('KOSKITA',
                                style: TextStyle(color: Colors.white, fontSize: 12,
                                    fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Daftarkan\nProperti Anda',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            height: 1.15,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Lengkapi dua langkah berikut untuk mulai\nmengelola kos Anda secara profesional.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 28),
                        // Step progress bar
                        _buildProgressBar(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Form Steps ───────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── STEP 1: Properti Kos ──────────────────────────────────
                _buildStepCard(
                  step: 1,
                  title: 'Data Properti Kos',
                  subtitle: 'Informasi dasar tentang properti Anda',
                  icon: Icons.home_work_rounded,
                  isDone: _step0Done,
                  isActive: _currentStep >= 0,
                  child: _buildStep0Form(),
                ),

                // ── STEP 2: Rekening (unlocks after step 0 done) ──────────
                AnimatedSize(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  child: _step0Done
                    ? SlideTransition(
                        position: _step1Slide,
                        child: FadeTransition(
                          opacity: _step1Fade,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: _buildStepCard(
                              step: 2,
                              title: 'Informasi Rekening',
                              subtitle: 'Terima pembayaran dari penyewa',
                              icon: Icons.account_balance_rounded,
                              isDone: _step1Done,
                              isActive: _currentStep >= 1,
                              child: _buildStep1Form(),
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
                ),

                // ── STEP 3: Konfirmasi (unlocks after step 1 done) ────────
                AnimatedSize(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  child: _step1Done
                    ? SlideTransition(
                        position: _step2Slide,
                        child: FadeTransition(
                          opacity: _step2Fade,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: _buildConfirmationCard(),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Progress Bar ──────────────────────────────────────────────────────────
  Widget _buildProgressBar() {
    final steps = ['Properti', 'Rekening', 'Selesai'];
    return Row(
      children: List.generate(steps.length, (i) {
        final isDone    = (i == 0 && _step0Done) || (i == 1 && _step1Done) || (i == 2 && _step1Done);
        final isActive  = _currentStep == i || isDone;
        final isPast    = (i == 0 && _step0Done) || (i == 1 && _step1Done);

        return Expanded(
          child: Row(
            children: [
              if (i > 0)
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    height: 2,
                    color: isPast ? Colors.white : Colors.white.withOpacity(0.25),
                  ),
                ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isPast
                          ? Colors.white
                          : isActive
                              ? Colors.white.withOpacity(0.25)
                              : Colors.white.withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isPast || isActive ? Colors.white : Colors.white.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: isPast
                        ? const Icon(Icons.check_rounded, size: 16, color: _T.primary)
                        : Center(
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                color: isActive ? Colors.white : Colors.white.withOpacity(0.5),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    steps[i],
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.white.withOpacity(0.45),
                      fontSize: 10,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (i < steps.length - 1)
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    height: 2,
                    color: isDone ? Colors.white : Colors.white.withOpacity(0.25),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  // ── Step Card Wrapper ─────────────────────────────────────────────────────
  Widget _buildStepCard({
    required int step,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isDone,
    required bool isActive,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDone ? _T.success.withOpacity(0.3)
              : isActive ? _T.primary.withOpacity(0.2)
              : _T.border,
          width: isDone || isActive ? 1.5 : 1,
        ),
        boxShadow: _T.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: isDone
                        ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)])
                        : isActive
                            ? const LinearGradient(colors: [Color(0xFF6D5EF6), Color(0xFF7C6EFA)])
                            : null,
                    color: isDone || isActive ? null : _T.bg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isDone ? Icons.check_rounded : icon,
                    color: isDone || isActive ? Colors.white : _T.textMuted,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold, color: _T.textMain)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(fontSize: 12, color: _T.textSub)),
                    ],
                  ),
                ),
                if (isDone)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _T.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Selesai',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _T.success)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Divider(color: _T.border, height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ],
      ),
    );
  }

  // ── STEP 0: Properti Form ─────────────────────────────────────────────────
  Widget _buildStep0Form() {
    if (_step0Done) {
      // Show compact summary
      return _buildDoneSummary([
        (Icons.home_work_rounded, 'Nama Kos', _namaKosCtrl.text),
        (Icons.location_on_rounded, 'Alamat', _alamatKosCtrl.text),
        (Icons.phone_outlined, 'Telepon', _phoneKosCtrl.text),
        (Icons.meeting_room_rounded, 'Jumlah Kamar', '${_kapasitasCtrl.text} kamar'),
      ], onEdit: () {
        setState(() {
          _step0Done = false;
          _step1Done = false;
          _currentStep = 0;
          _step1Anim.reset();
          _step2Anim.reset();
        });
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildField(
          controller: _namaKosCtrl,
          label: 'Nama Kos',
          hint: 'cth. Kos Ananda Jaya',
          icon: Icons.home_work_rounded,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 14),
        _buildField(
          controller: _alamatKosCtrl,
          label: 'Alamat Lengkap',
          hint: 'Jl. Ngesrep Timur V No.12, Banyumanik...',
          icon: Icons.location_on_rounded,
          maxLines: 3,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 14),
        _buildField(
          controller: _phoneKosCtrl,
          label: 'Nomor Telepon Kos',
          hint: '08xxxxxxxxxx',
          icon: Icons.phone_outlined,
          inputType: TextInputType.phone,
          formatters: [FilteringTextInputFormatter.digitsOnly],
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 14),
        _buildField(
          controller: _kapasitasCtrl,
          label: 'Jumlah Kamar Tersedia',
          hint: 'cth. 12',
          icon: Icons.meeting_room_rounded,
          inputType: TextInputType.number,
          formatters: [FilteringTextInputFormatter.digitsOnly],
          suffix: 'kamar',
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 24),
        _buildNextButton(
          label: 'Lanjut ke Informasi Rekening',
          onTap: _nextFromStep0,
        ),
      ],
    );
  }

  // ── STEP 1: Rekening Form ─────────────────────────────────────────────────
  Widget _buildStep1Form() {
    if (_step1Done) {
      return _buildDoneSummary([
        (Icons.account_balance_rounded, 'Tipe', _bankType),
        (Icons.business_rounded, 'Bank / Platform', _namaBankCtrl.text),
        (Icons.credit_card_rounded, 'Nomor', _nomorRekeningCtrl.text),
        (Icons.badge_outlined, 'Atas Nama', _namaRekeningCtrl.text),
      ], onEdit: () {
        setState(() {
          _step1Done = false;
          _currentStep = 1;
          _step2Anim.reset();
        });
      });
    }

   
    

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Type toggle
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _T.bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _T.border),
          ),
          child: Row(
            children: ['Bank', 'E-Wallet'].map((type) {
              final sel = _bankType == type;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _bankType = type;
                    _namaBankCtrl.clear();
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      gradient: sel
                          ? const LinearGradient(colors: [_T.primary, Color(0xFF7C6EFA)])
                          : null,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          type == 'Bank' ? Icons.account_balance_rounded : Icons.wallet_rounded,
                          size: 15,
                          color: sel ? Colors.white : _T.textSub,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          type,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                            color: sel ? Colors.white : _T.textSub,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // Bank/EWallet manual input (tanpa dropdown)
        _buildField(
          controller: _namaBankCtrl,
          label: _bankType == 'Bank' ? 'Nama Bank' : 'Nama E-Wallet',
          hint: _bankType == 'Bank' ? 'cth. BCA / Mandiri / BNI' : 'cth. GoPay / OVO / Dana',
          icon: _bankType == 'Bank'
              ? Icons.account_balance_rounded
              : Icons.wallet_rounded,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 14),


        _buildField(
          controller: _nomorRekeningCtrl,
          label: _bankType == 'Bank' ? 'Nomor Rekening' : 'Nomor Akun / HP',
          hint: _bankType == 'Bank' ? '1234 5678 9012' : '08xxxxxxxxxx',
          icon: Icons.credit_card_rounded,
          inputType: TextInputType.number,
          formatters: [FilteringTextInputFormatter.digitsOnly],
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 14),
        _buildField(
          controller: _namaRekeningCtrl,
          label: 'Atas Nama',
          hint: 'Nama pemilik rekening / akun',
          icon: Icons.badge_outlined,
          textInputAction: TextInputAction.done,
        ),

        const SizedBox(height: 8),
        // Info note
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _T.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _T.primary.withOpacity(0.12)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: _T.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Rekening ini akan ditampilkan kepada penyewa sebagai tujuan transfer pembayaran.',
                  style: TextStyle(fontSize: 12, color: _T.primary, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildNextButton(
          label: 'Selesai & Tinjau',
          onTap: _nextFromStep1,
        ),
      ],
    );
  }

  // ── Confirmation Card ─────────────────────────────────────────────────────
  Widget _buildConfirmationCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6D5EF6), Color(0xFF48B3FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: _T.elevatedShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon badge
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 16),
            const Text('Semuanya siap!',
              style: TextStyle(color: Colors.white, fontSize: 22,
                  fontWeight: FontWeight.bold, letterSpacing: -0.5)),
            const SizedBox(height: 6),
            Text(
              'Data properti dan rekening Anda telah tersimpan. Mulai kelola kos Anda sekarang.',
              style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 20),

            // Summary chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _confChip(Icons.home_work_rounded, _namaKosCtrl.text),
                _confChip(Icons.meeting_room_rounded, '${_kapasitasCtrl.text} kamar'),
                _confChip(Icons.account_balance_rounded, _namaBankCtrl.text),
              ],
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _T.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  disabledBackgroundColor: Colors.white.withOpacity(0.6),
                ),
                child: _isSubmitting
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _T.primary))
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Masuk ke Dashboard',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Done Summary (compact view after completing a step) ───────────────────
  Widget _buildDoneSummary(
    List<(IconData, String, String)> items, {
    required VoidCallback onEdit,
  }) {
    return Column(
      children: [
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Icon(item.$1, size: 15, color: _T.textMuted),
              const SizedBox(width: 10),
              Text(item.$2,
                style: const TextStyle(fontSize: 12, color: _T.textSub)),
              const Spacer(),
              Text(item.$3,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _T.textMain)),
            ],
          ),
        )),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 14, color: _T.primary),
            label: const Text('Ubah', style: TextStyle(color: _T.primary, fontSize: 12)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ],
    );
  }

  // ── Confirmation chip ─────────────────────────────────────────────────────
  Widget _confChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12,
              fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ── Primary Next Button ───────────────────────────────────────────────────
  Widget _buildNextButton({required String label, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_T.primary, Color(0xFF7C6EFA)]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: _T.elevatedShadow,
      ),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded, size: 16),
          ],
        ),
      ),
    );
  }

  // ── Shared Field Builder ──────────────────────────────────────────────────
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? hint,
    required IconData icon,
    bool readOnly = false,
    int maxLines = 1,
    TextInputType inputType = TextInputType.text,
    List<TextInputFormatter>? formatters,
    String? suffix,
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      maxLines: maxLines,
      keyboardType: inputType,
      inputFormatters: formatters,
      textInputAction: textInputAction,
      style: const TextStyle(fontSize: 14, color: _T.textMain),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
        prefixIcon: Icon(icon, size: 20, color: _T.textSub),
        alignLabelWithHint: maxLines > 1,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _T.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _T.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _T.primary, width: 1.5)),
      ),
    );
  }
}