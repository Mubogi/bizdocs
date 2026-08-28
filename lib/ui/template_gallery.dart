import 'package:flutter/material.dart';
import '../db/database.dart';
import '../models.dart';
import '../pdf_layouts.dart';

/// Grid gallery: every template rendered as a live mini-preview so users
/// see exactly what they pick. Free templates usable; PRO ones watermarked.
class TemplateGallery extends StatefulWidget {
  final Business business;
  final PdfLayout selected;
  final void Function(PdfLayout) onSelect;
  const TemplateGallery(
      {super.key,
      required this.business,
      required this.selected,
      required this.onSelect});

  @override
  State<TemplateGallery> createState() => _TemplateGalleryState();
}

class _TemplateGalleryState extends State<TemplateGallery> {
  bool _isPro = false;

  @override
  void initState() {
    super.initState();
    AppDatabase.instance.subscription().then((s) {
      if (mounted) setState(() => _isPro = s.isPro);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, childAspectRatio: 0.66,
          crossAxisSpacing: 8, mainAxisSpacing: 8),
      itemCount: PdfLayout.values.length,
      itemBuilder: (_, i) {
        final l = PdfLayout.values[i];
        final isFree = !(pdfLayoutIsPro[l] ?? true);
        final locked = !isFree && !_isPro;
        final selected = l == widget.selected;
        return _TemplateCard(
            layout: l,
            business: widget.business,
            locked: locked,
            selected: selected,
            onTap: locked ? null : () => widget.onSelect(l));
      },
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final PdfLayout layout;
  final Business business;
  final bool locked;
  final bool selected;
  final VoidCallback? onTap;
  const _TemplateCard(
      {required this.layout,
      required this.business,
      required this.locked,
      required this.selected,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: selected ? cs.primaryContainer : cs.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: selected ? cs.primary : cs.outlineVariant,
                  width: selected ? 2.5 : 1)),
          child: Column(children: [
            Expanded(child: TemplatePreview(layout: layout, business: business)),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              decoration: BoxDecoration(
                  color: selected ? cs.primary : cs.surfaceContainerHighest,
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(9))),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Flexible(
                    child: Text(pdfLayoutNames[layout]!,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: selected
                                ? cs.onPrimary
                                : cs.onSurfaceVariant))),
                if (locked) ...[
                  const SizedBox(width: 3),
                  Icon(Icons.lock,
                      size: 10,
                      color: selected ? cs.onPrimary : cs.tertiary),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// A miniature live preview of a template, painted in Flutter.
class TemplatePreview extends StatelessWidget {
  final PdfLayout layout;
  final Business business;
  const TemplatePreview({super.key, required this.layout, required this.business});

  @override
  Widget build(BuildContext context) {
    final (c1, c2) = layoutColors(layout);
    final a = Color(c1);
    final b = Color(c2);
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
      child: Container(
        color: Colors.white,
        child: CustomPaint(
            painter: _PreviewPainter(
                layout: layout, a: a, b: b, name: business.name)),
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  final PdfLayout layout;
  final Color a;
  final Color b;
  final String name;
  _PreviewPainter(
      {required this.layout, required this.a, required this.b, required this.name});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint();
    final rows = _fakeRows(canvas, w, h);

    switch (layout) {
      case PdfLayout.classic:
      case PdfLayout.modernBlue:
      case PdfLayout.simpleGreen:
        paint.color = a;
        canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.28), paint);
        _whiteBlocks(canvas, w, h * 0.28);
        rows();
        break;
      case PdfLayout.modern:
        paint.color = a;
        canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h * 0.3),
                const Radius.circular(14)),
            paint);
        _whiteBlocks(canvas, w, h * 0.3);
        rows();
        break;
      case PdfLayout.elegant:
        _centerName(canvas, w, h * 0.1);
        paint.color = a;
        canvas.drawRect(Rect.fromLTWH(w * 0.1, h * 0.24, w * 0.8, 1.6), paint);
        canvas.drawRect(Rect.fromLTWH(w * 0.2, h * 0.27, w * 0.6, 0.8), paint);
        _centerMeta(canvas, w, h * 0.32);
        rows();
        break;
      case PdfLayout.minimal:
        _leftName(canvas, w, h * 0.08);
        paint.color = a;
        canvas.drawRect(Rect.fromLTWH(w * 0.08, h * 0.22, w * 0.84, 1), paint);
        rows();
        break;
      case PdfLayout.sideBand:
        paint.color = a;
        canvas.drawRect(Rect.fromLTWH(0, 0, w * 0.16, h), paint);
        _leftName(canvas, w * 0.2, h * 0.08, offset: w * 0.2);
        rows(dx: w * 0.2);
        break;
      case PdfLayout.gradient:
        paint.shader = LinearGradient(colors: [a, b]).createShader(
            Rect.fromLTWH(0, 0, w, h * 0.3));
        canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.3), paint);
        _whiteBlocks(canvas, w, h * 0.3);
        rows();
        break;
      case PdfLayout.boldType:
        final tp = TextPainter(
            text: TextSpan(
                text: name.isEmpty ? 'B' : name[0].toUpperCase(),
                style: TextStyle(
                    color: a, fontSize: h * 0.2, fontWeight: FontWeight.w900)),
            textDirection: TextDirection.ltr)
          ..layout();
        tp.paint(canvas, Offset(w * 0.08, h * 0.02));
        rows(dy: h * 0.24);
        break;
      case PdfLayout.scandinavian:
        _leftName(canvas, w, h * 0.08);
        rows(borderless: true);
        break;
      case PdfLayout.twoColumn:
        _centerName(canvas, w, h * 0.08);
        paint.color = a;
        canvas.drawRect(Rect.fromLTWH(w * 0.2, h * 0.2, w * 0.6, 1), paint);
        _centerMeta(canvas, w, h * 0.26);
        rows();
        break;
      case PdfLayout.boldStationary:
        _leftName(canvas, w, h * 0.08);
        paint.color = a;
        canvas.drawRect(
            Rect.fromLTWH(w * 0.55, h * 0.04, w * 0.4, h * 0.14), paint);
        rows();
        break;
      case PdfLayout.bigPrice:
        _leftName(canvas, w, h * 0.06);
        paint.color = a.withValues(alpha: 0.15);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(w * 0.15, h * 0.16, w * 0.7, h * 0.16),
                const Radius.circular(8)),
            paint);
        rows(dy: h * 0.38);
        break;
      case PdfLayout.geometric:
        paint.color = a;
        canvas.drawRect(Rect.fromLTWH(0, 0, w * 0.35, h * 0.05), paint);
        paint.color = b;
        canvas.drawRect(Rect.fromLTWH(w * 0.35, 0, w * 0.2, h * 0.05), paint);
        paint.color = a.withValues(alpha: 0.4);
        canvas.drawRect(Rect.fromLTWH(w * 0.55, 0, w * 0.45, h * 0.05), paint);
        _leftName(canvas, w, h * 0.1, dy: h * 0.08);
        rows(dy: h * 0.24);
        break;
      case PdfLayout.footerBanner:
        _leftName(canvas, w, h * 0.06);
        rows();
        paint.color = a.withValues(alpha: 0.2);
        canvas.drawRect(Rect.fromLTWH(0, h * 0.85, w, h * 0.15), paint);
        break;
      case PdfLayout.navy:
        paint.color = a;
        canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.26), paint);
        _whiteBlocks(canvas, w, h * 0.26);
        rows();
        break;
      case PdfLayout.script:
        _centerName(canvas, w, h * 0.1);
        paint.color = a;
        canvas.drawRect(Rect.fromLTWH(w * 0.15, h * 0.26, w * 0.7, 0.8), paint);
        _centerMeta(canvas, w, h * 0.32);
        rows();
        break;
      case PdfLayout.framedGold:
        paint
          ..color = a
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawRect(Rect.fromLTWH(3, 3, w - 6, h - 6), paint);
        canvas.drawRect(Rect.fromLTWH(6, 6, w - 12, h - 12), paint..strokeWidth = 0.8);
        paint.style = PaintingStyle.fill;
        _centerName(canvas, w, h * 0.12);
        rows();
        break;
      case PdfLayout.monochrome:
        _leftName(canvas, w, h * 0.08);
        paint.color = Colors.black;
        canvas.drawRect(Rect.fromLTWH(w * 0.08, h * 0.2, w * 0.84, 2), paint);
        rows(borderless: true);
        break;
      case PdfLayout.twoToneSplit:
        paint.color = a.withValues(alpha: 0.15);
        canvas.drawRect(Rect.fromLTWH(0, 0, w * 0.4, h), paint);
        _leftName(canvas, w * 0.4, h * 0.08);
        rows(dx: w * 0.44);
        break;
      case PdfLayout.accentBar:
        _leftName(canvas, w, h * 0.06);
        rows();
        paint.color = a;
        canvas.drawRect(Rect.fromLTWH(0, h * 0.88, w, h * 0.04), paint);
        break;
      case PdfLayout.roundedCard:
        paint.color = a.withValues(alpha: 0.12);
        canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h * 0.3),
                const Radius.circular(12)),
            paint);
        _leftName(canvas, w, h * 0.07, dy: h * 0.03);
        rows(dy: h * 0.32);
        break;
    }
  }

  void _whiteBlocks(Canvas canvas, double w, double hh) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.9);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.08, hh * 0.25, w * 0.3, hh * 0.18),
            const Radius.circular(2)),
        paint);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.08, hh * 0.52, w * 0.45, hh * 0.1),
            const Radius.circular(2)),
        paint..color = Colors.white.withValues(alpha: 0.6));
  }

  void _leftName(Canvas canvas, double w, double hh, {double offset = 0, double dy = 0}) {
    final tp = TextPainter(
        text: TextSpan(
            text: name.isEmpty ? 'Business' : name,
            style: TextStyle(
                color: Colors.black87,
                fontSize: hh * 0.5,
                fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr)
      ..layout(maxWidth: w * 0.8);
    tp.paint(canvas, Offset(w * 0.08 + offset, w * 0.05 + dy));
  }

  void _centerName(Canvas canvas, double w, double hh) {
    final tp = TextPainter(
        text: TextSpan(
            text: name.isEmpty ? 'Business' : name,
            style: TextStyle(
                color: Colors.black87,
                fontSize: hh * 0.5,
                fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr)
      ..layout(maxWidth: w * 0.9);
    tp.paint(canvas, Offset((w - tp.width) / 2, hh * 0.4));
  }

  void _centerMeta(Canvas canvas, double w, double dy) {
    final paint = Paint()..color = Colors.black38;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.35, dy, w * 0.3, 4), const Radius.circular(2)),
        paint);
  }

  void Function({double dx, double dy, bool borderless}) _fakeRows(
      Canvas canvas, double w, double h) {
    return ({double dx = 0, double dy = 0, bool borderless = false}) {
      final paint = Paint();
      // header row
      paint.color = a.withValues(alpha: 0.25);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(w * 0.08 + dx, h * 0.36 + dy, w * 0.84 - dx, 5),
              const Radius.circular(2)),
          paint);
      // item rows
      for (var i = 0; i < 3; i++) {
        paint.color = borderless
            ? Colors.black.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: i.isEven ? 0.06 : 0.12);
        final y = h * 0.44 + dy + i * (h * 0.09);
        if (!borderless) {
          canvas.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromLTWH(w * 0.08 + dx, y, w * 0.84 - dx, h * 0.06),
                  const Radius.circular(3)),
              paint);
        } else {
          canvas.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromLTWH(w * 0.08 + dx, y + h * 0.02, w * 0.5, 3),
                  const Radius.circular(1.5)),
              paint..color = Colors.black.withValues(alpha: 0.25));
          canvas.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromLTWH(w * 0.75, y + h * 0.02, w * 0.17, 3),
                  const Radius.circular(1.5)),
              paint..color = a.withValues(alpha: 0.6));
        }
      }
      // totals
      paint.color = a;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(w * 0.6, h * 0.76 + dy, w * 0.32, h * 0.08),
              const Radius.circular(4)),
          paint);
    };
  }

  @override
  bool shouldRepaint(covariant _PreviewPainter old) =>
      old.layout != layout || old.a != a || old.b != b || old.name != name;
}
