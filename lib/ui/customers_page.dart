import 'package:flutter/material.dart';
import '../db/database.dart';
import '../models.dart';

class CustomersPage extends StatefulWidget {
  final Business business;
  const CustomersPage({super.key, required this.business});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  List<Customer> _customers = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final list = await AppDatabase.instance.listCustomers(widget.business.id);
    if (mounted) setState(() => _customers = list);
  }

  Future<void> _form([Customer? c]) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: CustomerSheet(customer: c, businessId: widget.business.id),
      ),
    );
    if (done == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      body: _customers.isEmpty
          ? const Center(child: Text('No customers yet. Tap + to add.'))
          : ListView.builder(
              itemCount: _customers.length,
              itemBuilder: (_, i) {
                final c = _customers[i];
                return ListTile(
                  leading: CircleAvatar(child: Text(c.name.isNotEmpty ? c.name[0] : '?')),
                  title: Text(c.name),
                  subtitle: Text([
                    if ((c.phone ?? '').isNotEmpty) c.phone,
                    if ((c.whatsapp ?? '').isNotEmpty) 'WA ${c.whatsapp}',
                    if ((c.address ?? '').isNotEmpty) c.address,
                  ].whereType<String>().join(' · ')),
                  trailing: IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _form(c)),
                );
              }),
      floatingActionButton: FloatingActionButton(
          onPressed: () => _form(), child: const Icon(Icons.add)),
    );
  }
}

class CustomerSheet extends StatefulWidget {
  final Customer? customer;
  final String businessId;
  const CustomerSheet({super.key, this.customer, required this.businessId});

  @override
  State<CustomerSheet> createState() => _CustomerSheetState();
}

class _CustomerSheetState extends State<CustomerSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _tin = TextEditingController();

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    if (c != null) {
      _name.text = c.name;
      _phone.text = c.phone ?? '';
      _whatsapp.text = c.whatsapp ?? '';
      _email.text = c.email ?? '';
      _address.text = c.address ?? '';
      _tin.text = c.tin ?? '';
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final old = widget.customer;
    final c = Customer(
      id: old?.id ?? AppDatabase.newId(),
      businessId: old?.businessId ?? widget.businessId,
      name: _name.text.trim(),
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      whatsapp: _whatsapp.text.trim().isEmpty ? null : _whatsapp.text.trim(),
      email: _email.text.trim().isEmpty ? null : _email.text.trim(),
      address: _address.text.trim().isEmpty ? null : _address.text.trim(),
      tin: _tin.text.trim().isEmpty ? null : _tin.text.trim(),
      createdAt: old?.createdAt ?? now,
      updatedAt: now,
    );
    await AppDatabase.instance.upsertCustomer(c);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _form,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(widget.customer == null ? 'Add customer' : 'Edit customer',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
          const SizedBox(height: 8),
          TextFormField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone')),
          const SizedBox(height: 8),
          TextFormField(controller: _whatsapp, decoration: const InputDecoration(labelText: 'WhatsApp')),
          const SizedBox(height: 8),
          TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 8),
          TextFormField(controller: _address, decoration: const InputDecoration(labelText: 'Address')),
          const SizedBox(height: 8),
          TextFormField(controller: _tin, decoration: const InputDecoration(labelText: 'TIN (if VAT customer)')),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ]),
      ),
    );
  }
}
