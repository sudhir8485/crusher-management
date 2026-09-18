import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/api/api_client.dart';

// ── Font cache — loaded once, reused for every PDF ────────────────────────────
pw.Font? _cachedFont;
pw.Font? _cachedFontBold;

Future<pw.Font> _font()     async => _cachedFont     ??= await PdfGoogleFonts.notoSansRegular();
Future<pw.Font> _fontBold() async => _cachedFontBold ??= await PdfGoogleFonts.notoSansBold();

// ── Number-to-words (Indian numbering) ────────────────────────────────────────

const _ones = [
  '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
  'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
  'Seventeen', 'Eighteen', 'Nineteen',
];
const _tens = [
  '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty',
  'Sixty', 'Seventy', 'Eighty', 'Ninety',
];

String _two(int n) {
  if (n <= 0) return '';
  if (n < 20) return _ones[n];
  return '${_tens[n ~/ 10]}${n % 10 != 0 ? ' ${_ones[n % 10]}' : ''}';
}

String _three(int n) {
  if (n == 0) return '';
  if (n >= 100) { final r = n % 100; return '${_ones[n ~/ 100]} Hundred${r != 0 ? ' ${_two(r)}' : ''}'; }
  return _two(n);
}

String _wordify(int n) {
  if (n == 0) return '';
  final c = n ~/ 10000000; final l = (n % 10000000) ~/ 100000;
  final t = (n % 100000) ~/ 1000; final r = n % 1000;
  final p = <String>[];
  if (c > 0) p.add('${_three(c)} Crore${c > 1 ? 's' : ''}');
  if (l > 0) p.add('${_two(l)} Lakh${l > 1 ? 's' : ''}');
  if (t > 0) p.add('${_two(t)} Thousand');
  if (r > 0) p.add(_three(r));
  return p.join(' ');
}

String amountInWords(double amount) {
  final ru = amount.floor(); final pa = ((amount - ru) * 100).round();
  if (ru == 0 && pa == 0) return 'Zero Rupees Only';
  final p = <String>[];
  if (ru > 0) p.add('${_wordify(ru)} Rupee${ru == 1 ? '' : 's'}');
  if (pa > 0) p.add('${_two(pa)} Paise');
  return '${p.join(' and ')} Only';
}

// ── Formatting ─────────────────────────────────────────────────────────────────

final _dateFmt = DateFormat('dd.MM.yyyy');
final _currFmt = NumberFormat('#,##,##0.00', 'en_IN');
final _qtyFmt  = NumberFormat('#,##,##0.###', 'en_IN');

String _fd(String? d) {
  if (d == null || d.isEmpty) return '';
  try { return _dateFmt.format(DateTime.parse(d)); } catch (_) { return d; }
}
String _rs(double v) => '${_currFmt.format(v)}';

// ── PDF builder ────────────────────────────────────────────────────────────────

Future<pw.Document> buildInvoicePdf(
  Map<String, dynamic> inv,
  Map<String, dynamic> profile,
) async {
  // ── Fonts (Noto Sans — cached after first load) ───────────────────────────
  final font     = await _font();
  final fontBold = await _fontBold();

  final isJw = inv['_src'] == 'jw';

  // ── Business Profile ───────────────────────────────────────────────────────
  final companyName   = ((profile['name'] as String?)?.trim() ?? '').let((s) => s.isNotEmpty ? s : 'Your Company');
  final address       = (profile['address']     as String?)?.trim() ?? '';
  final phone         = (profile['phone']       as String?)?.trim() ?? '';
  final email         = (profile['email']       as String?)?.trim() ?? '';
  final tenantGstin   = (profile['gstin']       as String?)?.trim() ?? '';
  final bankName      = (profile['bankName']     as String?)?.trim() ?? '';
  final bankAccNo     = (profile['bankAccountNo'] as String?)?.trim() ?? '';
  final bankIfsc      = (profile['bankIfsc']     as String?)?.trim() ?? '';
  final logoB64       = profile['logoBase64']   as String?;
  final invoiceTerms  = (profile['invoiceTerms'] as String?)?.trim();

  pw.ImageProvider? logoImage;
  if (logoB64 != null && logoB64.isNotEmpty) {
    try {
      final data = logoB64.contains(',') ? logoB64.split(',').last : logoB64;
      logoImage  = pw.MemoryImage(base64Decode(data));
    } catch (_) {}
  }

  // ── Invoice data ───────────────────────────────────────────────────────────
  final invoiceNo   = inv['invoiceNo']    as String? ?? '—';
  final invoiceDate = inv['invoiceDate']  as String? ?? '';
  final supplyDate  = inv['supplyDate']   as String?;
  final poNo        = (inv['poNo']        as String?)?.trim() ?? '';
  final partyName   = inv['vendorName']   as String? ?? '—';
  final partyGstin  = (inv['vendorGstin'] as String?)?.trim() ?? '';
  final partyAddr   = (inv['vendorAddress'] as String?)?.trim() ?? '';
  final siteName    = inv['siteName']     as String?;
  final periodFrom  = inv['periodFrom']   as String?;
  final periodTo    = inv['periodTo']     as String?;
  final items       = List<Map<String, dynamic>>.from(inv['items'] as List? ?? []);
  final cgstRate    = (inv['cgstRate']    as num? ?? 0).toDouble();
  final sgstRate    = (inv['sgstRate']    as num? ?? 0).toDouble();
  final subtotal    = (inv['subtotal']    as num? ?? 0).toDouble();
  final cgstAmt     = (inv['cgstAmount']  as num? ?? 0).toDouble();
  final sgstAmt     = (inv['sgstAmount']  as num? ?? 0).toDouble();
  final grandTotal  = (inv['grandTotal']  as num? ?? 0).toDouble();
  final isPending   = inv['gstStatus'] == 'PENDING';

  // Round-up (nearest rupee)
  final rounded   = grandTotal.ceilToDouble();
  final roundUp   = rounded - grandTotal;
  final netTotal  = rounded;

  // ── Style helpers ──────────────────────────────────────────────────────────
  pw.TextStyle ts(double sz, {bool bold = false, PdfColor? color}) => pw.TextStyle(
    font: bold ? fontBold : font, fontSize: sz,
    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color,
  );

  pw.Widget pad(pw.Widget child, {double h = 3, double v = 3}) =>
      pw.Padding(padding: pw.EdgeInsets.symmetric(horizontal: h, vertical: v), child: child);

  // ── 1. HEADER ──────────────────────────────────────────────────────────────
  // Logo on left + company name centred + contact below

  final header = pw.Column(children: [
    pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
      // Logo
      if (logoImage != null) ...[
        pw.Image(logoImage, width: 60, height: 60, fit: pw.BoxFit.contain),
        pw.SizedBox(width: 12),
      ],
      // Company name
      pw.Expanded(
        child: pw.Text(companyName,
            textAlign: pw.TextAlign.center,
            style: ts(20, bold: true)),
      ),
    ]),
    pw.SizedBox(height: 6),
    if (address.isNotEmpty)
      pw.Text('Reg. Add- $address',
          textAlign: pw.TextAlign.center,
          style: ts(8, color: PdfColors.grey800)),
    if (phone.isNotEmpty || email.isNotEmpty)
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 2),
        child: pw.Text(
          [if (email.isNotEmpty) 'E-Mail - $email', if (phone.isNotEmpty) 'Mob.No.- $phone'].join(',  '),
          textAlign: pw.TextAlign.center,
          style: ts(8, color: PdfColors.grey800),
        ),
      ),
    if (tenantGstin.isNotEmpty)
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 2),
        child: pw.Text('GSTIN- $tenantGstin',
            textAlign: pw.TextAlign.center,
            style: ts(8, bold: true)),
      ),
    pw.SizedBox(height: 4),
    pw.Divider(thickness: 1, color: PdfColors.black),
    // "Tax Invoice" title bar
    pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.black, width: 0.5),
        ),
      ),
      child: pw.Text(isJw ? 'Tax Invoice (Job Work)' : 'Tax Invoice',
          textAlign: pw.TextAlign.center,
          style: ts(9, bold: true)),
    ),
  ]);

  // ── 2. PARTY / SITE / INVOICE META (3-column table row) ───────────────────
  const _brd = pw.BorderSide(color: PdfColors.black, width: 0.5);
  const _allBorder = pw.BoxDecoration(border: pw.Border(top: _brd, left: _brd, right: _brd, bottom: _brd));

  pw.Widget lbl(String t, {bool bold = false, double sz = 8}) =>
      pw.Text(t, style: ts(sz, bold: bold));

  // Determine site address text
  String siteAddrText = '';
  if (isJw && siteName != null && siteName.isNotEmpty) {
    siteAddrText = siteName;
  }
  if (isJw && periodFrom != null && periodTo != null) {
    final pf = _fd(periodFrom); final pt = _fd(periodTo);
    if (pf.isNotEmpty) siteAddrText += '\n$pf – $pt';
  }

  final partyBlock = pw.Container(
    padding: const pw.EdgeInsets.all(5),
    decoration: _allBorder,
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      lbl('Party Name :- $partyName', bold: true),
      pw.SizedBox(height: 3),
      if (partyAddr.isNotEmpty) lbl('Address:- $partyAddr'),
      pw.SizedBox(height: 3),
      lbl('GST No.:- $partyGstin', bold: true),
    ]),
  );

  final siteBlock = pw.Container(
    padding: const pw.EdgeInsets.all(5),
    decoration: _allBorder,
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      lbl('Site Address:-', bold: true),
      pw.SizedBox(height: 3),
      if (siteAddrText.isNotEmpty) lbl(siteAddrText),
    ]),
  );

  String _rl(String label) => '$label:-';
  pw.Widget invLine(String label, String val) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 2),
    child: pw.Row(children: [
      pw.SizedBox(width: 90, child: lbl(_rl(label))),
      pw.Expanded(child: lbl(val, bold: true)),
    ]),
  );

  final invBlock = pw.Container(
    padding: const pw.EdgeInsets.all(5),
    decoration: _allBorder,
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      invLine('Invoice No.',   invoiceNo),
      invLine('Invoice Date',  _fd(invoiceDate)),
      invLine('Date of Supply', supplyDate != null ? _fd(supplyDate) : ''),
      invLine('P.O.No.',       poNo),
      invLine('Bill Ref.No.',  ''),
    ]),
  );

  final partyMetaRow = pw.Row(children: [
    pw.Expanded(flex: 45, child: partyBlock),
    pw.Expanded(flex: 25, child: siteBlock),
    pw.Expanded(flex: 30, child: invBlock),
  ]);

  // ── 3. ITEMS TABLE ─────────────────────────────────────────────────────────
  // Columns: Sr.No | Item Description | HSN | Qty (Brss) | Rate (Brss) | Amount

  pw.Widget th(String t, {pw.Alignment align = pw.Alignment.centerLeft}) =>
      pad(pw.Align(alignment: align, child: lbl(t, bold: true)), h: 4, v: 4);

  pw.Widget td(String t, {pw.Alignment align = pw.Alignment.centerLeft, bool bold = false}) =>
      pad(pw.Align(alignment: align, child: lbl(t, bold: bold)), h: 4, v: 3);

  final tableRows = <pw.TableRow>[
    // Header
    pw.TableRow(
      decoration: pw.BoxDecoration(color: PdfColors.grey200,
          border: pw.Border.all(color: PdfColors.black, width: 0.5)),
      children: [
        th('Sr.No', align: pw.Alignment.center),
        th('Item Description'),
        th('HSN'),
        th('Qty (Brss)', align: pw.Alignment.center),
        th('Rate (Brss)', align: pw.Alignment.centerRight),
        th('Amount', align: pw.Alignment.centerRight),
      ],
    ),
    // Data rows
    ...items.asMap().entries.map((e) {
      final i = e.key; final item = e.value;
      final desc   = item['description'] as String? ?? '—';
      final hsn    = isJw
          ? (item['sacCode'] as String? ?? '')
          : (item['hsn']    as String? ?? '');
      final qtyRaw = isJw
          ? item['quantity']      as num?
          : item['quantityBrass'] as num?;
      final qty    = qtyRaw != null ? _qtyFmt.format(qtyRaw.toDouble()) : '';
      final rate   = item['rate']   as num?;
      final amt    = (item['amount'] as num? ?? 0).toDouble();
      final bg     = i.isOdd ? PdfColors.grey50 : PdfColors.white;
      return pw.TableRow(
        decoration: pw.BoxDecoration(color: bg,
            border: pw.Border.all(color: PdfColors.black, width: 0.5)),
        children: [
          td('${i + 1}', align: pw.Alignment.center),
          td(desc),
          td(hsn, align: pw.Alignment.center),
          td(qty, align: pw.Alignment.center),
          td(rate != null ? _rs(rate.toDouble()) : '', align: pw.Alignment.centerRight),
          td(_rs(amt), bold: true, align: pw.Alignment.centerRight),
        ],
      );
    }),
  ];

  final itemsTable = pw.Table(
    columnWidths: const {
      0: pw.FixedColumnWidth(28),   // Sr.No
      1: pw.FlexColumnWidth(4),     // Description
      2: pw.FlexColumnWidth(1.2),   // HSN
      3: pw.FlexColumnWidth(1.3),   // Qty
      4: pw.FlexColumnWidth(1.5),   // Rate
      5: pw.FlexColumnWidth(1.8),   // Amount
    },
    children: tableRows,
  );

  // ── 4. BOTTOM 3-COLUMN: balance | bank details | totals ───────────────────
  String _rateStr(double r) =>
      r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toStringAsFixed(1);

  pw.Widget totLine(String label, String val, {bool bold = false, double sz = 8}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          lbl(label, bold: bold, sz: sz),
          lbl(val,   bold: bold, sz: sz),
        ]),
      );

  final balanceCol = pw.Container(
    padding: const pw.EdgeInsets.all(5),
    decoration: _allBorder,
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      lbl('Balance till Date', bold: true),
      pw.SizedBox(height: 8),
      pw.Divider(thickness: 0.5),
      pw.SizedBox(height: 4),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        lbl('Bill Amount'),
        lbl(_rs(grandTotal), bold: true),
      ]),
      pw.SizedBox(height: 4),
      pw.Divider(thickness: 0.5),
      pw.SizedBox(height: 4),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        lbl('Net Balance'),
        lbl(_rs(netTotal), bold: true),
      ]),
    ]),
  );

  final bankCol = pw.Container(
    padding: const pw.EdgeInsets.all(5),
    decoration: _allBorder,
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      lbl('Bank Details', bold: true),
      pw.SizedBox(height: 4),
      if (bankName.isNotEmpty) ...[
        lbl('A/c Name- $companyName'),
        pw.SizedBox(height: 2),
      ],
      if (bankAccNo.isNotEmpty) ...[
        lbl('A/c No.- $bankAccNo'),
        pw.SizedBox(height: 2),
      ],
      if (bankName.isNotEmpty) ...[
        lbl('Bank Name- $bankName'),
        pw.SizedBox(height: 2),
      ],
      if (bankIfsc.isNotEmpty)
        lbl('IFSC Code:- $bankIfsc'),
      if (bankName.isEmpty && bankAccNo.isEmpty && bankIfsc.isEmpty)
        pw.Text('(Add bank details in Business Profile)',
            style: ts(8, color: PdfColors.grey600)),
    ]),
  );

  final totalsCol = pw.Container(
    padding: const pw.EdgeInsets.all(5),
    decoration: _allBorder,
    child: pw.Column(children: [
      totLine('Sub Total', _rs(subtotal)),
      pw.Divider(thickness: 0.5),
      if (!isPending) ...[
        totLine('CGST ${_rateStr(cgstRate)} %', _rs(cgstAmt)),
        pw.Divider(thickness: 0.5),
        totLine('SGST ${_rateStr(sgstRate)} %', _rs(sgstAmt)),
        pw.Divider(thickness: 0.5),
        totLine('Round Up -', _rs(roundUp)),
        pw.Divider(thickness: 0.5),
        totLine('Grand Total', _rs(netTotal), bold: true, sz: 9),
      ] else ...[
        totLine('GST', 'Pending', bold: false),
        pw.Divider(thickness: 0.5),
        totLine('Grand Total', _rs(grandTotal), bold: true, sz: 9),
      ],
    ]),
  );

  // Use Table (not Row+Expanded) so cells get proper width constraints
  final bottomRow = pw.Table(
    columnWidths: const {
      0: pw.FlexColumnWidth(35),
      1: pw.FlexColumnWidth(35),
      2: pw.FlexColumnWidth(30),
    },
    children: [
      pw.TableRow(children: [balanceCol, bankCol, totalsCol]),
    ],
  );

  // ── 5. AMOUNT IN WORDS ─────────────────────────────────────────────────────
  final wordsRow = pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    decoration: _allBorder,
    child: pw.Row(children: [
      lbl('Amount in words:-  '),
      pw.Expanded(child: lbl(amountInWords(netTotal), bold: true)),
    ]),
  );

  // ── 6. TERMS ───────────────────────────────────────────────────────────────
  // Terms are tenant-configurable via Business Profile → Invoice Terms.
  // If none configured, fall back to generic placeholder.
  final termsLines = (invoiceTerms != null && invoiceTerms.isNotEmpty)
      ? invoiceTerms.split('\n').where((l) => l.trim().isNotEmpty).toList()
      : <String>[];
  final termsRow = pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    decoration: _allBorder,
    child: termsLines.isEmpty
        ? lbl('No terms & conditions configured. Add them in Business Profile → Invoice Terms.', sz: 7.5)
        : pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: termsLines.asMap().entries.map((e) => pw.Padding(
              padding: pw.EdgeInsets.only(bottom: e.key < termsLines.length - 1 ? 2 : 0),
              child: lbl(e.value, sz: 7.5),
            )).toList(),
          ),
  );

  // ── 7. HSN TAX BREAKDOWN TABLE ────────────────────────────────────────────
  final taxable  = subtotal;
  final hsnCode  = items.isNotEmpty ? ((isJw ? items[0]['sacCode'] : items[0]['hsn']) as String? ?? '') : '';

  final hsnTable = pw.Table(
    border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
    columnWidths: const {
      0: pw.FlexColumnWidth(2),  // HSN Code
      1: pw.FlexColumnWidth(2),  // Taxable Value
      2: pw.FlexColumnWidth(1),  // CT Rate
      3: pw.FlexColumnWidth(1.5),// CT Amount
      4: pw.FlexColumnWidth(1),  // ST Rate
      5: pw.FlexColumnWidth(1.5),// ST Amount
      6: pw.FlexColumnWidth(1.5),// Total Tax
    },
    children: [
      // Merged header: Central Tax | State Tax
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          pad(lbl('HSN Code', bold: true)),
          pad(lbl('Taxable Value', bold: true)),
          pw.Padding(
            padding: const pw.EdgeInsets.all(3),
            child: pw.Column(children: [
              lbl('Central Tax', bold: true),
              pw.SizedBox(height: 2),
              pw.Row(children: [
                pw.Expanded(child: lbl('Rate', bold: true)),
                pw.Expanded(child: lbl('Amount', bold: true)),
              ]),
            ]),
          ),
          pw.SizedBox(),
          pw.Padding(
            padding: const pw.EdgeInsets.all(3),
            child: pw.Column(children: [
              lbl('State Tax', bold: true),
              pw.SizedBox(height: 2),
              pw.Row(children: [
                pw.Expanded(child: lbl('Rate', bold: true)),
                pw.Expanded(child: lbl('Amount', bold: true)),
              ]),
            ]),
          ),
          pw.SizedBox(),
          pad(lbl('Total Tax\nAmount', bold: true)),
        ],
      ),
      // Data row
      if (!isPending) pw.TableRow(children: [
        pad(lbl(hsnCode)),
        pad(lbl(_rs(taxable), bold: true), h: 4, v: 3),
        pad(lbl('${_rateStr(cgstRate)}%')),
        pad(lbl(_rs(cgstAmt))),
        pad(lbl('${_rateStr(sgstRate)}%')),
        pad(lbl(_rs(sgstAmt))),
        pad(lbl(_rs(cgstAmt + sgstAmt), bold: true)),
      ]),
      // TOTAL row
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.grey100),
        children: [
          pad(lbl('TOTAL', bold: true)),
          pad(lbl(_rs(taxable), bold: true)),
          pw.SizedBox(),
          pad(lbl(!isPending ? _rs(cgstAmt) : '—', bold: true)),
          pw.SizedBox(),
          pad(lbl(!isPending ? _rs(sgstAmt) : '—', bold: true)),
          pad(lbl(!isPending ? _rs(cgstAmt + sgstAmt) : '—', bold: true)),
        ],
      ),
    ],
  );

  // ── 8. SIGNATURE ROW ──────────────────────────────────────────────────────
  final sigRow = pw.Container(
    decoration: _allBorder,
    child: pw.Row(children: [
      pw.Expanded(
        child: pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 16),
          child: lbl("Receiver's Signature"),
        ),
      ),
      pw.Container(width: 0.5, color: PdfColors.black, height: 40),
      pw.Expanded(
        child: pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            lbl('For ${companyName}', bold: true),
            pw.SizedBox(height: 16),
            lbl('Authorised Signatory'),
          ]),
        ),
      ),
    ]),
  );

  // ── Assemble ───────────────────────────────────────────────────────────────
  final doc = pw.Document(theme: pw.ThemeData.withFont(base: font, bold: fontBold));
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(20, 20, 20, 20),
    build: (_) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        header,
        pw.SizedBox(height: 4),
        partyMetaRow,
        itemsTable,
        bottomRow,
        wordsRow,
        termsRow,
        pw.SizedBox(height: 4),
        hsnTable,
        pw.SizedBox(height: 4),
        sigRow,
      ],
    ),
  ));

  return doc;
}

// ── Public: fetch tenant profile ───────────────────────────────────────────────

Future<Map<String, dynamic>> fetchTenantProfile(ApiClient api) async {
  try {
    final res = await api.get('/api/tenant/profile');
    return Map<String, dynamic>.from(res.data as Map);
  } catch (_) {
    return {};
  }
}

// ── Public: download as PDF file ───────────────────────────────────────────────

Future<void> downloadInvoicePdf(Map<String, dynamic> inv, ApiClient api) async {
  final profile   = await fetchTenantProfile(api);
  final doc       = await buildInvoicePdf(inv, profile);
  final bytes     = await doc.save();
  final invoiceNo = (inv['invoiceNo'] as String? ?? 'invoice').replaceAll('/', '_');
  await Printing.sharePdf(bytes: bytes, filename: '$invoiceNo.pdf');
}

// ── Extension ──────────────────────────────────────────────────────────────────
extension _Let<T> on T {
  R let<R>(R Function(T) fn) => fn(this);
}
