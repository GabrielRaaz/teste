import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'data.dart';

String brl(double v) {
  final p = v.toStringAsFixed(2).split('.');
  return '${p[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')},${p[1]}';
}

/// Zona: setor, coluna/linha iniciais na grade 10x6, colunas, linhas, posição do destaque.
class Z {
  final String s;
  final int c0, r0, n, r, dr, dc;
  const Z(this.s, this.c0, this.r0, this.n, this.r, this.dr, this.dc);
}

const zonas = [
  Z('Perfumes', 0, 0, 5, 3, 1, 0),
  Z('Cosméticos', 0, 3, 5, 2, 1, 3),
  Z('Eletrônicos', 5, 0, 5, 3, 1, 3),
  Z('Casa e Cozinha', 5, 3, 5, 2, 1, 0),
  Z('Infantil', 0, 5, 10, 1, 0, 4),
];
const azul = PdfColor.fromInt(0xFF1A3FB0);

pw.Widget _pos(double l, double t, double w, double h, pw.Widget c) => pw.Positioned(left: l, top: t, child: pw.SizedBox(width: w, height: h, child: c));

pw.Widget _card(Produto? p, bool d, double h) {
  if (p == null) return pw.SizedBox();
  final foto = p.foto == null ? pw.SizedBox() : pw.Image(pw.MemoryImage(p.foto!), fit: pw.BoxFit.contain);
  final c = d ? PdfColors.white : PdfColors.black;
  final txt = pw.Column(mainAxisSize: pw.MainAxisSize.min, crossAxisAlignment: d ? pw.CrossAxisAlignment.start : pw.CrossAxisAlignment.center, children: [
    pw.Text(p.nome.toUpperCase(), textAlign: d ? pw.TextAlign.left : pw.TextAlign.center, style: pw.TextStyle(fontSize: d ? 9 : 7.5, fontWeight: pw.FontWeight.bold, color: c)),
    if (p.desc.isNotEmpty) pw.Text(p.desc.toUpperCase(), style: pw.TextStyle(fontSize: 5.5, color: c)),
    pw.SizedBox(height: 2),
    pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: pw.BoxDecoration(color: d ? PdfColors.white : azul, borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Text('R\$ ${brl(p.usd * Store.cot)}', style: pw.TextStyle(fontSize: d ? 15 : 12, fontWeight: pw.FontWeight.bold, color: d ? azul : PdfColors.white)),
    ),
    pw.Text('US\$ ${brl(p.usd)}', style: pw.TextStyle(fontSize: 5.5, color: c)),
  ]);
  if (d) {
    return pw.Container(
      margin: pw.EdgeInsets.only(top: h * .2),
      padding: const pw.EdgeInsets.all(4),
      decoration: pw.BoxDecoration(color: azul, borderRadius: pw.BorderRadius.circular(18)),
      child: pw.Row(children: [pw.Expanded(flex: 48, child: foto), pw.Expanded(flex: 52, child: pw.Align(alignment: pw.Alignment.centerLeft, child: txt))]),
    );
  }
  return pw.Container(
    padding: const pw.EdgeInsets.all(2),
    decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: .5))),
    child: pw.Column(children: [pw.Expanded(child: foto), txt]),
  );
}

/// Panfleto A3 paisagem (2 páginas A4 lado a lado). Usado na prévia, na impressão e no PDF.
Future<Uint8List> gerarPdf(PdfPageFormat _) async {
  const mm = PdfPageFormat.mm;
  final W = 420 * mm, H = 297 * mm, mx = W * .03, my = H * .012, cw = (W - 2 * mx) / 10, ch = (H - 2 * my) / 6;
  final kids = <pw.Widget>[];
  for (final z in zonas) {
    final its = Store.produtos.where((p) => p.setor == z.s && p.sel).toList();
    final d = its.where((p) => p.dest).firstOrNull;
    final rg = its.where((p) => p != d).toList();
    var k = 0;
    for (var r = 0; r < z.r; r++) {
      for (var c = 0; c < z.n; c++) {
        final x = mx + (z.c0 + c) * cw, y = my + (z.r0 + r) * ch;
        if (r == z.dr && (c == z.dc || c == z.dc + 1)) {
          if (c == z.dc) kids.add(_pos(x, y, cw * 2, ch, _card(d, true, ch)));
        } else if (k < rg.length) {
          kids.add(_pos(x, y, cw, ch, _card(rg[k++], false, ch)));
        }
      }
    }
  }
  final aviso = 'COTAÇÃO DO DÓLAR R\$ ${brl(Store.cot)}. OS VALORES EM REAIS PODEM VARIAR CONFORME A COTAÇÃO NO MOMENTO DA COMPRA, BEM COMO O DIREITO DE CORRIGIR ERROS GRÁFICOS, DE INFORMAÇÕES OU VALORES.';
  kids.add(pw.Positioned(left: 0, right: 0, bottom: 1, child: pw.Center(child: pw.Text(aviso, style: const pw.TextStyle(fontSize: 5)))));
  kids.add(pw.Positioned(left: W / 2, top: 0, child: pw.Container(width: .5, height: H, color: PdfColors.grey400)));
  final doc = pw.Document();
  doc.addPage(pw.Page(pageFormat: PdfPageFormat(W, H, marginAll: 0), build: (_) => pw.Stack(fit: pw.StackFit.expand, children: kids)));
  return doc.save();
}
