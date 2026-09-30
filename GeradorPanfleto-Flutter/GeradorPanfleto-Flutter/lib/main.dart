import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'bg.dart';
import 'data.dart';
import 'flyer.dart';
import 'ocr.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.load();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
      title: 'Gerador de Panfletos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1A3FB0), useMaterial3: true),
      home: const Home());
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _H();
}

class _H extends State<Home> {
  int v = 0;
  String st = '';
  bool busy = false, semFundo = true;

  void mudou() {
    Store.save();
    setState(() => v++);
  }

  Future<Uint8List?> escolherFoto() async {
    final b = (await FilePicker.platform.pickFiles(type: FileType.image, withData: true))?.files.single.bytes;
    if (b == null) return null;
    return semFundo ? Bg.remover(b) : Bg.normal(b);
  }

  Future<void> novo([Produto? e]) async {
    final n = TextEditingController(text: e?.nome), d = TextEditingController(text: e?.desc);
    final u = TextEditingController(text: e == null ? '' : e.usd.toString().replaceAll('.', ','));
    var setor = e?.setor ?? setores[0];
    Uint8List? foto = e?.foto;
    String erro = '';
    await showDialog(
        context: context,
        builder: (_) => StatefulBuilder(
            builder: (ctx, ss) => AlertDialog(
                  title: Text(e == null ? 'Novo produto' : 'Editar produto'),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    CheckboxListTile(dense: true, title: const Text('Remover fundo da foto'), value: semFundo, onChanged: (x) => ss(() => semFundo = x!)),
                    if (foto != null) SizedBox(height: 90, child: Image.memory(foto!)),
                    TextButton.icon(
                        icon: const Icon(Icons.image),
                        label: const Text('Escolher foto'),
                        onPressed: () async {
                          try {
                            final f = await escolherFoto();
                            if (f != null) ss(() => foto = f);
                          } catch (x) {
                            ss(() => erro = '$x');
                          }
                        }),
                    if (erro.isNotEmpty) Text(erro, style: const TextStyle(color: Colors.red)),
                    TextField(controller: n, decoration: const InputDecoration(labelText: 'Nome')),
                    TextField(controller: d, decoration: const InputDecoration(labelText: 'Descrição')),
                    TextField(controller: u, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Valor em US\$')),
                    DropdownButtonFormField<String>(value: setor, items: [for (final s in setores) DropdownMenuItem(value: s, child: Text(s))], onChanged: (x) => setor = x!),
                  ])),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                    FilledButton(
                        onPressed: () {
                          final usd = double.tryParse(u.text.replaceAll(',', '.'));
                          if (n.text.trim().isEmpty || usd == null) return;
                          if (e == null) {
                            Store.produtos.add(Produto(id: DateTime.now().microsecondsSinceEpoch.toString(), nome: n.text.trim(), desc: d.text.trim(), usd: usd, setor: setor, foto: foto));
                          } else {
                            e..nome = n.text.trim()..desc = d.text.trim()..usd = usd..setor = setor..foto = foto;
                          }
                          mudou();
                          Navigator.pop(ctx);
                        },
                        child: const Text('Salvar')),
                  ],
                )));
  }

  Future<void> importar() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
    if (r == null) return;
    setState(() {
      busy = true;
      st = 'Lendo… (pode levar um minuto)';
    });
    try {
      var n = 0;
      for (final f in r.files) {
        for (final a in await Ocr.ler(f.path!, semFundo: semFundo)) {
          Store.produtos.add(Produto(id: '${DateTime.now().microsecondsSinceEpoch}${n++}', nome: a.nome, desc: a.desc, usd: a.usd ?? 0, setor: a.setor, foto: a.foto));
        }
      }
      st = '$n produtos adicionados. Toque em cada um para conferir nome e valor.';
      mudou();
    } catch (e) {
      st = 'Erro: $e';
    }
    setState(() => busy = false);
  }

  void destaque(Produto p) {
    final on = !p.dest;
    for (final o in Store.produtos) {
      if (o.setor == p.setor) o.dest = false;
    }
    p.dest = on;
    mudou();
  }

  Widget produtos() => ListView(padding: const EdgeInsets.all(12), children: [
        Card(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Importar panfleto antigo', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Text('Lê as fotos do panfleto direto no aparelho, sem internet e sem API. Confira sempre os dados depois.'),
                  const SizedBox(height: 8),
                  Row(children: [FilledButton(onPressed: busy ? null : importar, child: const Text('Ler panfleto')), const SizedBox(width: 12), Expanded(child: Text(st))]),
                ]))),
        for (final p in Store.produtos)
          ListTile(
              leading: p.foto == null ? const Icon(Icons.image_not_supported) : Image.memory(p.foto!, width: 48, height: 48),
              title: Text(p.nome),
              subtitle: Text('${p.setor} – US\$ ${brl(p.usd)}'),
              onTap: () => novo(p),
              trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () { Store.produtos.remove(p); mudou(); })),
      ]);

  Widget panfleto() => Column(children: [
        Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              SizedBox(
                  width: 170,
                  child: TextFormField(
                      initialValue: brl(Store.cot),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Cotação do dólar (R\$)'),
                      onChanged: (t) {
                        final x = double.tryParse(t.replaceAll(',', '.'));
                        if (x != null && x > 0) Store.cot = x;
                      })),
              const SizedBox(width: 12),
              FilledButton.tonal(onPressed: mudou, child: const Text('Atualizar panfleto')),
            ])),
        SizedBox(
            height: 150,
            child: ListView(children: [
              for (final p in Store.produtos)
                CheckboxListTile(
                    dense: true,
                    title: Text(p.nome),
                    subtitle: Text(p.setor),
                    value: p.sel,
                    onChanged: (x) { p.sel = x!; mudou(); },
                    secondary: IconButton(icon: Icon(p.dest ? Icons.star : Icons.star_border), tooltip: 'Destaque do setor', onPressed: () => destaque(p))),
            ])),
        Expanded(child: PdfPreview(key: ValueKey(v), build: gerarPdf, canChangePageFormat: false, canChangeOrientation: false, pdfFileName: 'panfleto.pdf')),
      ]);

  @override
  Widget build(BuildContext c) => DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(title: const Text('Gerador de Panfletos'), bottom: const TabBar(tabs: [Tab(text: 'Produtos'), Tab(text: 'Panfleto')])),
        floatingActionButton: FloatingActionButton(onPressed: () => novo(), child: const Icon(Icons.add)),
        body: TabBarView(children: [produtos(), panfleto()]),
      ));
}
