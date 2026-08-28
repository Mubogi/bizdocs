import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:path_provider/path_provider.dart';
import '../db/database.dart';
import '../pdf_doc.dart'
    show PdfLayout;
import '../pdf_layouts.dart' show layoutColors;
import '../models.dart';
import 'template_gallery.dart';

class BusinessSetupPage extends StatefulWidget {
  final Business? existing;
  const BusinessSetupPage({super.key, this.existing});

  @override
  State<BusinessSetupPage> createState() => _BusinessSetupPageState();
}

class _BusinessSetupPageState extends State<BusinessSetupPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _tin = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();
  final _email = TextEditingController();
  final _currency = TextEditingController(text: 'UGX');
  final _tax = TextEditingController();
  String? _logoPath;

  final _bankName = TextEditingController();
  final _bankAccountName = TextEditingController();
  final _bankAccountNo = TextEditingController();
  final _momoNumber = TextEditingController();
  final _momoProvider = TextEditingController();
  final _merchantCode = TextEditingController();
  final _terms = TextEditingController();
  String _language = 'en';

  int _accent = 0xFF0F7A3D; // green default
  PdfLayout _layout = PdfLayout.classic;

  @override
  void initState() {
    super.initState();
    final b = widget.existing;
    if (b != null) {
      _name.text = b.name;
      _tin.text = b.tin ?? '';
      _address.text = b.address ?? '';
      _phone.text = b.phone ?? '';
      _whatsapp.text = b.whatsapp ?? '';
      _email.text = b.email ?? '';
      _currency.text = b.currency;
      _tax.text = b.defaultTaxPercent == 0 ? '' : b.defaultTaxPercent.toString();
      _logoPath = b.logoPath;
      _bankName.text = b.bankName ?? '';
      _bankAccountName.text = b.bankAccountName ?? '';
      _bankAccountNo.text = b.bankAccountNo ?? '';
      _momoNumber.text = b.mobileMoneyNumber ?? '';
      _momoProvider.text = b.mobileMoneyProvider ?? '';
      _merchantCode.text = b.merchantCode ?? '';
      _terms.text = b.termsTemplate ?? '';
      _language = b.language;
      if (b.templateJson != null) {
        try {
          final j = jsonDecode(b.templateJson!);
          _accent = (j['accent'] as num?)?.toInt() ?? _accent;
          final l = j['layout'] as String?;
          if (l != null) {
            _layout = PdfLayout.values.firstWhere((e) => e.name == l,
                orElse: () => PdfLayout.classic);
          }
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name, _tin, _address, _phone, _whatsapp, _email, _currency, _tax,
      _bankName, _bankAccountName, _bankAccountNo, _momoNumber, _momoProvider, _merchantCode
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final files = await fp.FilePicker.pickFiles(type: fp.FileType.image);
    if (files.isEmpty || files.single.path == null) return;
    final file = files.single;
    final dir = await getApplicationDocumentsDirectory();
    final dest = '${dir.path}/logo_${DateTime.now().millisecondsSinceEpoch}.${(file.extension?.isNotEmpty == true ? file.extension : "png")}';
    await File(file.path!).copy(dest);
    setState(() => _logoPath = dest);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final ex = widget.existing;
    final b = Business(
      id: ex?.id ?? AppDatabase.newId(),
      name: _name.text.trim(),
      tin: _tin.text.trim().isEmpty ? null : _tin.text.trim(),
      address: _address.text.trim().isEmpty ? null : _address.text.trim(),
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      whatsapp: _whatsapp.text.trim().isEmpty ? null : _whatsapp.text.trim(),
      email: _email.text.trim().isEmpty ? null : _email.text.trim(),
      logoPath: _logoPath,
      bankName: _bankName.text.trim().isEmpty ? null : _bankName.text.trim(),
      bankAccountName:
          _bankAccountName.text.trim().isEmpty ? null : _bankAccountName.text.trim(),
      bankAccountNo:
          _bankAccountNo.text.trim().isEmpty ? null : _bankAccountNo.text.trim(),
      mobileMoneyNumber:
          _momoNumber.text.trim().isEmpty ? null : _momoNumber.text.trim(),
      mobileMoneyProvider:
          _momoProvider.text.trim().isEmpty ? null : _momoProvider.text.trim(),
      merchantCode:
          _merchantCode.text.trim().isEmpty ? null : _merchantCode.text.trim(),
      termsTemplate: _terms.text.trim().isEmpty ? null : _terms.text.trim(),
      language: _language,
      templateJson: jsonEncode({
        'accent': _accent,
        'accent2': layoutColors(_layout).$2,
        'layout': _layout.name,
      }),
      currency: _currency.text.trim().isEmpty ? 'UGX' : _currency.text.trim(),
      defaultTaxPercent: double.tryParse(_tax.text.trim()) ?? 0,
      createdAt: ex?.createdAt ?? now,
      updatedAt: now,
    );
    await AppDatabase.instance.upsertBusiness(b);
    if (mounted) Navigator.of(context).pop(b);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Business settings')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Center(child: GestureDetector(
              onTap: _pickLogo,
              child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                      image: _logoPath != null && File(_logoPath!).existsSync()
                          ? DecorationImage(image: FileImage(File(_logoPath!)), fit: BoxFit.cover)
                          : null),
                  child: _logoPath == null
                      ? const Icon(Icons.add_photo_alternate, size: 40)
                      : null))),
          const SizedBox(height: 16),
          _section(context, 'Identity'),
          TextFormField(controller: _name,
              decoration: const InputDecoration(labelText: 'Business name *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
          const SizedBox(height: 8),
          TextFormField(controller: _tin, decoration: const InputDecoration(labelText: 'URA TIN (optional)')),
          const SizedBox(height: 8),
          TextFormField(controller: _address, decoration: const InputDecoration(labelText: 'Address')),
          const SizedBox(height: 8),
          TextFormField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone')),
          const SizedBox(height: 8),
          TextFormField(controller: _whatsapp, decoration: const InputDecoration(labelText: 'WhatsApp')),
          const SizedBox(height: 8),
          TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 16),
          _section(context, 'Presentation'),
          DropdownButtonFormField<String>(
              value: _accCurrencies.contains(_currency.text) ? _currency.text : 'UGX',
              decoration: const InputDecoration(labelText: 'Currency'),
              items: _accCurrencies
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _currency.text = v ?? 'UGX')),
          const SizedBox(height: 8),
          TextFormField(controller: _tax,
              decoration: const InputDecoration(labelText: 'Default tax %'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true)),
          const SizedBox(height: 8),
          Row(children: [
            const Text('Accent color: '),
            ..._accents.map((c) => GestureDetector(
                onTap: () => setState(() => _accent = c),
                child: Container(
                    width: 40, height: 40, margin: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                        color: Color(c), shape: BoxShape.circle,
                        border: Border.all(
                            color: _accent == c ? Colors.black : Colors.transparent, width: 3))))),
          ]),
          const SizedBox(height: 16),
          Text('Document design',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text('Tap a design to preview and choose it. Locked ones need Pro.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          TemplateGallery(
              business: Business(
                  id: widget.existing?.id ?? 'preview',
                  name: _name.text.isEmpty ? 'Your Business' : _name.text,
                  createdAt: 0,
                  updatedAt: 0),
              selected: _layout,
              onSelect: (l) {
                setState(() {
                  _layout = l;
                  _accent = layoutColors(l).$1;
                });
              }),
          const SizedBox(height: 16),
          _section(context, 'Payment details (invoice footer)'),
          TextFormField(controller: _bankName,
              decoration: const InputDecoration(labelText: 'Bank name (e.g. Stanbic Bank)')),
          const SizedBox(height: 8),
          TextFormField(controller: _bankAccountName, decoration: const InputDecoration(labelText: 'Account name')),
          const SizedBox(height: 8),
          TextFormField(controller: _bankAccountNo, decoration: const InputDecoration(labelText: 'Account number')),
          const SizedBox(height: 8),
          TextFormField(controller: _momoNumber,
              decoration: const InputDecoration(labelText: 'Mobile Money number / Pay Bill')),
          const SizedBox(height: 8),
          TextFormField(controller: _momoProvider,
              decoration: const InputDecoration(labelText: 'MoMo provider (e.g. MTN, Airtel)')),
          const SizedBox(height: 8),
          TextFormField(controller: _merchantCode,
              decoration: const InputDecoration(labelText: 'Merchant code (from aggregator)')),
          const SizedBox(height: 16),
          _section(context, 'Documents'),
          DropdownButtonFormField<String>(
              value: _language,
              decoration: const InputDecoration(labelText: 'App language'),
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'lg', child: Text('Luganda')),
                DropdownMenuItem(value: 'sw', child: Text('Kiswahili')),
              ],
              onChanged: (v) => setState(() => _language = v ?? 'en')),
          const SizedBox(height: 8),
          TextFormField(controller: _terms,
              maxLines: 4,
              decoration: const InputDecoration(
                  labelText: 'Terms & conditions (prints on every document)',
                  hintText: 'e.g. Payment due within 30 days. Goods remain property of seller until paid in full.',
                  alignLabelWithHint: true)),
          const SizedBox(height: 24),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check), label: const Text('Save settings')),
        ]),
      ),
    );
  }

  Widget _section(BuildContext ctx, String t) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(t,
          style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
              color: Theme.of(ctx).colorScheme.primary)));

  static final List<int> _accents = [
    0xFF0F7A3D, // green
    0xFF1E3A8A, // navy
    0xFFB91C1C, // red
    0xFF7C3AED, // purple
    0xFFB45309, // orange
    0xFF111827, // black
  ];

  static const List<String> _accCurrencies = [
    'UGX', 'KES', 'TZS', 'RWF', 'NGN', 'ZAR', 'USD', 'EUR', 'GBP'
  ];
}
