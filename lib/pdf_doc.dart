import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'models.dart';

double _money(int v) => v.toDouble();

Future<String> buildDocumentPdf({
  required Business business,
  required Customer? customer,
  required Document doc,
  required List<DocumentItem> items,
  Uint8List? signaturePng,
  String? signerName,
  String? docHash,
  bool isPro = false,
}) async {
  final pdf = pw.Document();
  final isReceipt = doc.docType == DocType.receipt;
  final isLetter = doc.docType == DocType.letter;
  final pageFormat = isReceipt
      ? PdfPageFormat(80 * PdfPageFormat.mm, 210 * PdfPageFormat.mm,
          marginAll: 5 * PdfPageFormat.mm)
      : PdfPageFormat.a4.copyWith(
          marginTop: 40, marginLeft: 40, marginRight: 40, marginBottom: 48);

  final df = DateFormat('dd MMM yyyy');

  pdf.addPage(pw.Page(
    pageFormat: pageFormat,
    build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Expanded(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(business.name,
                style: pw.TextStyle(fontSize: isReceipt ? 12 : 18, fontWeight: pw.FontWeight.bold)),
            if (business.tin != null && business.tin!.isNotEmpty)
              pw.Text('TIN: ${business.tin}', style: pw.TextStyle(fontSize: isReceipt ? 7 : 10)),
            if (business.address != null && business.address!.isNotEmpty)
              pw.Text(business.address!, style: pw.TextStyle(fontSize: isReceipt ? 7 : 10)),
            if (business.phone != null && business.phone!.isNotEmpty)
              pw.Text('Tel: ${business.phone}', style: pw.TextStyle(fontSize: isReceipt ? 7 : 10)),
          ])),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text(docTypeLabel(doc.docType).toUpperCase(),
                style: pw.TextStyle(fontSize: isReceipt ? 11 : 16, fontWeight: pw.FontWeight.bold)),
            pw.Text(doc.docNumber, style: pw.TextStyle(fontSize: isReceipt ? 8 : 11)),
            pw.Text(df.format(DateTime.fromMillisecondsSinceEpoch(doc.issueDate)),
                style: pw.TextStyle(fontSize: isReceipt ? 7 : 10)),
          ]),
        ]),
        pw.SizedBox(height: isReceipt ? 6 : 12),
        if (customer != null) ...[
          pw.Text('To: ${customer.name}',
              style: pw.TextStyle(fontSize: isReceipt ? 8 : 11, fontWeight: pw.FontWeight.bold)),
          if ((customer.address ?? '').isNotEmpty)
            pw.Text(customer.address!, style: pw.TextStyle(fontSize: isReceipt ? 7 : 9)),
          if (customer.tin != null && customer.tin!.isNotEmpty)
            pw.Text('TIN: ${customer.tin}', style: pw.TextStyle(fontSize: isReceipt ? 7 : 9)),
          pw.SizedBox(height: isReceipt ? 4 : 8),
        ],
        if (isLetter) ...[
          pw.Expanded(
              child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 8),
                  child: pw.Text(doc.content ?? '', style: const pw.TextStyle(fontSize: 11)))),
        ] else ...[
          pw.Table(
            border: isReceipt ? null : pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
            columnWidths: isReceipt
                ? {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(1),
                    2: const pw.FlexColumnWidth(1)
                  }
                : {
                    0: const pw.FlexColumnWidth(4),
                    1: const pw.FlexColumnWidth(1),
                    2: const pw.FlexColumnWidth(2),
                    3: const pw.FlexColumnWidth(2)
                  },
            children: [
              if (!isReceipt)
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: ['Item', 'Qty', 'Unit', 'Total']
                      .map((h) => pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          child: pw.Text(h, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))))
                      .toList()),
              ...items.map((it) => pw.TableRow(children: [
                    pw.Padding(
                        padding: pw.EdgeInsets.symmetric(horizontal: isReceipt ? 0 : 4, vertical: 3),
                        child: pw.Text(it.description, style: pw.TextStyle(fontSize: isReceipt ? 7 : 10))),
                    pw.Padding(
                        padding: pw.EdgeInsets.symmetric(horizontal: isReceipt ? 0 : 4, vertical: 3),
                        child: pw.Text(_fmtQty(it.quantity), style: pw.TextStyle(fontSize: isReceipt ? 7 : 10))),
                    if (!isReceipt)
                      pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                          child: pw.Text(_fmtMoney(it.unitPrice), style: const pw.TextStyle(fontSize: 10))),
                    pw.Padding(
                        padding: pw.EdgeInsets.symmetric(horizontal: isReceipt ? 0 : 4, vertical: 3),
                        child: pw.Align(
                            alignment: pw.Alignment.centerRight,
                            child: pw.Text(_fmtMoney(it.lineTotal),
                                style: pw.TextStyle(fontSize: isReceipt ? 7 : 10)))),
                  ])),
            ],
          ),
          pw.SizedBox(height: isReceipt ? 4 : 8),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('Subtotal: ${business.currency} ${_fmtMoney(doc.subtotal)}',
                  style: pw.TextStyle(fontSize: isReceipt ? 8 : 10)),
              if (doc.taxTotal > 0)
                pw.Text('Tax: ${business.currency} ${_fmtMoney(doc.taxTotal)}',
                    style: pw.TextStyle(fontSize: isReceipt ? 8 : 10)),
              pw.Text('TOTAL: ${business.currency} ${_fmtMoney(doc.total)}',
                  style: pw.TextStyle(fontSize: isReceipt ? 9 : 12, fontWeight: pw.FontWeight.bold)),
            ]),
          ]),
        ],
        pw.SizedBox(height: isReceipt ? 6 : 16),
        if (signaturePng != null) ...[
          pw.Row(children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Image(pw.MemoryImage(signaturePng), height: isReceipt ? 28 : 56),
              pw.Container(
                  width: isReceipt ? 80 : 160,
                  decoration: const pw.BoxDecoration(
                      border: pw.Border(top: pw.BorderSide(width: 1, color: PdfColors.grey))),
                  padding: const pw.EdgeInsets.only(top: 4),
                  child: pw.Text((signerName ?? 'Authorized Signature'),
                      style: pw.TextStyle(fontSize: isReceipt ? 7 : 9))),
            ]),
          ]),
          if ((docHash ?? '').isNotEmpty)
            pw.Padding(
                padding: const pw.EdgeInsets.only(top: 4),
                child: pw.Text('Doc signature hash: ${docHash!.substring(0, 24)}',
                    style: pw.TextStyle(fontSize: isReceipt ? 5 : 7, color: PdfColors.grey))),
        ],
        pw.Spacer(),
        if (!isPro)
          pw.Center(
              child: pw.Text('Generated with BizDocs (Free) — remove watermark by upgrading.',
                  style: pw.TextStyle(fontSize: isReceipt ? 5 : 7, color: PdfColors.grey600))),
      ],
    ),
  ));

  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/${doc.docNumber.replaceAll('/', '_')}.pdf');
  await file.writeAsBytes(await pdf.save());
  return file.path;
}

String _fmtQty(double q) {
  return q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(1);
}

String _fmtMoney(int v) => NumberFormat('#,##0').format(_money(v));
