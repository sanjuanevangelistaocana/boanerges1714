import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/services/storage_service.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/models/documento.dart';
import 'package:boanerges1714/models/revista.dart';

class ManageDocumentosScreen extends StatelessWidget {
  const ManageDocumentosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [AppTheme.primaryDark, AppTheme.primaryColor]),
            ),
            child: Column(
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: const Row(
                      children: [
                        Icon(Icons.folder_open, color: Colors.white, size: 28),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text('Gesti\u00f3n de Documentos',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const TabBar(
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  indicatorColor: Colors.white,
                  tabs: [
                    Tab(
                        text: 'Documentos Cofrades',
                        icon: Icon(Icons.description)),
                    Tab(
                        text: 'Revistas Boanerges',
                        icon: Icon(Icons.menu_book)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _DocumentosTab(fs: fs),
                _RevistasTab(fs: fs),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentosTab extends StatelessWidget {
  final FirestoreService fs;
  const _DocumentosTab({required this.fs});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Documentos',
                      style: Theme.of(context).textTheme.headlineSmall),
                  ElevatedButton.icon(
                    onPressed: () => _showDocDialog(context, fs),
                    icon: const Icon(Icons.add),
                    label: const Text('A\u00f1adir'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<Documento>>(
                stream: fs.getDocumentos(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data ?? [];
                  if (docs.isEmpty) {
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200)),
                      child: const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: Text('No hay documentos.'))),
                    );
                  }
                  return Column(
                    children:
                        docs.map((d) => _DocAdminCard(doc: d, fs: fs)).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocAdminCard extends StatelessWidget {
  final Documento doc;
  final FirestoreService fs;
  const _DocAdminCard({required this.doc, required this.fs});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: AppTheme.primaryColor.withAlpha(15),
              borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.description, color: AppTheme.primaryColor),
        ),
        title: Text(doc.titulo,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${doc.tipo} \u00b7 ${fmt.format(doc.fecha)}',
            style: const TextStyle(fontSize: 13)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => _showDocDialog(context, fs, doc: doc),
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Eliminar documento'),
                    content: Text('\u00bfEliminar "${doc.titulo}"?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancelar')),
                      ElevatedButton(
                        onPressed: () {
                          fs.deleteDocumento(doc.id);
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                        child: const Text('Eliminar'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

void _showDocDialog(BuildContext context, FirestoreService fs,
    {Documento? doc}) {
  final tituloC = TextEditingController(text: doc?.titulo ?? '');
  final urlC = TextEditingController(text: doc?.archivoUrl ?? '');
  final descripcionC = TextEditingController(text: doc?.descripcion ?? '');
  String tipo = doc?.tipo ?? 'general';
  bool uploading = false;
  Map<String, String> uploadedMeta = {};

  showDialog(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(doc == null ? 'Nuevo Documento' : 'Editar Documento'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: tituloC,
                  decoration:
                      const InputDecoration(labelText: 'T\u00edtulo *')),
              const SizedBox(height: 8),
              TextField(
                  controller: urlC,
                  decoration:
                      const InputDecoration(labelText: 'URL del documento')),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                icon: uploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.upload_file, size: 18),
                label: Text(uploading ? 'Subiendo...' : 'Subir archivo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: uploading
                    ? null
                    : () async {
                        setDialogState(() => uploading = true);
                        try {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.any,
                            withData: true,
                            allowMultiple: false,
                          );
                          if (result != null && result.files.isNotEmpty) {
                            final file = result.files.first;
                            if (file.bytes != null) {
                              final storage = dialogCtx.read<StorageService>();
                              final uploaded = await storage.uploadFile(
                                path: 'documentos',
                                bytes: file.bytes!,
                                fileName: file.name,
                                allowedExtensions: const {
                                  'pdf',
                                  'doc',
                                  'docx',
                                  'xls',
                                  'xlsx',
                                  'jpg',
                                  'jpeg',
                                  'png',
                                },
                              );
                              setDialogState(() {
                                uploadedMeta = uploaded;
                                urlC.text = uploaded['url'] ?? '';
                              });
                            }
                            if (file.bytes == null && ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'No se pudo leer el archivo seleccionado.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                  content: Text('Error al subir: $e'),
                                  backgroundColor: Colors.red),
                            );
                          }
                        } finally {
                          setDialogState(() => uploading = false);
                        }
                      },
              ),
              const SizedBox(height: 8),
              TextField(
                  controller: descripcionC,
                  decoration:
                      const InputDecoration(labelText: 'Descripci\u00f3n'),
                  maxLines: 2),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: tipo,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const [
                  DropdownMenuItem(value: 'general', child: Text('General')),
                  DropdownMenuItem(
                      value: 'estatutos', child: Text('Estatutos')),
                  DropdownMenuItem(
                      value: 'reglamento_interno',
                      child: Text('Reglamento Interno')),
                  DropdownMenuItem(
                      value: 'actas_junta_general',
                      child: Text('Actas Junta General')),
                  DropdownMenuItem(
                      value: 'normativa', child: Text('Normativa')),
                  DropdownMenuItem(value: 'acta', child: Text('Acta')),
                  DropdownMenuItem(
                      value: 'formulario', child: Text('Formulario')),
                  DropdownMenuItem(value: 'gdpr', child: Text('GDPR')),
                ],
                onChanged: (v) => setDialogState(() => tipo = v ?? 'general'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: uploading
                ? null
                : () async {
                    if (tituloC.text.trim().isEmpty) return;
                    if (urlC.text.trim().isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Sube un archivo o indica una URL antes de guardar.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    final auth = ctx.read<AuthService>();
                    final tamanoBytes =
                        int.tryParse(uploadedMeta['tamano_bytes'] ?? '');
                    if (doc == null) {
                      await fs.createDocumento(Documento(
                        id: '',
                        titulo: tituloC.text.trim(),
                        archivoUrl: urlC.text.trim(),
                        tipo: tipo,
                        fecha: DateTime.now(),
                        descripcion: descripcionC.text.trim(),
                        archivoNombre: uploadedMeta['nombre'],
                        storagePath: uploadedMeta['storage_path'],
                        contentType: uploadedMeta['tipo'],
                        tamanoBytes: tamanoBytes,
                        subidoPor: auth.userId,
                        modulo: 'documentos',
                      ));
                    } else {
                      await fs.updateDocumento(doc.id, {
                        'titulo': tituloC.text.trim(),
                        'archivo_url': urlC.text.trim(),
                        'tipo': tipo,
                        'descripcion': descripcionC.text.trim(),
                        if (uploadedMeta['nombre'] != null)
                          'archivo_nombre': uploadedMeta['nombre'],
                        if (uploadedMeta['storage_path'] != null)
                          'storage_path': uploadedMeta['storage_path'],
                        if (uploadedMeta['tipo'] != null)
                          'content_type': uploadedMeta['tipo'],
                        if (tamanoBytes != null) 'tamano_bytes': tamanoBytes,
                        if (auth.userId != null) 'subido_por': auth.userId,
                        'modulo': 'documentos',
                      });
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
            child: Text(doc == null ? 'Crear' : 'Guardar'),
          ),
        ],
      ),
    ),
  );
}

class _RevistasTab extends StatelessWidget {
  final FirestoreService fs;
  const _RevistasTab({required this.fs});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Revistas Boanerges',
                      style: Theme.of(context).textTheme.headlineSmall),
                  ElevatedButton.icon(
                    onPressed: () => _showRevistaDialog(context, fs),
                    icon: const Icon(Icons.add),
                    label: const Text('A\u00f1adir'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<Revista>>(
                stream: fs.getRevistas(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final revistas = snapshot.data ?? [];
                  if (revistas.isEmpty) {
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200)),
                      child: const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: Text('No hay revistas.'))),
                    );
                  }
                  return Column(
                    children: revistas
                        .map((r) => _RevistaAdminCard(revista: r, fs: fs))
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RevistaAdminCard extends StatelessWidget {
  final Revista revista;
  final FirestoreService fs;
  const _RevistaAdminCard({required this.revista, required this.fs});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: AppTheme.primaryColor.withAlpha(15),
              borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.menu_book, color: AppTheme.primaryColor),
        ),
        title: Text(revista.titulo,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
            'N.\u00ba ${revista.numero} \u00b7 ${fmt.format(revista.fecha)}',
            style: const TextStyle(fontSize: 13)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () =>
                  _showRevistaDialog(context, fs, revista: revista),
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Eliminar revista'),
                    content: Text('\u00bfEliminar "${revista.titulo}"?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancelar')),
                      ElevatedButton(
                        onPressed: () {
                          fs.deleteRevista(revista.id);
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                        child: const Text('Eliminar'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

void _showRevistaDialog(BuildContext context, FirestoreService fs,
    {Revista? revista}) {
  final tituloC = TextEditingController(text: revista?.titulo ?? '');
  final descripcionC = TextEditingController(text: revista?.descripcion ?? '');
  final pdfUrlC = TextEditingController(text: revista?.pdfUrl ?? '');
  final portadaUrlC = TextEditingController(text: revista?.portadaUrl ?? '');
  final numeroC =
      TextEditingController(text: revista?.numero.toString() ?? '0');
  bool uploadingPdf = false;
  bool uploadingPortada = false;

  showDialog(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(revista == null ? 'Nueva Revista' : 'Editar Revista'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: tituloC,
                  decoration:
                      const InputDecoration(labelText: 'T\u00edtulo *')),
              const SizedBox(height: 8),
              TextField(
                  controller: numeroC,
                  decoration: const InputDecoration(labelText: 'N\u00famero'),
                  keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              TextField(
                  controller: descripcionC,
                  decoration:
                      const InputDecoration(labelText: 'Descripci\u00f3n'),
                  maxLines: 2),
              const SizedBox(height: 12),
              TextField(
                  controller: pdfUrlC,
                  decoration:
                      const InputDecoration(labelText: 'URL del PDF *')),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                icon: uploadingPdf
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.picture_as_pdf, size: 18),
                label: Text(uploadingPdf ? 'Subiendo PDF...' : 'Subir PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: uploadingPdf
                    ? null
                    : () async {
                        setDialogState(() => uploadingPdf = true);
                        try {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['pdf'],
                            withData: true,
                            allowMultiple: false,
                          );
                          if (result != null && result.files.isNotEmpty) {
                            final file = result.files.first;
                            if (file.bytes != null) {
                              final storage = dialogCtx.read<StorageService>();
                              final uploaded = await storage.uploadFile(
                                path: 'revistas/pdf',
                                bytes: file.bytes!,
                                fileName: file.name,
                                contentType: 'application/pdf',
                              );
                              setDialogState(
                                  () => pdfUrlC.text = uploaded['url'] ?? '');
                            }
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                  content: Text('Error al subir PDF: $e'),
                                  backgroundColor: Colors.red),
                            );
                          }
                        } finally {
                          setDialogState(() => uploadingPdf = false);
                        }
                      },
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: portadaUrlC,
                  decoration: const InputDecoration(
                      labelText: 'URL de portada (opcional)')),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                icon: uploadingPortada
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.image, size: 18),
                label: Text(uploadingPortada ? 'Subiendo...' : 'Subir portada'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: uploadingPortada
                    ? null
                    : () async {
                        setDialogState(() => uploadingPortada = true);
                        try {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.image,
                            withData: true,
                            allowMultiple: false,
                          );
                          if (result != null && result.files.isNotEmpty) {
                            final file = result.files.first;
                            if (file.bytes != null) {
                              final storage = dialogCtx.read<StorageService>();
                              final uploaded = await storage.uploadFile(
                                path: 'revistas/portadas',
                                bytes: file.bytes!,
                                fileName: file.name,
                              );
                              setDialogState(() =>
                                  portadaUrlC.text = uploaded['url'] ?? '');
                            }
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                  content: Text('Error al subir portada: $e'),
                                  backgroundColor: Colors.red),
                            );
                          }
                        } finally {
                          setDialogState(() => uploadingPortada = false);
                        }
                      },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: (uploadingPdf || uploadingPortada)
                ? null
                : () async {
                    if (tituloC.text.trim().isEmpty) return;
                    if (revista == null) {
                      await fs.createRevista(Revista(
                        id: '',
                        titulo: tituloC.text.trim(),
                        descripcion: descripcionC.text.trim(),
                        pdfUrl: pdfUrlC.text.trim(),
                        portadaUrl: portadaUrlC.text.trim(),
                        numero: int.tryParse(numeroC.text) ?? 0,
                        fecha: DateTime.now(),
                      ));
                    } else {
                      await fs.updateRevista(revista.id, {
                        'titulo': tituloC.text.trim(),
                        'descripcion': descripcionC.text.trim(),
                        'pdf_url': pdfUrlC.text.trim(),
                        'portada_url': portadaUrlC.text.trim(),
                        'numero': int.tryParse(numeroC.text) ?? 0,
                      });
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
            child: Text(revista == null ? 'Crear' : 'Guardar'),
          ),
        ],
      ),
    ),
  );
}
