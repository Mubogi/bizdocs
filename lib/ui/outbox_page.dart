import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../db/database.dart';
import '../models.dart';
import '../pdf_doc.dart';

class OutboxPage extends StatefulWidget {
  const OutboxPage({super.key});

  @override
  State<OutboxPage> createState() => _OutboxPageState();
}

class _OutboxPageState extends State<OutboxPage> {
  List<OutboxEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    _entries = await AppDatabase.instance.listOutbox();
    if (mounted) setState(() {});
  }

  Future<int> _pendingCount() async {
    final pending = await AppDatabase.instance.listOutbox(status: 'PENDING');
    return pending.length;
  }

  Future<void> _send(OutboxEntry e) async {
    final db = AppDatabase.instance;
    final raw = await db.db;
    final docs = await raw.query('documents',
        where: 'id = ?', whereArgs: [e.documentId], limit: 1);
    if (docs.isEmpty) {
      await db.markOutbox(e, 'FAILED', lastError: 'Document missing');
      _refresh();
      return;
    }
    final doc = Document.fromMap(docs.first);
    String? path = doc.pdfPath;

    // Rebuild PDF if missing
    if (path == null || !File(path).existsSync()) {
      try {
        final items = await db.documentItems(doc.id);
        final bizRow = await raw.query('businesses',
            where: 'id = ?', whereArgs: [doc.businessId], limit: 1);
        if (bizRow.isEmpty) {
          await db.markOutbox(e, 'FAILED', lastError: 'Business missing');
          _refresh();
          return;
        }
        Customer? cust;
        if (doc.customerId != null) {
          final custs = await db.listCustomers(doc.businessId);
          try {
            cust = custs.firstWhere((c) => c.id == doc.customerId);
          } catch (_) {}
        }
        final isPro = (await db.subscription()).isPro;
        final sig = await db.getSignature(doc.id);
        final sigPng = sig != null && File(sig.imagePath).existsSync()
            ? await File(sig.imagePath).readAsBytes()
            : null;
        path = await documentPdfToCache(
            business: Business.fromMap(bizRow.first),
            customer: cust,
            doc: doc,
            items: items,
            signaturePng: sigPng,
            signerName: sig?.signerName,
            docHash: doc.hash,
            isPro: isPro);
        await db.updateDocumentPdf(doc.id, path, doc.hash ?? '');
      } catch (err) {
        await db.markOutbox(e, 'FAILED', lastError: '$err');
        _refresh();
        return;
      }
    }

    final text = '${docTypeLabel(doc.docType)} ${doc.docNumber}';
    try {
      await SharePlus.instance
          .share(ShareParams(files: [XFile(path)], text: text));
      await db.markOutbox(e, 'SENT');
    } catch (err) {
      await db.markOutbox(e, 'FAILED', lastError: '$err');
    }
    _refresh();
  }

  Future<void> _sendAllPending() async {
    final pending = await AppDatabase.instance.listOutbox(status: 'PENDING');
    for (final e in pending) {
      await _send(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Send queue'),
          actions: [
            FutureBuilder<int>(
              future: _pendingCount(),
              builder: (ctx, snap) => IconButton(
                  icon: Badge(
                      label: Text('${snap.data ?? 0}'),
                      child: const Icon(Icons.send)),
                  onPressed: ((snap.data ?? 0) > 0) ? _sendAllPending : null),
            ),
          ]),
      body: _entries.isEmpty
          ? const Center(child: Text('Nothing queued yet.'))
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.builder(
                  itemCount: _entries.length,
                  itemBuilder: (_, i) {
                    final e = _entries[i];
                    return ListTile(
                      leading: Icon(e.status == 'SENT'
                          ? Icons.check_circle
                          : e.status == 'FAILED'
                              ? Icons.error
                              : Icons.schedule),
                      title: Text('${e.channel} → ${e.recipient}'),
                      subtitle: Text([
                        e.status,
                        if ((e.lastError ?? '').isNotEmpty) e.lastError,
                      ].whereType<String>().join(' · ')),
                      trailing: e.status == 'PENDING'
                          ? IconButton(
                              icon: const Icon(Icons.send),
                              onPressed: () => _send(e))
                          : null,
                    );
                  })),
    );
  }
}
