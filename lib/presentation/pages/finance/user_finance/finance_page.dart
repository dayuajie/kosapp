import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '/../data/repositories/supabase_finance_repository.dart';
import '/../../core/transaction_refresh_notifier.dart';
// ═════════════════════════════════════════════════════════════════════════
//  DESIGN TOKENS
// ═════════════════════════════════════════════════════════════════════════
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
 
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withOpacity(0.04),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];
}
 
final _currencyFmt =
    NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
final _numFmt = NumberFormat('#,###', 'id_ID');
 
class _TransactionCategory {
  final String label;
  final IconData icon;
  const _TransactionCategory(this.label, this.icon);
}
 
const _incomeCategories = [
  _TransactionCategory('Sewa Kamar', Icons.meeting_room_rounded),
  _TransactionCategory('Denda', Icons.gavel_rounded),
  _TransactionCategory('Lainnya', Icons.more_horiz_rounded),
];
 
const _expenseCategories = [
  _TransactionCategory('Listrik & Air', Icons.bolt_rounded),
  _TransactionCategory('Perawatan', Icons.build_rounded),
  _TransactionCategory('Kebersihan', Icons.cleaning_services_rounded),
  _TransactionCategory('Lainnya', Icons.more_horiz_rounded),
];
 

class _NewTransactionInput {
  final DateTime date;
  final String description;
  final double amount;
  final TransactionType type;
  final String category;
 
  const _NewTransactionInput({
    required this.date,
    required this.description,
    required this.amount,
    required this.type,
    required this.category,
  });
}
 
class FinancePage extends StatefulWidget {
  final String? activeKosId;
 
  const FinancePage({super.key, this.activeKosId});
 
  @override
  State<FinancePage> createState() => _financePageState();
}
 
class _financePageState extends State<FinancePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _repo = SupabaseFinanceRepository();
 
  bool _isLoading = true;
  String? _error;
  final List<TransactionEntity> _entries = [];
 
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadEntries();
  }
 
  @override
  void didUpdateWidget(covariant FinancePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeKosId != widget.activeKosId) {
      _loadEntries();
    }
  }
 
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
 
  String? get _resolvedKosId =>
      widget.activeKosId ??
      Supabase.instance.client.auth.currentUser?.userMetadata?['kos_id']
          ?.toString();
 
  Future<void> _loadEntries() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
 
    final kosId = _resolvedKosId;
    if (kosId == null || kosId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Belum ada kos aktif. Daftarkan/pilih kos terlebih dahulu.';
        _entries.clear();
      });
      return;
    }
 
    try {
      final list = await _repo.fetchTransactions(kosId: kosId);
      if (!mounted) return;
      setState(() {
        _entries
          ..clear()
          ..addAll(list);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat transaksi: $e';
        _entries.clear();
        _isLoading = false;
      });
    }
  }
 
  Future<void> _addEntry(_NewTransactionInput input) async {
  final kosId = _resolvedKosId;
  if (kosId == null || kosId.isEmpty) {
    _showSnack('Belum ada kos aktif.', isSuccess: false);
    return;
  }

  try {
    final created = await _repo.createTransaction(
      kosId: kosId,
      date: input.date,
      description: input.description,
      amount: input.amount,
      type: input.type,
      category: input.category,
    );
    
    if (!mounted) return;
    TransactionRefreshNotifier.instance.notifyTransactionsChanged();
    
    // Update state lokal
    setState(() => _entries.insert(0, created));
    
    _showSnack('Transaksi berhasil dicatat', isSuccess: true);
    
    // Tutup form dan kembali ke tab Transaksi (index 0)
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    
  } catch (e) {
    if (!mounted) return;
    _showSnack('Gagal menyimpan transaksi: $e', isSuccess: false);
  }
}
 
  Future<void> _deleteEntry(TransactionEntity entry) async {
    
    setState(() => _entries.removeWhere((e) => e.id == entry.id));
 
    try {
      await _repo.deleteTransaction(id: entry.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${entry.description}" berhasil dihapus'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          action: SnackBarAction(
            label: 'Urungkan',
            textColor: Colors.white,
            onPressed: () async {
              
              await _addEntry(_NewTransactionInput(
                date: entry.date,
                description: entry.description,
                amount: entry.amount,
                type: entry.type,
                category: entry.category,
              ));
            },
          ),
        ),
      );
    } catch (e) {
      // Gagal hapus di server -> kembalikan ke list lokal.
      if (!mounted) return;
      setState(() => _entries.add(entry));
      _showSnack('Gagal menghapus transaksi: $e', isSuccess: false);
    }
  }
 
  void _showSnack(String msg, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isSuccess ? _T.success : _T.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
 
  Future<void> _openForm() async {
    final result = await Navigator.of(context).push<_NewTransactionInput>(
      MaterialPageRoute(builder: (_) => const _TransactionFormPage()),
    );
    if (result != null) await _addEntry(result);
  }
 
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
 
    return Scaffold(
      backgroundColor: _T.bg,
      appBar: AppBar(
        backgroundColor: _T.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Keuangan Kos',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: _T.textMain,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _T.textSub),
            onPressed: _loadEntries,
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              height: 64,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: _T.cardShadow,
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: _T.textSub,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  gradient: const LinearGradient(colors: [_T.primary, Color(0xFF8B7FF8)]),
                  borderRadius: BorderRadius.circular(11),
                ),
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(icon: Icon(Icons.swap_horiz_rounded, size: 18), text: 'Transaksi'),
                  Tab(icon: Icon(Icons.receipt_long_rounded, size: 18), text: 'Laporan'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _T.primary))
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 44, color: _T.danger),
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: _T.textSub, fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadEntries,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Coba lagi'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _T.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _TransaksiTab(entries: _entries, onDelete: _deleteEntry),
                      _LaporanTab(entries: _entries),
                    ],
                  ),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          // Tombol tambah hanya relevan di tab Transaksi.
          if (_tabController.index != 0) return const SizedBox.shrink();
          return Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_T.primary, Color(0xFF8B7FF8)]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: _T.primary.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: FloatingActionButton.extended(
              onPressed: _openForm,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Catat Transaksi',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              backgroundColor: Colors.transparent,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          );
        },
      ),
    );
  }
}
 

 
class _TransaksiTab extends StatefulWidget {
  final List<TransactionEntity> entries;
  final void Function(TransactionEntity) onDelete;
 
  const _TransaksiTab({required this.entries, required this.onDelete});
 
  @override
  State<_TransaksiTab> createState() => _TransaksiTabState();
}
 
class _TransaksiTabState extends State<_TransaksiTab>
    with SingleTickerProviderStateMixin {
  late TabController _typeTab;
  
 
  @override
  void initState() {
    super.initState();
    _typeTab = TabController(length: 2, vsync: this);
  }
 
  @override
  void dispose() {
    _typeTab.dispose();
    super.dispose();
  }
 
  
 
  List<TransactionEntity> _filtered(TransactionType type) {
  final now = DateTime.now();
  final firstDayOfMonth = DateTime(now.year, now.month, 1);
  return widget.entries.where((e) {
    if (e.type != type) return false;
    if (e.date.isBefore(firstDayOfMonth)) return false;
    return true;
  }).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
}
 
  double get _totalIncome =>
      _filtered(TransactionType.income).fold(0.0, (s, e) => s + e.amount);
  double get _totalExpense =>
      _filtered(TransactionType.expense).fold(0.0, (s, e) => s + e.amount);
 

  void _confirmDelete(TransactionEntity e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Transaksi?',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _T.textMain)),
        content: Text('Tindakan ini akan menghapus "${e.description}" secara permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _T.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok == true) widget.onDelete(e);
  }
 
  @override
  Widget build(BuildContext context) {
    final balance = _totalIncome - _totalExpense;
 
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Wallet card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_T.primary, Color(0xFF8B7FF8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: _T.primary.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 8)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Saldo Bersih (Bulan ini)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                          child: Text(balance >= 0 ? 'Surplus' : 'Defisit',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(_currencyFmt.format(balance),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 28, letterSpacing: -0.5)),
                    ),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(child: _BalanceStat(icon: Icons.arrow_downward_rounded, label: 'Pemasukan', value: _currencyFmt.format(_totalIncome), color: _T.success)),
                      Container(width: 1, height: 32, color: Colors.white.withOpacity(0.2), margin: const EdgeInsets.symmetric(horizontal: 16)),
                      Expanded(child: _BalanceStat(icon: Icons.arrow_upward_rounded, label: 'Pengeluaran', value: _currencyFmt.format(_totalExpense), color: _T.danger)),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 14),
 
              // Income/Expense sub-tab
              Container(
                height: 46,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: _T.cardShadow),
                child: TabBar(
                  controller: _typeTab,
                  labelColor: Colors.white,
                  unselectedLabelColor: _T.textSub,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(gradient: const LinearGradient(colors: [_T.primary, Color(0xFF8B7FF8)]), borderRadius: BorderRadius.circular(11)),
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: const [Tab(text: 'Uang Masuk'), Tab(text: 'Uang Keluar')],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _typeTab,
            children: [
              _TxList(items: _filtered(TransactionType.income), onDelete: _confirmDelete),
              _TxList(items: _filtered(TransactionType.expense), onDelete: _confirmDelete),
            ],
          ),
        ),
      ],
    );
  }
}
 
class _BalanceStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _BalanceStat({required this.icon, required this.label, required this.value, required this.color});
 
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 28, height: 28, decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle), child: Icon(icon, size: 14, color: color)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 11)),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
            ],
          ),
        ),
      ],
    );
  }
}
 
class _TxList extends StatelessWidget {
  final List<TransactionEntity> items;
  final void Function(TransactionEntity) onDelete;
  const _TxList({required this.items, required this.onDelete});
 
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.assignment_turned_in_outlined, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text('Riwayat Transaksi Kosong', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text('Tidak ditemukan aktivitas pada periode ini.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
            ],
          ),
        ),
      );
    }
 
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      physics: const BouncingScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, idx) {
        final t = items[idx];
        final isIncome = t.type == TransactionType.income;
        final typeColor = isIncome ? _T.success : _T.danger;
 
        return Dismissible(
          key: ValueKey(t.id),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) async {
            onDelete(t);
            return false; // hapus ditangani lewat dialog konfirmasi -> state
          },
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(color: _T.danger, borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: _T.cardShadow),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 40, height: 40, decoration: BoxDecoration(color: typeColor.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                    child: Icon(isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: typeColor, size: 18)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _T.textMain)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: _T.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: _T.border)),
                            child: Text(t.category, style: const TextStyle(color: _T.textSub, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.access_time_rounded, size: 11, color: _T.textMuted),
                            const SizedBox(width: 4),
                            Text(DateFormat('dd MMM yyyy', 'id_ID').format(t.date), style: const TextStyle(color: _T.textSub, fontSize: 11)),
                          ]),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isIncome ? '+' : '-'} ${_currencyFmt.format(t.amount)}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: typeColor),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => onDelete(t),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: _T.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
 
// ═════════════════════════════════════════════════════════════════════════
//  FORM — Tambah Transaksi (dipanggil dari FinancePage)
// ═════════════════════════════════════════════════════════════════════════
class _TransactionFormPage extends StatefulWidget {
  const _TransactionFormPage();
 
  @override
  State<_TransactionFormPage> createState() => _TransactionFormPageState();
}
 
class _TransactionFormPageState extends State<_TransactionFormPage> {
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  DateTime _pickedDate = DateTime.now();
  bool _isIncome = true;
  int _categoryIndex = 0;
 
  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }
 
  List<_TransactionCategory> get _categories => _isIncome ? _incomeCategories : _expenseCategories;
 
  Future<void> _pickDate() async {
    final dt = await showDatePicker(
      context: context,
      initialDate: _pickedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('id', 'ID'),
    );
    if (dt != null) setState(() => _pickedDate = dt);
  }
 
  void _submit() {
  final title = _titleCtrl.text.trim();
  final cleaned = _amountCtrl.text.replaceAll('.', '').replaceAll(',', '');
  final amount = double.tryParse(cleaned) ?? 0.0;

  if (title.isEmpty) {
    _snack('Judul transaksi tidak boleh kosong');
    return;
  }
  if (amount <= 0) {
    _snack('Masukkan jumlah nominal yang valid');
    return;
  }

  // Return input untuk diproses oleh FinancePage
  Navigator.of(context).pop(_NewTransactionInput(
    date: _pickedDate,
    description: title,
    amount: amount,
    type: _isIncome ? TransactionType.income : TransactionType.expense,
    category: _categories[_categoryIndex].label,
  ));
}
 
  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }
 
  InputDecoration _dec(String label, {IconData? icon, String? hint, String? prefixText}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefixText,
      prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: _T.textMain),
      prefixIcon: icon != null ? Icon(icon, color: _T.primary, size: 20) : null,
      filled: true,
      fillColor: _T.bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _T.primary, width: 1.5)),
    );
  }
 
  @override
  Widget build(BuildContext context) {
    final accentColor = _isIncome ? _T.success : _T.danger;
 
    return Scaffold(
      backgroundColor: _T.bg,
      appBar: AppBar(
        backgroundColor: _T.bg,
        elevation: 0,
        title: const Text('Pencatatan Baru', style: TextStyle(fontWeight: FontWeight.bold, color: _T.textMain)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: _TypeOption(label: 'Uang Masuk', icon: Icons.arrow_downward_rounded, color: _T.success, selected: _isIncome, onTap: () => setState(() { _isIncome = true; _categoryIndex = 0; }))),
                  const SizedBox(width: 12),
                  Expanded(child: _TypeOption(label: 'Uang Keluar', icon: Icons.arrow_upward_rounded, color: _T.danger, selected: !_isIncome, onTap: () => setState(() { _isIncome = false; _categoryIndex = 0; }))),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_categories.length, (i) {
                  final cat = _categories[i];
                  final selected = i == _categoryIndex;
                  return InkWell(
                    onTap: () => setState(() => _categoryIndex = i),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? accentColor : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: selected ? accentColor : _T.border),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(cat.icon, size: 16, color: selected ? Colors.white : accentColor),
                        const SizedBox(width: 6),
                        Text(cat.label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: selected ? Colors.white : _T.textMain)),
                      ]),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: _T.cardShadow),
                child: Column(
                  children: [
                    TextField(
                      controller: _titleCtrl,
                      decoration: _dec(
                        'Deskripsi Ringkas',
                        hint: _isIncome
                            ? 'Misal: Pembayaran Kamar A-10'
                            : 'Misal: Perbaikan pipa air',
                        icon: Icons.edit_note_rounded,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _amountCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
],
                      decoration: _dec(
                        'Nominal Transaksi',
                        hint: '0',
                        prefixText: 'Rp ',
                        icon: Icons.payments_rounded,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: _T.cardShadow),
                  child: Row(
                    children: [
                      Container(width: 36, height: 36, decoration: BoxDecoration(color: _T.primaryLight, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.calendar_today_rounded, color: _T.primary, size: 16)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Tanggal Berlaku', style: TextStyle(color: _T.textMuted, fontSize: 11)),
                          Text(DateFormat('dd MMM yyyy', 'id_ID').format(_pickedDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _T.textMain)),
                        ]),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: _T.textMuted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: _T.primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                  label: const Text('Validasi & Simpan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
 
class _TypeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _TypeOption({required this.label, required this.icon, required this.color, required this.selected, required this.onTap});
 
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? color.withOpacity(0.3) : _T.border, width: 1.5),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: selected ? color : _T.textSub))),
        ]),
      ),
    );
  }
}
 
// ═════════════════════════════════════════════════════════════════════════
//  TAB 2 — LAPORAN (jurnal akuntansi per periode + export PDF)
// ═════════════════════════════════════════════════════════════════════════
class _LaporanTab extends StatefulWidget {
  final List<TransactionEntity> entries;
  const _LaporanTab({required this.entries});
 
  @override
  State<_LaporanTab> createState() => _LaporanTabState();
}
 
class _LaporanTabState extends State<_LaporanTab> {
  late int _selectedMonth;
  late int _selectedYear;
 
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
  }
 
  List<TransactionEntity> get _filteredEntries {
    return widget.entries
        .where((e) => e.date.month == _selectedMonth && e.date.year == _selectedYear)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }
 
  double get _totalIncome => _filteredEntries.where((e) => e.type == TransactionType.income).fold(0, (s, e) => s + e.amount);
  double get _totalExpense => _filteredEntries.where((e) => e.type == TransactionType.expense).fold(0, (s, e) => s + e.amount);
  double get _netBalance => _totalIncome - _totalExpense;
  String get _periodLabel => DateFormat('MMMM yyyy', 'id_ID').format(DateTime(_selectedYear, _selectedMonth));
 
  Future<void> _openPeriodPicker() async {
    int tempYear = _selectedYear;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModal) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black.withOpacity(0.1), borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 14),
                const Text('Pilih Periode', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    IconButton(onPressed: () => setModal(() => tempYear--), icon: const Icon(Icons.chevron_left_rounded)),
                    Expanded(child: Center(child: Text('$tempYear', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)))),
                    IconButton(onPressed: () => setModal(() => tempYear++), icon: const Icon(Icons.chevron_right_rounded)),
                  ]),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.2,
                  physics: const NeverScrollableScrollPhysics(),
                  children: List.generate(12, (i) {
                    final m = i + 1;
                    final selected = m == _selectedMonth && tempYear == _selectedYear;
                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        setState(() { _selectedMonth = m; _selectedYear = tempYear; });
                        Navigator.of(ctx).pop();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(color: selected ? _T.primary : Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                        alignment: Alignment.center,
                        child: Text(DateFormat.MMM('id_ID').format(DateTime(tempYear, m)), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: selected ? Colors.white : Colors.black87)),
                      ),
                    );
                  }),
                ),
              ],
            ),
          );
        });
      },
    );
  }
 
  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    final entries = _filteredEntries;
    final period = _periodLabel;
    final income = _totalIncome;
    final expense = _totalExpense;
    final balance = _netBalance;
 
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('JURNAL AKUNTANSI KOS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 15)),
                  pw.SizedBox(height: 2),
                  pw.Text('Periode: $period', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ]),
                pw.Text('Dicetak: ${DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(thickness: 1.5, color: PdfColors.indigo),
            pw.SizedBox(height: 6),
          ],
        ),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Aplikasi Manajemen Kos', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            pw.Text('Halaman ${ctx.pageNumber} dari ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ],
        ),
        build: (_) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(color: PdfColors.indigo50, borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _pdfSummaryBox('Total Pemasukan', _currencyFmt.format(income), PdfColors.green700),
                _pdfVDivider(),
                _pdfSummaryBox('Total Pengeluaran', _currencyFmt.format(expense), PdfColors.red700),
                _pdfVDivider(),
                _pdfSummaryBox('Saldo Bersih', _currencyFmt.format(balance), balance >= 0 ? PdfColors.indigo700 : PdfColors.red700),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(24),
              1: const pw.FixedColumnWidth(60),
              2: const pw.FlexColumnWidth(3),
              3: const pw.FixedColumnWidth(80),
              4: const pw.FixedColumnWidth(80),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.indigo700),
                children: [
                  _pdfTh('No.'),
                  _pdfTh('Tanggal'),
                  _pdfTh('Keterangan'),
                  _pdfTh('Debit (Rp)', align: pw.TextAlign.right),
                  _pdfTh('Kredit (Rp)', align: pw.TextAlign.right),
                ],
              ),
              ...entries.asMap().entries.map((e) {
                final i = e.key;
                final item = e.value;
                final isIncome = item.type == TransactionType.income;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: i % 2 == 0 ? PdfColors.white : PdfColors.grey50),
                  children: [
                    _pdfTd('${i + 1}', align: pw.TextAlign.center),
                    _pdfTd(DateFormat('dd/MM/yyyy').format(item.date)),
                    _pdfTd(item.description),
                    _pdfTd(isIncome ? _numFmt.format(item.amount) : '-', align: pw.TextAlign.right, color: isIncome ? PdfColors.green700 : PdfColors.grey400),
                    _pdfTd(!isIncome ? _numFmt.format(item.amount) : '-', align: pw.TextAlign.right, color: !isIncome ? PdfColors.red700 : PdfColors.grey400),
                  ],
                );
              }),
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.indigo50),
                children: [
                  _pdfTd(''),
                  _pdfTd(''),
                  _pdfTd('TOTAL', bold: true),
                  _pdfTd(_numFmt.format(income), align: pw.TextAlign.right, bold: true, color: PdfColors.green700),
                  _pdfTd(_numFmt.format(expense), align: pw.TextAlign.right, bold: true, color: PdfColors.red700),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: pw.BoxDecoration(
              color: balance >= 0 ? PdfColors.green50 : PdfColors.red50,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: balance >= 0 ? PdfColors.green300 : PdfColors.red300, width: 0.5),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text('Saldo Bersih Periode $period :  ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                pw.Text(_currencyFmt.format(balance), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: balance >= 0 ? PdfColors.green700 : PdfColors.red700)),
              ],
            ),
          ),
        ],
      ),
    );
 
    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }
 
  pw.Widget _pdfSummaryBox(String label, String value, PdfColor color) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        pw.SizedBox(height: 4),
        pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: color)),
      ]);
 
  pw.Widget _pdfVDivider() => pw.Container(width: 0.5, height: 30, color: PdfColors.indigo200, margin: const pw.EdgeInsets.symmetric(horizontal: 8));
 
  pw.Widget _pdfTh(String text, {pw.TextAlign align = pw.TextAlign.left}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: pw.Text(text, textAlign: align, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white)),
      );
 
  pw.Widget _pdfTd(String text, {pw.TextAlign align = pw.TextAlign.left, bool bold = false, PdfColor color = PdfColors.black}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Text(text, textAlign: align, style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
      );
 
  @override
  Widget build(BuildContext context) {
    final entries = _filteredEntries;
 
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _openPeriodPicker,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: _T.cardShadow),
                    child: Row(
                      children: [
                        Container(width: 36, height: 36, decoration: BoxDecoration(color: _T.primaryLight, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.calendar_month_rounded, color: _T.primary, size: 18)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Periode Jurnal', style: TextStyle(color: _T.textMuted, fontWeight: FontWeight.w600, fontSize: 11)),
                            Text(_periodLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: _T.textMain)),
                          ]),
                        ),
                        const Icon(Icons.unfold_more_rounded, color: _T.textMuted),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), boxShadow: _T.cardShadow),
                child: ElevatedButton.icon(
                  onPressed: entries.isEmpty ? null : _exportPdf,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _T.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: const Text('PDF', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(child: _SummaryMiniCard(label: 'Pemasukan', value: _currencyFmt.format(_totalIncome), icon: Icons.arrow_downward_rounded, color: _T.success)),
              const SizedBox(width: 8),
              Expanded(child: _SummaryMiniCard(label: 'Pengeluaran', value: _currencyFmt.format(_totalExpense), icon: Icons.arrow_upward_rounded, color: _T.danger)),
              const SizedBox(width: 8),
              Expanded(child: _SummaryMiniCard(label: 'Saldo Bersih', value: _currencyFmt.format(_netBalance), icon: Icons.account_balance_wallet_rounded, color: _netBalance >= 0 ? _T.primary : _T.danger)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Flexible(child: Text('${entries.length} transaksi', overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, color: _T.textMain, fontSize: 13))),
              const Spacer(),
              Flexible(child: Text(_periodLabel, textAlign: TextAlign.right, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _T.textMuted, fontWeight: FontWeight.w600, fontSize: 12))),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 48, color: Colors.black.withOpacity(0.15)),
                        const SizedBox(height: 12),
                        Text('Tidak ada transaksi', textAlign: TextAlign.center, style: TextStyle(color: Colors.black.withOpacity(0.4), fontWeight: FontWeight.w700)),
                        Text('pada periode $_periodLabel', textAlign: TextAlign.center, style: TextStyle(color: Colors.black.withOpacity(0.3), fontSize: 12)),
                      ],
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: _T.cardShadow),
                    clipBehavior: Clip.antiAlias,
                    child: _JournalTable(entries: entries, totalIncome: _totalIncome, totalExpense: _totalExpense),
                  ),
                ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
 
// ── Mini summary card ───────────────────────────────────────────────────
class _SummaryMiniCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _SummaryMiniCard({required this.label, required this.value, required this.icon, required this.color});
 
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: _T.cardShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 26, height: 26, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(7)), child: Icon(icon, size: 13, color: color)),
            const SizedBox(width: 6),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _T.textMuted, fontWeight: FontWeight.w700, fontSize: 11))),
          ]),
          const SizedBox(height: 6),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, maxLines: 1, style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 14))),
        ],
      ),
    );
  }
}
 
// ── Lebar kolom tabel jurnal ─────────────────────────────────────────────
class _ColWidth {
  static const double no = 36;
  static const double date = 90;
  static const double description = 180;
  static const double debit = 110;
  static const double credit = 110;
  static const double total = no + date + description + debit + credit + 24;
}
 
class _TH extends StatelessWidget {
  final String text;
  final double width;
  final TextAlign align;
  const _TH(this.text, this.width, {this.align = TextAlign.left});
 
  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width, child: Text(text, textAlign: align, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.white)));
  }
}
 
class _JournalTable extends StatefulWidget {
  final List<TransactionEntity> entries;
  final double totalIncome;
  final double totalExpense;
  const _JournalTable({required this.entries, required this.totalIncome, required this.totalExpense});
 
  @override
  State<_JournalTable> createState() => _JournalTableState();
}
 
class _JournalTableState extends State<_JournalTable> {
  final ScrollController _hScroll = ScrollController();
  final ScrollController _vScroll = ScrollController();
 
  @override
  void dispose() {
    _hScroll.dispose();
    _vScroll.dispose();
    super.dispose();
  }
 
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
 
    return Scrollbar(
      controller: _hScroll,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _hScroll,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: SizedBox(
          width: _ColWidth.total,
          child: Column(
            children: [
              Container(
                color: _T.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                child: Row(children: [
                  _TH('No.', _ColWidth.no),
                  _TH('Tanggal', _ColWidth.date),
                  _TH('Keterangan', _ColWidth.description),
                  _TH('Debit (Rp)', _ColWidth.debit, align: TextAlign.right),
                  _TH('Kredit (Rp)', _ColWidth.credit, align: TextAlign.right),
                ]),
              ),
              Expanded(
                child: Scrollbar(
                  controller: _vScroll,
                  child: ListView.builder(
                    controller: _vScroll,
                    padding: EdgeInsets.zero,
                    itemCount: widget.entries.length + 1,
                    itemBuilder: (context, idx) {
                      if (idx == widget.entries.length) {
                        return Container(
                          decoration: BoxDecoration(color: _T.primary.withOpacity(0.07), border: Border(top: BorderSide(color: _T.primary.withOpacity(0.3), width: 1.2))),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          child: Row(children: [
                            const SizedBox(width: _ColWidth.no),
                            const SizedBox(width: _ColWidth.date),
                            SizedBox(width: _ColWidth.description, child: Text('TOTAL', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900, color: _T.primary, letterSpacing: 0.8))),
                            SizedBox(width: _ColWidth.debit, child: Text(_numFmt.format(widget.totalIncome), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w900, color: _T.success))),
                            SizedBox(width: _ColWidth.credit, child: Text(_numFmt.format(widget.totalExpense), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w900, color: _T.danger))),
                          ]),
                        );
                      }
 
                      final entry = widget.entries[idx];
                      final isIncome = entry.type == TransactionType.income;
                      final isEven = idx % 2 == 0;
                      final amtColor = isIncome ? _T.success : _T.danger;
 
                      return Container(
                        decoration: BoxDecoration(color: isEven ? Colors.white : Colors.grey.shade50, border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 0.8))),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: _ColWidth.no, child: Text('${idx + 1}', style: TextStyle(color: Colors.black.withOpacity(0.35), fontWeight: FontWeight.w700, fontSize: 12))),
                            SizedBox(width: _ColWidth.date, child: Text(DateFormat('dd/MM/yyyy').format(entry.date), style: TextStyle(color: Colors.black.withOpacity(0.6), fontWeight: FontWeight.w600, fontSize: 12))),
                            SizedBox(
                              width: _ColWidth.description,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(entry.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: amtColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                    child: Text(isIncome ? 'Pemasukan' : 'Pengeluaran', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: amtColor)),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: _ColWidth.debit, child: Text(isIncome ? _numFmt.format(entry.amount) : '-', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: isIncome ? _T.success : Colors.black.withOpacity(0.2)))),
                            SizedBox(width: _ColWidth.credit, child: Text(!isIncome ? _numFmt.format(entry.amount) : '-', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: !isIncome ? _T.danger : Colors.black.withOpacity(0.2)))),
                          ],
                        ),
                      );
                    },
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