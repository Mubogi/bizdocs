import 'package:flutter/material.dart';
import '../db/database.dart';
import '../models.dart';
import 'document_editor_page.dart';

class DocumentsPage extends StatefulWidget {
  final Business business;
  const DocumentsPage({super.key, required this.business});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  DocType? _filter;
  String _search = '';
  List<Document> _docs = [];
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final docs = await AppDatabase.instance
        .listDocuments(widget.business.id, type: _filter);
    if (mounted) setState(() => _docs = docs);
  }

  List<Document> get _visible {
    if (_search.isEmpty) return _docs;
    final q = _search.toLowerCase();
    return _docs
        .where((d) =>
            d.docNumber.toLowerCase().contains(q) ||
            docTypeLabel(d.docType).toLowerCase().contains(q) ||
            d.status.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _create() async {
    final type = await showModalBottomSheet<DocType>(
        context: context,
        builder: (ctx) => SafeArea(
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                ListTile(
                    leading: const Icon(Icons.receipt),
                    title: const Text('Invoice'),
                    onTap: () => Navigator.pop(ctx, DocType.invoice)),
                ListTile(
                    leading: const Icon(Icons.payments),
                    title: const Text('Receipt'),
                    onTap: () => Navigator.pop(ctx, DocType.receipt)),
                ListTile(
                    leading: const Icon(Icons.request_quote),
                    title: const Text('Quotation'),
                    onTap: () => Navigator.pop(ctx, DocType.quotation)),
                ListTile(
                    leading: const Icon(Icons.mail),
                    title: const Text('Letter'),
                    onTap: () => Navigator.pop(ctx, DocType.letter)),
                const Divider(),
                ListTile(
                    leading: const Icon(Icons.calculate_outlined),
                    title: const Text('Estimate'),
                    onTap: () => Navigator.pop(ctx, DocType.estimate)),
                ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Proforma invoice'),
                    onTap: () => Navigator.pop(ctx, DocType.proforma)),
                ListTile(
                    leading: const Icon(Icons.local_shipping_outlined),
                    title: const Text('Delivery note'),
                    onTap: () => Navigator.pop(ctx, DocType.deliveryNote)),
                ListTile(
                    leading: const Icon(Icons.verified_outlined),
                    title: const Text('E-Receipt (URA)'),
                    onTap: () => Navigator.pop(ctx, DocType.uraReceipt)),
                ListTile(
                    leading: const Icon(Icons.notification_important_outlined),
                    title: const Text('Payment reminder'),
                    onTap: () => Navigator.pop(ctx, DocType.reminder)),
              ]),
            )));
    if (type == null) return;
    final created = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => DocumentEditorPage(business: widget.business, docType: type)));
    if (created == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                FilterChip(
                    selected: _filter == null,
                    onSelected: (_) {
                      setState(() => _filter = null);
                      _refresh();
                    },
                    label: const Text('All')),
                ...DocType.values.map((t) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: FilterChip(
                          selected: _filter == t,
                          onSelected: (_) {
                            setState(() => _filter = t);
                            _refresh();
                          },
                          label: Text(docTypeLabel(t))),
                    )),
              ]),
            ),
          ),
        ),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                  hintText: 'Search number, type or status…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _search = '');
                          }),
                  filled: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none))),
        ),
        Expanded(
            child: _visible.isEmpty
                ? Center(
                    child: Text(_docs.isEmpty
                        ? 'No documents yet. Tap + to create.'
                        : 'Nothing matches "$_search".'))
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.builder(
                        itemCount: _visible.length,
                        itemBuilder: (_, i) {
                          final d = _visible[i];
                    return ListTile(
                      leading: CircleAvatar(child: Text(d.docNumber.split('-').first)),
                      title: Text(d.docNumber),
                      subtitle: Text('${docTypeLabel(d.docType)} · ${d.status}'
                          '${d.locked ? ' 🔒' : ''}'),
                      trailing: d.total > 0
                          ? Text('${widget.business.currency} ${d.total}',
                              style: const TextStyle(fontWeight: FontWeight.bold))
                          : null,
                      onTap: () async {
                        await Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => DocumentEditorPage(
                                  business: widget.business,
                                  docType: d.docType,
                                  existing: d,
                                )));
                        _refresh();
                      },
                    );
                  })),
        ),
      ]),
      floatingActionButton:
          FloatingActionButton(onPressed: _create, child: const Icon(Icons.add)),
    );
  }
}
