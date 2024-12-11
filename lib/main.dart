import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final listaDeCameras = await availableCameras();
  final firstCamera = listaDeCameras.first;

  final database = openDatabase(
    path.join(await getDatabasesPath(), 'ocorrencias.db'),
    onCreate: (db, version) {
      return db.execute(
        'CREATE TABLE ocorrencias(id INTEGER PRIMARY KEY, titulo TEXT, descricao TEXT, imagem TEXT)',
      );
    },
    version: 1,
  );

  runApp(MyApp(database, firstCamera));
}

class MyApp extends StatelessWidget {
  final Future<Database> database;
  final CameraDescription camera;

  MyApp(this.database, this.camera);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ocorrências',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: OcorrenciaListPage(database, camera),
    );
  }
}

class Ocorrencia {
  final int? id;
  final String titulo;
  final String descricao;
  final String imagem;

  Ocorrencia({this.id, required this.titulo, required this.descricao, required this.imagem});

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'titulo': titulo,
      'descricao': descricao,
      'imagem': imagem,
    };
  }

  @override
  String toString() {
    return 'Ocorrencia{id: $id, titulo: $titulo, descricao: $descricao, imagem: $imagem}';
  }
}

class OcorrenciaListPage extends StatefulWidget {
  final Future<Database> database;
  final CameraDescription camera;

  OcorrenciaListPage(this.database, this.camera);

  @override
  _OcorrenciaListPageState createState() => _OcorrenciaListPageState();
}

class _OcorrenciaListPageState extends State<OcorrenciaListPage> {
  late Future<List<Ocorrencia>> ocorrencias;

  @override
  void initState() {
    super.initState();
    ocorrencias = listaOcorrencias();
  }

  Future<void> insereOcorrencia(Ocorrencia ocorrencia) async {
    final db = await widget.database;

    await db.insert(
      'ocorrencias',
      ocorrencia.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    setState(() {
      ocorrencias = listaOcorrencias();
    });
  }

  Future<List<Ocorrencia>> listaOcorrencias() async {
    final db = await widget.database;

    final List<Map<String, dynamic>> maps = await db.query('ocorrencias');

    return List.generate(maps.length, (i) {
      return Ocorrencia(
        id: maps[i]['id'],
        titulo: maps[i]['titulo'],
        descricao: maps[i]['descricao'],
        imagem: maps[i]['imagem'],
      );
    });
  }

  Future<void> deletaOcorrencia(int id) async {
    final db = await widget.database;

    await db.delete(
      'ocorrencias',
      where: 'id = ?',
      whereArgs: [id],
    );

    setState(() {
      ocorrencias = listaOcorrencias();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Lista de Ocorrências')),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<Ocorrencia>>(
              future: ocorrencias,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Erro: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('Nenhuma ocorrência registrada.'));
                } else {
                  return ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final ocorrencia = snapshot.data![index];
                      return ListTile(
                        title: Text(ocorrencia.titulo),
                        subtitle: Text(ocorrencia.descricao),
                        trailing: IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            deletaOcorrencia(ocorrencia.id!);
                          },
                        ),
                      );
                    },
                  );
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: () async {
                final novaOcorrencia = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddOcorrenciaPage(camera: widget.camera),
                  ),
                );
                if (novaOcorrencia != null) {
                  insereOcorrencia(novaOcorrencia);
                }
              },
              child: Text('Adicionar Ocorrência'),
            ),
          ),
        ],
      ),
    );
  }
}

class AddOcorrenciaPage extends StatefulWidget {
  final CameraDescription camera;

  const AddOcorrenciaPage({Key? key, required this.camera}) : super(key: key);

  @override
  _AddOcorrenciaPageState createState() => _AddOcorrenciaPageState();
}

class _AddOcorrenciaPageState extends State<AddOcorrenciaPage> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descricaoController = TextEditingController();

  String? _imagePath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Adicionar Ocorrência')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              ElevatedButton(
                onPressed: () async {
                  final imagePath = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CameraPage(camera: widget.camera),
                    ),
                  );
                  if (imagePath != null) {
                    setState(() {
                      _imagePath = imagePath;
                    });
                  }
                },
                child: Text('Abrir Câmera'),
              ),
              SizedBox(height: 20),
              if (_imagePath != null) Image.file(File(_imagePath!)),
              SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _tituloController,
                      decoration: InputDecoration(labelText: 'Título'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, insira um título.';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _descricaoController,
                      decoration: InputDecoration(labelText: 'Descrição'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, insira uma descrição.';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          final ocorrencia = Ocorrencia(
                            titulo: _tituloController.text,
                            descricao: _descricaoController.text,
                            imagem: _imagePath ?? '',
                          );
                          Navigator.pop(context, ocorrencia);
                        }
                      },
                      child: Text('Salvar'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CameraPage extends StatefulWidget {
  final CameraDescription camera;

  const CameraPage({Key? key, required this.camera}) : super(key: key);

  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _controller;
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
    );
    _initializeControllerFuture = _controller!.initialize();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    try {
      if (_controller != null && _controller!.value.isInitialized) {
        final image = await _controller!.takePicture();
        Navigator.pop(context, image.path);
      }
    } catch (e) {
      print('Erro ao tirar foto: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Câmera')),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                CameraPreview(_controller!),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: FloatingActionButton(
                      onPressed: _takePicture,
                      child: Icon(Icons.camera_alt),
                    ),
                  ),
                ),
              ],
            );
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
