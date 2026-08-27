import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database.dart';
import '../models.dart';
import 'documents_page.dart';
import 'customers_page.dart';
import 'products_page.dart';
import 'reports_page.dart';
import 'outbox_page.dart';

final _money = NumberFormat('#,###');

class DashboardPage extends StatefulWidget {
  final Business business;
  const DashboardPage({super.key, required this.business});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _outstanding = 0;
  int _docCount = 0;
  Map<String, int>? _pnl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = AppDatabase.instance;
    final aging = await db.agingReport(widget.business.id);
    final docs =
        await db.listDocuments(widget.business.id);
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month).millisecondsSinceEpoch;
    final pnl = await db.pnl(widget.business.id, fromMillis: monthStart);
    if (!mounted) return;
    setState(() {
      _outstanding = aging['total'] ?? 0;
      _docCount = docs.length;
      _pnl = pnl;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final b = widget.business;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        // Hero business card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                cs.primary,
                Color.lerp(cs.primary, cs.secondary, 0.5)!
              ]),
              borderRadius: BorderRadius.circular(20)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(
                  radius: 26,
                  backgroundColor: cs.onPrimary,
                  child: Text(
                      b.name.isNotEmpty ? b.name[0].toUpperCase() : 'B',
                      style: TextStyle(
                          color: cs.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 24))),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(b.name,
                        style: TextStyle(
                            color: cs.onPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    Text('${_docCount} documents · ${b.currency}',
                        style: TextStyle(
                            color: cs.onPrimary.withValues(alpha: 0.85))),
                  ])),
            ]),
            const SizedBox(height: 16),
            Text('Outstanding balance',
                style: TextStyle(
                    color: cs.onPrimary.withValues(alpha: 0.85), fontSize: 12)),
            Text('${b.currency} ${_money.format(_outstanding)}',
                style: TextStyle(
                    color: cs.onPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold)),
          ]),
        ),
        const SizedBox(height: 20),
        // Stats row
        Row(children: [
          Expanded(
              child: _Stat(
                  icon: Icons.receipt_long_outlined,
                  label: 'This month',
                  value: '${b.currency} ${_money.format(_pnl?['revenue'] ?? 0)}',
                  onTap: () => _open(ReportsPage(business: b)))),
          const SizedBox(width: 12),
          Expanded(
              child: _Stat(
                  icon: Icons.hourglass_top_outlined,
                  label: 'Overdue',
                  value: '${b.currency} ${_money.format(_outstanding)}',
                  onTap: () => _open(ReportsPage(business: b)))),
        ]),
        const SizedBox(height: 20),
        Text('Quick actions', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 12, children: [
          _Action(
              icon: Icons.description_outlined,
              label: 'Documents',
              onTap: () => _open(DocumentsPage(business: b))),
          _Action(
              icon: Icons.people_outlined,
              label: 'Customers',
              onTap: () => _open(CustomersPage(business: b))),
          _Action(
              icon: Icons.inventory_2_outlined,
              label: 'Products',
              onTap: () => _open(ProductsPage(business: b))),
          _Action(
              icon: Icons.insights_outlined,
              label: 'Reports',
              onTap: () => _open(ReportsPage(business: b))),
          _Action(
              icon: Icons.ios_share_outlined,
              label: 'Send queue',
              onTap: () => _open(const OutboxPage())),
        ]),
        const SizedBox(height: 24),
        // Recent documents
        Text('Recent documents', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        FutureBuilder<List<Document>>(
          future: AppDatabase.instance.listDocuments(widget.business.id),
          builder: (context, snap) {
            final docs = snap.data ?? [];
            if (docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                    child: Text('No documents yet. Create your first one!')),
              );
            }
            return Column(children: [
              for (final d in docs.take(5))
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                        backgroundColor: cs.primaryContainer,
                        child: Icon(_iconFor(d.docType), color: cs.primary)),
                    title: Text(d.docNumber),
                    subtitle: Text(
                        '${docTypeLabel(d.docType)} · ${d.status}${d.locked ? ' 🔒' : ''}'),
                    trailing: d.total > 0
                        ? Text('${d.currency} ${_money.format(d.total)}',
                            style: const TextStyle(fontWeight: FontWeight.bold))
                        : null,
                    onTap: () => _open(DocumentsPage(business: b))),
            ]);
          },
        ),
      ]),
    );
  }

  void _open(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  IconData _iconFor(DocType t) => {
        DocType.invoice: Icons.receipt,
        DocType.receipt: Icons.payments,
        DocType.quotation: Icons.request_quote,
        DocType.letter: Icons.mail_outline,
        DocType.estimate: Icons.calculate_outlined,
        DocType.deliveryNote: Icons.local_shipping_outlined,
        DocType.proforma: Icons.description_outlined,
        DocType.uraReceipt: Icons.verified_outlined,
        DocType.reminder: Icons.notification_important_outlined,
      }[t]!;
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  const _Stat(
      {required this.icon,
      required this.label,
      required this.value,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: cs.primary, size: 20),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
                overflow: TextOverflow.ellipsis),
          ]),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Action({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minWidth: 102),
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            Icon(icon, color: cs.primary),
            const SizedBox(height: 6),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ]),
        ),
      ),
    );
  }
}
