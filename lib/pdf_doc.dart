import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'models.dart';

class PdfTheme {
  final int accent;
  PdfTheme({this.accent = 0xFF0F7A3D});
}

PdfColor _lighten(PdfColor c, double amount) {
  return PdfColor(
      (c.red + (1.0 - c.red) * amount),
      (c.green + (1.0 - c.green) * amount),
      (c.blue + (1.0 - c.blue) * amount));
}

PdfTheme _theme(Business b) {
  if (b.templateJson == null) return PdfTheme();
  try {
    final j = jsonDecode(b.templateJson!) as Map<String, dynamic>;
    return PdfTheme(
        accent: (j['accent'] as num?)?.toInt() ?? 0xFF0F7A3D);
  } catch (_) {
    return PdfTheme();
  }
}

Future<Uint8List> documentPdfBytes({
  required Business business,
  required Customer? customer,
  required Document doc,
  required List<DocumentItem> items,
  Uint8List? signaturePng,
  String? signerName,
  String? docHash,
  bool isPro = false,
}) async {
  final theme = _theme(business);
  final logo = business.logoPath != null && File(business.logoPath!).existsSync()
      ? await File(business.logoPath!).readAsBytes()
      : null;

  final isReceipt = doc.docType == DocType.receipt;
  final isLetter = doc.docType == DocType.letter;
  final isQuotation = doc.docType == DocType.quotation;
  final pageFormat = isReceipt
      ? PdfPageFormat(80 * PdfPageFormat.mm, 210 * PdfPageFormat.mm,
          marginAll: 6 * PdfPageFormat.mm)
      : PdfPageFormat.a4.copyWith(
          marginTop: 36, marginBottom: 40, marginLeft: 36, marginRight: 36);

  final df = DateFormat('dd MMM yyyy');
  final accent = PdfColor.fromInt(theme.accent);
  final isMinimalLayout = isReceipt;

  final headingFontSize = isMinimalLayout ? 11.0 : 20.0;
  final baseFontSize = isMinimalLayout ? 8.0 : 10.0;
  final smallFontSize = isMinimalLayout ? 6.5 : 8.0;
  final tinyFontSize = isMinimalLayout ? 5.0 : 6.5;

  final bankInfo = [
    if ((business.bankName != null && business.bankName!.isNotEmpty) ||
        (business.mobileMoneyNumber != null && business.mobileMoneyNumber!.isNotEmpty))
      'Payment details',
    if (business.bankName != null &&
        business.bankName!.isNotEmpty &&
        business.bankAccountName != null)
      '${business.bankAccountName!}${business.bankAccountNo != null && business.bankAccountNo!.isNotEmpty ? ' · ${business.bankAccountNo}' : ''}',
    if (business.bankName != null && business.bankName!.isNotEmpty) business.bankName!,
    if (business.mobileMoneyNumber != null &&
        business.mobileMoneyNumber!.isNotEmpty)
      '${business.mobileMoneyProvider ?? 'Merchant / MoMo'}: ${business.mobileMoneyNumber!}'
      '${business.merchantCode != null && business.merchantCode!.isNotEmpty ? ' (Merchant code: ${business.merchantCode})' : ''}',
  ].whereType<String>().toList();

  final widgets = <pw.Widget>[
    // Header
    pw.Container(
      padding: pw.EdgeInsets.all(isMinimalLayout ? 6 : 12),
      decoration: isMinimalLayout
          ? null
          : pw.BoxDecoration(
              color: accent, borderRadius: pw.BorderRadius.circular(4)),
      child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              if (logo != null)
                pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 6),
                    height: isMinimalLayout ? 24 : 48,
                    child: pw.Image(pw.MemoryImage(logo))),
              if (logo == null)
                pw.Text(business.name,
                    style: pw.TextStyle(
                        fontSize: headingFontSize, fontWeight: pw.FontWeight.bold,
                        color: isMinimalLayout ? PdfColors.black : PdfColors.white)),
              if (business.tin != null && business.tin!.isNotEmpty)
                pw.Text('TIN: ${business.tin}',
                    style: pw.TextStyle(fontSize: smallFontSize, color: isMinimalLayout ? PdfColors.black : PdfColors.white)),
              if (business.address != null && business.address!.isNotEmpty)
                pw.Text(business.address!,
                    style: pw.TextStyle(fontSize: smallFontSize, color: isMinimalLayout ? PdfColors.black : PdfColors.white)),
              if (business.phone != null && business.phone!.isNotEmpty)
                pw.Text('Tel: ${business.phone}',
                    style: pw.TextStyle(fontSize: smallFontSize, color: isMinimalLayout ? PdfColors.black : PdfColors.white)),
              if (business.email != null && business.email!.isNotEmpty)
                pw.Text(business.email!,
                    style: pw.TextStyle(fontSize: smallFontSize, color: isMinimalLayout ? PdfColors.black : PdfColors.white)),
            ])),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text(docTypeLabel(doc.docType).toUpperCase(),
                  style: pw.TextStyle(
                      fontSize: isMinimalLayout ? 11 : (isQuotation ? 16 : 18),
                      fontWeight: pw.FontWeight.bold,
                      color: isMinimalLayout ? PdfColors.black : PdfColors.white)),
              pw.SizedBox(height: 3),
              pw.Text(doc.docNumber,
                  style: pw.TextStyle(fontSize: baseFontSize, color: isMinimalLayout ? PdfColors.black : PdfColors.white)),
              pw.Text(df.format(DateTime.fromMillisecondsSinceEpoch(doc.issueDate)),
                  style: pw.TextStyle(fontSize: smallFontSize, color: isMinimalLayout ? PdfColors.black : PdfColors.white)),
              if (doc.dueDate != null)
                pw.Text('Due: ${df.format(DateTime.fromMillisecondsSinceEpoch(doc.dueDate!))}',
                    style: pw.TextStyle(fontSize: smallFontSize, color: isMinimalLayout ? PdfColors.black : PdfColors.white)),
            ]),
          ]),
    ),
    pw.SizedBox(height: isMinimalLayout ? 6 : 14),
    // Bill To
    if (!isLetter && customer != null) ...[
      pw.Container(
        width: double.infinity,
        padding: pw.EdgeInsets.all(isMinimalLayout ? 4 : 10),
        decoration: isMinimalLayout
            ? null
            : pw.BoxDecoration(
                color: _lighten(accent, 0.92),
                border: pw.Border.all(color: accent, width: 0.5),
                borderRadius: pw.BorderRadius.circular(3)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('Bill to',
              style: pw.TextStyle(
                  fontSize: tinyFontSize, color: accent, fontWeight: pw.FontWeight.bold)),
          pw.Text(customer.name,
              style: pw.TextStyle(fontSize: baseFontSize + 1, fontWeight: pw.FontWeight.bold)),
          if ((customer.address ?? '').isNotEmpty)
            pw.Text(customer.address!, style: pw.TextStyle(fontSize: smallFontSize)),
          if (customer.tin != null && customer.tin!.isNotEmpty)
            pw.Text('TIN: ${customer.tin}', style: pw.TextStyle(fontSize: smallFontSize)),
        ]),
      ),
      pw.SizedBox(height: isMinimalLayout ? 6 : 12),
    ],
  ];

  if (isLetter) {
    widgets.addAll([
      pw.Expanded(
          child: pw.Container(
              width: double.infinity,
              padding: pw.EdgeInsets.all(isMinimalLayout ? 4 : 12),
              child: pw.Text(doc.content ?? '', style: pw.TextStyle(fontSize: baseFontSize + 1, height: 1.5)))),
    ]);
  } else {
    // Items table
    widgets.addAll([
      pw.Table(
        border: pw.TableBorder.all(
            width: isMinimalLayout ? 0 : 0.4, color: isMinimalLayout ? PdfColors.white : PdfColors.grey300),
        columnWidths: {
          0: const pw.FlexColumnWidth(4),
          1: const pw.FlexColumnWidth(1.2),
          2: const pw.FlexColumnWidth(2),
          3: const pw.FlexColumnWidth(2.2),
        },
        children: [
          pw.TableRow(
              decoration: pw.BoxDecoration(color: accent),
              children: ['Item', 'Qty', isMinimalLayout ? 'Amount' : 'Unit', 'Total']
                  .map((h) => pw.Padding(
                      padding: pw.EdgeInsets.symmetric(horizontal: isMinimalLayout ? 2 : 6, vertical: 4),
                      child: pw.Align(
                          alignment: h == 'Item' ? pw.Alignment.centerLeft : pw.Alignment.centerRight,
                          child: pw.Text(h,
                              style: pw.TextStyle(
                                  fontSize: smallFontSize, fontWeight: pw.FontWeight.bold, color: PdfColors.white)))))
                  .toList()),
          ...items.asMap().entries.map((e) => pw.TableRow(
              decoration: pw.BoxDecoration(
                  color: e.key % 2 == 0 ? PdfColors.white : _lighten(accent, 0.96)),
              children: [
                pw.Padding(
                    padding: pw.EdgeInsets.symmetric(horizontal: isMinimalLayout ? 2 : 6, vertical: 3),
                    child: pw.Text(e.value.description, style: pw.TextStyle(fontSize: smallFontSize))),
                pw.Padding(
                    padding: pw.EdgeInsets.symmetric(horizontal: isMinimalLayout ? 2 : 6, vertical: 3),
                    child: pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: pw.Text(_fmtQty(e.value.quantity),
                            style: pw.TextStyle(fontSize: smallFontSize)))),
                if (!isMinimalLayout)
                  pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      child: pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child:
                              pw.Text(_fmtMoney(e.value.unitPrice),
                                  style: pw.TextStyle(fontSize: smallFontSize)))),
                pw.Padding(
                    padding: pw.EdgeInsets.symmetric(horizontal: isMinimalLayout ? 2 : 6, vertical: 3),
                    child: pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: pw.Text(_fmtMoney(e.value.lineTotal),
                            style: pw.TextStyle(fontSize: smallFontSize))))
              ])),
        ],
      ),
      pw.SizedBox(height: isMinimalLayout ? 4 : 10),
      // Totals block
      pw.Container(
        color: _lighten(accent, 0.93),
        padding: pw.EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Padding(padding: pw.EdgeInsets.symmetric(vertical: 4, horizontal: isMinimalLayout ? 2 : 8),
                    child: pw.Text('Subtotal: ${_fmtMoney(doc.subtotal)}',
                        style: pw.TextStyle(fontSize: baseFontSize))),
                if (doc.taxTotal > 0)
                  pw.Padding(padding: pw.EdgeInsets.symmetric(vertical: 4, horizontal: isMinimalLayout ? 2 : 8),
                      child: pw.Text('Tax: ${_fmtMoney(doc.taxTotal)}',
                          style: pw.TextStyle(fontSize: baseFontSize))),
                pw.Container(
                    padding: pw.EdgeInsets.all(isMinimalLayout ? 3 : 6),
                    color: accent,
                    child: pw.Text(
                        'TOTAL: ${business.currency} ${_fmtMoney(doc.total)}',
                        style: pw.TextStyle(
                            fontSize: isMinimalLayout ? 9 : 13, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
              ]),
            ]),
      ),
    ]);
  }

  // Payment details & signature
  widgets.addAll([
    pw.SizedBox(height: isMinimalLayout ? 4 : 12),
  ]);

  if (bankInfo.isNotEmpty && !isLetter) {
    widgets.add(pw.Container(
        width: double.infinity,
        padding: pw.EdgeInsets.all(isMinimalLayout ? 3 : 8),
        decoration: pw.BoxDecoration(
            border: pw.Border(
                left: pw.BorderSide(color: accent, width: 3))),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('Payment details',
              style: pw.TextStyle(
                  fontSize: tinyFontSize, color: accent, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          for (final line in bankInfo.skip(1))
            pw.Text(line, style: pw.TextStyle(fontSize: smallFontSize)),
        ])));
    widgets.add(pw.SizedBox(height: isMinimalLayout ? 3 : 8));
  }

  if (signaturePng != null) {
    widgets.add(pw.Row(children: [
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Image(pw.MemoryImage(signaturePng), height: isMinimalLayout ? 28 : 52),
        pw.Container(
            width: isMinimalLayout ? 80 : 170,
            padding: pw.EdgeInsets.only(top: 3),
            decoration: pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: PdfColors.grey700, width: 0.8))),
            child: pw.Text(
                signerName == null || signerName.isEmpty
                    ? 'Authorized Signature'
                    : signerName,
                style: pw.TextStyle(fontSize: smallFontSize))),
      ]),
      if (!isMinimalLayout && doc.hash != null && doc.hash!.isNotEmpty)
        pw.SizedBox(width: 16),
      if (!isMinimalLayout && doc.hash != null && doc.hash!.isNotEmpty)
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('Document integrity', style: pw.TextStyle(fontSize: tinyFontSize, color: PdfColors.grey600)),
          pw.Text('SHA-256: ${doc.hash!.substring(0, 24)}...', style: pw.TextStyle(fontSize: tinyFontSize, color: PdfColors.grey600)),
          pw.Text('Signed: ${df.format(DateTime.fromMillisecondsSinceEpoch(doc.createdAt))}', style: pw.TextStyle(fontSize: tinyFontSize, color: PdfColors.grey600)),
        ]),
    ]));
  }

  if (!isPro) {
    widgets.addAll([
      pw.SizedBox(height: 6),
      pw.Center(
          child: pw.Text(
              'Generated with BizDocs - upgrade to Pro to remove this.',
              style: pw.TextStyle(fontSize: tinyFontSize, color: PdfColors.grey500))),
    ]);
  }

  final pdf = pw.Document();
  pdf.addPage(pw.Page(pageFormat: pageFormat, build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start, children: widgets)));
  return pdf.save();
}

Future<String> documentPdfToCache({
  required Business business,
  required Customer? customer,
  required Document doc,
  required List<DocumentItem> items,
  Uint8List? signaturePng,
  String? signerName,
  String? docHash,
  bool isPro = false,
}) async {
  final bytes = await documentPdfBytes(
      business: business,
      customer: customer,
      doc: doc,
      items: items,
      signaturePng: signaturePng,
      signerName: signerName,
      docHash: docHash,
      isPro: isPro);
  final dir = await getApplicationDocumentsDirectory();
  final path = '${dir.path}/${doc.docNumber.replaceAll('/', '_')}.pdf';
  await File(path).writeAsBytes(bytes);
  return path;
}

String _fmtQty(double q) =>
    q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(1);

String _fmtMoney(int v) => NumberFormat('#,##0').format(v);
