import 'package:flutter/material.dart';
import '../db/database.dart';
import '../models.dart';

class ProductsPage extends StatefulWidget {
  final Business business;
  const ProductsPage({super.key, required this.business});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  List<Product> _products = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final list = await AppDatabase.instance.listProducts(widget.business.id);
    if (mounted) setState(() => _products = list);
  }

  Future<void> _form([Product? p]) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ProductSheet(product: p, businessId: widget.business.id, defaultTax: widget.business.defaultTaxPercent),
      ),
    );
    if (done == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Products & services')),
      body: _products.isEmpty
          ? const Center(child: Text('No products yet. Tap + to add.'))
          : ListView.builder(
              itemCount: _products.length,
              itemBuilder: (_, i) {
                final p = _products[i];
                return ListTile(
                  title: Text(p.name),
                  subtitle: Text([
                    if ((p.sku ?? '').isNotEmpty) p.sku,
                    if ((p.description ?? '').isNotEmpty) p.description,
                  ].whereType<String>().join(' · ')),
                  trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${widget.business.currency} ${p.unitPrice}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _form(p)),
                      ]),
                );
              }),
      floatingActionButton: FloatingActionButton(
          onPressed: () => _form(), child: const Icon(Icons.add)),
    );
  }
}

class ProductSheet extends StatefulWidget {
  final Product? product;
  final String businessId;
  final double defaultTax;
  const ProductSheet({super.key, this.product, required this.businessId, this.defaultTax = 0});

  @override
  State<ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends State<ProductSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _tax = TextEditingController();
  bool _track = false;
  final _stock = TextEditingController();

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    if (p != null) {
      _name.text = p.name;
      _sku.text = p.sku ?? '';
      _description.text = p.description ?? '';
      _price.text = p.unitPrice.toString();
      _tax.text = p.taxPercent?.toString() ?? '';
      _track = p.trackStock;
      _stock.text = p.stockQty?.toString() ?? '';
    } else if (widget.defaultTax > 0) {
      _tax.text = widget.defaultTax.toString();
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final old = widget.product;
    final p = Product(
      id: old?.id ?? AppDatabase.newId(),
      businessId: old?.businessId ?? widget.businessId,
      name: _name.text.trim(),
      sku: _sku.text.trim().isEmpty ? null : _sku.text.trim(),
      description: _description.text.trim().isEmpty ? null : _description.text.trim(),
      unitPrice: int.tryParse(_price.text.replaceAll(RegExp(r'[,\s]'), '')) ?? 0,
      taxPercent: _tax.text.trim().isEmpty ? null : double.tryParse(_tax.text.trim()),
      trackStock: _track,
      stockQty: _track ? double.tryParse(_stock.text.trim()) : null,
      createdAt: old?.createdAt ?? now,
      updatedAt: now,
    );
    await AppDatabase.instance.upsertProduct(p);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _form,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(widget.product == null ? 'Add product' : 'Edit product',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
          const SizedBox(height: 8),
          TextFormField(controller: _sku, decoration: const InputDecoration(labelText: 'SKU')),
          const SizedBox(height: 8),
          TextFormField(controller: _description, decoration: const InputDecoration(labelText: 'Description')),
          const SizedBox(height: 8),
          TextFormField(
              controller: _price,
              decoration: const InputDecoration(labelText: 'Unit price'),
              keyboardType: TextInputType.number),
          const SizedBox(height: 8),
          TextFormField(controller: _tax, decoration: const InputDecoration(labelText: 'Tax %')),
          const SizedBox(height: 8),
          CheckboxListTile(
              value: _track, onChanged: (v) => setState(() => _track = v ?? false),
              title: const Text('Track stock')),
          if (_track)
            TextFormField(controller: _stock, decoration: const InputDecoration(labelText: 'Stock qty'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true)),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ]),
      ),
    );
  }
}
