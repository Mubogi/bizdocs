import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

class SignatureResult {
  final Uint8List bytes;
  final String? name;
  SignatureResult(this.bytes, this.name);
}

class SignaturePage extends StatefulWidget {
  const SignaturePage({super.key});

  @override
  State<SignaturePage> createState() => _SignaturePageState();
}

class _SignaturePageState extends State<SignaturePage> {
  late final SignatureController _controller;
  final _name = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = SignatureController(penStrokeWidth: 3, penColor: Colors.black);
  }

  @override
  void dispose() {
    _controller.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_controller.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign first.')));
      return;
    }
    final bytes = await _controller.toPngBytes();
    if (bytes == null) return;
    if (!mounted) return;
    Navigator.of(context).pop(SignatureResult(
        bytes, _name.text.trim().isEmpty ? null : _name.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Customer signature'),
          actions: [
            TextButton(onPressed: _controller.clear, child: const Text('Clear')),
          ]),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
                controller: _name,
                decoration: const InputDecoration(
                    labelText: 'Signer name (optional)',
                    border: OutlineInputBorder()))),
        Expanded(
            child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                    color: Colors.white, border: Border.all(color: Colors.grey)),
                child: Signature(
                    controller: _controller,
                    backgroundColor: Colors.white))),
        const SizedBox(height: 16),
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                    onPressed: _confirm,
                    icon: const Icon(Icons.check),
                    label: const Text('Confirm signature')))),
      ]),
    );
  }
}
