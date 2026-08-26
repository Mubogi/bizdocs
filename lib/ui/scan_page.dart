import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Camera page that returns the first barcode value detected.
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final _controller = MobileScannerController();
  bool _found = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan barcode'), actions: [
        IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch()),
      ]),
      body: Stack(children: [
        MobileScanner(
          controller: _controller,
          onDetect: (capture) {
            if (_found) return;
            final code = capture.barcodes
                .map((b) => b.rawValue)
                .whereType<String>()
                .firstOrNull;
            if (code != null && code.isNotEmpty) {
              _found = true;
              Navigator.of(context).pop(code);
            }
          },
        ),
        Center(
            child: Container(
                width: 240,
                height: 140,
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                    borderRadius: BorderRadius.circular(12)))),
        const Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Point the camera at a product barcode',
                    style: TextStyle(color: Colors.white)))),
      ]),
    );
  }
}
