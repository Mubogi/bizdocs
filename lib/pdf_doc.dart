import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'models.dart';
import 'pdf_layouts.dart' as layouts;

export 'pdf_layouts.dart'
    show PdfLayout, pdfLayoutNames, pdfLayoutIsPro, pdfLayoutDescriptions, themeFrom;

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

Future<Uint8List> documentPdfBytes({
  required Business business,
  required Customer? customer,
  required Document doc,
  required List<DocumentItem> items,
  Uint8List? signaturePng,
  String? signerName,
  String? docHash,
  bool isPro = false,
}) =>
    layouts.renderDocument(
        business: business,
        customer: customer,
        doc: doc,
        items: items,
        signaturePng: signaturePng,
        signerName: signerName,
        docHash: docHash,
        isPro: isPro);

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

