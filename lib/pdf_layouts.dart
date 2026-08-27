import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'models.dart';

final _money = NumberFormat('#,###');
final _date = DateFormat('dd MMM yyyy');

enum PdfLayout {
  classic,        // 1
  modern,         // 2
  elegant,        // 3
  minimal,        // 4
  sideBand,       // 5
  gradient,       // 6
  boldType,       // 7
  scandinavian,   // 8
  twoColumn,      // 9
  boldStationary, // 10
  bigPrice,       // 11
  geometric,      // 12
  footerBanner,   // 13
  navy,           // 14
  script,         // 15
  modernBlue,     // 16
  simpleGreen,    // 17
  framedGold,     // 18
  monochrome,     // 19
  twoToneSplit,   // 20
  accentBar,      // 21
  roundedCard,    // 22
}

const Map<PdfLayout, String> pdfLayoutNames = {
  PdfLayout.classic: 'Classic',
  PdfLayout.modern: 'Modern+',
  PdfLayout.elegant: 'Elegant',
  PdfLayout.minimal: 'Minimal',
  PdfLayout.sideBand: 'Side Band',
  PdfLayout.gradient: 'Gradient',
  PdfLayout.boldType: 'Bold Type',
  PdfLayout.scandinavian: 'Scandinavian',
  PdfLayout.twoColumn: 'Two Column',
  PdfLayout.boldStationary: 'Bold Stationary',
  PdfLayout.bigPrice: 'Big Price',
  PdfLayout.geometric: 'Geometric',
  PdfLayout.footerBanner: 'Footer Banner',
  PdfLayout.navy: 'Navy',
  PdfLayout.script: 'Script',
  PdfLayout.modernBlue: 'Modern Blue',
  PdfLayout.simpleGreen: 'Simple Green',
  PdfLayout.framedGold: 'Framed Gold',
  PdfLayout.monochrome: 'Monochrome',
  PdfLayout.twoToneSplit: 'Two-Tone Split',
  PdfLayout.accentBar: 'Accent Bar',
  PdfLayout.roundedCard: 'Rounded Card',
};

const Map<PdfLayout, bool> pdfLayoutIsPro = {
  PdfLayout.classic: false,
  PdfLayout.modern: true,
  PdfLayout.elegant: true,
  PdfLayout.minimal: true,
  PdfLayout.sideBand: true,
  PdfLayout.gradient: true,
  PdfLayout.boldType: true,
  PdfLayout.scandinavian: true,
  PdfLayout.twoColumn: true,
  PdfLayout.boldStationary: true,
  PdfLayout.bigPrice: true,
  PdfLayout.geometric: true,
  PdfLayout.footerBanner: true,
  PdfLayout.navy: true,
  PdfLayout.script: true,
  PdfLayout.modernBlue: true,
  PdfLayout.simpleGreen: true,
  PdfLayout.framedGold: true,
  PdfLayout.monochrome: true,
  PdfLayout.twoToneSplit: true,
  PdfLayout.accentBar: true,
  PdfLayout.roundedCard: true,
};


const Map<PdfLayout, String> pdfLayoutDescriptions = {
  PdfLayout.classic: 'The standard professional layout. Free forever.',
  PdfLayout.modern: 'Bold accent band with rounded corners, agency-grade.',
  PdfLayout.elegant: 'Centered letterhead with fine double rules.',
  PdfLayout.minimal: 'Maximum whitespace, single accent line.',
  PdfLayout.sideBand: 'Brand-colour side rail down the left margin.',
  PdfLayout.gradient: 'Diagonal brand gradient header.',
  PdfLayout.boldType: 'Oversized typography, no background blocks.',
  PdfLayout.scandinavian: 'Sparse, airy, borderless table.',
  PdfLayout.twoColumn: 'Centered letterhead, stacked doc meta.',
  PdfLayout.boldStationary: 'Solid accent block for document meta.',
  PdfLayout.bigPrice: 'Total amount front and center in a pill.',
  PdfLayout.geometric: 'Triple-bar geometric accent strip.',
  PdfLayout.footerBanner: 'Clean header, strong bottom accent.',
  PdfLayout.navy: 'Deep navy header, white text, high contrast.',
  PdfLayout.script: 'Thin elegant rules, centered composition.',
  PdfLayout.modernBlue: 'Classic with brand-blue emphasis.',
  PdfLayout.simpleGreen: 'Classic with fresh green accents.',
  PdfLayout.framedGold: 'Double gold frame around the whole page.',
  PdfLayout.monochrome: 'Pure black-and-white, heavy rules.',
  PdfLayout.twoToneSplit: 'Coloured brand panel beside white meta.',
  PdfLayout.accentBar: 'Bold accent bar above the totals.',
  PdfLayout.roundedCard: 'Soft rounded card header panel.',
};

class PdfTheme {
  final int accent;
  final PdfLayout layout;
  PdfTheme({this.accent = 0xFF0F7A3D, this.layout = PdfLayout.classic});
}

PdfTheme themeFrom(Business b) {
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

PdfColor _lighten(PdfColor c, double a) => PdfColor(
    c.red + (1 - c.red) * a, c.green + (1 - c.green) * a, c.blue + (1 - c.blue) * a);

class _Ctx {
  final Business business;
  final Customer? customer;
  final Document doc;
  final List<DocumentItem> items;
  final Uint8List? logo;
  final Uint8List? signature;
  final String? signerName;
  final String? docHash;
  final bool isPro;
  final PdfTheme theme;
  final PdfColor accent;
  final bool narrow;

  _Ctx({
    required this.business,
    required this.customer,
    required this.doc,
    required this.items,
    required this.logo,
    required this.signature,
    required this.signerName,
    required this.docHash,
    required this.isPro,
    required this.theme,
    required this.accent,
    required this.narrow,
  });

  double get h1 => narrow ? 11.0 : 20.0;
  double get h2 => narrow ? 9.0 : 13.0;
  double get base => narrow ? 8.0 : 10.0;
  double get small => narrow ? 6.5 : 8.0;
  double get tiny => narrow ? 5.5 : 7.0;

  String get docLabel => docTypeLabel(doc.docType).toUpperCase();
  String get issued => _date.format(DateTime.fromMillisecondsSinceEpoch(doc.issueDate));
  String? get due =>
      doc.dueDate == null ? null : _date.format(DateTime.fromMillisecondsSinceEpoch(doc.dueDate!));

  bool get isLetter => doc.docType == DocType.letter || doc.docType == DocType.reminder;

  List<String> get bankLines => [
        if ((business.bankName ?? '').isNotEmpty) 'Bank: ${business.bankName}',
        if ((business.bankAccountName ?? '').isNotEmpty) 'Account name: ${business.bankAccountName}',
        if ((business.bankAccountNo ?? '').isNotEmpty) 'Account no: ${business.bankAccountNo}',
        if ((business.mobileMoneyNumber ?? '').isNotEmpty)
          '${business.mobileMoneyProvider ?? 'MoMo'}: ${business.mobileMoneyNumber}${(business.merchantCode ?? '').isNotEmpty ? ' (Merchant: ${business.merchantCode})' : ''}',
      ];

  String? get terms =>
      (doc.terms ?? '').isNotEmpty ? doc.terms : business.termsTemplate;

  bool get hasFdn => (doc.fdn ?? '').isNotEmpty;

  String get qrData => (doc.verificationCode ?? '').isNotEmpty
      ? 'FDN:${doc.fdn}|VC:${doc.verificationCode}'
      : 'FDN:${doc.fdn ?? doc.docNumber}|DOC:${doc.docNumber}|TIN:${business.tin ?? ''}|TOTAL:${doc.total}';

  // ---------- shared widgets ----------

  pw.Widget logoOrName({bool light = false, double size = 44}) {
    if (logo != null) {
      return pw.Image(pw.MemoryImage(logo!), height: narrow ? 24 : size);
    }
    return pw.Text(business.name,
        style: pw.TextStyle(
            fontSize: h1, fontWeight: pw.FontWeight.bold,
            color: light ? PdfColors.white : PdfColors.black));
  }

  pw.Widget businessDetails({bool light = false}) {
    final color = light ? PdfColors.white : PdfColors.grey700;
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      if ((business.tin ?? '').isNotEmpty)
        pw.Text('TIN: ${business.tin}', style: pw.TextStyle(fontSize: small, color: color)),
      if ((business.address ?? '').isNotEmpty)
        pw.Text(business.address!, style: pw.TextStyle(fontSize: small, color: color)),
      if ((business.phone ?? '').isNotEmpty)
        pw.Text('Tel: ${business.phone}', style: pw.TextStyle(fontSize: small, color: color)),
      if ((business.email ?? '').isNotEmpty)
        pw.Text(business.email!, style: pw.TextStyle(fontSize: small, color: color)),
    ]);
  }

  pw.Widget docMeta({bool light = false}) {
    final color = light ? PdfColors.white : PdfColors.black;
    final sub = light ? PdfColors.white : PdfColors.grey700;
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
      pw.Text(docLabel,
          style: pw.TextStyle(
              fontSize: narrow ? 11 : 18, fontWeight: pw.FontWeight.bold, color: color)),
      pw.SizedBox(height: 2),
      pw.Text(doc.docNumber, style: pw.TextStyle(fontSize: base, color: color)),
      pw.Text(issued, style: pw.TextStyle(fontSize: small, color: sub)),
      if (due != null) pw.Text('Due: $due', style: pw.TextStyle(fontSize: small, color: sub)),
    ]);
  }

  pw.Widget billTo() {
    if (customer == null || isLetter) return pw.SizedBox();
    return pw.Container(
      width: double.infinity,
      padding: pw.EdgeInsets.all(narrow ? 3 : 8),
      decoration: pw.BoxDecoration(
          color: _lighten(accent, 0.94), borderRadius: pw.BorderRadius.circular(3)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('BILL TO',
            style: pw.TextStyle(
                fontSize: tiny, color: accent, fontWeight: pw.FontWeight.bold)),
        pw.Text(customer!.name,
            style: pw.TextStyle(fontSize: base, fontWeight: pw.FontWeight.bold)),
        if ((customer!.phone ?? '').isNotEmpty)
          pw.Text(customer!.phone!, style: pw.TextStyle(fontSize: small)),
        if ((customer!.address ?? '').isNotEmpty)
          pw.Text(customer!.address!, style: pw.TextStyle(fontSize: small)),
      ]),
    );
  }

  pw.Widget itemsTable() {
    return pw.Table(
      border: pw.TableBorder.all(width: narrow ? 0 : 0.4, color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(4),
        1: const pw.FlexColumnWidth(1.2),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(2.2),
      },
      children: [
        pw.TableRow(
            decoration: pw.BoxDecoration(color: accent),
            children: ['Item', 'Qty', narrow ? 'Amount' : 'Unit', 'Total']
                .map((h) => pw.Padding(
                    padding: pw.EdgeInsets.symmetric(
                        horizontal: narrow ? 2 : 6, vertical: 4),
                    child: pw.Align(
                        alignment: h == 'Item'
                            ? pw.Alignment.centerLeft
                            : pw.Alignment.centerRight,
                        child: pw.Text(h,
                            style: pw.TextStyle(
                                fontSize: small,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white)))))
                .toList()),
        ...items.asMap().entries.map((e) => pw.TableRow(
            decoration: pw.BoxDecoration(
                color: e.key % 2 == 0 ? PdfColors.white : _lighten(accent, 0.96)),
            children: [
              pw.Padding(
                  padding: pw.EdgeInsets.symmetric(
                      horizontal: narrow ? 2 : 6, vertical: 3),
                  child: pw.Text(e.value.description,
                      style: pw.TextStyle(fontSize: small))),
              pw.Padding(
                  padding: pw.EdgeInsets.symmetric(
                      horizontal: narrow ? 2 : 6, vertical: 3),
                  child: pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(_fmtQty(e.value.quantity),
                          style: pw.TextStyle(fontSize: small)))),
              if (!narrow)
                pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    child: pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: pw.Text(_money.format(e.value.unitPrice),
                            style: pw.TextStyle(fontSize: small)))),
              pw.Padding(
                  padding: pw.EdgeInsets.symmetric(
                      horizontal: narrow ? 2 : 6, vertical: 3),
                  child: pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(_money.format(e.value.lineTotal),
                          style: pw.TextStyle(fontSize: small))))
            ])),
      ],
    );
  }

  pw.Widget totalsBlock({bool boxed = true}) {
    final rows = <pw.Widget>[
      _totalRow('Subtotal', doc.subtotal),
      if (doc.discountTotal > 0) _totalRow('Discount', -doc.discountTotal),
      if (doc.taxTotal > 0) _totalRow('Tax', doc.taxTotal),
      if (doc.chargeTotal > 0) _totalRow('Charges', doc.chargeTotal),
    ];
    final totalWidget = pw.Container(
        padding: pw.EdgeInsets.all(narrow ? 3 : 6),
        color: accent,
        child: pw.Text(
            'TOTAL: ${doc.currency} ${_money.format(doc.total)}',
            style: pw.TextStyle(
                fontSize: narrow ? 9 : 13,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white)));
    final inner = pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [...rows, totalWidget]);
    if (!boxed) return inner;
    return pw.Container(
        color: _lighten(accent, 0.93),
        padding: const pw.EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end, children: [inner]));
  }

  pw.Widget _totalRow(String label, int amount) => pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: 3, horizontal: narrow ? 2 : 8),
      child: pw.Text('$label: ${_money.format(amount)}',
          style: pw.TextStyle(fontSize: base)));

  pw.Widget amountWords() {
    if (doc.total <= 0 || isLetter) return pw.SizedBox();
    final cur = doc.currency == 'UGX' ? 'Shillings' : doc.currency;
    return pw.Container(
        width: double.infinity,
        padding: pw.EdgeInsets.all(narrow ? 3 : 8),
        decoration: pw.BoxDecoration(
            color: _lighten(accent, 0.92),
            borderRadius: pw.BorderRadius.circular(3)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('AMOUNT IN WORDS',
              style: pw.TextStyle(
                  fontSize: tiny, color: accent, fontWeight: pw.FontWeight.bold)),
          pw.Text('${wordsToEnglish(doc.total)} $cur only',
              style: pw.TextStyle(fontSize: small)),
        ]));
  }

  pw.Widget bankBlock() {
    if (bankLines.isEmpty || isLetter) return pw.SizedBox();
    return pw.Container(
        width: double.infinity,
        padding: pw.EdgeInsets.all(narrow ? 3 : 8),
        decoration: pw.BoxDecoration(
            border: pw.Border(left: pw.BorderSide(color: accent, width: 3))),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('PAYMENT DETAILS',
              style: pw.TextStyle(
                  fontSize: tiny, color: accent, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          for (final l in bankLines)
            pw.Text(l, style: pw.TextStyle(fontSize: small)),
        ]));
  }

  pw.Widget termsBlock() {
    final t = terms;
    if (t == null || t.isEmpty || isLetter) return pw.SizedBox();
    return pw.Container(
        width: double.infinity,
        padding: pw.EdgeInsets.all(narrow ? 3 : 8),
        decoration: pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('TERMS',
              style: pw.TextStyle(
                  fontSize: tiny, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text(t, style: pw.TextStyle(fontSize: small, color: PdfColors.grey700)),
        ]));
  }

  pw.Widget signatureBlock() {
    if (signature == null) return pw.SizedBox();
    return pw.Row(children: [
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Image(pw.MemoryImage(signature!), height: narrow ? 28 : 52),
        pw.Container(
            width: narrow ? 80 : 170,
            padding: const pw.EdgeInsets.only(top: 3),
            decoration: pw.BoxDecoration(
                border: pw.Border(
                    top: pw.BorderSide(color: PdfColors.grey700, width: 0.8))),
            child: pw.Text(
                signerName == null || signerName!.isEmpty
                    ? 'Authorized Signature'
                    : signerName!,
                style: pw.TextStyle(fontSize: small))),
      ]),
      if (!narrow && docHash != null && docHash!.isNotEmpty) ...[
        pw.SizedBox(width: 16),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('Document integrity',
              style: pw.TextStyle(fontSize: tiny, color: PdfColors.grey600)),
          pw.Text('SHA-256: ${docHash!.substring(0, 24)}...',
              style: pw.TextStyle(fontSize: tiny, color: PdfColors.grey600)),
          pw.Text('Signed: $issued',
              style: pw.TextStyle(fontSize: tiny, color: PdfColors.grey600)),
        ]),
      ],
    ]);
  }

  pw.Widget fdnBlock() {
    if (!hasFdn) return pw.SizedBox();
    return pw.Container(
        width: double.infinity,
        padding: pw.EdgeInsets.all(narrow ? 4 : 8),
        decoration: pw.BoxDecoration(
            border: pw.Border.all(color: accent, width: 1),
            borderRadius: pw.BorderRadius.circular(3)),
        child: pw.Row(children: [
          pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: qrData,
              width: narrow ? 44 : 64,
              height: narrow ? 44 : 64),
          pw.SizedBox(width: 8),
          pw.Expanded(
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                pw.Text('EFRIS FISCAL DOCUMENT',
                    style: pw.TextStyle(
                        fontSize: tiny,
                        color: accent,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text('FDN: ${doc.fdn}', style: pw.TextStyle(fontSize: small)),
                if ((doc.verificationCode ?? '').isNotEmpty)
                  pw.Text('VC: ${doc.verificationCode}',
                      style: pw.TextStyle(fontSize: small)),
                pw.Text('Verify with the URA EFRIS app',
                    style: pw.TextStyle(fontSize: tiny, color: PdfColors.grey600)),
              ])),
        ]));
  }

  pw.Widget paidStamp() {
    if (doc.status != 'PAID') return pw.SizedBox();
    return pw.Positioned(
        right: 24,
        bottom: 120,
        child: pw.Transform.rotate(
            angle: -0.3,
            child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: accent, width: 2),
                    borderRadius: pw.BorderRadius.circular(4),
                    color: PdfColors.white),
                child: pw.Text('PAID',
                    style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        color: accent)))));
  }

  pw.Widget watermark() {
    if (isPro) return pw.SizedBox();
    return pw.Positioned.fill(
        child: pw.Center(
            child: pw.Opacity(
                opacity: 0.06,
                child: pw.Text('BIZDOCS',
                    style: pw.TextStyle(
                        fontSize: 120, fontWeight: pw.FontWeight.bold)))));
  }

  pw.Widget footerNote() {
    final text = isPro
        ? 'Made in Uganda · BizDocs by JD Hub'
        : 'Generated with BizDocs · Upgrade to Pro';
    return pw.Center(
        child: pw.Text(text,
            style: pw.TextStyle(fontSize: tiny, color: PdfColors.grey500)));
  }
}

Future<Uint8List> renderDocument({
  required Business business,
  required Customer? customer,
  required Document doc,
  required List<DocumentItem> items,
  Uint8List? signaturePng,
  String? signerName,
  String? docHash,
  bool isPro = false,
}) async {
  final theme = themeFrom(business);
  final logo = business.logoPath != null && File(business.logoPath!).existsSync()
      ? await File(business.logoPath!).readAsBytes()
      : null;
  final narrow = (doc.docType == DocType.receipt ||
      doc.docType == DocType.uraReceipt);
  final accent = PdfColor.fromInt(theme.accent);
  final ctx = _Ctx(
      business: business,
      customer: customer,
      doc: doc,
      items: items,
      logo: logo,
      signature: signaturePng,
      signerName: signerName,
      docHash: docHash,
      isPro: isPro,
      theme: theme,
      accent: accent,
      narrow: narrow);

  final pageFormat = narrow
      ? PdfPageFormat(80 * PdfPageFormat.mm, 210 * PdfPageFormat.mm,
          marginAll: 6 * PdfPageFormat.mm)
      : PdfPageFormat.a4.copyWith(
          marginTop: 36, marginBottom: 40, marginLeft: 36, marginRight: 36);

  final pdf = pw.Document();
  pdf.addPage(pw.Page(
      pageFormat: pageFormat,
      build: (c) => pw.Stack(children: [
            ctx.watermark(),
            pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: _layout(ctx)),
            ctx.paidStamp(),
          ])));

  // Attachment photos print as extra pages.
  if (doc.attachmentsJson != null && doc.attachmentsJson!.isNotEmpty) {
    try {
      for (final p in List<dynamic>.from(jsonDecode(doc.attachmentsJson!))) {
        final f = File(p.toString());
        if (!f.existsSync()) continue;
        pdf.addPage(pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (_) => pw.Center(
                child: pw.Image(pw.MemoryImage(f.readAsBytesSync()),
                    fit: pw.BoxFit.contain))));
      }
    } catch (_) {}
  }
  return pdf.save();
}

List<pw.Widget> _layout(_Ctx c) {
  switch (c.theme.layout) {
    case PdfLayout.modern:
      return _modern(c);
    case PdfLayout.elegant:
      return _elegant(c);
    case PdfLayout.minimal:
      return _minimal(c);
    case PdfLayout.sideBand:
      return _sideBand(c);
    case PdfLayout.gradient:
      return _gradient(c);
    case PdfLayout.boldType:
      return _boldType(c);
    case PdfLayout.scandinavian:
      return _scandinavian(c);
    case PdfLayout.twoColumn:
      return _twoColumn(c);
    case PdfLayout.boldStationary:
      return _boldStationary(c);
    case PdfLayout.bigPrice:
      return _bigPrice(c);
    case PdfLayout.geometric:
      return _geometric(c);
    case PdfLayout.footerBanner:
      return _footerBanner(c);
    case PdfLayout.navy:
      return _navy(c);
    case PdfLayout.script:
      return _script(c);
    case PdfLayout.modernBlue:
      return _modernBlue(c);
    case PdfLayout.simpleGreen:
      return _simpleGreen(c);
    case PdfLayout.framedGold:
      return _framedGold(c);
    case PdfLayout.monochrome:
      return _monochrome(c);
    case PdfLayout.twoToneSplit:
      return _twoToneSplit(c);
    case PdfLayout.accentBar:
      return _accentBar(c);
    case PdfLayout.roundedCard:
      return _roundedCard(c);
    case PdfLayout.classic:
      return _classic(c);
  }
}

// ---------------- layouts ----------------

List<pw.Widget> _classic(_Ctx c) => [
      pw.Container(
        padding: pw.EdgeInsets.all(c.narrow ? 6 : 12),
        decoration: c.narrow
            ? null
            : pw.BoxDecoration(
                color: c.accent, borderRadius: pw.BorderRadius.circular(4)),
        child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                  child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                    c.logoOrName(light: !c.narrow),
                    c.businessDetails(light: !c.narrow),
                  ])),
              c.docMeta(light: !c.narrow),
            ]),
      ),
      pw.SizedBox(height: c.narrow ? 6 : 14),
      ..._body(c),
    ];

List<pw.Widget> _modern(_Ctx c) => [
      pw.Container(
        decoration: pw.BoxDecoration(
            color: c.accent,
            borderRadius: pw.BorderRadius.only(
                bottomLeft: const pw.Radius.circular(18),
                bottomRight: const pw.Radius.circular(18))),
        padding: pw.EdgeInsets.symmetric(
            horizontal: c.narrow ? 8 : 16, vertical: c.narrow ? 8 : 14),
        child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                  child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                    c.logoOrName(light: true),
                    c.businessDetails(light: true),
                  ])),
              c.docMeta(light: true),
            ]),
      ),
      pw.SizedBox(height: c.narrow ? 6 : 14),
      ..._body(c),
    ];

List<pw.Widget> _elegant(_Ctx c) => [
      pw.Center(
          child: pw.Column(children: [
        c.logoOrName(),
        c.businessDetails(),
      ])),
      pw.SizedBox(height: 8),
      pw.Container(height: 2, color: c.accent, width: double.infinity),
      pw.SizedBox(height: 2),
      pw.Container(height: 0.5, color: c.accent, width: double.infinity),
      pw.SizedBox(height: 10),
      pw.Center(child: c.docMeta()),
      pw.SizedBox(height: c.narrow ? 6 : 14),
      ..._body(c),
    ];

List<pw.Widget> _minimal(_Ctx c) => [
      pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [c.logoOrName(), c.businessDetails()])),
            c.docMeta(),
          ]),
      pw.SizedBox(height: 8),
      pw.Container(height: 1, color: c.accent, width: double.infinity),
      pw.SizedBox(height: c.narrow ? 6 : 14),
      ..._body(c),
    ];

List<pw.Widget> _sideBand(_Ctx c) => [
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Container(
            width: c.narrow ? 20 : 40,
            height: c.narrow ? 60 : 120,
            color: c.accent),
        pw.SizedBox(width: 12),
        pw.Expanded(
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [c.logoOrName(), c.businessDetails()])),
        c.docMeta(),
      ]),
      pw.SizedBox(height: c.narrow ? 6 : 14),
      ..._body(c),
    ];

List<pw.Widget> _gradient(_Ctx c) => [
      pw.Container(
          decoration: pw.BoxDecoration(
              gradient: pw.LinearGradient(colors: [
                c.accent,
                _lighten(c.accent, 0.3),
              ]),
              borderRadius: pw.BorderRadius.circular(6)),
          padding: pw.EdgeInsets.all(c.narrow ? 6 : 14),
          child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                    child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                      c.logoOrName(light: true),
                      c.businessDetails(light: true),
                    ])),
                c.docMeta(light: true),
              ])),
      pw.SizedBox(height: c.narrow ? 6 : 14),
      ..._body(c),
    ];

List<pw.Widget> _boldType(_Ctx c) => [
      pw.Text(c.business.name,
          style: pw.TextStyle(
              fontSize: c.narrow ? 14 : 28,
              fontWeight: pw.FontWeight.bold,
              color: c.accent)),
      pw.SizedBox(height: 4),
      c.businessDetails(),
      pw.SizedBox(height: 8),
      pw.Align(alignment: pw.Alignment.centerRight, child: c.docMeta()),
      pw.SizedBox(height: c.narrow ? 6 : 14),
      ..._body(c),
    ];

List<pw.Widget> _scandinavian(_Ctx c) => [
      pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [c.logoOrName(), c.businessDetails()])),
            c.docMeta(),
          ]),
      pw.SizedBox(height: c.narrow ? 6 : 14),
      ..._body(c, borderedTable: false),
    ];

List<pw.Widget> _twoColumn(_Ctx c) => [
      pw.Center(child: c.logoOrName()),
      pw.Center(child: c.businessDetails()),
      pw.Container(height: 1, color: c.accent, width: double.infinity),
      pw.SizedBox(height: 8),
      c.docMeta(),
      pw.SizedBox(height: c.narrow ? 6 : 14),
      ..._body(c),
    ];

List<pw.Widget> _boldStationary(_Ctx c) => [
      pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [c.logoOrName(), c.businessDetails()])),
            pw.Container(
                padding: const pw.EdgeInsets.all(8),
                color: c.accent,
                child: c.docMeta(light: true)),
          ]),
      pw.SizedBox(height: c.narrow ? 6 : 14),
      ..._body(c),
    ];

List<pw.Widget> _bigPrice(_Ctx c) => [
      pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [c.logoOrName(), c.businessDetails()])),
            c.docMeta(),
          ]),
      pw.SizedBox(height: 10),
      pw.Center(
          child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: pw.BoxDecoration(
                  color: _lighten(c.accent, 0.9),
                  borderRadius: pw.BorderRadius.circular(8)),
              child: pw.Text(
                  '${c.doc.currency} ${_money.format(c.doc.total)}',
                  style: pw.TextStyle(
                      fontSize: c.narrow ? 14 : 24,
                      fontWeight: pw.FontWeight.bold,
                      color: c.accent)))),
      pw.SizedBox(height: c.narrow ? 6 : 14),
      ..._body(c),
    ];

List<pw.Widget> _geometric(_Ctx c) => [
      pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [c.logoOrName(), c.businessDetails()])),
            c.docMeta(),
          ]),
      pw.SizedBox(height: 4),
      pw.Row(children: [
        pw.Container(width: 40, height: 8, color: c.accent),
        pw.Container(width: 20, height: 8, color: _lighten(c.accent, 0.4)),
        pw.Container(width: 60, height: 8, color: _lighten(c.accent, 0.7)),
      ]),
      pw.SizedBox(height: c.narrow ? 6 : 14),
      ..._body(c),
    ];

List<pw.Widget> _footerBanner(_Ctx c) => [
      pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [c.logoOrName(), c.businessDetails()])),
            c.docMeta(),
          ]),
      pw.SizedBox(height: c.narrow ? 6 : 14),
      ..._body(c),
    ];

List<pw.Widget> _navy(_Ctx c) => [
      pw.Container(
          width: double.infinity,
          color: c.accent,
          padding: pw.EdgeInsets.all(c.narrow ? 6 : 14),
          child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                    child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                      c.logoOrName(light: true),
                      c.businessDetails(light: true),
                    ])),
                c.docMeta(light: true),
              ])),
      pw.SizedBox(height: c.narrow ? 6 : 14),
      ..._body(c),
    ];

List<pw.Widget> _script(_Ctx c) => [
      pw.Center(child: c.logoOrName()),
      pw.Center(child: c.businessDetails()),
      pw.SizedBox(height: 4),
      pw.Container(height: 0.5, color: c.accent, width: double.infinity),
      pw.SizedBox(height: 8),
      c.docMeta(),
      pw.SizedBox(height: c.narrow ? 6 : 14),
      ..._body(c),
    ];

List<pw.Widget> _modernBlue(_Ctx c) => _classic(c);
List<pw.Widget> _simpleGreen(_Ctx c) => _classic(c);
List<pw.Widget> _framedGold(_Ctx c) => [
      pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
              border: pw.Border.all(color: c.accent, width: 2),
              borderRadius: pw.BorderRadius.circular(4)),
          child: pw.Column(children: [
            pw.Center(child: c.logoOrName()),
            pw.Center(child: c.businessDetails()),
            pw.SizedBox(height: 8),
            c.docMeta(),
            pw.SizedBox(height: c.narrow ? 6 : 14),
            ..._body(c),
          ])),
    ];

List<pw.Widget> _monochrome(_Ctx c) => [
      pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [c.logoOrName(), c.businessDetails()])),
            c.docMeta(),
          ]),
      pw.SizedBox(height: 4),
      pw.Container(height: 2, color: PdfColors.black, width: double.infinity),
      pw.SizedBox(height: c.narrow ? 6 : 14),
      ..._body(c),
    ];

List<pw.Widget> _twoToneSplit(_Ctx c) => [
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
            flex: 4,
            child: pw.Container(
                color: _lighten(c.accent, 0.9),
                padding: const pw.EdgeInsets.all(12),
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [c.logoOrName(), c.businessDetails()]))),
        pw.Expanded(
            flex: 6,
            child: pw.Padding(
                padding: const pw.EdgeInsets.all(12),
                child: c.docMeta())),
      ]),
      pw.SizedBox(height: c.narrow ? 6 : 14),
      ..._body(c),
    ];

List<pw.Widget> _accentBar(_Ctx c) => [
      pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [c.logoOrName(), c.businessDetails()])),
            c.docMeta(),
          ]),
      pw.SizedBox(height: c.narrow ? 6 : 14),
      ..._body(c),
      pw.SizedBox(height: 4),
      pw.Container(height: 3, color: c.accent, width: double.infinity),
    ];

List<pw.Widget> _roundedCard(_Ctx c) => [
      pw.Container(
          decoration: pw.BoxDecoration(
              color: _lighten(c.accent, 0.97),
              borderRadius: pw.BorderRadius.circular(12),
              border: pw.Border.all(color: _lighten(c.accent, 0.8))),
          padding: pw.EdgeInsets.all(c.narrow ? 8 : 16),
          child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                    child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [c.logoOrName(), c.businessDetails()])),
                c.docMeta(),
              ])),
      pw.SizedBox(height: c.narrow ? 6 : 14),
      ..._body(c),
    ];

// ---------- shared body ----------

List<pw.Widget> _body(_Ctx c, {bool borderedTable = true}) {
  if (c.isLetter) {
    return [
      pw.Container(
          width: double.infinity,
          padding: pw.EdgeInsets.all(c.narrow ? 4 : 12),
          child: pw.Text(c.doc.content ?? '',
              style: pw.TextStyle(fontSize: c.base + 1, height: 1.5))),
      pw.SizedBox(height: c.narrow ? 4 : 12),
      if (c.doc.total > 0)
        pw.Container(
            width: double.infinity,
            padding: pw.EdgeInsets.all(c.narrow ? 4 : 10),
            decoration: pw.BoxDecoration(
                color: _lighten(c.accent, 0.9),
                border: pw.Border.all(color: c.accent, width: 0.5),
                borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Text(
                'Amount outstanding: ${c.doc.currency} ${_money.format(c.doc.total)}',
                style: pw.TextStyle(
                    fontSize: c.base, fontWeight: pw.FontWeight.bold))),
      pw.SizedBox(height: c.narrow ? 4 : 12),
      c.signatureBlock(),
      pw.SizedBox(height: c.narrow ? 3 : 8),
      c.fdnBlock(),
      pw.SizedBox(height: c.narrow ? 3 : 8),
      c.footerNote(),
    ];
  }
  return [
    c.billTo(),
    pw.SizedBox(height: c.narrow ? 3 : 8),
    c.itemsTable(),
    pw.SizedBox(height: c.narrow ? 4 : 10),
    c.totalsBlock(),
    pw.SizedBox(height: c.narrow ? 3 : 8),
    c.amountWords(),
    pw.SizedBox(height: c.narrow ? 3 : 8),
    c.bankBlock(),
    pw.SizedBox(height: c.narrow ? 3 : 8),
    c.termsBlock(),
    pw.SizedBox(height: c.narrow ? 3 : 8),
    c.fdnBlock(),
    pw.SizedBox(height: c.narrow ? 4 : 12),
    c.signatureBlock(),
    pw.SizedBox(height: c.narrow ? 3 : 8),
    c.footerNote(),
  ];
}

String _fmtQty(double q) =>
    q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(1);
