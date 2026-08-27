import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../pro_codes.dart';

/// JD Hub admin: create/copy/export Pro codes. Guarded by PIN.
class AdminCodesPage extends StatefulWidget {
  const AdminCodesPage({super.key});

  @override
  State<AdminCodesPage> createState() => _AdminCodesPageState();
}

class _AdminCodesPageState extends State<AdminCodesPage> {
  bool _unlocked = false;
  List<GeneratedCode> _codes = [];

  Future<void> _tryUnlock() async {
    final pin = TextEditingController();
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('JD Hub admin'),
              content: TextField(
                  controller: pin,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Admin PIN')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Enter')),
              ],
            ));
    if (ok == true && await checkAdminPin(pin.text)) {
      setState(() => _unlocked = true);
      _load();
    } else if (ok == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Wrong PIN.')));
    }
  }

  Future<void> _load() async {
    final list = await ProCodeStore.list();
    if (mounted) setState(() => _codes = list);
  }

  Future<void> _create() async {
    final note = TextEditingController();
    int months = 12;
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
              builder: (ctx2, setLocal) => AlertDialog(
                title: const Text('New Pro code'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  DropdownButtonFormField<int>(
                      value: months,
                      decoration: const InputDecoration(labelText: 'Valid for'),
                      items: const [1, 3, 6, 12, 24]
                          .map((m) => DropdownMenuItem(
                              value: m, child: Text('$m month${m == 1 ? '' : 's'}')))
                          .toList(),
                      onChanged: (v) => setLocal(() => months = v ?? 12)),
                  TextField(
                      controller: note,
                      decoration: const InputDecoration(
                          labelText: 'Buyer (optional note)')),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Generate')),
                ],
              ),
            ));
    if (ok != true) return;
    final expiry = DateTime.now().add(Duration(days: months * 30));
    final gc = await ProCodeStore.create(expiry,
        note: note.text.trim().isEmpty ? null : note.text.trim());
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Code: ${gc.code}'), duration: const Duration(seconds: 8)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy');
    return Scaffold(
      appBar: AppBar(title: const Text('Pro code admin')),
      body: !_unlocked
          ? Center(
              child: FilledButton.icon(
                  onPressed: _tryUnlock,
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Unlock with admin PIN')),
            )
          : Column(children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(
                      child: FilledButton.icon(
                          onPressed: _create,
                          icon: const Icon(Icons.add),
                          label: const Text('New code'))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: OutlinedButton.icon(
                          onPressed: () => ProCodeStore.exportShare(),
                          icon: const Icon(Icons.share),
                          label: const Text('Export all'))),
                ]),
              ),
              Expanded(
                child: ListView.builder(
                    itemCount: _codes.length,
                    itemBuilder: (_, i) {
                      final c = _codes[i];
                      final expired =
                          c.expiry < DateTime.now().millisecondsSinceEpoch;
                      return ListTile(
                        leading: Icon(
                            expired ? Icons.history : Icons.verified_outlined,
                            color: expired ? Colors.grey : Colors.green),
                        title: SelectableText(c.code,
                            style: const TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            'expires ${df.format(DateTime.fromMillisecondsSinceEpoch(c.expiry))}'
                            '${(c.note ?? '').isNotEmpty ? ' · ${c.note}' : ''}'),
                      );
                    }),
              ),
            ]),
    );
  }
}
