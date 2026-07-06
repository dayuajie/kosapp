import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/supabase_occupancy_repository.dart';
import '../../data/repositories/supabase_finance_repository.dart';
import '../../domain/entities/tenant_entity.dart';
import '../../domain/entities/payment_context.dart';
import '../../core/transaction_refresh_notifier.dart';
import '../../core/tenant_refresh_notifier.dart';

class _T {
  static const primary = Color(0xFF6D5EF6);
  static const primaryLight = Color(0xFFF5F3FF);
  static const bg = Color(0xFFF8FAFC);
  static const border = Color(0xFFE2E8F0);
  static const textMain = Color(0xFF0F172A);
  static const textSub = Color(0xFF64748B);
  static const textMuted = Color(0xFF94A3B8);
  static const success = Color(0xFF10B981);
  static const danger = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.04),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];
}

enum ComposerMode { renewal, newPayment, settlement }

class TransactionComposerPage extends StatefulWidget {
  final TenantEntity tenant;
  final ComposerMode mode;
  
  const TransactionComposerPage({
    super.key,
    required this.tenant,
    this.mode = ComposerMode.renewal,
  });

  @override
  State<TransactionComposerPage> createState() => _TransactionComposerPageState();
}

class _TransactionComposerPageState extends State<TransactionComposerPage> {
  final _priceCtrl = TextEditingController();
  final _paidAmountCtrl = TextEditingController();
  final _lateFeeCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  
  DateTime? _startDate;
  DateTime? _endDate;
  String _rentType = 'Bulanan';
  String _paymentStatus = 'Lunas';
  String _paymentMethod = 'Transfer Bank';
  
  bool _isSubmitting = false;
  bool _isLoadingSummary = true;
  String? _kosId;
  
  double _currentTotalDue = 0;
  double _currentTotalPaid = 0;
  double _currentRemaining = 0;
  String _currentStatus = 'pending';
  int? _daysOverdue;
  
  final _occupancyRepo = SupabaseOccupancyRepository();
  final _financeRepo = SupabaseFinanceRepository();
  
  final _rentTypes = ['Harian', 'Mingguan', 'Bulanan', 'Tahunan'];
  final _paymentStatuses = ['Lunas', 'Dicicil'];
  final _paymentMethods = ['Transfer Bank', 'Tunai / Cash', 'E-Wallet', 'QRIS'];
  
  TenantEntity get tenant => widget.tenant;

  @override
  void initState() {
    super.initState();
    _loadKosId();
  }
  
  Future<void> _loadKosId() async {
    // PRIORITAS 1: Dari auth metadata
    final metaKosId = Supabase.instance.client.auth.currentUser?.userMetadata?['kos_id']?.toString();
    if (metaKosId != null && metaKosId.isNotEmpty) {
      _kosId = metaKosId;
      await _initializeData();
      return;
    }
    
    // PRIORITAS 2: Dari tabel kos
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final data = await Supabase.instance.client
            .from('kos')
            .select('id')
            .eq('owner_id', userId)
            .maybeSingle();
        _kosId = data?['id']?.toString();
      }
    } catch (_) {}
    
    await _initializeData();
  }
  
  Future<void> _initializeData() async {
    if (tenant.occupancyId != null) {
      try {
        final summary = await _occupancyRepo.getPaymentSummary(tenant.occupancyId!);
        if (mounted) {
          setState(() {
            _currentTotalDue = summary.totalDue;
            _currentTotalPaid = summary.totalPaid;
            _currentRemaining = summary.remaining;
            _currentStatus = summary.status;
            _daysOverdue = summary.daysOverdue;
          });
        }
      } catch (_) {}
    }
    
    // Set defaults berdasarkan mode
    switch (widget.mode) {
      case ComposerMode.renewal:
        _startDate = tenant.endDate ?? DateTime.now();
        _priceCtrl.text = tenant.rentPrice?.toString() ?? '';
        break;
      case ComposerMode.newPayment:
        _startDate = tenant.moveInDate;
        _endDate = tenant.endDate;
        _priceCtrl.text = _currentRemaining > 0 
            ? _currentRemaining.toStringAsFixed(0) 
            : tenant.rentPrice?.toString() ?? '';
        _paymentStatus = _currentStatus == 'pending' ? 'Lunas' : 'Dicicil';
        break;
      case ComposerMode.settlement:
        _startDate = tenant.moveInDate;
        _endDate = tenant.endDate;
        _priceCtrl.text = _currentRemaining.toStringAsFixed(0);
        _lateFeeCtrl.text = _calculateLateFee().toStringAsFixed(0);
        break;
    }
    
    _calculateEndDate();
    
    if (mounted) setState(() => _isLoadingSummary = false);
  }
  
  double _calculateLateFee() {
    if (_daysOverdue == null || _daysOverdue! <= 0) return 0;
    final feePercent = (_daysOverdue! * 0.01).clamp(0.0, 0.1);
    return _currentRemaining * feePercent;
  }
  
  void _calculateEndDate() {
    if (_startDate == null) return;
    setState(() {
      switch (_rentType) {
        case 'Harian': _endDate = _startDate!.add(const Duration(days: 1)); break;
        case 'Mingguan': _endDate = _startDate!.add(const Duration(days: 7)); break;
        case 'Bulanan': _endDate = DateTime(_startDate!.year, _startDate!.month + 1, _startDate!.day); break;
        case 'Tahunan': _endDate = DateTime(_startDate!.year + 1, _startDate!.month, _startDate!.day); break;
      }
    });
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: _T.primary, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() { _startDate = picked; _calculateEndDate(); });
  }
  
  Future<void> _pickEndDate() async {
    if (_startDate == null) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate!.add(const Duration(days: 30)),
      firstDate: _startDate!.add(const Duration(days: 1)),
      lastDate: _startDate!.add(const Duration(days: 365 * 2)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: _T.primary, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _endDate = picked);
  }
  
  // ═══════════════════════════════════════════════════════════════════════
  //  PERBAIKAN UTAMA: Semua method sekarang pakai _kosId yang valid
  // ═══════════════════════════════════════════════════════════════════════
  
  Future<void> _handleRenewal(String occupancyId, double price, double paidAmount) async {
    // 1. Update occupancy
    await _occupancyRepo.extendOccupancyWithPayment(
      occupancyId: occupancyId,
      newEndDate: _endDate!,
      price: price,
      rentType: _rentType,
      paymentStatus: _paymentStatus == 'Lunas' ? PaymentStatus.paid : PaymentStatus.partial,
      paidAmount: paidAmount,
      paymentMethod: _paymentMethod,
      notes: _notesCtrl.text.trim(),
    );
    
    // 2. Catat transaksi ✅ kosId valid dari auth
    if (paidAmount > 0) {
      await _financeRepo.createTransaction(
        kosId: _kosId!,
        date: DateTime.now(),
        description: 'Perpanjangan ${tenant.room} - ${tenant.fullName}',
        amount: paidAmount,
        type: TransactionType.income,
        category: 'Perpanjangan Sewa',
      );
    }
  }
  
  Future<void> _handleNewPayment(String occupancyId, double price, double paidAmount) async {
    await _occupancyRepo.recordPartialPayment(
      occupancyId: occupancyId,
      amount: paidAmount,
      method: _paymentMethod,
      note: _notesCtrl.text.trim(),
    );
    
    await _financeRepo.createTransaction(
      kosId: _kosId!,
      date: DateTime.now(),
      description: 'Pembayaran ${tenant.room} - ${tenant.fullName}',
      amount: paidAmount,
      type: TransactionType.income,
      category: 'Pembayaran Sewa',
    );
  }
  
  Future<void> _handleSettlement(String occupancyId, double price, double paidAmount) async {
    final lateFee = double.tryParse(_lateFeeCtrl.text.trim()) ?? 0;
    
    await _occupancyRepo.extendOccupancyWithPayment(
      occupancyId: occupancyId,
      newEndDate: _endDate!,
      price: price,
      paymentStatus: PaymentStatus.paid,
      paidAmount: price,
      paymentMethod: _paymentMethod,
      notes: 'Pelunasan. ${_notesCtrl.text.trim()}',
    );
    
    await _financeRepo.createTransaction(
      kosId: _kosId!,
      date: DateTime.now(),
      description: 'Pelunasan ${tenant.room} - ${tenant.fullName}',
      amount: paidAmount,
      type: TransactionType.income,
      category: 'Pelunasan',
    );
    
    if (lateFee > 0) {
      await _financeRepo.createTransaction(
        kosId: _kosId!,
        date: DateTime.now(),
        description: 'Denda ${tenant.fullName} ($_daysOverdue hari)',
        amount: lateFee,
        type: TransactionType.income,
        category: 'Denda',
      );
    }
  }
  
  Future<void> _submit() async {
    // VALIDASI kosId
    if (_kosId == null || _kosId!.isEmpty) {
      _showSnack('Data kos tidak ditemukan. Login ulang.', isError: true);
      return;
    }
    
    final priceText = _priceCtrl.text.trim().replaceAll('.', '').replaceAll(',', '');
    final price = double.tryParse(priceText) ?? 0;
    if (price <= 0) { _showSnack('Harga tidak valid', isError: true); return; }
    
    if (_startDate == null || _endDate == null) {
      _showSnack('Periode sewa belum lengkap', isError: true); return;
    }
    
    final occupancyId = tenant.occupancyId;
    if (occupancyId == null || occupancyId.isEmpty) {
      _showSnack('Data hunian tidak ditemukan', isError: true); return;
    }
    
    final paidAmount = _paymentStatus == 'Lunas' 
        ? price 
        : (double.tryParse(_paidAmountCtrl.text.trim().replaceAll('.', '').replaceAll(',', '')) ?? 0);
    
    if (_paymentStatus == 'Dicicil' && paidAmount <= 0) {
      _showSnack('Jumlah cicilan harus diisi', isError: true); return;
    }
    
    setState(() => _isSubmitting = true);
    
    try {
      switch (widget.mode) {
        case ComposerMode.renewal: await _handleRenewal(occupancyId, price, paidAmount); break;
        case ComposerMode.newPayment: await _handleNewPayment(occupancyId, price, paidAmount); break;
        case ComposerMode.settlement: await _handleSettlement(occupancyId, price, paidAmount); break;
      }
      
      TransactionRefreshNotifier.instance.notifyTransactionsChanged();
      TenantRefreshNotifier.instance.notifyTenantsChanged();
      
      if (!mounted) return;
      _showSnack(_getSuccessMessage(), isError: false);
      Navigator.of(context).pop(true);
      
    } catch (e) {
      if (!mounted) return;
      _showSnack('Gagal: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
  
  String _getSuccessMessage() {
    switch (widget.mode) {
      case ComposerMode.renewal: return 'Perpanjangan berhasil!';
      case ComposerMode.newPayment: return 'Pembayaran tercatat!';
      case ComposerMode.settlement: return 'Tunggakan dilunasi!';
    }
  }
  
  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: isError ? _T.danger : _T.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // LOADING STATE
    if (_isLoadingSummary || _kosId == null) {
      return Scaffold(
        backgroundColor: _T.bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: _T.primary),
              const SizedBox(height: 16),
              Text(
                _kosId == null ? 'Memuat data kos...' : 'Memuat data pembayaran...',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }
    
    final fmt = DateFormat('dd MMM yyyy', 'id_ID');
    
    return Scaffold(
      backgroundColor: _T.bg,
      appBar: AppBar(
        backgroundColor: _T.bg,
        elevation: 0,
        title: Text(
          _getPageTitle(),
          style: const TextStyle(fontWeight: FontWeight.bold, color: _T.textMain, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _T.textMain, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTenantInfoCard(),
              const SizedBox(height: 20),
              if (_shouldShowStatusBanner()) ...[
                _buildStatusBanner(),
                const SizedBox(height: 16),
              ],
              _buildSectionTitle('Detail Transaksi'),
              const SizedBox(height: 8),
              _buildCard([
                if (widget.mode == ComposerMode.renewal) ...[
                  DropdownButtonFormField<String>(
                    value: _rentType,
                    items: _rentTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) { setState(() { _rentType = v!; _calculateEndDate(); }); },
                    decoration: _inputDecoration('Rentang Waktu', Icons.av_timer_rounded),
                  ),
                  const SizedBox(height: 16),
                ],
                if (widget.mode == ComposerMode.renewal) _buildDateRangePicker(fmt) else _buildReadOnlyDateRange(fmt),
                const SizedBox(height: 16),
                TextField(
                  controller: _priceCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontWeight: FontWeight.w600, color: _T.textMain),
                  decoration: _inputDecoration('Total Tagihan (Rp)', Icons.payments_outlined),
                ),
                if (widget.mode == ComposerMode.settlement) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _lateFeeCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(fontWeight: FontWeight.w600, color: _T.danger),
                    decoration: _inputDecoration('Denda (Rp)', Icons.warning_amber_rounded)
                        .copyWith(
                          prefixIcon: const Icon(Icons.warning_amber_rounded, color: _T.danger),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(14)),
                            borderSide: BorderSide(color: _T.danger, width: 1.5),
                          ),
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text('Denda: ${_daysOverdue ?? 0} hari', style: const TextStyle(fontSize: 11, color: _T.danger)),
                ],
              ]),
              const SizedBox(height: 20),
              _buildSectionTitle('Pembayaran'),
              const SizedBox(height: 8),
              _buildCard([
                _buildPaymentStatusInfo(),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _paymentStatus,
                  items: _paymentStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setState(() {
                    _paymentStatus = v!;
                    if (_paymentStatus == 'Lunas') _paidAmountCtrl.clear();
                  }),
                  decoration: _inputDecoration('Status', Icons.fact_check_outlined),
                ),
                if (_paymentStatus == 'Dicicil') ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _paidAmountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    decoration: _inputDecoration('Jumlah Dibayar (Rp)', Icons.price_change_outlined),
                  ),
                  const SizedBox(height: 6),
                  Text('Sisa: Rp ${NumberFormat('#,###', 'id_ID').format(_currentRemaining)}', 
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _paymentMethod,
                  items: _paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (v) => setState(() => _paymentMethod = v!),
                  decoration: _inputDecoration('Metode', Icons.account_balance_wallet_outlined),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: _inputDecoration('Catatan', Icons.sticky_note_2_outlined),
                ),
              ]),
              const SizedBox(height: 32),
              SizedBox(
                height: 54,
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getSubmitColor(),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Text(_getSubmitText(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  String _getPageTitle() {
    switch (widget.mode) {
      case ComposerMode.renewal: return 'Perpanjang Sewa';
      case ComposerMode.newPayment: return 'Catat Pembayaran';
      case ComposerMode.settlement: return 'Pelunasan Tunggakan';
    }
  }
  
  bool _shouldShowStatusBanner() => widget.mode == ComposerMode.settlement || widget.mode == ComposerMode.newPayment;
  
  Color _getSubmitColor() {
    switch (widget.mode) {
      case ComposerMode.renewal: return _T.primary;
      case ComposerMode.newPayment: return _T.success;
      case ComposerMode.settlement: return _T.warning;
    }
  }
  
  String _getSubmitText() {
    switch (widget.mode) {
      case ComposerMode.renewal: return 'Simpan Perpanjangan';
      case ComposerMode.newPayment: return 'Catat Pembayaran';
      case ComposerMode.settlement: return 'Lunasi Sekarang';
    }
  }
  
  // ... helper widgets (sama seperti sebelumnya) ...
  Widget _buildTenantInfoCard() => Container(/* ... */);
  Widget _buildStatusBanner() => Container(/* ... */);
  Widget _buildPaymentStatusInfo() => Container(/* ... */);
  Widget _buildDateRangePicker(DateFormat fmt) => Row(/* ... */);
  Widget _buildReadOnlyDateRange(DateFormat fmt) => Row(/* ... */);
  Widget _buildSectionTitle(String t) => Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _T.textSub));
  Widget _buildCard(List<Widget> children) => Container(/* ... */);
  InputDecoration _inputDecoration(String label, IconData icon) => InputDecoration(/* ... */);
  
  @override
  void dispose() {
    _priceCtrl.dispose();
    _paidAmountCtrl.dispose();
    _lateFeeCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }
}