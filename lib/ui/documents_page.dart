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
  List<Document> _docs = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final docs = await AppDatabase.instance.listDocuments(widget.business.id, type: _filter);
    if (mounted) setState(() => _docs = docs);
  }

  Future<void> _create() async {
    final type = await showModalBottomSheet<DocType>(
        context: context,
        builder: (ctx) => SafeArea(
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
              ]),
            ));
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
      body: _docs.isEmpty
          ? const Center(child: Text('No documents yet. Tap + to create.'))
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.builder(
                  itemCount: _docs.length,
                  itemBuilder: (_, i) {
                    final d = _docs[i];
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
      floatingActionButton: FloatingActionButton(onPressed: _create, child: const Icon(Icons.add)),
    );
  }
}
