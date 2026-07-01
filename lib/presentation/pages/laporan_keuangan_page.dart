import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:math' as math;

// ======================== MODEL ========================

enum JournalType { income, expense }

class JournalEntry {
  final String id;
  final DateTime date;
  final String description;
  final double amount;
  final JournalType type;

  JournalEntry({
    required this.id,
    required this.date,
    required this.description,
    required this.amount,
    required this.type,
  });
}

// ======================== LEBAR KOLOM ========================

class _ColWidth {
  static const double no = 36;
  static const double date = 90;
  static const double description = 180; // diperlebar
  static const double debit = 110;       // diperlebar agar angka muat
  static const double credit = 110;      // diperlebar agar angka muat

  static const double total = no + date + description + debit + credit + 24; // +24 padding kiri-kanan
}

// ======================== PAGE ========================

class LaporanKeuanganPage extends StatefulWidget {
  const LaporanKeuanganPage({super.key});

  @override
  State<LaporanKeuanganPage> createState() => _LaporanKeuanganPageState();
}

class _LaporanKeuanganPageState extends State<LaporanKeuanganPage> {
  final _currencyFmt =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
  final _numFmt = NumberFormat('#,###', 'id_ID');

  late int _selectedMonth;
  late int _selectedYear;

  final List<JournalEntry> _allEntries = [
    JournalEntry(id: '1', date: DateTime(2026, 6, 1), description: 'Sewa Kamar 01',  amount: 1200000, type: JournalType.income),
    JournalEntry(id: '2', date: DateTime(2026, 6, 3), description: 'Listrik Juni',   amount: 320000, type: JournalType.expense),
    JournalEntry(id: '3', date: DateTime(2026, 6, 5), description: 'Sewa Kamar 02',   amount: 1200000, type: JournalType.income),
    JournalEntry(id: '4', date: DateTime(2026, 6, 10), description: 'Perbaikan Kunci',   amount: 150000, type: JournalType.expense),
    JournalEntry(id: '5', date: DateTime(2026, 6, 12), description: 'Sewa Kamar 03',   amount: 1200000, type: JournalType.income),
    JournalEntry(id: '6', date: DateTime(2026, 6, 15), description: 'Air PDAM',   amount: 85000, type: JournalType.expense),
    JournalEntry(id: '7', date: DateTime(2026, 6, 20), description: 'Denda Terlambat K01',   amount: 50000, type: JournalType.income),
    JournalEntry(id: '8', date: DateTime(2026, 6, 25), description: 'Kebersihan Bulan Juni',   amount: 200000, type: JournalType.expense),
    JournalEntry(id: '9', date: DateTime(2026, 6, 28), description: 'Sewa Kamar 04',   amount: 1200000, type: JournalType.income),
    JournalEntry(id: '10', date: DateTime(2026, 6, 5), description: 'Sewa Kamar 01 Mei',   amount: 1200000, type: JournalType.income),
    JournalEntry(id: '11', date: DateTime(2026, 6, 10), description: 'Listrik Mei',   amount: 310000, type: JournalType.expense),
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
  }

  List<JournalEntry> get _filteredEntries {
    return _allEntries
        .where((e) =>
            e.date.month == _selectedMonth && e.date.year == _selectedYear)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  double get _totalIncome => _filteredEntries
      .where((e) => e.type == JournalType.income)
      .fold(0, (s, e) => s + e.amount);

  double get _totalExpense => _filteredEntries
      .where((e) => e.type == JournalType.expense)
      .fold(0, (s, e) => s + e.amount);

  double get _netBalance => _totalIncome - _totalExpense;

  String get _periodLabel =>
      DateFormat('MMMM yyyy', 'id_ID').format(DateTime(_selectedYear, _selectedMonth));

  // ===== Period Picker =====
  Future<void> _openPeriodPicker() async {
    int tempYear = _selectedYear;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Pilih Periode',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 12),
                  // Year navigator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => setModal(() => tempYear--),
                          icon: const Icon(Icons.chevron_left_rounded),
                          visualDensity: VisualDensity.compact,
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              '$tempYear',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900, fontSize: 17),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => setModal(() => tempYear++),
                          icon: const Icon(Icons.chevron_right_rounded),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Month grid
                  GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.2,
                    physics: const NeverScrollableScrollPhysics(),
                    children: List.generate(12, (i) {
                      final m = i + 1;
                      final selected =
                          m == _selectedMonth && tempYear == _selectedYear;
                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          setState(() {
                            _selectedMonth = m;
                            _selectedYear = tempYear;
                          });
                          Navigator.of(ctx).pop();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFF6D5EF6)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            DateFormat.MMM('id_ID')
                                .format(DateTime(tempYear, m)),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: selected ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ===== Export PDF =====
  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    final entries = _filteredEntries;
    final period = _periodLabel;
    final income = _totalIncome;
    final expense = _totalExpense;
    final balance = _netBalance;
    final currFmt =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
    final numFmt = NumberFormat('#,###', 'id_ID');

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
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('JURNAL AKUNTANSI KOS',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 15)),
                    pw.SizedBox(height: 2),
                    pw.Text('Periode: $period',
                        style: const pw.TextStyle(
                            fontSize: 10, color: PdfColors.grey700)),
                  ],
                ),
                pw.Text(
                  'Dicetak: ${DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.now())}',
                  style: const pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey600),
                ),
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
            pw.Text('Aplikasi Manajemen Kos',
                style: const pw.TextStyle(
                    fontSize: 8, color: PdfColors.grey600)),
            pw.Text('Halaman ${ctx.pageNumber} dari ${ctx.pagesCount}',
                style: const pw.TextStyle(
                    fontSize: 8, color: PdfColors.grey600)),
          ],
        ),
        build: (_) => [
          // Ringkasan
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.indigo50,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _pdfSummaryBox(
                    'Total Pemasukan', currFmt.format(income), PdfColors.green700),
                _pdfVDivider(),
                _pdfSummaryBox(
                    'Total Pengeluaran', currFmt.format(expense), PdfColors.red700),
                _pdfVDivider(),
                _pdfSummaryBox(
                  'Saldo Bersih',
                  currFmt.format(balance),
                  balance >= 0 ? PdfColors.indigo700 : PdfColors.red700,
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // Tabel
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(24),
              1: const pw.FixedColumnWidth(60),
              2: const pw.FlexColumnWidth(3),
              3: const pw.FlexColumnWidth(2),
              4: const pw.FixedColumnWidth(80),
              5: const pw.FixedColumnWidth(80),
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
                final isIncome = item.type == JournalType.income;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                      color: i % 2 == 0 ? PdfColors.white : PdfColors.grey50),
                  children: [
                    _pdfTd('${i + 1}', align: pw.TextAlign.center),
                    _pdfTd(DateFormat('dd/MM/yyyy').format(item.date)),
                    _pdfTd(item.description),
                    _pdfTd(
                      isIncome ? numFmt.format(item.amount) : '-',
                      align: pw.TextAlign.right,
                      color: isIncome ? PdfColors.green700 : PdfColors.grey400,
                    ),
                    _pdfTd(
                      !isIncome ? numFmt.format(item.amount) : '-',
                      align: pw.TextAlign.right,
                      color: !isIncome ? PdfColors.red700 : PdfColors.grey400,
                    ),
                  ],
                );
              }),
              // Total row
              pw.TableRow(
                decoration:
                    const pw.BoxDecoration(color: PdfColors.indigo50),
                children: [
                  _pdfTd(''),
                  _pdfTd(''),
                  _pdfTd('TOTAL', bold: true),
                  _pdfTd(''),
                  _pdfTd(numFmt.format(income),
                      align: pw.TextAlign.right,
                      bold: true,
                      color: PdfColors.green700),
                  _pdfTd(numFmt.format(expense),
                      align: pw.TextAlign.right,
                      bold: true,
                      color: PdfColors.red700),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 14),

          // Saldo bersih
          pw.Container(
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: pw.BoxDecoration(
              color: balance >= 0 ? PdfColors.green50 : PdfColors.red50,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(
                color: balance >= 0 ? PdfColors.green300 : PdfColors.red300,
                width: 0.5,
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text('Saldo Bersih Periode $period :  ',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 10)),
                pw.Text(
                  currFmt.format(balance),
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                    color: balance >= 0
                        ? PdfColors.green700
                        : PdfColors.red700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  // PDF helpers
  pw.Widget _pdfSummaryBox(String label, String value, PdfColor color) =>
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        pw.Text(label,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        pw.SizedBox(height: 4),
        pw.Text(value,
            style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontSize: 10, color: color)),
      ]);

  pw.Widget _pdfVDivider() => pw.Container(
      width: 0.5,
      height: 30,
      color: PdfColors.indigo200,
      margin: const pw.EdgeInsets.symmetric(horizontal: 8));

  pw.Widget _pdfTh(String text,
          {pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: pw.Text(text,
            textAlign: align,
            style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
                color: PdfColors.white)),
      );

  pw.Widget _pdfTd(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    bool bold = false,
    PdfColor color = PdfColors.black,
  }) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Text(text,
            textAlign: align,
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight:
                    bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: color)),
      );

  // ======================== BUILD ========================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = _filteredEntries;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F6FA),
        elevation: 0,
        title: Text(
          'Jurnal Akuntansi',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            color: Colors.black87,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: entries.isEmpty ? null : _exportPdf,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6D5EF6),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
              label: const Text('PDF',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ===== Filter Periode =====
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: InkWell(
                onTap: _openPeriodPicker,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF6D5EF6).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.calendar_month_rounded,
                            color: Color(0xFF6D5EF6), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Periode Jurnal',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.black.withOpacity(0.45),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              _periodLabel,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.unfold_more_rounded,
                          color: Colors.black.withOpacity(0.3)),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ===== Summary Cards =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryMiniCard(
                      label: 'Pemasukan',
                      value: _currencyFmt.format(_totalIncome),
                      icon: Icons.arrow_downward_rounded,
                      color: const Color(0xFF22C55E),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SummaryMiniCard(
                      label: 'Pengeluaran',
                      value: _currencyFmt.format(_totalExpense),
                      icon: Icons.arrow_upward_rounded,
                      color: const Color(0xFFF43F5E),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SummaryMiniCard(
                      label: 'Saldo Bersih',
                      value: _currencyFmt.format(_netBalance),
                      icon: Icons.account_balance_wallet_rounded,
                      color: _netBalance >= 0
                          ? const Color(0xFF6D5EF6)
                          : const Color(0xFFF43F5E),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ===== Label =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '${entries.length} transaksi',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Colors.black.withOpacity(0.7),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _periodLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black.withOpacity(0.4),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ===== Tabel Jurnal =====
            Expanded(
              child: entries.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 48,
                              color: Colors.black.withOpacity(0.15)),
                          const SizedBox(height: 12),
                          Text(
                            'Tidak ada transaksi',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.black.withOpacity(0.4),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'pada periode $_periodLabel',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.black.withOpacity(0.3),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 14,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _JournalTable(
                          entries: entries,
                          totalIncome: _totalIncome,
                          totalExpense: _totalExpense,
                          numFmt: _numFmt,
                        ),
                      ),
                    ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ======================== JOURNAL TABLE ========================

class _JournalTable extends StatefulWidget {
  final List<JournalEntry> entries;
  final double totalIncome;
  final double totalExpense;
  final NumberFormat numFmt;

  const _JournalTable({
    required this.entries,
    required this.totalIncome,
    required this.totalExpense,
    required this.numFmt,
  });

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
      // Scrollbar horizontal di paling bawah
      child: SingleChildScrollView(
        controller: _hScroll,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: SizedBox(
          width: _ColWidth.total,
          child: Column(
            children: [
              // ----- Header (tidak scroll vertikal, ikut horizontal bersama rows) -----
              Container(
                color: const Color(0xFF6D5EF6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                child: Row(
                  children: [
                    _TH('No.', _ColWidth.no),
                    _TH('Tanggal', _ColWidth.date),
                    _TH('Keterangan', _ColWidth.description),
                    _TH('Debit (Rp)', _ColWidth.debit, align: TextAlign.right),
                    _TH('Kredit (Rp)', _ColWidth.credit, align: TextAlign.right),
                  ],
                ),
              ),

              // ----- Rows (scroll vertikal) -----
              Expanded(
                child: Scrollbar(
                  controller: _vScroll,
                  thumbVisibility: false,
                  child: ListView.builder(
                    controller: _vScroll,
                    padding: EdgeInsets.zero,
                    itemCount: widget.entries.length + 1,
                    itemBuilder: (context, idx) {
                      // Total row
                      if (idx == widget.entries.length) {
                        return Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF6D5EF6).withOpacity(0.07),
                            border: Border(
                              top: BorderSide(
                                color: const Color(0xFF6D5EF6).withOpacity(0.3),
                                width: 1.2,
                              ),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 11),
                          child: Row(
                            children: [
                              SizedBox(width: _ColWidth.no),
                              SizedBox(width: _ColWidth.date),
                              SizedBox(
                                width: _ColWidth.description,
                                child: Text(
                                  'TOTAL',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF6D5EF6),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: _ColWidth.debit,
                                child: Text(
                                  widget.numFmt.format(widget.totalIncome),
                                  textAlign: TextAlign.right,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF22C55E),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: _ColWidth.credit,
                                child: Text(
                                  widget.numFmt.format(widget.totalExpense),
                                  textAlign: TextAlign.right,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFFF43F5E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      // Data row
                      final entry = widget.entries[idx];
                      final isIncome = entry.type == JournalType.income;
                      final isEven = idx % 2 == 0;
                      final amtColor = isIncome
                          ? const Color(0xFF22C55E)
                          : const Color(0xFFF43F5E);

                      return Container(
                        decoration: BoxDecoration(
                          color: isEven ? Colors.white : Colors.grey.shade50,
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey.shade100,
                              width: 0.8,
                            ),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // No
                            SizedBox(
                              width: _ColWidth.no,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 1),
                                child: Text(
                                  '${idx + 1}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.black.withOpacity(0.35),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            // Tanggal
                            SizedBox(
                              width: _ColWidth.date,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 1),
                                child: Text(
                                  DateFormat('dd/MM/yyyy').format(entry.date),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.black.withOpacity(0.6),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            // Keterangan
                            SizedBox(
                              width: _ColWidth.description,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  // Badge jenis transaksi kecil
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: amtColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isIncome ? 'Pemasukan' : 'Pengeluaran',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: amtColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Debit
                            SizedBox(
                              width: _ColWidth.debit,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 1),
                                child: Text(
                                  isIncome
                                      ? widget.numFmt.format(entry.amount)
                                      : '-',
                                  textAlign: TextAlign.right,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: isIncome
                                        ? const Color(0xFF22C55E)
                                        : Colors.black.withOpacity(0.2),
                                  ),
                                ),
                              ),
                            ),
                            // Kredit
                            SizedBox(
                              width: _ColWidth.credit,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 1),
                                child: Text(
                                  !isIncome
                                      ? widget.numFmt.format(entry.amount)
                                      : '-',
                                  textAlign: TextAlign.right,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: !isIncome
                                        ? const Color(0xFFF43F5E)
                                        : Colors.black.withOpacity(0.2),
                                  ),
                                ),
                              ),
                            ),
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

// ======================== HELPER WIDGETS ========================

/// Cell header tabel
class _TH extends StatelessWidget {
  final String text;
  final double width;
  final TextAlign align;

  const _TH(this.text, this.width, {this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 11,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Summary card kecil di atas tabel
class _SummaryMiniCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryMiniCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 13, color: color),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.black.withOpacity(0.5),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}