import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show Rect;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'bg.dart';
import 'data.dart';

class Achado {
  String nome, desc, setor;
  double? usd;
  Uint8List foto;
  Achado(this.nome, this.desc, this.setor, this.usd, this.foto);
}

/// Lê um panfleto no layout deste app: OCR local + regras de posição (sem IA online).
/// Cada produto é achado pela pílula "R$ xx,xx"; o nome e a descrição ficam logo acima,
/// o "US$" logo abaixo e a foto na área acima do nome.
class Ocr {
  static final _brl = RegExp(r'R\$\s*([\d.]+,\d{2})'), _usd = RegExp(r'US\$\s*([\d.]+,\d{2})');
  static double _n(String s) => double.parse(s.replaceAll('.', '').replaceAll(',', '.'));

  static Future<List<Achado>> ler(String path, {bool semFundo = true}) async {
    if (!Platform.isAndroid) throw 'A leitura automática ainda não está disponível no Windows nesta versão.';
    var im = img.decodeImage(await File(path).readAsBytes())!;
    if (im.width > 3000) im = img.copyResize(im, width: 3000);
    final tmp = File('${Directory.systemTemp.path}/pf.png')..writeAsBytesSync(img.encodePng(im));
    final rec = TextRecognizer();
    final rt = await rec.processImage(InputImage.fromFilePath(tmp.path));
    await rec.close();
    final L = [for (final b in rt.blocks) for (final l in b.lines) l];
    final W = im.width.toDouble(), H = im.height.toDouble(), cw = W / 10;
    final out = <Achado>[];
    for (final p in L.where((l) => _brl.hasMatch(l.text))) {
      final r = p.boundingBox, cx = r.center.dx;
      bool perto(Rect q) => (q.center.dx - cx).abs() < cw * .6;
      final us = L.where((l) => _usd.hasMatch(l.text) && perto(l.boundingBox) && l.boundingBox.top >= r.center.dy && l.boundingBox.top - r.bottom < cw * .4).toList();
      final acima = L.where((l) => l != p && !_usd.hasMatch(l.text) && perto(l.boundingBox) && l.boundingBox.bottom <= r.top + 4 && r.top - l.boundingBox.bottom < cw * .7).toList()
        ..sort((a, b) => b.boundingBox.bottom.compareTo(a.boundingBox.bottom));
      if (acima.isEmpty) continue;
      final desc = acima.length > 1 ? acima[0].text : '';
      final nomeL = acima.length > 1 ? acima[1] : acima[0];
      final x0 = (cx - cw / 2).clamp(0.0, W - 2).toInt(), y1 = nomeL.boundingBox.top.clamp(2.0, H).toInt();
      final y0 = (y1 - cw * 1.15).clamp(0.0, y1 - 1.0).toInt();
      final crop = img.copyCrop(im, x: x0, y: y0, width: min(cw.toInt(), im.width - x0), height: y1 - y0);
      var png = Uint8List.fromList(img.encodePng(crop));
      if (semFundo) png = await Bg.remover(png);
      final brl = _n(_brl.firstMatch(p.text)!.group(1)!);
      final usd = us.isNotEmpty ? _n(_usd.firstMatch(us.first.text)!.group(1)!) : double.parse((brl / Store.cot).toStringAsFixed(2));
      final fx = cx / W, fy = r.center.dy / H;
      final setor = fy > .83 ? 'Infantil' : fx < .5 ? (fy < .5 ? 'Perfumes' : 'Cosméticos') : (fy < .5 ? 'Eletrônicos' : 'Casa e Cozinha');
      out.add(Achado(nomeL.text.trim(), desc.trim(), setor, usd, png));
    }
    return out;
  }
}
