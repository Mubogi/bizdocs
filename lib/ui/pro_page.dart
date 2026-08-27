import 'package:flutter/material.dart';
import '../pdf_doc.dart' show PdfLayout, pdfLayoutNames, pdfLayoutDescriptions;

/// Sales page that shows exactly what Pro unlocks.
class ProPage extends StatelessWidget {
  final bool isPro;
  final VoidCallback onUnlock;
  const ProPage({super.key, required this.isPro, required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('BizDocs Pro')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                cs.primary,
                cs.primaryContainer,
              ]),
              borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.workspace_premium,
                size: 40, color: Theme.of(context).colorScheme.onPrimary),
            const SizedBox(height: 8),
            Text('One code. A year of Pro.',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: cs.onPrimary, fontWeight: FontWeight.bold)),
            Text(isPro
                ? 'Pro is active on this device.'
                : 'UGX 15,000 / year — buy once, works fully offline.',
                style: TextStyle(color: cs.onPrimary.withValues(alpha: 0.9))),
          ]),
        ),
        const SizedBox(height: 16),
        _Benefit(icon: Icons.palette_outlined, title: 'Premium document designs',
            body: 'Modern+, Elegant and Minimal templates that make your '
                'invoices look like they came from an agency.'),
        _Benefit(icon: Icons.no_photography_outlined, title: 'No watermark',
            body: 'The "Generated with BizDocs" footer disappears. Your brand stands alone.'),
        _Benefit(icon: Icons.lock_clock, title: 'Month-end lock',
            body: 'Freeze a month\'s documents. No one can quietly edit last month\'s sales.'),
        _Benefit(icon: Icons.priority_high, title: 'Priority templates roadmap',
            body: 'New designs land in Pro first — EFRIS auto-mode, branded themes, more.'),
        if (!isPro) ...[
          const SizedBox(height: 16),
          Text('How it works',
              style: Theme.of(context).textTheme.titleMedium),
          const ListTile(
              leading: Icon(Icons.looks_one_outlined),
              title: Text('Buy a code from JD Hub'),
              subtitle: Text('WhatsApp +256 754 687 597 · jordandesignhub@gmail.com · UGX 15,000/year')),
          const ListTile(
              leading: Icon(Icons.looks_two_outlined),
              title: Text('Enter it once'),
              subtitle: Text('Pro stays active for a full year. No internet needed — codes are cryptographically signed offline.')),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Text('Premium designs',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final l in PdfLayout.values.skip(1))
                  ListTile(
                      dense: true,
                      leading: const Icon(Icons.check_circle_outline, size: 18),
                      title: Text(pdfLayoutNames[l]!),
                      subtitle: Text(pdfLayoutDescriptions[l]!)),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
                onPressed: onUnlock,
                icon: const Icon(Icons.key),
                label: const Text('Enter Pro code')),
          ),
          TextButton(
              onPressed: () {
                showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                          title: const Text('Buy a code'),
                          content: const Text(
                              'WhatsApp +256 754 687 597 or email jordandesignhub@gmail.com '
                              '— UGX 15,000/year, Mobile Money accepted. Codes arrive instantly.'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('OK')),
                          ],
                        ));
              },
              child: const Text('Where do I buy a code?')),
        ] else
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Card(
              color: cs.primaryContainer,
              child: const ListTile(
                  leading: Icon(Icons.verified),
                  title: Text('Pro is active'),
                  subtitle: Text(
                      'Premium designs unlocked in Business settings → Document design.')),
            ),
          ),
      ]),
    );
  }
}

class _Benefit extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _Benefit({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(body));
  }
}
