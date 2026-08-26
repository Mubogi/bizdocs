import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

class PdfPreviewPage extends StatelessWidget {
  final Future<Uint8List> Function() buildPdf;
  final String title;

  const PdfPreviewPage(
      {super.key, required this.buildPdf, this.title = 'Preview'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: PdfPreview(build: (_) => buildPdf()),
    );
  }
}
