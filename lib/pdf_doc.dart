import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'models.dart';

// Customer-facing labels translated for Luganda (lg) and Kiswahili (sw).
const Map<String, Map<String, String>> _pdfStrings = {
  'lg': {
    'Invoice': 'Invoice',
    'Receipt': 'Risiti',
    'Quotation': 'Okutebenkera emiwendo',
    'Estimate': 'Okutebenkera',
    'Proforma Invoice': 'Proforma Invoice',
    'Delivery Note': 'Lupapula olutwala ebintu',
    'E-Receipt (URA)': 'E-Risiti (URA)',
    'Payment Reminder': 'Okujjukiza okusasula',
    'Letter': 'Ebbaluwa',
    'TOTAL': 'OMUGATIKKO',
    'Subtotal': 'Omugattiko ogw\'oluse',
    'Tax': 'Omusolo',
    'Discount': 'Okukendeezwa',
    'Amount in words': 'Mu bigambo',
    'Payment details': 'Enkola y\'okusasula',
  },
  'sw': {
    'Invoice': 'Ankara',
    'Receipt': 'Risiti',
    'Quotation': 'Makadirio ya bei',
    'Estimate': 'Makadirio',
    'Proforma Invoice': 'Ankara ya Proforma',
    'Delivery Note': 'Noti ya Uwasilishaji',
    'E-Receipt (URA)': 'Risiti ya Kielektroniki (URA)',
    'Payment Reminder': 'Kikumbusho cha Malipo',
    'Letter': 'Barua',
    'TOTAL': 'JUMLA',
    'Subtotal': 'Jumla ndogo',
    'Tax': 'Kodi',
    'Discount': 'Punguzo',
    'Amount in words': 'Kwa maneno',
    'Payment details': 'Maelezo ya malipo',
  },
};

String _tr(String label, String lang) => _pdfStrings[lang]?[label] ?? label;

enum PdfLayout { classic, modern, elegant, minimal }

class PdfTheme {
  final int accent;
  final PdfLayout layout;
  PdfTheme({this.accent = 0xFF0F7A3D, this.layout = PdfLayout.classic});
}

const Map<PdfLayout, String> pdfLayoutNames = {
  PdfLayout.classic: 'Classic',
  PdfLayout.modern: 'Modern+',
  PdfLayout.elegant: 'Elegant',
  PdfLayout.minimal: 'Minimal',
};

const Map<PdfLayout, String> pdfLayoutDescriptions = {
  PdfLayout.classic: 'The standard professional layout. Free forever.',
  PdfLayout.modern: 'Bold accent header band, big total panel.',
  PdfLayout.elegant: 'Centered letterhead, fine rules, premium feel.',
  PdfLayout.minimal: 'Maximum whitespace, monochrome with one accent.',
};

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
    final layoutName = j['layout'] as String?;
    return PdfTheme(
        accent: (j['accent'] as num?)?.toInt() ?? 0xFF0F7A3D,
        layout: layoutName == null
            ? PdfLayout.classic
            : PdfLayout.values.firstWhere((e) => e.name == layoutName,
                orElse: () => PdfLayout.classic));
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

  final narrow = (doc.docType == DocType.receipt ||
      doc.docType == DocType.uraReceipt);
  final isLetter = doc.docType == DocType.letter;
  final isReminder = doc.docType == DocType.reminder;
  final isQuotation = doc.docType == DocType.quotation ||
      doc.docType == DocType.estimate ||
      doc.docType == DocType.proforma;
  final pageFormat = narrow
      ? PdfPageFormat(80 * PdfPageFormat.mm, 210 * PdfPageFormat.mm,
          marginAll: 6 * PdfPageFormat.mm)
      : PdfPageFormat.a4.copyWith(
          marginTop: 36, marginBottom: 40, marginLeft: 36, marginRight: 36);

  final df = DateFormat('dd MMM yyyy');
  final accent = PdfColor.fromInt(theme.accent);
  final isMinimalLayout = narrow;

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

  pw.Widget businessBlock({bool lightText = false}) {
    final color = lightText ? PdfColors.white : PdfColors.black;
    final sub = lightText ? PdfColors.white : PdfColors.grey700;
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      if (logo != null)
        pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 6),
            height: isMinimalLayout ? 24 : 48,
            child: pw.Image(pw.MemoryImage(logo))),
      if (logo == null)
        pw.Text(business.name,
            style: pw.TextStyle(
                fontSize: headingFontSize, fontWeight: pw.FontWeight.bold,
                color: color)),
      if (business.tin != null && business.tin!.isNotEmpty)
        pw.Text('TIN: ${business.tin}',
            style: pw.TextStyle(fontSize: smallFontSize, color: sub)),
      if (business.address != null && business.address!.isNotEmpty)
        pw.Text(business.address!,
            style: pw.TextStyle(fontSize: smallFontSize, color: sub)),
      if (business.phone != null && business.phone!.isNotEmpty)
        pw.Text('Tel: ${business.phone}',
            style: pw.TextStyle(fontSize: smallFontSize, color: sub)),
      if (business.email != null && business.email!.isNotEmpty)
        pw.Text(business.email!,
            style: pw.TextStyle(fontSize: smallFontSize, color: sub)),
    ]);
  }

  pw.Widget docMetaBlock({bool lightText = false}) {
    final color = lightText ? PdfColors.white : PdfColors.black;
    final sub = lightText ? PdfColors.white : PdfColors.grey700;
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
      pw.Text(_tr(docTypeLabel(doc.docType), business.language).toUpperCase(),
          style: pw.TextStyle(
              fontSize: isMinimalLayout ? 11 : (isQuotation ? 16 : 18),
              fontWeight: pw.FontWeight.bold,
              color: color)),
      pw.SizedBox(height: 3),
      pw.Text(doc.docNumber,
          style: pw.TextStyle(fontSize: baseFontSize, color: color)),
      pw.Text(df.format(DateTime.fromMillisecondsSinceEpoch(doc.issueDate)),
          style: pw.TextStyle(fontSize: smallFontSize, color: sub)),
      if (doc.dueDate != null)
        pw.Text('Due: ${df.format(DateTime.fromMillisecondsSinceEpoch(doc.dueDate!))}',
            style: pw.TextStyle(fontSize: smallFontSize, color: sub)),
    ]);
  }

  pw.Widget header;
  switch (theme.layout) {
    case PdfLayout.modern:
      header = pw.Container(
        decoration: pw.BoxDecoration(
            color: accent,
            borderRadius: pw.BorderRadius.only(
                bottomLeft: const pw.Radius.circular(18),
                bottomRight: const pw.Radius.circular(18))),
        padding: pw.EdgeInsets.symmetric(
            horizontal: isMinimalLayout ? 8 : 16,
            vertical: isMinimalLayout ? 8 : 14),
        child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(child: businessBlock(lightText: true)),
              docMetaBlock(lightText: true),
            ]),
      );
      break;
    case PdfLayout.elegant:
      header = pw.Column(children: [
        pw.Center(child: businessBlock()),
        pw.SizedBox(height: 6),
        pw.Container(height: 2, color: accent, width: double.infinity),
        pw.SizedBox(height: 2),
        pw.Container(height: 0.5, color: accent, width: double.infinity),
        pw.SizedBox(height: 8),
        pw.Center(child: docMetaBlock()),
      ]);
      break;
    case PdfLayout.minimal:
      header = pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(child: businessBlock()),
            docMetaBlock(),
          ]);
      break;
    case PdfLayout.classic:
      header = pw.Container(
        padding: pw.EdgeInsets.all(isMinimalLayout ? 6 : 12),
        decoration: isMinimalLayout
            ? null
            : pw.BoxDecoration(
                color: accent, borderRadius: pw.BorderRadius.circular(4)),
        child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(child: businessBlock(lightText: !isMinimalLayout)),
              docMetaBlock(lightText: !isMinimalLayout),
            ]),
      );
  }

  final widgets = <pw.Widget>[
    header,
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

  if (isLetter || isReminder) {
    widgets.addAll([
      pw.Expanded(
          child: pw.Container(
              width: double.infinity,
              padding: pw.EdgeInsets.all(isMinimalLayout ? 4 : 12),
              child: pw.Text(doc.content ?? '', style: pw.TextStyle(fontSize: baseFontSize + 1, height: 1.5)))),
    ]);
    if (doc.total > 0 && isReminder) {
      widgets.addAll([
        pw.SizedBox(height: 8),
        pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: _lighten(accent, 0.9),
              border: pw.Border.all(color: accent, width: 0.5),
              borderRadius: pw.BorderRadius.circular(3)),
            child: pw.Text(
                'Amount outstanding: ${doc.currency} ${_fmtMoney(doc.total - (doc.chargeTotal - doc.discountTotal))}',
                style: pw.TextStyle(
                    fontSize: baseFontSize, fontWeight: pw.FontWeight.bold))),
      ]);
    }
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
                    child: pw.Text('${_tr('Subtotal', business.language)}: ${_fmtMoney(doc.subtotal)}',
                        style: pw.TextStyle(fontSize: baseFontSize))),
                if (doc.taxTotal > 0)
                  pw.Padding(padding: pw.EdgeInsets.symmetric(vertical: 4, horizontal: isMinimalLayout ? 2 : 8),
                      child: pw.Text('${_tr('Tax', business.language)}: ${_fmtMoney(doc.taxTotal)}',
                          style: pw.TextStyle(fontSize: baseFontSize))),
                if (doc.discountTotal > 0)
                  pw.Padding(padding: pw.EdgeInsets.symmetric(vertical: 4, horizontal: isMinimalLayout ? 2 : 8),
                      child: pw.Text('${_tr('Discount', business.language)}: -${_fmtMoney(doc.discountTotal)}',
                          style: pw.TextStyle(fontSize: baseFontSize))),
                if (doc.chargeTotal > 0)
                  pw.Padding(padding: pw.EdgeInsets.symmetric(vertical: 4, horizontal: isMinimalLayout ? 2 : 8),
                      child: pw.Text('Charges: +${_fmtMoney(doc.chargeTotal)}',
                          style: pw.TextStyle(fontSize: baseFontSize))),
                pw.Container(
                    padding: pw.EdgeInsets.all(isMinimalLayout ? 3 : 6),
                    color: accent,
                    child: pw.Text(
                        '${_tr('TOTAL', business.language)}: ${doc.currency} ${_fmtMoney(doc.total)}',
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
          pw.Text(_tr('Payment details', business.language),
              style: pw.TextStyle(
                  fontSize: tinyFontSize, color: accent, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          for (final line in bankInfo.skip(1))
            pw.Text(line, style: pw.TextStyle(fontSize: smallFontSize)),
        ])));
    widgets.add(pw.SizedBox(height: isMinimalLayout ? 3 : 8));
  }

  if (!isLetter && doc.total > 0) {
    widgets.addAll([
      pw.SizedBox(height: isMinimalLayout ? 3 : 8),
      pw.Container(
          width: double.infinity,
          padding: pw.EdgeInsets.all(isMinimalLayout ? 3 : 8),
          decoration: pw.BoxDecoration(
              color: _lighten(accent, 0.92),
              borderRadius: pw.BorderRadius.circular(3)),
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(_tr('Amount in words', business.language),
                    style: pw.TextStyle(fontSize: tinyFontSize, color: accent, fontWeight: pw.FontWeight.bold)),
                pw.Text('${wordsToEnglish(doc.total)} ${doc.currency == 'UGX' ? 'Shillings' : doc.currency} only',
                    style: pw.TextStyle(fontSize: smallFontSize)),
              ])),
      pw.SizedBox(height: isMinimalLayout ? 3 : 8),
    ]);
  }

  final terms = (doc.terms != null && doc.terms!.isNotEmpty)
      ? doc.terms
      : business.termsTemplate;
  if (!isLetter && terms != null && terms.isNotEmpty) {
    widgets.addAll([
      pw.Container(
          width: double.infinity,
          padding: pw.EdgeInsets.all(isMinimalLayout ? 3 : 8),
          decoration: pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Terms & conditions',
                style: pw.TextStyle(fontSize: tinyFontSize, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text(terms, style: pw.TextStyle(fontSize: smallFontSize, color: PdfColors.grey700)),
          ])),
      pw.SizedBox(height: isMinimalLayout ? 3 : 8),
    ]);
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

  // EFRIS fiscalization block: QR + FDN + verification code.
  if (doc.fdn != null && doc.fdn!.isNotEmpty) {
    final qrData = doc.verificationCode != null && doc.verificationCode!.isNotEmpty
        ? 'FDN:${doc.fdn}|VC:${doc.verificationCode}'
        : 'FDN:${doc.fdn}';
    widgets.addAll([
      pw.SizedBox(height: isMinimalLayout ? 4 : 10),
      pw.Container(
          width: double.infinity,
          padding: pw.EdgeInsets.all(isMinimalLayout ? 4 : 8),
          decoration: pw.BoxDecoration(
              border: pw.Border.all(color: accent, width: 1),
              borderRadius: pw.BorderRadius.circular(3)),
          child: pw.Row(children: [
            pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: qrData,
                width: isMinimalLayout ? 44 : 64,
                height: isMinimalLayout ? 44 : 64),
            pw.SizedBox(width: 8),
            pw.Expanded(
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                  pw.Text('EFRIS fiscal document',
                      style: pw.TextStyle(
                          fontSize: tinyFontSize,
                          color: accent,
                          fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 2),
                  pw.Text('FDN: ${doc.fdn}',
                      style: pw.TextStyle(fontSize: smallFontSize)),
                  if (doc.verificationCode != null &&
                      doc.verificationCode!.isNotEmpty)
                    pw.Text('Verification code: ${doc.verificationCode}',
                        style: pw.TextStyle(fontSize: smallFontSize)),
                  pw.Text('Verify with the URA EFRIS app',
                      style: pw.TextStyle(
                          fontSize: tinyFontSize, color: PdfColors.grey600)),
                ])),
          ])),
    ]);
  }

  if (!isPro) {
    widgets.addAll([
      pw.SizedBox(height: 6),
      pw.Center(
          child: pw.Text(
              'Generated with BizDocs - upgrade to Pro to remove this.',
              style: pw.TextStyle(fontSize: tinyFontSize, color: PdfColors.grey500))),
    ]);
  } else {
    widgets.addAll([
      pw.SizedBox(height: 4),
      pw.Center(
          child: pw.Text('Made in Uganda · BizDocs by JD Hub',
              style: pw.TextStyle(
                  fontSize: tinyFontSize, color: PdfColors.grey400))),
    ]);
  }

  final pdf = pw.Document();
  pdf.addPage(pw.Page(pageFormat: pageFormat, build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start, children: widgets)));

  // Attachment photos print as full pages after the document.
  if (doc.attachmentsJson != null && doc.attachmentsJson!.isNotEmpty) {
    try {
      final paths = List<dynamic>.from(jsonDecode(doc.attachmentsJson!));
      for (final p in paths) {
        final f = File(p.toString());
        if (!f.existsSync()) continue;
        final img = pw.MemoryImage(await f.readAsBytes());
        pdf.addPage(pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (ctx) => pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain))));
      }
    } catch (_) {}
  }
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
