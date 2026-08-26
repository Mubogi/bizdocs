import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../db/database.dart';
import '../models.dart';
import '../pdf_doc.dart' as pdfgen;
import 'signature_page.dart';
import 'outbox_page.dart';
import 'pdf_preview_page.dart';

class DocumentEditorPage extends StatefulWidget {
  final Business business;
  final DocType docType;
  final Document? existing;

  const DocumentEditorPage(
      {super.key, required this.business, required this.docType, this.existing});

  @override
  State<DocumentEditorPage> createState() => _DocumentEditorPageState();
}

class _DocumentEditorPageState extends State<DocumentEditorPage> {
  Document? _doc;
  List<DocumentItem> _items = [];
  Customer? _customer;
  final _content = TextEditingController();
  bool _busy = false;

  bool get _isLetter => widget.docType == DocType.letter;
  bool get _isLocked => _doc != null && _doc!.locked;

  int get _total {
    if (_doc != null && _doc!.total > 0) return _doc!.total;
    int subtotal = 0, tax = 0;
    for (final it in _items) {
      subtotal += it.lineTotal;
      tax += (((it.taxPercent ?? 0) / 100) * it.lineTotal).round();
    }
    return subtotal + tax;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = AppDatabase.instance;
    if (widget.existing != null) {
      _doc = widget.existing;
      _items = await db.documentItems(_doc!.id);
      if (_doc!.customerId != null) {
        final c = await db.listCustomers(widget.business.id);
        try {
          _customer = c.firstWhere((e) => e.id == _doc!.customerId);
        } catch (_) {}
        if (_doc!.content != null) _content.text = _doc!.content!;
      }
      if (mounted) setState(() {});
    }
  }

  Future<void> _reloadDoc() async {
    final db = await AppDatabase.instance.db;
    final rows = await db.query('documents',
        where: 'id = ?', whereArgs: [_doc!.id], limit: 1);
    if (rows.isNotEmpty) _doc = Document.fromMap(rows.first);
    _items = await AppDatabase.instance.documentItems(_doc!.id);
    if (mounted) setState(() {});
  }

  Future<void> _ensureDoc() async {
    if (_doc != null) return;
    final number =
        await AppDatabase.instance.nextDocNumber(widget.business.id, widget.docType);
    final now = DateTime.now().millisecondsSinceEpoch;
    _doc = Document(
        id: AppDatabase.newId(),
        businessId: widget.business.id,
        docType: widget.docType,
        docNumber: number,
        issueDate: now,
        createdAt: now,
        updatedAt: now);
    if (_isLetter) _doc!.content = _content.text;
    await AppDatabase.instance.saveDocument(_doc!, []);
    await _reloadDoc();
  }

  Future<void> _pickCustomer() async {
    if (_isLocked) return;
    final list = await AppDatabase.instance.listCustomers(widget.business.id);
    if (!mounted) return;
    final picked = await showModalBottomSheet<Customer?>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => ListView(children: [
              ListTile(
                  leading: const Icon(Icons.person_off_outlined),
                  title: const Text('Walk-in / no customer'),
                  onTap: () => Navigator.pop(ctx, _NoCustomer())),
              ...list.map((c) => ListTile(
                    leading: CircleAvatar(child: Text(c.name.isNotEmpty ? c.name[0] : '?')),
                    title: Text(c.name),
                    subtitle: Text([
                      if ((c.whatsapp ?? '').isNotEmpty) c.whatsapp,
                      if ((c.phone ?? '').isNotEmpty) c.phone,
                    ].whereType<String>().join(' · ')),
                    onTap: () => Navigator.pop(ctx, c))),
            ]));
    if (picked is _NoCustomer) {
      setState(() => _customer = null);
    } else if (picked != null) {
      setState(() => _customer = picked);
    }
  }

  Future<void> _addItem() async {
    if (_isLocked) return;
    final products = await AppDatabase.instance.listProducts(widget.business.id);
    if (!mounted) return;
    final result = await showModalBottomSheet<DocumentItem>(
        context: context,
        isScrollControlled: true,
        builder: (_) => Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: ItemSheet(
                products: products,
                defaultTax: widget.business.defaultTaxPercent)));
    if (result == null) return;
    await _ensureDoc();
    result.documentId = _doc!.id;
    result.id = AppDatabase.newId();
    await AppDatabase.instance.saveDocument(_doc!, [..._items, result]);
    await AppDatabase.instance.updateDocumentTotals(_doc!.id);
    await _reloadDoc();
  }

  Future<void> _removeItem(DocumentItem it) async {
    if (_isLocked) return;
    final remaining = [..._items]..removeWhere((x) => x.id == it.id);
    await AppDatabase.instance.saveDocument(_doc!, remaining);
    await AppDatabase.instance.updateDocumentTotals(_doc!.id);
    await _reloadDoc();
  }

  Future<void> _buildAndPreviewPdf({bool andSend = false}) async {
    await _ensureDoc();
    if (_isLetter) {
      _doc!.content = _content.text;
      await AppDatabase.instance.saveDocument(_doc!, _items);
    }
    final isPro = (await AppDatabase.instance.subscription()).isPro;
    final sigPath = await AppDatabase.instance.getSignature(_doc!.id);
    final sigPng = sigPath != null && File(sigPath.imagePath).existsSync()
        ? await File(sigPath.imagePath).readAsBytes()
        : null;
    Future<Uint8List> build() => pdfgen.documentPdfBytes(
        business: widget.business,
        customer: _customer,
        doc: _doc!,
        items: _items,
        signaturePng: sigPng,
        signerName: sigPath?.signerName,
        docHash: _doc!.hash,
        isPro: isPro);
    if (!mounted) return;
    if (andSend) {
      await pdfgen.documentPdfToCache(
          business: widget.business,
          customer: _customer,
          doc: _doc!,
          items: _items,
          signaturePng: sigPng,
          signerName: sigPath?.signerName,
          docHash: _doc!.hash,
          isPro: isPro);
      await AppDatabase.instance.enqueueOutbox(OutboxEntry(
          id: AppDatabase.newId(),
          documentId: _doc!.id,
          channel: 'PDF',
          recipient: _customer?.whatsapp ?? _customer?.phone ?? 'customer',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch));
      if (!mounted) return;
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const OutboxPage()));
    } else {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PdfPreviewPage(
              buildPdf: build,
              title: '${_doc!.docNumber} Preview')));
    }
  }

  Future<void> _sign() async {
    await _ensureDoc();
    if (_isLetter) {
      _doc!.content = _content.text;
      final db = await AppDatabase.instance.db;
      await db.update('documents', {'content': _content.text},
          where: 'id = ?', whereArgs: [_doc!.id]);
    }
    await AppDatabase.instance.setDocumentStatus(_doc!.id, 'ISSUED');
    final sig = await Navigator.of(context).push<SignatureResult>(
        MaterialPageRoute(builder: (_) => const SignaturePage()));
    if (sig == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final hash = shortContentHash(_doc!, _items);
      final dir = await getApplicationDocumentsDirectory();
      final sigPath = '${dir.path}/sig_${_doc!.id}.png';
      await File(sigPath).writeAsBytes(sig.bytes);
      await AppDatabase.instance.saveSignature(DocSignature(
          id: AppDatabase.newId(),
          documentId: _doc!.id,
          signerName: sig.name,
          imagePath: sigPath,
          hash: hash,
          signedAt: DateTime.now().millisecondsSinceEpoch));
      final isPro = (await AppDatabase.instance.subscription()).isPro;
      final pdfPath = await pdfgen.documentPdfToCache(
          business: widget.business,
          customer: _customer,
          doc: _doc!,
          items: _items,
          signaturePng: sig.bytes,
          signerName: sig.name,
          docHash: hash,
          isPro: isPro);
      await AppDatabase.instance.updateDocumentPdf(_doc!.id, pdfPath, hash);
      await AppDatabase.instance.enqueueOutbox(OutboxEntry(
          id: AppDatabase.newId(),
          documentId: _doc!.id,
          channel: 'PDF',
          recipient: _customer?.whatsapp ?? _customer?.phone ?? 'customer',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch));
      await _reloadDoc();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_doc!.docNumber} signed and queued.')));
      await _buildAndPreviewPdf(andSend: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recordPayment() async {
    if (_doc == null || _doc!.total <= 0) return;
    final paid = await AppDatabase.instance.totalPaid(_doc!.id);
    if (paid >= _doc!.total) return;
    final amtCtrl = TextEditingController(text: (_doc!.total - paid).toString());
    String method = 'MTN';
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text('Record payment for ${_doc!.docNumber}'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: amtCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: 'Amount (${widget.business.currency})')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                    value: method,
                    items: const [
                      DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                      DropdownMenuItem(value: 'MTN', child: Text('MTN Mobile Money')),
                      DropdownMenuItem(value: 'AIRTEL', child: Text('Airtel Money')),
                      DropdownMenuItem(value: 'BANK', child: Text('Bank')),
                    ],
                    onChanged: (v) => method = v ?? 'CASH'),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Save')),
              ],
            ));
    if (ok != true) return;
    final amount =
        int.tryParse(amtCtrl.text.replaceAll(RegExp(r'[,\s]'), '')) ?? 0;
    if (amount <= 0) return;
    await AppDatabase.instance.addPayment(Payment(
        id: AppDatabase.newId(),
        documentId: _doc!.id,
        amount: amount,
        method: method,
        paidAt: DateTime.now().millisecondsSinceEpoch));
    await _reloadDoc();
  }

  Future<void> _convert(DocType target) async {
    if (_doc == null) return;
    final number =
        await AppDatabase.instance.nextDocNumber(widget.business.id, target);
    final now = DateTime.now().millisecondsSinceEpoch;
    final newDoc = Document(
        id: AppDatabase.newId(),
        businessId: _doc!.businessId,
        customerId: _doc!.customerId,
        docType: target,
        docNumber: number,
        issueDate: now,
        linkedDocId: _doc!.id,
        createdAt: now,
        updatedAt: now);
    final items = _items
        .map((it) => DocumentItem(
            id: AppDatabase.newId(),
            documentId: newDoc.id,
            productId: it.productId,
            description: it.description,
            quantity: it.quantity,
            unitPrice: it.unitPrice,
            taxPercent: it.taxPercent,
            lineTotal: it.lineTotal))
        .toList();
    await AppDatabase.instance.saveDocument(newDoc, items);
    await AppDatabase.instance.updateDocumentTotals(newDoc.id);
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DocumentEditorPage(
            business: widget.business, docType: target, existing: newDoc)));
  }

  @override
  Widget build(BuildContext context) {
    final doc = _doc;
    final total = _total;
    return Scaffold(
      appBar: AppBar(
        title: Text(doc != null
            ? doc.docNumber
            : 'New ${docTypeLabel(widget.docType)}'),
        actions: [
          if (doc != null)
            IconButton(
                icon: const Icon(Icons.preview),
                tooltip: 'Preview PDF',
                onPressed: () => _buildAndPreviewPdf()),
          if (doc != null && doc.locked)
            IconButton(
                icon: const Icon(Icons.ios_share),
                tooltip: 'Send / Share',
                onPressed: () => _buildAndPreviewPdf(andSend: true)),
        ],
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              ListTile(
                leading: const Icon(Icons.person),
                title: Text(_customer?.name ?? 'Walk-in / Customer'),
                subtitle: _customer?.whatsapp != null
                    ? Text(_customer!.whatsapp!)
                    : null,
                trailing: _isLocked
                    ? null
                    : TextButton(
                        onPressed: _pickCustomer,
                        child: const Text('Change')),
              ),
              if (_isLetter)
                Expanded(
                    child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                      controller: _content,
                      enabled: !_isLocked,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                          hintText: 'Write the letter here…',
                          border: OutlineInputBorder())),
                ))
              else if (doc == null)
                Expanded(child: _emptyDraft())
              else
                Expanded(
                    child: _items.isEmpty
                        ? Center(
                            child:
                                Text('No items yet. Tap below to add.'))
                        : ListView.builder(
                            itemCount: _items.length,
                            itemBuilder: (_, i) {
                              final it = _items[i];
                              return ListTile(
                                title: Text(it.description),
                                subtitle:
                                    Text('${it.quantity} × ${it.unitPrice}'),
                                trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('${it.lineTotal}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      if (!_isLocked)
                                        IconButton(
                                            icon: const Icon(
                                                Icons.delete_outline),
                                            onPressed: () =>
                                                _removeItem(it)),
                                    ]),
                              );
                            })),
              Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest),
                  child: Row(children: [
                    Expanded(
                        child: Text(
                            'Total: ${widget.business.currency} $total',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold))),
                    if (!_isLetter && !_isLocked)
                      ElevatedButton.icon(
                          onPressed: doc == null
                              ? _ensureDoc
                              : _addItem,
                          icon: const Icon(Icons.add),
                          label: Text(doc == null ? 'Start' : 'Add item')),
                  ])),
            ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            if (doc != null && !doc.locked)
              Expanded(
                  child: FilledButton.icon(
                      onPressed: _busy ? null : _sign,
                      icon: const Icon(Icons.gesture),
                      label: const Text('Issue & Sign'))),
            if (doc != null && doc.locked) ...[
              Expanded(
                  child: FilledButton.icon(
                      onPressed: () => _buildAndPreviewPdf(andSend: true),
                      icon: const Icon(Icons.ios_share),
                      label: Text('Send ${doc.docNumber}'))),
              if (doc.docType == DocType.quotation) ...[
                const SizedBox(width: 8),
                Expanded(
                    child: OutlinedButton.icon(
                        onPressed: () => _convert(DocType.invoice),
                        icon: const Icon(Icons.transform),
                        label: const Text('To Invoice'))),
              ],
              if (doc.docType == DocType.invoice) ...[
                const SizedBox(width: 8),
                Expanded(
                    child: OutlinedButton.icon(
                        onPressed: _recordPayment,
                        icon: const Icon(Icons.payments),
                        label: const Text('Payment'))),
                const SizedBox(width: 8),
                Expanded(
                    child: OutlinedButton.icon(
                        onPressed: () => _convert(DocType.receipt),
                        icon: const Icon(Icons.receipt),
                        label: const Text('Receipt'))),
              ],
            ],
          ]),
        ),
      ),
    );
  }

  Widget _emptyDraft() {
    return Center(
        child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
          _isLetter
              ? 'Write your letter above, then press "Issue & Sign".'
              : 'Add items below, then press "Issue & Sign".',
          textAlign: TextAlign.center),
    ));
  }
}

class _NoCustomer extends Customer {
  _NoCustomer()
      : super(
            id: '',
            businessId: '',
            name: '',
            createdAt: 0,
            updatedAt: 0);
}

class ItemSheet extends StatefulWidget {
  final List<Product> products;
  final double defaultTax;
  const ItemSheet({super.key, required this.products, this.defaultTax = 0});

  @override
  State<ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<ItemSheet> {
  Product? _selected;
  final _description = TextEditingController();
  final _qty = TextEditingController(text: '1');
  final _price = TextEditingController();
  final _tax = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.defaultTax > 0) _tax.text = widget.defaultTax.toString();
  }

  void _onProduct(Product? p) {
    setState(() => _selected = p);
    if (p != null) {
      _description.text = p.name;
      _price.text = p.unitPrice.toString();
      if (p.taxPercent != null && _tax.text.isEmpty) {
        _tax.text = p.taxPercent.toString();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Add item', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (widget.products.isNotEmpty)
          DropdownButtonFormField<Product?>(
              value: _selected,
              decoration: const InputDecoration(labelText: 'From products'),
              items: [
                const DropdownMenuItem<Product?>(
                    value: null, child: Text('Custom item')),
                ...widget.products.map((p) => DropdownMenuItem<Product?>(
                    value: p, child: Text(p.name))),
              ],
              onChanged: _onProduct),
        TextField(
            controller: _description,
            decoration: const InputDecoration(labelText: 'Description')),
        Row(children: [
          Expanded(
              child: TextField(
                  controller: _qty,
                  decoration: const InputDecoration(labelText: 'Qty'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true))),
          const SizedBox(width: 8),
          Expanded(
              child: TextField(
                  controller: _price,
                  decoration: const InputDecoration(labelText: 'Unit price'),
                  keyboardType: TextInputType.number)),
          const SizedBox(width: 8),
          Expanded(
              child: TextField(
                  controller: _tax,
                  decoration: const InputDecoration(labelText: 'Tax %'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true))),
        ]),
        const SizedBox(height: 16),
        FilledButton(
            onPressed: () {
              final desc = _description.text.trim();
              final qty = double.tryParse(_qty.text.replaceAll(',', '')) ?? 1;
              final price =
                  int.tryParse(_price.text.replaceAll(RegExp(r'[,\s]'), '')) ?? 0;
              final tax = double.tryParse(_tax.text.trim());
              if (desc.isEmpty) return;
              final item = DocumentItem(
                  id: AppDatabase.newId(),
                  documentId: '',
                  productId: _selected?.id,
                  description: desc,
                  quantity: qty,
                  unitPrice: price,
                  taxPercent: tax,
                  lineTotal: (qty * price).round());
              Navigator.of(context).pop(item);
            },
            child: const Text('Add')),
      ]),
    );
  }
}
