import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../db/database.dart';
import '../models.dart';

final _money = NumberFormat('#,###');

class ReportsPage extends StatelessWidget {
  final Business business;
  const ReportsPage({super.key, required this.business});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports & tools')),
      body: ListView(children: [
        ListTile(
            leading: const Icon(Icons.trending_up),
            title: const Text('Profit & loss'),
            subtitle: const Text('Revenue vs expenses, this month'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PnlPage(business: business)))),
        ListTile(
            leading: const Icon(Icons.hourglass_top),
            title: const Text('Invoice aging'),
            subtitle: const Text('Who owes you, by how late'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AgingPage(business: business)))),
        ListTile(
            leading: const Icon(Icons.money_off),
            title: const Text('Expenses'),
            subtitle: const Text('Record business spending'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ExpensesPage(business: business)))),
        ListTile(
            leading: const Icon(Icons.repeat),
            title: const Text('Recurring invoices'),
            subtitle: const Text('Auto-generate on a schedule'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => RecurringPage(business: business)))),
        ListTile(
            leading: const Icon(Icons.contact_page_outlined),
            title: const Text('Customer statement'),
            subtitle: const Text('Full history PDF for one customer'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => StatementPage(business: business)))),
        const Divider(),
        ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Backup & export'),
            subtitle: const Text('JSON backup + CSV of documents'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => BackupPage(business: business)))),
      ]),
    );
  }
}

class PnlPage extends StatefulWidget {
  final Business business;
  const PnlPage({super.key, required this.business});

  @override
  State<PnlPage> createState() => _PnlPageState();
}

class _PnlPageState extends State<PnlPage> {
  Map<String, int>? _data;
  String _period = 'month';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    int? from;
    if (_period == 'week') {
      from = now.subtract(Duration(days: now.weekday - 1)).millisecondsSinceEpoch;
    } else if (_period == 'month') {
      from = DateTime(now.year, now.month).millisecondsSinceEpoch;
    } else if (_period == 'year') {
      from = DateTime(now.year).millisecondsSinceEpoch;
    }
    final data = await AppDatabase.instance.pnl(widget.business.id, fromMillis: from);
    if (mounted) setState(() => _data = data);
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      appBar: AppBar(title: const Text('Profit & loss')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'week', label: Text('Week')),
                ButtonSegment(value: 'month', label: Text('Month')),
                ButtonSegment(value: 'year', label: Text('Year')),
                ButtonSegment(value: 'all', label: Text('All time')),
              ],
              selected: {_period},
              onSelectionChanged: (s) {
                setState(() => _period = s.first);
                _load();
              }),
        ),
        if (d == null)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else
          Expanded(
              child: ListView(padding: const EdgeInsets.all(16), children: [
            _PnLCard(
                title: 'Revenue',
                value: d['revenue'] ?? 0,
                currency: widget.business.currency,
                color: Colors.green.shade700),
            _PnLCard(
                title: 'Expenses',
                value: d['expenses'] ?? 0,
                currency: widget.business.currency,
                color: Colors.red.shade700),
            _PnLCard(
                title: 'Net profit',
                value: d['net'] ?? 0,
                currency: widget.business.currency,
                color: (d['net'] ?? 0) >= 0
                    ? Colors.green.shade900
                    : Colors.red.shade900,
                large: true),
            const SizedBox(height: 12),
            const Text(
                'Revenue counts issued/signed/paid invoices, receipts and e-receipts. '
                'Record expenses under Reports → Expenses to keep this accurate.'),
          ])),
      ]),
    );
  }
}

class _PnLCard extends StatelessWidget {
  final String title;
  final int value;
  final String currency;
  final Color color;
  final bool large;
  const _PnLCard(
      {required this.title,
      required this.value,
      required this.currency,
      required this.color,
      this.large = false});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 16))),
          Text('$currency ${_money.format(value)}',
              style: TextStyle(
                  fontSize: large ? 22 : 16,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ]),
      ),
    );
  }
}

class AgingPage extends StatefulWidget {
  final Business business;
  const AgingPage({super.key, required this.business});

  @override
  State<AgingPage> createState() => _AgingPageState();
}

class _AgingPageState extends State<AgingPage> {
  Map<String, int>? _buckets;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final b = await AppDatabase.instance.agingReport(widget.business.id);
    if (mounted) setState(() => _buckets = b);
  }

  @override
  Widget build(BuildContext context) {
    final b = _buckets;
    final cur = widget.business.currency;
    return Scaffold(
      appBar: AppBar(title: const Text('Invoice aging')),
      body: b == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              for (final k in ['0-30', '31-60', '61-90', '90+'])
                ListTile(
                    leading: Icon(k == '90+'
                        ? Icons.error_outline
                        : Icons.schedule_outlined),
                    title: Text('$k days overdue'),
                    trailing: Text('$cur ${_money.format(b[k] ?? 0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold))),
              const Divider(),
              ListTile(
                  title: const Text('Total outstanding',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  trailing: Text('$cur ${_money.format(b['total'] ?? 0)}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary))),
            ]),
    );
  }
}

class ExpensesPage extends StatefulWidget {
  final Business business;
  const ExpensesPage({super.key, required this.business});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  List<Expense> _expenses = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final e = await AppDatabase.instance.listExpenses(widget.business.id);
    if (mounted) setState(() => _expenses = e);
  }

  Future<void> _add() async {
    final narration = TextEditingController();
    final amount = TextEditingController();
    String category = 'STOCK';
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Record expense'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: narration,
                    decoration: const InputDecoration(labelText: 'What was it?')),
                const SizedBox(height: 8),
                TextField(
                    controller: amount,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: 'Amount (${widget.business.currency})')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                    value: category,
                    items: const [
                      DropdownMenuItem(value: 'STOCK', child: Text('Stock / purchases')),
                      DropdownMenuItem(value: 'RENT', child: Text('Rent')),
                      DropdownMenuItem(value: 'TRANSPORT', child: Text('Transport')),
                      DropdownMenuItem(value: 'WAGES', child: Text('Wages')),
                      DropdownMenuItem(value: 'UTILITIES', child: Text('Utilities')),
                      DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                    ],
                    onChanged: (v) => category = v ?? 'OTHER'),
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
    final amt = int.tryParse(amount.text.replaceAll(RegExp(r'[,\s]'), '')) ?? 0;
    if (amt <= 0 || narration.text.trim().isEmpty) return;
    await AppDatabase.instance.addExpense(Expense(
        id: AppDatabase.newId(),
        businessId: widget.business.id,
        narration: narration.text.trim(),
        amount: amt,
        category: category,
        currency: widget.business.currency,
        expenseAt: DateTime.now().millisecondsSinceEpoch,
        createdAt: DateTime.now().millisecondsSinceEpoch));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM');
    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      body: _expenses.isEmpty
          ? const Center(child: Text('No expenses recorded. Tap + to add.'))
          : ListView.builder(
              itemCount: _expenses.length,
              itemBuilder: (_, i) {
                final e = _expenses[i];
                return ListTile(
                  leading: const Icon(Icons.money_off),
                  title: Text(e.narration),
                  subtitle: Text(
                      '${e.category} · ${df.format(DateTime.fromMillisecondsSinceEpoch(e.expenseAt))}'),
                  trailing: Text('${e.currency} ${_money.format(e.amount)}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                );
              }),
      floatingActionButton:
          FloatingActionButton(onPressed: _add, child: const Icon(Icons.add)),
    );
  }
}

class RecurringPage extends StatefulWidget {
  final Business business;
  const RecurringPage({super.key, required this.business});

  @override
  State<RecurringPage> createState() => _RecurringPageState();
}

class _RecurringPageState extends State<RecurringPage> {
  List<RecurringInvoice> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r =
        await AppDatabase.instance.listRecurringInvoices(widget.business.id);
    if (mounted) setState(() => _items = r);
  }

  Future<void> _add() async {
    final customers =
        await AppDatabase.instance.listCustomers(widget.business.id);
    if (!mounted) return;
    Customer? customer = customers.isNotEmpty ? customers.first : null;
    final amount = TextEditingController();
    final desc = TextEditingController();
    int interval = 30;
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
              builder: (ctx2, setLocal) => AlertDialog(
                title: const Text('Recurring invoice'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (customers.isNotEmpty)
                    DropdownButtonFormField<Customer>(
                        value: customer,
                        decoration: const InputDecoration(labelText: 'Customer'),
                        items: customers
                            .map((c) =>
                                DropdownMenuItem(value: c, child: Text(c.name)))
                            .toList(),
                        onChanged: (v) => setLocal(() => customer = v)),
                  TextField(
                      controller: desc,
                      decoration:
                          const InputDecoration(labelText: 'Item description')),
                  TextField(
                      controller: amount,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: 'Amount (${widget.business.currency})')),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                      value: interval,
                      decoration: const InputDecoration(labelText: 'Repeat every'),
                      items: const [
                        DropdownMenuItem(value: 7, child: Text('7 days (weekly)')),
                        DropdownMenuItem(value: 14, child: Text('14 days')),
                        DropdownMenuItem(value: 30, child: Text('30 days (monthly)')),
                        DropdownMenuItem(value: 90, child: Text('90 days (quarterly)')),
                      ],
                      onChanged: (v) => setLocal(() => interval = v ?? 30)),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Save')),
                ],
              ),
            ));
    if (ok != true) return;
    final amt = int.tryParse(amount.text.replaceAll(RegExp(r'[,\s]'), '')) ?? 0;
    if (amt <= 0 || desc.text.trim().isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await AppDatabase.instance.upsertRecurringInvoice(RecurringInvoice(
        id: AppDatabase.newId(),
        businessId: widget.business.id,
        customerId: customer?.id,
        docType: 'INVOICE',
        itemsJson: jsonEncode([
          {'description': desc.text.trim(), 'quantity': 1, 'unit_price': amt}
        ]),
        currency: widget.business.currency,
        amount: amt,
        intervalDays: interval,
        nextDue: now + interval * 24 * 3600 * 1000,
        createdAt: now));
    await _load();
  }

  Future<void> _generateDue() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final due = _items.where((r) => r.nextDue <= now).toList();
    if (due.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No recurring invoices are due yet.')));
      return;
    }
    var created = 0;
    for (final r in due) {
      final number = await AppDatabase.instance
          .nextDocNumber(widget.business.id, DocType.invoice);
      final items = (jsonDecode(r.itemsJson) as List)
          .map((m) => DocumentItem(
              id: AppDatabase.newId(),
              documentId: '',
              description: m['description'] as String,
              quantity: (m['quantity'] as num).toDouble(),
              unitPrice: (m['unit_price'] as num).toInt(),
              lineTotal: ((m['quantity'] as num) * (m['unit_price'] as num)).round()))
          .toList();
      final docId = AppDatabase.newId();
      for (final it in items) {
        it.documentId = docId;
      }
      final doc = Document(
          id: docId,
          businessId: widget.business.id,
          customerId: r.customerId,
          docType: DocType.invoice,
          docNumber: number,
          issueDate: now,
          currency: r.currency,
          terms: widget.business.termsTemplate,
          createdAt: now,
          updatedAt: now);
      await AppDatabase.instance.saveDocument(doc, items);
      await AppDatabase.instance.updateDocumentTotals(docId);
      r.nextDue = now + r.intervalDays * 24 * 3600 * 1000;
      await AppDatabase.instance.upsertRecurringInvoice(r);
      created++;
    }
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$created invoice(s) generated. Find them in Documents.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy');
    return Scaffold(
      appBar: AppBar(title: const Text('Recurring invoices'), actions: [
        IconButton(
            tooltip: 'Generate due invoices now',
            onPressed: _generateDue,
            icon: const Icon(Icons.play_circle_outline)),
      ]),
      body: _items.isEmpty
          ? const Center(child: Text('No schedules. Tap + to add one.'))
          : ListView.builder(
              itemCount: _items.length,
              itemBuilder: (_, i) {
                final r = _items[i];
                final overdue = r.nextDue <= DateTime.now().millisecondsSinceEpoch;
                return ListTile(
                  leading: Icon(Icons.repeat,
                      color: overdue ? Colors.red : null),
                  title: Text('${r.currency} ${_money.format(r.amount)}'),
                  subtitle: Text(
                      'Every ${r.intervalDays} days · next ${df.format(DateTime.fromMillisecondsSinceEpoch(r.nextDue))}'
                      '${overdue ? ' · DUE NOW' : ''}'),
                  trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await AppDatabase.instance.deleteRecurringInvoice(r.id);
                        await _load();
                      }),
                );
              }),
      floatingActionButton:
          FloatingActionButton(onPressed: _add, child: const Icon(Icons.add)),
    );
  }
}

class StatementPage extends StatefulWidget {
  final Business business;
  const StatementPage({super.key, required this.business});

  @override
  State<StatementPage> createState() => _StatementPageState();
}

class _StatementPageState extends State<StatementPage> {
  List<Customer> _customers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await AppDatabase.instance.listCustomers(widget.business.id);
    if (mounted) setState(() => _customers = c);
  }

  Future<void> _statement(Customer c) async {
    final db = await AppDatabase.instance.db;
    final rows = await db.query('documents',
        where: 'customer_id = ? AND doc_type IN (?,?,?)',
        whereArgs: [c.id, 'INVOICE', 'RECEIPT', 'URERECEIPT'],
        orderBy: 'issue_date ASC');
    final docs = rows.map(Document.fromMap).toList();
    if (docs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No transactions for ${c.name}.')));
      }
      return;
    }
    final df = DateFormat('dd MMM yyyy');
    var running = 0;
    final lines = <List<String>>[];
    for (final d in docs) {
      final paid = await AppDatabase.instance.totalPaid(d.id);
      running += d.total - paid;
      lines.add([
        df.format(DateTime.fromMillisecondsSinceEpoch(d.issueDate)),
        d.docNumber,
        docTypeLabel(d.docType),
        _money.format(d.total),
        _money.format(paid),
        _money.format(running),
      ]);
    }
    // Simple text statement exported as CSV-style, shareable immediately.
    final buffer = StringBuffer()
      ..writeln('STATEMENT OF ACCOUNT')
      ..writeln(widget.business.name)
      ..writeln('Customer: ${c.name}')
      ..writeln('Generated: ${df.format(DateTime.now())}')
      ..writeln('')
      ..writeln('Date,Number,Type,Amount,Paid,Balance');
    for (final l in lines) {
      buffer.writeln(l.join(','));
    }
    buffer
      ..writeln('')
      ..writeln('Outstanding balance,${widget.business.currency} ${_money.format(running)}');
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
        '${dir.path}/statement_${c.name.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_')}.csv');
    await file.writeAsString(buffer.toString());
    if (mounted) {
      await SharePlus.instance.share(ShareParams(
          files: [XFile(file.path)], text: 'Statement for ${c.name}'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customer statement')),
      body: _customers.isEmpty
          ? const Center(child: Text('Add customers first.'))
          : ListView.builder(
              itemCount: _customers.length,
              itemBuilder: (_, i) {
                final c = _customers[i];
                return ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(c.name),
                    trailing: const Icon(Icons.download_outlined),
                    onTap: () => _statement(c));
              }),
    );
  }
}

class BackupPage extends StatelessWidget {
  final Business business;
  const BackupPage({super.key, required this.business});

  Future<void> _exportJson(BuildContext context) async {
    final db = await AppDatabase.instance.db;
    final dump = <String, dynamic>{
      'exported_at': DateTime.now().toIso8601String(),
      'business': (await db.query('businesses')).firstOrNull,
      'customers': await db.query('customers'),
      'products': await db.query('products'),
      'documents': await db.query('documents'),
      'document_items': await db.query('document_items'),
      'payments': await db.query('payments'),
      'expenses': await db.query('expenses'),
    };
    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final file = File('${dir.path}/bizdocs_backup_$stamp.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(dump));
    if (context.mounted) {
      await SharePlus.instance.share(ShareParams(
          files: [XFile(file.path)],
          text: 'BizDocs backup $stamp — keep this file safe.'));
    }
  }

  Future<void> _exportCsv(BuildContext context) async {
    final docs =
        await AppDatabase.instance.listDocuments(business.id);
    final df = DateFormat('yyyy-MM-dd');
    final buffer = StringBuffer()
      ..writeln('number,type,status,customer_id,issue_date,due_date,subtotal,discount,tax,total,currency');
    for (final d in docs) {
      buffer.writeln([
        d.docNumber,
        d.docType.name,
        d.status,
        d.customerId ?? '',
        df.format(DateTime.fromMillisecondsSinceEpoch(d.issueDate)),
        d.dueDate != null
            ? df.format(DateTime.fromMillisecondsSinceEpoch(d.dueDate!))
            : '',
        d.subtotal,
        d.discountTotal,
        d.taxTotal,
        d.total,
        d.currency,
      ].join(','));
    }
    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final file = File('${dir.path}/bizdocs_documents_$stamp.csv');
    await file.writeAsString(buffer.toString());
    if (context.mounted) {
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & export')),
      body: ListView(padding: const EdgeInsets.all(8), children: [
        ListTile(
            leading: const Icon(Icons.save_alt),
            title: const Text('Full backup (JSON)'),
            subtitle: const Text(
                'Everything: business, customers, products, documents, payments, expenses'),
            onTap: () => _exportJson(context)),
        ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: const Text('Documents (CSV)'),
            subtitle: const Text('Opens in Excel — for your accountant'),
            onTap: () => _exportCsv(context)),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
              'Backups are saved on this device and shared via the share sheet. '
              'Send the JSON to your email or WhatsApp to keep a copy off the phone.'),
        ),
      ]),
    );
  }
}
