import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

const setores = ['Perfumes', 'Eletrônicos', 'Cosméticos', 'Casa e Cozinha', 'Infantil'];

class Produto {
  String id, nome, desc, setor;
  double usd;
  Uint8List? foto;
  bool sel, dest;
  Produto({required this.id, required this.nome, this.desc = '', required this.usd, required this.setor, this.foto, this.sel = true, this.dest = false});
  Map<String, dynamic> toJson() => {'id': id, 'nome': nome, 'desc': desc, 'usd': usd, 'setor': setor, 'sel': sel, 'dest': dest, 'foto': foto == null ? null : base64Encode(foto!)};
  static Produto fromJson(Map j) => Produto(id: j['id'], nome: j['nome'], desc: j['desc'] ?? '', usd: (j['usd'] as num).toDouble(), setor: j['setor'], sel: j['sel'] ?? true, dest: j['dest'] ?? false, foto: j['foto'] == null ? null : base64Decode(j['foto']));
}

/// Cadastro salvo em um arquivo JSON na pasta de dados do app (Windows e Android).
class Store {
  static final produtos = <Produto>[];
  static double cot = 5.32;
  static Future<File> _f() async => File('${(await getApplicationSupportDirectory()).path}/dados.json');
  static Future<void> load() async {
    try {
      final f = await _f();
      if (!await f.exists()) return;
      final j = jsonDecode(await f.readAsString());
      cot = (j['cot'] as num).toDouble();
      produtos..clear()..addAll((j['p'] as List).map((e) => Produto.fromJson(e)));
    } catch (_) {}
  }
  static Future<void> save() async => (await _f()).writeAsString(jsonEncode({'cot': cot, 'p': produtos.map((e) => e.toJson()).toList()}));
}
