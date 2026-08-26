import 'package:flutter/material.dart';
import '../db/database.dart';
import '../models.dart';

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
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _tin, _address, _phone, _whatsapp, _email, _currency, _tax]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = widget.existing;
    final b = Business(
      id: existing?.id ?? AppDatabase.newId(),
      name: _name.text.trim(),
      tin: _tin.text.trim(),
      address: _address.text.trim(),
      phone: _phone.text.trim(),
      whatsapp: _whatsapp.text.trim().isEmpty ? null : _whatsapp.text.trim(),
      email: _email.text.trim().isEmpty ? null : _email.text.trim(),
      currency: _currency.text.trim().isEmpty ? 'UGX' : _currency.text.trim(),
      defaultTaxPercent: double.tryParse(_tax.text.trim()) ?? 0,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await AppDatabase.instance.upsertBusiness(b);
    if (!mounted) return;
    Navigator.of(context).pop(b);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your business')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Business name *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
          const SizedBox(height: 12),
          TextFormField(controller: _tin, decoration: const InputDecoration(labelText: 'URA TIN (if any)')),
          const SizedBox(height: 12),
          TextFormField(controller: _address, decoration: const InputDecoration(labelText: 'Address')),
          const SizedBox(height: 12),
          TextFormField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone')),
          const SizedBox(height: 12),
          TextFormField(controller: _whatsapp, decoration: const InputDecoration(labelText: 'WhatsApp')),
          const SizedBox(height: 12),
          TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 12),
          TextFormField(controller: _currency, decoration: const InputDecoration(labelText: 'Currency')),
          const SizedBox(height: 12),
          TextFormField(
              controller: _tax,
              decoration: const InputDecoration(labelText: 'Default tax % (e.g. 18 for VAT)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true)),
          const SizedBox(height: 24),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check), label: const Text('Save')),
        ]),
      ),
    );
  }
}
