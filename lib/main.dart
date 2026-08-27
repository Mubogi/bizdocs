import 'package:flutter/material.dart';
import 'db/database.dart';
import 'models.dart';
import 'ui/documents_page.dart';
import 'ui/customers_page.dart';
import 'ui/products_page.dart';
import 'ui/more_page.dart';
import 'ui/onboarding_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BizDocsApp());
}

class BizDocsApp extends StatelessWidget {
  const BizDocsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BizDocs',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F7A3D)),
        useMaterial3: true,
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  Business? _business;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _loadBusiness();
  }

  Future<void> _loadBusiness() async {
    final b = await AppDatabase.instance.getBusiness();
    if (!mounted) return;
    if (b == null) {
      final done = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const OnboardingPage()));
      if (done == true) {
        _business = await AppDatabase.instance.getBusiness();
      }
      if (_business == null) return;
    } else {
      _business = b;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_business == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final pages = [
      DocumentsPage(business: _business!),
      CustomersPage(business: _business!),
      ProductsPage(business: _business!),
      MorePage(business: _business!, onBusinessChanged: _loadBusiness),
    ];
    return Scaffold(
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.description_outlined), label: 'Docs'),
          NavigationDestination(icon: Icon(Icons.people_outlined), label: 'Customers'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Products'),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}
