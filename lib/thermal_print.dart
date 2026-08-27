import 'dart:convert';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'models.dart';

/// ESC/POS byte builder for 80mm thermal printers (48 chars per line).
class EscPos {
  final List<int> _b = [];

  EscPos() {
    _b.addAll([0x1B, 0x40]); // init
  }

  void _text(String s, {bool bold = false, int align = 0, int size = 0}) {
    _b.addAll([0x1B, 0x61, align]); // align 0=left 1=center 2=right
    _b.addAll([0x1B, 0x45, bold ? 1 : 0]); // bold
    _b.addAll([0x1D, 0x21, size]); // size: 0 normal, 0x11 double
    _b.addAll(utf8.encode(s));
    _b.add(0x0A);
    _b.addAll([0x1D, 0x21, 0]); // reset size
    _b.addAll([0x1B, 0x45, 0]); // reset bold
  }

  void line([String ch = '-']) {
    _text(ch * 48);
  }

  void gap() => _b.add(0x0A);

  void center(String s, {bool bold = false, int size = 0}) =>
      _text(s, bold: bold, align: 1, size: size);

  void left(String s, {bool bold = false}) => _text(s, bold: bold);

  void row(String l, String r, {bool bold = false}) {
    final width = 48;
    final space = width - l.length - r.length;
    if (space <= 0) {
      _text('$l\n$r', bold: bold, align: 2);
    } else {
      _text(l + ' ' * space + r, bold: bold);
    }
  }

  void feed() {
    _b.addAll([0x1B, 0x64, 4]); // feed 4 lines
  }

  void cut() {
    _b.addAll([0x1D, 0x56, 0x42, 0x10]); // partial cut
  }

  List<int> build() => _b;
}

String _money(int v) {
  final s = v.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

List<int> buildThermalReceipt({
  required Business business,
  required Customer? customer,
  required Document doc,
  required List<DocumentItem> items,
  String? signerName,
}) {
  final p = EscPos();
  p.center(business.name, bold: true, size: 0x11);
  if ((business.address ?? '').isNotEmpty) p.center(business.address!);
  if ((business.phone ?? '').isNotEmpty) p.center('Tel: ${business.phone}');
  if ((business.tin ?? '').isNotEmpty) p.center('TIN: ${business.tin}');
  p.gap();
  p.center(docTypeLabel(doc.docType).toUpperCase(), bold: true);
  p.row(doc.docNumber, _date(doc.issueDate));
  if (customer != null) p.left('Customer: ${customer.name}');
  p.line();
  for (final it in items) {
    p.left(it.description);
    p.row('  ${_qty(it.quantity)} x ${_money(it.unitPrice)}', _money(it.lineTotal));
  }
  p.line();
  p.row('Subtotal', _money(doc.subtotal));
  if (doc.discountTotal > 0) p.row('Discount', '-${_money(doc.discountTotal)}');
  if (doc.taxTotal > 0) p.row('Tax', _money(doc.taxTotal));
  p.row('TOTAL', '${doc.currency} ${_money(doc.total)}', bold: true);
  p.gap();
  if ((doc.fdn ?? '').isNotEmpty) {
    p.line('=');
    p.center('EFRIS fiscal document', bold: true);
    p.center('FDN: ${doc.fdn}');
    if ((doc.verificationCode ?? '').isNotEmpty) {
      p.center('VC: ${doc.verificationCode}');
    }
  }
  if (signerName != null && signerName.isNotEmpty) {
    p.gap();
    p.left('Signed: $signerName');
  }
  if ((doc.terms ?? business.termsTemplate ?? '').isNotEmpty) {
    p.gap();
    p.left(doc.terms ?? business.termsTemplate!);
  }
  p.line();
  p.center('Thank you for your business');
  p.feed();
  p.cut();
  return p.build();
}

String _qty(double q) =>
    q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(1);

String _date(int millis) {
  final d = DateTime.fromMillisecondsSinceEpoch(millis);
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

Future<String?> printThermalReceipt({
  required Business business,
  required Customer? customer,
  required Document doc,
  required List<DocumentItem> items,
  String? signerName,
}) async {
  if (!await PrintBluetoothThermal.isPermissionBluetoothGranted) {
    return 'Bluetooth permission not granted. Allow it in app settings.';
  }
  if (!await PrintBluetoothThermal.bluetoothEnabled) {
    return 'Bluetooth is off. Turn it on and pair your printer first.';
  }
  final devices = await PrintBluetoothThermal.pairedBluetooths;
  if (devices.isEmpty) {
    return 'No paired printers. Pair the printer in Android Bluetooth settings first.';
  }
  final connected = await PrintBluetoothThermal.connectionStatus;
  if (!connected) {
    final ok = await PrintBluetoothThermal.connect(
        macPrinterAddress: devices.first.macAdress);
    if (!ok) return 'Could not connect to ${devices.first.name}.';
  }
  final bytes = buildThermalReceipt(
      business: business,
      customer: customer,
      doc: doc,
      items: items,
      signerName: signerName);
  final written = await PrintBluetoothThermal.writeBytes(bytes);
  return written ? null : 'Printer did not accept the data.';
}
