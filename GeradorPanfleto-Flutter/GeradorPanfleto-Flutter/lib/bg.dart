import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';

/// Remoção de fundo 100% offline: modelo U²-Net pequeno rodando via ONNX Runtime.
class Bg {
  static OrtSession? _s;
  static const _n = 320;

  static img.Image _decode(Uint8List b) {
    var i = img.decodeImage(b)!;
    if (max(i.width, i.height) > 500) {
      i = img.copyResize(i, width: i.width >= i.height ? 500 : null, height: i.height > i.width ? 500 : null);
    }
    return i;
  }

  /// Só reduz e converte para PNG (sem tirar o fundo).
  static Uint8List normal(Uint8List b) => img.encodePng(_decode(b));

  static Future<OrtSession> _sess() async {
    if (_s != null) return _s!;
    OrtEnv.instance.init();
    final raw = await rootBundle.load('assets/models/u2netp.onnx');
    return _s = OrtSession.fromBuffer(raw.buffer.asUint8List(), OrtSessionOptions());
  }

  /// Devolve PNG com fundo transparente, recortado rente ao objeto.
  static Future<Uint8List> remover(Uint8List bytes) async {
    final src = _decode(bytes);
    final small = img.copyResize(src, width: _n, height: _n);
    const mean = [0.485, 0.456, 0.406], std = [0.229, 0.224, 0.225];
    final data = Float32List(3 * _n * _n);
    for (var y = 0; y < _n; y++) {
      for (var x = 0; x < _n; x++) {
        final p = small.getPixel(x, y);
        final c = [p.r / 255, p.g / 255, p.b / 255];
        for (var k = 0; k < 3; k++) {
          data[k * _n * _n + y * _n + x] = (c[k] - mean[k]) / std[k];
        }
      }
    }
    final input = OrtValueTensor.createTensorWithDataList(data, [1, 3, _n, _n]);
    final ro = OrtRunOptions();
    final out = (await _sess()).run(ro, {'input.1': input});
    final m = ((out[0]!.value as List)[0] as List)[0] as List;
    input.release();
    ro.release();
    for (final o in out) {
      o?.release();
    }
    double mn = 1e9, mx = -1e9;
    for (final r in m) {
      for (final v in r) {
        mn = min(mn, (v as num).toDouble());
        mx = max(mx, v.toDouble());
      }
    }
    final mk = img.Image(width: _n, height: _n);
    for (var y = 0; y < _n; y++) {
      for (var x = 0; x < _n; x++) {
        final v = (((m[y][x] as num) - mn) / (mx - mn + 1e-9) * 255).round();
        mk.setPixelRgb(x, y, v, v, v);
      }
    }
    final big = img.copyResize(mk, width: src.width, height: src.height, interpolation: img.Interpolation.linear);
    final rgba = src.convert(numChannels: 4);
    int x0 = src.width, y0 = src.height, x1 = -1, y1 = -1;
    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
        final a = big.getPixel(x, y).r.toInt();
        rgba.getPixel(x, y).a = a;
        if (a > 40) {
          x0 = min(x0, x); x1 = max(x1, x); y0 = min(y0, y); y1 = max(y1, y);
        }
      }
    }
    if (x1 < 0) return img.encodePng(src);
    return img.encodePng(img.copyCrop(rgba, x: x0, y: y0, width: x1 - x0 + 1, height: y1 - y0 + 1));
  }
}
