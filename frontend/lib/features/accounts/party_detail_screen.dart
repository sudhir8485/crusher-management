import 'dart:typed_data';
import 'package:excel/excel.dart' as xl;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/api/api_client.dart';
import '../../core/widgets/app_widgets.dart';
import '../vendor_payments/vendor_payments_screen.dart' show showRecordPaymentDialog;

// ── Date range presets ────────────────────────────────────────────────────────

enum _Preset { thisMonth, lastMonth, thisYear, prevYear, custom }

class _Range { final DateTime from, to; const _Range(this.from, this.to); }

_Range _presetRange(_Preset p) {
  final now = DateTime.now();
  final fyStart = now.month >= 4
      ? DateTime(now.year, 4, 1)
      : DateTime(now.year - 1, 4, 1);
  switch (p) {
    case _Preset.thisMonth:
      return _Range(DateTime(now.year, now.month, 1), now);
    case _Preset.lastMonth:
      final m = now.month == 1 ? 12 : now.month - 1;
      final y = now.month == 1 ? now.year - 1 : now.year;
      return _Range(DateTime(y, m, 1), DateTime(y, m + 1, 0));
    case _Preset.thisYear:
      return _Range(fyStart, now);
    case _Preset.prevYear:
      return _Range(DateTime(fyStart.year - 1, 4, 1), DateTime(fyStart.year, 3, 31));
    case _Preset.custom:
      return _Range(now, now);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

class _LedgerKey {
  final int vendorId;
  final String from, to;
  const _LedgerKey(this.vendorId, this.from, this.to);
  @override bool operator ==(Object o) =>
      o is _LedgerKey && o.vendorId == vendorId && o.from == from && o.to == to;
  @override int get hashCode => Object.hash(vendorId, from, to);
}

final _ledgerProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, _LedgerKey>((ref, k) async {
  final res = await ref.read(apiClientProvider).get(
    '/api/ledger/party/${k.vendorId}',
    params: {'from': k.from, 'to': k.to},
  );
  return Map<String, dynamic>.from(res.data as Map);
});

final _dateFmtKey   = DateFormat('yyyy-MM-dd');
final _dateFmtLong  = DateFormat('d MMM yyyy');
final _dateFmtShort = DateFormat('d MMM yy');
final _numFmt       = NumberFormat('#,##,##0.##');

// ── Screen ────────────────────────────────────────────────────────────────────

class PartyDetailScreen extends ConsumerStatefulWidget {
  final int vendorId;
  final String vendorName;
  const PartyDetailScreen({super.key, required this.vendorId, required this.vendorName});

  @override
  ConsumerState<PartyDetailScreen> createState() => _PartyDetailScreenState();
}

class _PartyDetailScreenState extends ConsumerState<PartyDetailScreen> {
  _Preset _preset = _Preset.thisMonth;
  late DateTime _from;
  late DateTime _to;
  bool _printing = false;

  @override
  void initState() {
    super.initState();
    final r = _presetRange(_Preset.thisMonth);
    _from = r.from; _to = r.to;
  }

  _LedgerKey get _key =>
      _LedgerKey(widget.vendorId, _dateFmtKey.format(_from), _dateFmtKey.format(_to));

  void _applyPreset(_Preset p) {
    if (p == _Preset.custom) return;
    final r = _presetRange(p);
    setState(() { _preset = p; _from = r.from; _to = r.to; });
  }

  Future<void> _pickFrom() async {
    final d = await showDatePicker(
        context: context, initialDate: _from,
        firstDate: DateTime(2020), lastDate: DateTime.now());
    if (d != null) setState(() { _from = d; _preset = _Preset.custom; });
  }

  Future<void> _pickTo() async {
    final d = await showDatePicker(
        context: context, initialDate: _to,
        firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)));
    if (d != null) setState(() { _to = d; _preset = _Preset.custom; });
  }

  void _showExportOptions(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(
              color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          const Text('Export Ledger', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined, color: Colors.red),
            title: const Text('Print / Save as PDF'),
            subtitle: const Text('Opens print preview'),
            onTap: () { Navigator.pop(context); _printPdf(data); },
          ),
          ListTile(
            leading: const Icon(Icons.table_view_outlined, color: Colors.green),
            title: const Text('Export Excel (.xlsx)'),
            subtitle: const Text('Tally-format ledger — matches Ledger.xlsx'),
            onTap: () { Navigator.pop(context); _exportExcel(data); },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _printPdf(Map<String, dynamic> data) async {
    if (_printing) return;
    setState(() => _printing = true);
    try {
      final bytes = await _buildPdf(data);
      await Printing.layoutPdf(
        onLayout: (_) => bytes,
        name: '${widget.vendorName.replaceAll(' ', '_')}_Ledger.pdf',
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF failed: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _exportExcel(Map<String, dynamic> data) async {
    if (_printing) return;
    setState(() => _printing = true);
    try {
      final bytes = _buildExcel(data);
      await Printing.sharePdf(
        bytes: bytes,
        filename: '${widget.vendorName.replaceAll(' ', '_')}_Ledger.xlsx',
      );
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  // ── Excel export — Tally format matching Ledger.xlsx ─────────────────────────
  // Columns: A=Date  B=Particulars  C=Sub-amount  D=Voucher Type  E=Debit  F=Credit

  Uint8List _buildExcel(Map<String, dynamic> data) {
    final vendorName = data['vendorName'] as String? ?? widget.vendorName;
    final fromStr    = data['fromDate']   as String? ?? _dateFmtKey.format(_from);
    final toStr      = data['toDate']     as String? ?? _dateFmtKey.format(_to);
    final opening    = (data['openingBalance'] as num?)?.toDouble() ?? 0;
    final closing    = (data['closingBalance'] as num?)?.toDouble() ?? 0;
    final entries    = List<Map<String, dynamic>>.from(
        (data['entries'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));

    final fromFmt = _dateFmtLong.format(DateTime.parse(fromStr));
    final toFmt   = _dateFmtLong.format(DateTime.parse(toStr));

    final exl   = xl.Excel.createExcel();
    final sheet = exl['Sheet1'];
    exl.setDefaultSheet('Sheet1');

    xl.CellStyle hdrStyle()                        => xl.CellStyle(bold: true, backgroundColorHex: xl.ExcelColor.fromHexString('#D9E1F2'), horizontalAlign: xl.HorizontalAlign.Center);
    xl.CellStyle mainRowStyle({bool debit = true}) => xl.CellStyle(bold: true, backgroundColorHex: xl.ExcelColor.fromHexString(debit ? '#FFF2CC' : '#E2EFDA'));
    xl.CellStyle subStyle()                        => xl.CellStyle(backgroundColorHex: xl.ExcelColor.fromHexString('#FFFFFF'));
    xl.CellStyle pendingStyle()                    => xl.CellStyle(backgroundColorHex: xl.ExcelColor.fromHexString('#FFF8E1'), italic: true);
    xl.CellStyle totalStyle()                      => xl.CellStyle(bold: true, backgroundColorHex: xl.ExcelColor.fromHexString('#D6DCE4'));

    void setCell(int row, int col, dynamic val, [xl.CellStyle? style]) {
      final cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      if (val is double || val is int) {
        cell.value = xl.DoubleCellValue(val.toDouble());
      } else {
        cell.value = xl.TextCellValue(val?.toString() ?? '');
      }
      if (style != null) cell.cellStyle = style;
    }

    int row = 0;

    // Title row
    setCell(row, 0, vendorName, xl.CellStyle(bold: true, fontSize: 12));
    setCell(row, 1, 'Ledger Account');
    setCell(row, 2, '$fromFmt to $toFmt');
    sheet.setRowHeight(row, 20);
    row++;

    // Column headers
    for (var c = 0; c < 7; c++) {
      setCell(row, c, ['Date', 'Particulars', '', 'Voucher Type', 'Debit', 'Credit', 'Balance'][c], hdrStyle());
    }
    row++;

    String balXl(double v) {
      if (v > 0.5)  return '${_numFmt.format(v)} Dr';
      if (v < -0.5) return '${_numFmt.format(v.abs())} Cr';
      return '—';
    }

    // Opening balance
    if (opening.abs() > 0.5) {
      setCell(row, 1, 'Opening Balance', xl.CellStyle(bold: true));
      setCell(row, 4, opening > 0 ? opening : 0.0);
      setCell(row, 5, opening < 0 ? opening.abs() : 0.0);
      setCell(row, 6, balXl(opening), xl.CellStyle(bold: true));
      for (var c in [0, 2, 3]) setCell(row, c, '');
      row++;
    }

    double totalDebit = 0, totalCredit = 0;

    for (final e in entries) {
      final isSales  = (e['voucherType'] as String?) == 'Sales';
      final debit    = (e['debit']  as num?)?.toDouble();
      final credit   = (e['credit'] as num?)?.toDouble();
      final runBal   = (e['runningBalance'] as num?)?.toDouble() ?? 0;
      final dateStr  = DateFormat('dd.MM.yyyy').format(DateTime.parse(e['date'] as String));
      final particulars = e['particulars'] as String? ?? '—';
      final invoiceNo   = e['invoiceNo']   as String? ?? '';
      final isPending   = (e['gstStatus'] as String?) == 'PENDING';
      final details  = List<Map<String, dynamic>>.from(
          (e['details'] as List? ?? []).map((d) => Map<String, dynamic>.from(d as Map)));

      if (isSales && debit != null) {
        totalDebit += debit;
        final mainLabel = invoiceNo.isNotEmpty
            ? 'To (as per details)  [$invoiceNo]'
            : 'To (as per details)';

        setCell(row, 0, dateStr,       mainRowStyle(debit: true));
        setCell(row, 1, mainLabel,     mainRowStyle(debit: true));
        setCell(row, 2, '',            mainRowStyle(debit: true));
        setCell(row, 3, 'Sales',       mainRowStyle(debit: true));
        setCell(row, 4, debit,         mainRowStyle(debit: true));
        setCell(row, 5, '',            mainRowStyle(debit: true));
        setCell(row, 6, balXl(runBal), mainRowStyle(debit: true));
        row++;

        if (isPending) {
          setCell(row, 1, 'GST: Pending — tap invoice to set rate', pendingStyle());
          for (var c in [0, 2, 3, 4, 5, 6]) setCell(row, c, '', pendingStyle());
          row++;
        } else {
          for (final d in details) {
            final label  = d['label']  as String? ?? '';
            final amount = (d['amount'] as num?)?.toDouble();
            setCell(row, 1, label,  subStyle());
            if (amount != null) setCell(row, 2, amount, subStyle());
            for (var c in [0, 3, 4, 5, 6]) setCell(row, c, '', subStyle());
            row++;
          }
        }
      } else if ((e['voucherType'] as String?) == 'MachineWork') {
        final isPending = (e['gstStatus'] as String?) == 'PENDING';
        if (!isPending && debit != null) totalDebit += debit;
        setCell(row, 0, dateStr,        mainRowStyle(debit: true));
        setCell(row, 1, particulars,    mainRowStyle(debit: true));
        setCell(row, 2, '',             mainRowStyle(debit: true));
        setCell(row, 3, 'Machine Work', mainRowStyle(debit: true));
        setCell(row, 4, debit != null ? debit : '', mainRowStyle(debit: true));
        setCell(row, 5, '',             mainRowStyle(debit: true));
        setCell(row, 6, debit != null ? balXl(runBal) : '', mainRowStyle(debit: true));
        row++;
        if (isPending) {
          setCell(row, 1, 'Rate: Pending — tap entry to set rate', pendingStyle());
          for (var c in [0, 2, 3, 4, 5, 6]) setCell(row, c, '', pendingStyle());
          row++;
        } else {
          for (final d in details) {
            final label  = d['label']  as String? ?? '';
            final amount = (d['amount'] as num?)?.toDouble();
            setCell(row, 1, label,  subStyle());
            if (amount != null) setCell(row, 2, amount, subStyle());
            for (var c in [0, 3, 4, 5, 6]) setCell(row, c, '', subStyle());
            row++;
          }
        }
      } else if (!isSales && credit != null) {
        totalCredit += credit;
        setCell(row, 0, dateStr,       mainRowStyle(debit: false));
        setCell(row, 1, particulars,   mainRowStyle(debit: false));
        setCell(row, 2, '',            mainRowStyle(debit: false));
        setCell(row, 3, 'Receipt',     mainRowStyle(debit: false));
        setCell(row, 4, '',            mainRowStyle(debit: false));
        setCell(row, 5, credit,        mainRowStyle(debit: false));
        setCell(row, 6, balXl(runBal), mainRowStyle(debit: false));
        row++;
      }
    }

    // Balance / closing row
    final isOwed    = closing > 0.5;
    final isAdvance = closing < -0.5;
    setCell(row, 1, 'Balance',  totalStyle());
    setCell(row, 3, isOwed ? 'Outstanding' : isAdvance ? 'Advance' : 'Settled', totalStyle());
    setCell(row, 4, isOwed ? closing : 0.0, totalStyle());
    setCell(row, 5, isAdvance ? closing.abs() : 0.0, totalStyle());
    setCell(row, 6, balXl(closing), totalStyle());
    for (var c in [0, 2]) setCell(row, c, '', totalStyle());
    row++;

    // Totals row
    setCell(row, 3, 'TOTAL', totalStyle());
    setCell(row, 4, totalDebit  + (opening > 0 ? opening : 0), totalStyle());
    setCell(row, 5, totalCredit + (opening < 0 ? opening.abs() : 0), totalStyle());
    setCell(row, 6, '', totalStyle());
    for (var c in [0, 1, 2]) setCell(row, c, '', totalStyle());

    // Column widths
    sheet.setColumnWidth(0, 14);
    sheet.setColumnWidth(1, 48);
    sheet.setColumnWidth(2, 16);
    sheet.setColumnWidth(3, 14);
    sheet.setColumnWidth(4, 16);
    sheet.setColumnWidth(5, 16);
    sheet.setColumnWidth(6, 18);

    return Uint8List.fromList(exl.encode()!);
  }

  // ── PDF export — Tally format with Noto Sans (₹ support) ─────────────────────

  Future<Uint8List> _buildPdf(Map<String, dynamic> data) async {
    final font     = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();

    final vendorName = data['vendorName'] as String? ?? widget.vendorName;
    final fromStr    = data['fromDate']   as String? ?? _dateFmtKey.format(_from);
    final toStr      = data['toDate']     as String? ?? _dateFmtKey.format(_to);
    final opening    = (data['openingBalance'] as num?)?.toDouble() ?? 0;
    final closing    = (data['closingBalance'] as num?)?.toDouble() ?? 0;
    final totalDebit = (data['totalDebit']  as num?)?.toDouble() ?? 0;
    final totalCred  = (data['totalCredit'] as num?)?.toDouble() ?? 0;
    final entries    = List<Map<String, dynamic>>.from(
        (data['entries'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));

    final isOwed    = closing > 0.5;
    final isAdvance = closing < -0.5;
    final balColor  = isOwed ? PdfColors.orange900 : isAdvance ? PdfColors.blue700 : PdfColors.green800;

    String rs(double v) => '₹${_numFmt.format(v)}';
    String n(double v)  => _numFmt.format(v);
    String balStr(double v) => v > 0.5 ? rs(v) : v < -0.5 ? 'Adv ${rs(v.abs())}' : '₹0';

    pw.TextStyle bold({double size = 8.5}) => pw.TextStyle(font: fontBold, fontSize: size);
    pw.TextStyle reg({double size = 8.5, PdfColor? color}) =>
        pw.TextStyle(font: font, fontSize: size, color: color);
    pw.TextStyle small({PdfColor? color}) =>
        pw.TextStyle(font: font, fontSize: 7.5, color: color ?? PdfColors.grey700);

    pw.Widget c(String t, {bool b = false, pw.TextAlign a = pw.TextAlign.left, PdfColor? color}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: pw.Text(t, style: b ? bold() : reg(color: color), textAlign: a));

    final pdf = pw.Document(theme: pw.ThemeData.withFont(base: font, bold: fontBold));

    // Header (repeated on every page)
    pw.Widget pdfHeader(pw.Context ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Party Ledger Account', style: bold(size: 13)),
            pw.SizedBox(height: 2),
            pw.Text(vendorName, style: reg(size: 10, color: PdfColors.blueGrey700)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text(
              '${_dateFmtLong.format(DateTime.parse(fromStr))} — ${_dateFmtLong.format(DateTime.parse(toStr))}',
              style: bold(size: 9).copyWith(color: PdfColors.blueGrey700)),
            if (ctx.pageNumber > 1)
              pw.Text('(continued)', style: small(color: PdfColors.grey500)),
          ]),
        ]),
        pw.Divider(thickness: 0.8, color: PdfColors.blueGrey200),
      ]);

    // Summary block
    pw.Widget summaryRow() => pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      margin: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('Opening: ${balStr(opening)}', style: reg(size: 8)),
        pw.Text('Invoiced: ${rs(totalDebit)}', style: reg(size: 8, color: PdfColors.orange900)),
        pw.Text('Received: ${rs(totalCred)}', style: reg(size: 8, color: PdfColors.green800)),
        pw.Text(
          isOwed    ? 'Outstanding: ${rs(closing)}'
            : isAdvance ? 'Advance: ${rs(closing.abs())}'
            : 'Settled Up',
          style: bold(size: 8).copyWith(color: balColor)),
      ]),
    );

    // Tally-style table: Date | Particulars | Sub-amt | Voucher Type | Debit ₹ | Credit ₹ | Balance ₹
    const widths = <int, pw.TableColumnWidth>{
      0: pw.FixedColumnWidth(54),
      1: pw.FlexColumnWidth(3),
      2: pw.FixedColumnWidth(60),
      3: pw.FixedColumnWidth(48),
      4: pw.FixedColumnWidth(62),
      5: pw.FixedColumnWidth(62),
      6: pw.FixedColumnWidth(64),
    };

    // Balance cell — colored Dr/Cr suffix
    pw.Widget bal(double v) {
      final isAdv = v < -0.5;
      final isOwedBal = v > 0.5;
      final label = isAdv ? '${n(v.abs())} Cr' : isOwedBal ? '${n(v)} Dr' : '—';
      final color = isAdv ? PdfColors.blue700 : isOwedBal ? PdfColors.orange900 : PdfColors.green700;
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: pw.Text(label,
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(font: fontBold, fontSize: 8, color: color)));
    }

    final rows = <pw.TableRow>[];

    // Header row
    rows.add(pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
      children: [
        for (final h in ['Date', 'Particulars', '', 'Voucher Type', 'Debit ₹', 'Credit ₹', 'Balance ₹'])
          c(h, b: true),
      ],
    ));

    // Opening balance row
    if (opening.abs() > 0.5)
      rows.add(pw.TableRow(children: [
        c(''), c('Opening Balance', b: true), c(''), c(''),
        c(opening > 0 ? rs(opening) : '', b: true, a: pw.TextAlign.right),
        c(opening < 0 ? rs(opening.abs()) : '', b: true, a: pw.TextAlign.right),
        bal(opening),
      ]));

    for (final e in entries) {
      final isSales  = (e['voucherType'] as String?) == 'Sales';
      final debit    = (e['debit']  as num?)?.toDouble();
      final credit   = (e['credit'] as num?)?.toDouble();
      final runBal   = (e['runningBalance'] as num?)?.toDouble() ?? 0;
      final dateStr  = _dateFmtLong.format(DateTime.parse(e['date'] as String));
      final particulars = e['particulars'] as String? ?? '—';
      final invoiceNo   = e['invoiceNo']   as String? ?? '';
      final isPending   = (e['gstStatus'] as String?) == 'PENDING';
      final details  = List<Map<String, dynamic>>.from(
          (e['details'] as List? ?? []).map((d) => Map<String, dynamic>.from(d as Map)));

      if (isSales && debit != null) {
        rows.add(pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.orange50),
          children: [
            c(dateStr),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('To (as per details)', style: bold()),
                if (invoiceNo.isNotEmpty)
                  pw.Text(invoiceNo, style: small(color: PdfColors.blueGrey600)),
              ])),
            c(''),
            c('Sales', b: true),
            c(n(debit), b: true, a: pw.TextAlign.right),
            c(''),
            bal(runBal),
          ],
        ));

        if (isPending) {
          rows.add(pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.amber50),
            children: [
              c(''),
              pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(14, 2, 4, 2),
                child: pw.Text('GST: Pending',
                    style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: PdfColors.orange800))),
              c(''), c(''), c(''), c(''), c(''),
            ],
          ));
        } else {
          for (final d in details) {
            final label  = d['label']  as String? ?? '';
            final amount = (d['amount'] as num?)?.toDouble();
            rows.add(pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey50),
              children: [
                c(''),
                pw.Padding(
                  padding: const pw.EdgeInsets.fromLTRB(14, 1, 4, 1),
                  child: pw.Text(label, style: small())),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  child: pw.Text(
                    amount != null ? n(amount) : '',
                    style: small(), textAlign: pw.TextAlign.right)),
                c(''), c(''), c(''), c(''),
              ],
            ));
          }
        }
      } else if ((e['voucherType'] as String?) == 'MachineWork') {
        rows.add(pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.lightBlue50),
          children: [
            c(dateStr),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(particulars, style: bold()),
              ])),
            c(''),
            c('Mach.\nWork', b: true),
            debit != null
                ? c(n(debit), b: true, a: pw.TextAlign.right)
                : c('—', a: pw.TextAlign.right),
            c(''),
            debit != null ? bal(runBal) : c(''),
          ],
        ));
        if (isPending) {
          rows.add(pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.amber50),
            children: [
              c(''),
              pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(14, 2, 4, 2),
                child: pw.Text('Rate: Pending',
                    style: pw.TextStyle(
                        font: fontBold, fontSize: 7.5,
                        color: PdfColors.orange800))),
              c(''), c(''), c(''), c(''), c(''),
            ],
          ));
        } else {
          for (final d in details) {
            final label  = d['label']  as String? ?? '';
            final amount = (d['amount'] as num?)?.toDouble();
            rows.add(pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey50),
              children: [
                c(''),
                pw.Padding(
                  padding: const pw.EdgeInsets.fromLTRB(14, 1, 4, 1),
                  child: pw.Text(label, style: small())),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  child: pw.Text(
                    amount != null ? n(amount) : '',
                    style: small(), textAlign: pw.TextAlign.right)),
                c(''), c(''), c(''), c(''),
              ],
            ));
          }
        }
      } else if (!isSales && credit != null) {
        rows.add(pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.green50),
          children: [
            c(dateStr),
            c(particulars, b: true),
            c(''),
            c('Receipt'),
            c(''),
            c(n(credit), b: true, a: pw.TextAlign.right),
            bal(runBal),
          ],
        ));
      }
    }

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 24),
      header: pdfHeader,
      build: (_) => [
        summaryRow(),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
          columnWidths: widths,
          children: rows,
        ),
      ],
    ));

    return pdf.save();
  }

  Future<void> _showSetGstDialog(BuildContext ctx, int invoiceId, String invoiceNo) async {
    final rateCtrl = TextEditingController();
    double? previewRate;

    final confirmed = await showDialog<String>(
      context: ctx,
      builder: (dctx) => StatefulBuilder(builder: (dctx, setS) {
        void updatePreview(String v) {
          final d = double.tryParse(v);
          setS(() => previewRate = (d != null && d >= 0 && d <= 28) ? d : null);
        }

        return AlertDialog(
          title: Text('Set GST Rate — $invoiceNo'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Enter total GST % (SGST + CGST combined)',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 12),
            // Common rate chips
            Wrap(spacing: 8, children: [
              for (final r in [0, 5, 12, 18, 28])
                ActionChip(
                  label: Text('$r%'),
                  onPressed: () {
                    rateCtrl.text = r.toString();
                    updatePreview(r.toString());
                  },
                ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: rateCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Total GST %',
                suffixText: '%',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: updatePreview,
            ),
            if (previewRate != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  Text('SGST ${(previewRate! / 2).toStringAsFixed(previewRate! % 2 == 0 ? 0 : 1)}%',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Text('+'),
                  Text('CGST ${(previewRate! / 2).toStringAsFixed(previewRate! % 2 == 0 ? 0 : 1)}%',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Text('='),
                  Text('$previewRate%', style: const TextStyle(fontWeight: FontWeight.bold,
                      color: Colors.blue)),
                ]),
              ),
            ],
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: previewRate != null
                  ? () => Navigator.pop(dctx, rateCtrl.text)
                  : null,
              child: const Text('Apply & Lock'),
            ),
          ],
        );
      }),
    );

    if (confirmed == null || !mounted) return;
    final rate = double.tryParse(confirmed);
    if (rate == null) return;

    try {
      await ref.read(apiClientProvider).post(
        '/api/invoices/$invoiceId/set-gst-rate',
        data: null,
        params: {'rate': rate.toString()},
      );
      if (mounted) {
        ref.invalidate(_ledgerProvider(_key));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('GST set to $rate% on $invoiceNo — invoice locked'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _showSetMachineRateDialog(
      BuildContext ctx, int machineWorkId, double? totalHours, double? currentRate) async {
    final rateCtrl = TextEditingController(text: currentRate?.toString() ?? '');
    final isEditing = currentRate != null;
    double? previewTotal = (currentRate != null && totalHours != null)
        ? currentRate * totalHours : null;

    final confirmed = await showDialog<String>(
      context: ctx,
      builder: (dctx) => StatefulBuilder(builder: (dctx, setS) {
        void updatePreview(String v) {
          final r = double.tryParse(v);
          setS(() => previewTotal =
              (r != null && totalHours != null) ? r * totalHours : null);
        }

        return AlertDialog(
          title: Text(isEditing ? 'Edit Machine Work Rate' : 'Set Machine Work Rate'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            if (totalHours != null)
              Text('${totalHours.toStringAsFixed(2)} hrs of work',
                  style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: rateCtrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Rate ₹/hr',
                prefixText: '₹',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: updatePreview,
            ),
            if (previewTotal != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total:'),
                      Text(
                        '₹${_numFmt.format(previewTotal!)}',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                            fontSize: 15),
                      ),
                    ]),
              ),
            ],
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: rateCtrl.text.isNotEmpty
                  ? () => Navigator.pop(dctx, rateCtrl.text)
                  : null,
              child: Text(isEditing ? 'Update' : 'Apply & Lock'),
            ),
          ],
        );
      }),
    );

    if (confirmed == null || !mounted) return;
    final rate = double.tryParse(confirmed);
    if (rate == null) return;

    try {
      await ref.read(apiClientProvider).post(
        '/api/machine-work/$machineWorkId/set-rate',
        data: null,
        params: {'rate': rate.toString()},
      );
      if (mounted) {
        ref.invalidate(_ledgerProvider(_key));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEditing
              ? 'Rate updated to ₹$rate/hr'
              : 'Rate set to ₹$rate/hr — entry locked'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ledger = ref.watch(_ledgerProvider(_key));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.vendorName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_ledgerProvider(_key)),
          ),
        ],
      ),
      body: Column(children: [
        _DateFilterBar(preset: _preset, from: _from, to: _to,
            onPreset: _applyPreset, onPickFrom: _pickFrom, onPickTo: _pickTo),
        Expanded(
          child: ledger.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (data) => _LedgerBody(
              data: data,
              printing: _printing,
              onExport: () => _showExportOptions(data),
              onSetGst: _showSetGstDialog,
              onSetMachineRate: _showSetMachineRateDialog,
              onRecordPayment: () => showRecordPaymentDialog(
                context, ref,
                initialVendorId:   widget.vendorId,
                initialVendorName: widget.vendorName,
                onSaved: () => ref.invalidate(_ledgerProvider(_key)),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Date filter bar ───────────────────────────────────────────────────────────

class _DateFilterBar extends StatelessWidget {
  final _Preset preset;
  final DateTime from, to;
  final ValueChanged<_Preset> onPreset;
  final VoidCallback onPickFrom, onPickTo;

  const _DateFilterBar({
    required this.preset, required this.from, required this.to,
    required this.onPreset, required this.onPickFrom, required this.onPickTo,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final (lbl, p) in [
              ('This Month', _Preset.thisMonth), ('Last Month', _Preset.lastMonth),
              ('This FY', _Preset.thisYear), ('Prev FY', _Preset.prevYear),
            ])
              Padding(padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(lbl, style: const TextStyle(fontSize: 11)),
                    selected: preset == p,
                    onSelected: (_) => onPreset(p),
                    visualDensity: VisualDensity.compact,
                  )),
          ]),
        ),
        const SizedBox(height: 6),
        Row(children: [
          _datePill(_dateFmtShort.format(from), onPickFrom, cs),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('→', style: TextStyle(fontSize: 12))),
          _datePill(_dateFmtShort.format(to), onPickTo, cs),
        ]),
      ]),
    );
  }

  Widget _datePill(String label, VoidCallback onTap, ColorScheme cs) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          border: Border.all(color: cs.outline.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    ),
  );
}

// ── Ledger body ───────────────────────────────────────────────────────────────

class _LedgerBody extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool printing;
  final VoidCallback onExport;
  final VoidCallback onRecordPayment;
  final Future<void> Function(BuildContext, int, String) onSetGst;
  final Future<void> Function(BuildContext, int, double?, double?) onSetMachineRate;

  const _LedgerBody({
    required this.data, required this.printing,
    required this.onExport, required this.onRecordPayment,
    required this.onSetGst, required this.onSetMachineRate,
  });

  @override
  Widget build(BuildContext context) {
    final closing  = (data['closingBalance'] as num?)?.toDouble() ?? 0;
    final entries  = List<Map<String, dynamic>>.from(
        (data['entries'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));

    final isOwed    = closing > 0.5;
    final isAdvance = closing < -0.5;
    final balLabel  = isOwed    ? 'Owes ${fmtCurr(closing)}'
        : isAdvance ? 'Advance ${fmtCurr(closing.abs())}'
        : 'Settled Up';
    final balColor  = isOwed    ? Colors.orange.shade800
        : isAdvance ? Colors.blue.shade700
        : Colors.green.shade700;
    final balBg     = isOwed    ? Colors.orange.shade50
        : isAdvance ? Colors.blue.shade50
        : Colors.green.shade50;

    // Newest first
    final displayEntries = entries.reversed.toList();

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: balBg, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: balColor.withValues(alpha: 0.3)),
            ),
            child: Text(balLabel,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: balColor),
                textAlign: TextAlign.center),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: printing ? null : onExport,
              icon: printing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.table_view_outlined, size: 16),
              label: const Text('Export Ledger'),
            )),
            const SizedBox(width: 10),
            Expanded(child: FilledButton.icon(
              onPressed: onRecordPayment,
              icon: const Icon(Icons.payments_outlined, size: 16),
              label: const Text('Record Payment'),
            )),
          ]),
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: entries.isEmpty
            ? const AppEmptyState(
                icon: Icons.receipt_long_outlined,
                message: 'No invoices in this period',
                hint: 'Try a wider date range or create a GST invoice for this party',
              )
            : _EntryList(entries: displayEntries, onSetGst: onSetGst,
                onSetMachineRate: onSetMachineRate),
      ),
    ]);
  }
}

// ── Entry list with date grouping (newest first) ──────────────────────────────

class _EntryList extends StatelessWidget {
  final List<Map<String, dynamic>> entries;
  final Future<void> Function(BuildContext, int, String) onSetGst;
  final Future<void> Function(BuildContext, int, double?, double?) onSetMachineRate;
  const _EntryList({
    required this.entries, required this.onSetGst,
    required this.onSetMachineRate,
  });

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final e in entries) {
      grouped.putIfAbsent(e['date'] as String, () => []).add(e);
    }
    final dates = grouped.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 80),
      itemCount: dates.length,
      itemBuilder: (_, i) {
        final date      = dates[i];
        final dayEntries = grouped[date]!;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: double.infinity,
            color: Colors.grey.shade100,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              _dateFmtLong.format(DateTime.parse(date)),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600, letterSpacing: 0.3),
            ),
          ),
          const Divider(height: 1),
          ...dayEntries.map((e) => _EntryCard(
              entry: e, onSetGst: onSetGst, onSetMachineRate: onSetMachineRate)),
        ]);
      },
    );
  }
}

// ── Entry card — invoice with GST sub-rows, or payment ───────────────────────

class _EntryCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  final Future<void> Function(BuildContext, int, String) onSetGst;
  final Future<void> Function(BuildContext, int, double?, double?) onSetMachineRate;
  const _EntryCard({
    required this.entry, required this.onSetGst,
    required this.onSetMachineRate,
  });

  @override
  Widget build(BuildContext context) {
    final voucherType  = (entry['voucherType'] as String?) ?? '';
    final isSales      = voucherType == 'Sales';
    final isMachineWork = voucherType == 'MachineWork';
    final debit     = (entry['debit']  as num?)?.toDouble();
    final credit    = (entry['credit'] as num?)?.toDouble();
    final balance   = (entry['runningBalance'] as num?)?.toDouble() ?? 0;
    final particulars  = entry['particulars'] as String? ?? '—';
    final invoiceNo    = entry['invoiceNo']   as String? ?? '';
    final isPending    = (entry['gstStatus']  as String?) == 'PENDING';
    final sourceId     = entry['sourceId'] as int?;
    final totalHours   = (entry['totalHours'] as num?)?.toDouble();
    final details   = List<Map<String, dynamic>>.from(
        (entry['details'] as List? ?? []).map((d) => Map<String, dynamic>.from(d as Map)));

    final balIsOwed = balance > 0.5;
    final balIsAdv  = balance < -0.5;
    final balText   = balIsOwed ? 'Bal. ${fmtCurr(balance)}'
        : balIsAdv  ? 'Adv. ${fmtCurr(balance.abs())}'
        : 'Settled';
    final balColor  = balIsOwed ? Colors.orange.shade700
        : balIsAdv  ? Colors.blue.shade700
        : Colors.green.shade700;

    final cardBg = isPending
        ? Colors.amber.shade50
        : isSales ? Colors.white
        : isMachineWork ? Colors.lightBlue.shade50
        : Colors.green.shade50;

    VoidCallback? onTap;
    if (sourceId != null) {
      if (isSales && isPending) {
        onTap = () => onSetGst(context, sourceId, invoiceNo);
      } else if (isMachineWork) {
        final currentRate = (debit != null && totalHours != null && totalHours > 0)
            ? debit / totalHours : null;
        onTap = () => onSetMachineRate(context, sourceId, totalHours, currentRate);
      }
    }

    return InkWell(
      onTap: onTap,
      child: Container(
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Main row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Left: title + badge
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (isMachineWork)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(Icons.construction_outlined, size: 14,
                        color: Colors.blueGrey.shade600)),
                Expanded(
                  child: Text(
                    isSales
                        ? (invoiceNo.isNotEmpty ? invoiceNo : 'Sales Invoice')
                        : particulars,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                if (isPending)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.amber.shade400),
                    ),
                    child: Text(
                      isSales ? 'GST: Pending' : 'Rate: Pending',
                      style: TextStyle(fontSize: 10, color: Colors.orange.shade900,
                          fontWeight: FontWeight.w600)),
                  ),
              ]),
              const SizedBox(height: 2),
              if (balance != 0 || !isPending)
                Text(balText, style: TextStyle(fontSize: 11, color: balColor)),
            ])),
            const SizedBox(width: 12),
            // Right: type label + amount
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(
                isSales ? 'Billed'
                    : isMachineWork ? 'Machine Work'
                    : 'Received',
                style: TextStyle(fontSize: 10,
                    color: isSales ? Colors.orange.shade700
                        : isMachineWork ? Colors.blueGrey.shade600
                        : Colors.green.shade700),
              ),
              const SizedBox(height: 2),
              Text(
                isMachineWork
                    ? (debit != null ? fmtCurr(debit) : '—')
                    : isSales
                        ? fmtCurr(debit ?? 0)
                        : fmtCurr(credit ?? 0),
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold,
                  color: isSales ? Colors.orange.shade800
                      : isMachineWork ? Colors.blueGrey.shade700
                      : Colors.green.shade700,
                ),
              ),
            ]),
          ]),
        ),

        // Sub-rows: GST breakdown (Sales) or rate info (MachineWork)
        if ((isSales || isMachineWork) && !isPending && details.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: details.map((d) {
                final label  = d['label']  as String? ?? '';
                final amount = (d['amount'] as num?)?.toDouble();
                return Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(children: [
                    Expanded(child: Text(label,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600))),
                    if (amount != null)
                      Text(_numFmt.format(amount),
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  ]),
                );
              }).toList(),
            ),
          ),

        if ((isSales || isMachineWork) && isPending)
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 16, 8),
            child: Text(
              isSales ? 'Tap to set GST rate' : 'Tap to set rate',
              style: TextStyle(fontSize: 11, color: Colors.orange.shade700,
                  fontStyle: FontStyle.italic),
            ),
          ),
      ]),
    ));  // closes Container + InkWell
  }
}
