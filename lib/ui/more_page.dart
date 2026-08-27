import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../db/database.dart';
import '../models.dart';
import 'business_setup_page.dart';
import 'outbox_page.dart';
import 'reports_page.dart';
import '../pro_codes.dart';
import 'pro_page.dart';
import 'admin_codes_page.dart';

class MorePage extends StatefulWidget {
  final Business business;
  final Future<void> Function() onBusinessChanged;
  const MorePage({super.key, required this.business, required this.onBusinessChanged});

  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> {
  SubscriptionState _sub = SubscriptionState();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    _sub = await AppDatabase.instance.subscription();
    if (mounted) setState(() {});
  }

  Future<void> _editBusiness() async {
    final b = await Navigator.of(context).push<Business?>(MaterialPageRoute(
        builder: (_) => BusinessSetupPage(existing: widget.business)));
    if (b != null) await widget.onBusinessChanged();
  }

  Future<void> _subscriptionDialog() async {
    final codeCtrl = TextEditingController();
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text(_sub.isPro ? 'BizDocs Pro' : 'Upgrade to Pro'),
              content: _sub.isPro
                  ? const Text('Pro is active. Watermark removed, month-end lock and more unlocked.')
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('Enter your Pro unlock code (get it from your seller).'),
                      TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Code')),
                    ]),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Close')),
                if (!_sub.isPro)
                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Unlock')),
              ],
            ));
    if (ok != true) return;
    final code = codeCtrl.text.trim();
    int? valid;
    if (isLegacyCode(code)) {
      valid = DateTime.now().add(const Duration(days: 365)).millisecondsSinceEpoch;
    } else {
      final v = validateProCode(code);
      if (v != null) valid = int.parse(v.split('|').first);
    }
    if (valid != null) {
      if (valid < DateTime.now().millisecondsSinceEpoch) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('That code has expired.')));
        }
        return;
      }
      await AppDatabase.instance.setSubscription(SubscriptionState(
          plan: 'PRO',
          validUntil: valid,
          provider: 'CODE',
          lastVerifiedAt: DateTime.now().millisecondsSinceEpoch));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Pro unlocked. Enjoy the premium templates!')));
        _refresh();
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Invalid code.')));
    }
  }

  Future<void> _monthLock() async {
    if (!_sub.isPro) {
      await _subscriptionDialog();
      if (!(await AppDatabase.instance.subscription()).isPro) return;
    }
    final now = DateTime.now();
    int year = now.year, month = now.month;
    final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx2, setLocal) => AlertDialog(
                  title: const Text('Close month books'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Lock all documents issued in a month. Locked documents cannot be edited.'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                        value: year,
                        items: [for (var y = now.year - 3; y <= now.year; y++) DropdownMenuItem(value: y, child: Text('$y'))],
                        onChanged: (v) => setLocal(() => year = v!)),
                    DropdownButtonFormField<int>(
                        value: month,
                        items: [for (var m = 1; m <= 12; m++) DropdownMenuItem(value: m, child: Text(DateFormat('MMMM').format(DateTime(2024, m))))],
                        onChanged: (v) => setLocal(() => month = v!)),
                  ]),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lock')),
                  ],
                )));
    if (confirm != true) return;

    // Generate summary BEFORE locking statuses change.
    await _generateMonthSummary(widget.business, year, month);
    final count = await AppDatabase.instance.monthLock(widget.business.id, year, month);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$count documents locked for $month/$year.')));
    }
  }

  Future<void> _generateMonthSummary(Business b, int year, int month) async {
    final db = await AppDatabase.instance.db;
    final start = DateTime(year, month, 1).millisecondsSinceEpoch;
    final end = DateTime(year, month + 1, 1).millisecondsSinceEpoch;
    final rows = await db.query('documents',
        where: 'business_id = ? AND issue_date >= ? AND issue_date < ?',
        whereArgs: [b.id, start, end],
        orderBy: 'issue_date');
    final docs = rows.map(Document.fromMap).toList();

    final pdf = pw.Document();
    pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(b.name, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Text('Monthly summary — $month/$year', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
                children: [
                  pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: ['No.', 'Type', 'Status', 'Total']
                          .map((h) => pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text(h, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))))
                          .toList()),
                  ...docs.map((d) => pw.TableRow(children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(d.docNumber, style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(docTypeLabel(d.docType), style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(d.status, style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('${d.total}', style: const pw.TextStyle(fontSize: 9)))),
                      ])),
                  pw.TableRow(children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('', style: const pw.TextStyle(fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('', style: const pw.TextStyle(fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('TOTAL', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(NumberFormat('#,###').format(docs.fold<int>(0, (a, d) => a + d.total)), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)))),
                  ]),
                ],
              ),
            ])));
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/summary_${year}_${month.toString().padLeft(2, '0')}.pdf');
    await file.writeAsBytes(await pdf.save());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Summary saved: ${file.path}'),
          action: SnackBarAction(
              label: 'Share',
              onPressed: () => SharePlus.instance
                  .share(ShareParams(files: [XFile(file.path)])))));
    }
  }

  Future<void> _auditLog() async {
    final rows = await AppDatabase.instance.auditLog();
    if (!mounted) return;
    await showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (_) => ListView(children: [
              for (final r in rows)
                ListTile(
                    dense: true,
                    leading: const Icon(Icons.history),
                    title: Text(r['action'] as String),
                    subtitle: Text(
                        '${DateFormat('dd MMM yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(r['at'] as int))}'
                        '${(r['detail'] as String?) != null ? ' — ${r['detail']}' : ''}'),
                ),
            ]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(children: [
        ListTile(
            leading: const Icon(Icons.store),
            title: Text(widget.business.name),
            subtitle: Text('${widget.business.currency} · Default tax ${widget.business.defaultTaxPercent}%'),
            trailing: IconButton(onPressed: _editBusiness, icon: const Icon(Icons.edit_outlined))),
        ListTile(
            leading: const Icon(Icons.insights),
            title: const Text('Reports & tools'),
            subtitle: const Text('P&L, aging, expenses, recurring, statements, backup'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ReportsPage(business: widget.business)))),
        ListTile(
            leading: const Icon(Icons.ios_share),
            title: const Text('Send queue'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OutboxPage()))),
        ListTile(
            leading: Icon(Icons.workspace_premium,
                color: _sub.isPro
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.tertiary),
            title: Text(_sub.isPro ? 'BizDocs Pro' : 'Upgrade to Pro'),
            subtitle: Text(_sub.isPro
                ? 'Active${_sub.validUntil != null ? ' until ${DateFormat('dd MMM yyyy').format(DateTime.fromMillisecondsSinceEpoch(_sub.validUntil!))}' : ''}'
                : 'Premium templates, no watermark, month lock'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ProPage(isPro: _sub.isPro, onUnlock: () {
                  _subscriptionDialog();
                  _refresh();
                })))),
        ListTile(
            leading: Icon(Icons.lock_clock, color: _sub.isPro ? null : Colors.grey),
            title: const Text('Lock the month'),
            subtitle: const Text('Freeze transactions + monthly summary PDF'),
            onTap: _monthLock),
        ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Audit log'),
            subtitle: const Text('Document lifecycle events'),
            onTap: _auditLog),
        ListTile(
            leading: const Icon(Icons.vpn_key_outlined),
            title: const Text('Pro code admin (JD Hub)'),
            subtitle: const Text('Generate & export unlock codes'),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminCodesPage()))),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Made in Uganda by', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 4),
            Text('Jordan Design Hub (JD Hub)',
                style: Theme.of(context).textTheme.titleMedium),
            Text('Mubogi Gastavas Jordan Tech Ecosystem',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text('jordandesignhub@gmail.com · +256 754 687 597',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Text('BizDocs 1.4.0 · part of the Mubogi ecosystem',
                style: Theme.of(context).textTheme.labelSmall),
          ])),
      ]),
    );
  }
}
