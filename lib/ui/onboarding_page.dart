import 'package:flutter/material.dart';
import '../db/database.dart';
import '../models.dart';
import 'business_setup_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pager = PageController();
  int _page = 0;

  Future<void> _setup() async {
    final b = await Navigator.of(context).push<Business?>(
        MaterialPageRoute(builder: (_) => const BusinessSetupPage()));
    if (b != null && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: PageView(
              controller: _pager,
              onPageChanged: (i) => setState(() => _page = i),
              children: [
                _Slide(
                  icon: Icons.description_outlined,
                  color: cs.primary,
                  title: 'Every document your business needs',
                  body: 'Invoices, receipts, quotations, estimates, delivery notes, '
                      'payment reminders and URA-style e-receipts — all from one phone.',
                ),
                _Slide(
                  icon: Icons.wifi_off,
                  color: cs.primary,
                  title: 'Works with zero internet',
                  body: 'No login. No subscription servers. Sell in the deepest village, '
                      'sign on the spot, send later when network returns.',
                ),
                _Slide(
                  icon: Icons.qr_code_2,
                  color: cs.primary,
                  title: 'EFRIS-ready',
                  body: 'Fiscalize on the URA portal, enter the FDN, and a verifiable '
                      'QR code prints on every document you send.',
                ),
                _Slide(
                  icon: Icons.storefront,
                  color: cs.primary,
                  title: 'Set up in two minutes',
                  body: 'Tell us your business name, add your logo and payment details '
                      '(bank or Mobile Money), and start selling.',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < 4; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _page == i ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: _page == i ? cs.primary : cs.outlineVariant,
                        borderRadius: BorderRadius.circular(4)),
                  ),
              ]),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                    onPressed: _page == 3
                        ? _setup
                        : () => _pager.nextPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut),
                    icon: Icon(_page == 3 ? Icons.check : Icons.arrow_forward),
                    label: Text(_page == 3 ? 'Set up my business' : 'Next')),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _Slide(
      {required this.icon,
      required this.color,
      required this.title,
      required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 80, color: color)),
        const SizedBox(height: 32),
        Text(title,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Text(body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge),
      ]),
    );
  }
}
