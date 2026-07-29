import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/models/gallery.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/services/gallery_service.dart';
import 'package:boanerges1714/utils/gallery_download.dart';

class ModeratedGalleryEntry {
  final String name;
  final Uint8List bytes;
  final Uint8List thumbnail;

  const ModeratedGalleryEntry({
    required this.name,
    required this.bytes,
    required this.thumbnail,
  });
}

class GalleryModerationSection extends StatefulWidget {
  final List<GalleryFolder> folders;

  const GalleryModerationSection({
    required this.folders,
    super.key,
  });

  @override
  State<GalleryModerationSection> createState() =>
      _GalleryModerationSectionState();
}

class _GalleryModerationSectionState extends State<GalleryModerationSection> {
  GalleryUploadRequest? _selectedRequest;
  List<ModeratedGalleryEntry> _entries = const [];
  bool _loading = false;
  String _status = '';

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _download(GalleryUploadRequest request) async {
    try {
      final bytes =
          await context.read<GalleryService>().downloadUploadRequestZip(request);
      final downloaded =
          await downloadGalleryBytes(bytes, '${request.titulo}.zip');
      if (mounted) {
        setState(() => _status = downloaded
            ? 'ZIP descargado.'
            : 'La descarga directa está disponible en la versión web.');
      }
    } catch (error) {
      if (mounted) setState(() => _status = 'Error descargando el ZIP: $error');
    }
  }

  Future<void> _preview(GalleryUploadRequest request) async {
    setState(() {
      _loading = true;
      _selectedRequest = request;
      _entries = const [];
      _status = 'Descomprimiendo y generando vistas previas…';
    });
    try {
      final bytes = await context
          .read<GalleryService>()
          .downloadUploadRequestZip(request);
      final archive = ZipDecoder().decodeBytes(bytes);
      final entries = <ModeratedGalleryEntry>[];
      for (final file in archive.files) {
        if (!file.isFile || _isIgnored(file.name)) continue;
        final content = Uint8List.fromList(file.content as List<int>);
        final thumbnail =
            await context.read<GalleryService>().createThumbnail(content);
        entries.add(ModeratedGalleryEntry(
          name: file.name,
          bytes: content,
          thumbnail: thumbnail.bytes,
        ));
      }
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
        _status = '${entries.length} imágenes listas para revisar.';
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _status = 'No se pudo previsualizar el ZIP: $error';
        });
      }
    }
  }

  bool _isIgnored(String name) {
    final baseName = name.split('/').last;
    return name.startsWith('__MACOSX/') ||
        baseName == '.DS_Store' ||
        baseName.startsWith('.');
  }

  Future<GalleryFolder?> _createFolder() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva carpeta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              nameController.text.trim().isNotEmpty,
            ),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    final name = nameController.text.trim();
    final description = descriptionController.text.trim();
    nameController.dispose();
    descriptionController.dispose();
    if (result != true || name.isEmpty) return null;
    final now = DateTime.now();
    final folder = GalleryFolder(
      id: '',
      nombre: name,
      descripcion: description.isEmpty ? null : description,
      fechaCreacion: now,
      fechaActualizacion: now,
    );
    final id = await context.read<GalleryService>().createFolder(folder);
    return folder.copyWith(id: id);
  }

  Future<void> _approve(GalleryUploadRequest request) async {
    if (_entries.isEmpty) {
      await _preview(request);
      if (_entries.isEmpty) return;
    }
    final folders = [...widget.folders];
    final defaultFolderId = folders.isEmpty ? null : folders.first.id;
    final assignments = <String, String?>{
      for (final entry in _entries) entry.name: defaultFolderId,
    };
    final names = <String, TextEditingController>{
      for (final entry in _entries)
        entry.name: TextEditingController(text: entry.name.split('/').last),
    };
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Importar «${request.titulo}»'),
          content: SizedBox(
            width: 760,
            height: 560,
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('Asignar todas a:'),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: folders.isEmpty ? null : folders.first.id,
                        items: folders
                            .map((folder) => DropdownMenuItem(
                                  value: folder.id,
                                  child: Text(folder.nombre),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            for (final key in assignments.keys) {
                              assignments[key] = value;
                            }
                          });
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: 'Crear carpeta',
                      onPressed: () async {
                        final folder = await _createFolder();
                        if (folder == null) return;
                        folders.add(folder);
                        setDialogState(() {
                          for (final key in assignments.keys) {
                            assignments[key] ??= folder.id;
                          }
                        });
                      },
                      icon: const Icon(Icons.create_new_folder),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: _entries.length,
                    itemBuilder: (context, index) {
                      final entry = _entries[index];
                      return Row(
                        children: [
                          Image.memory(entry.thumbnail,
                              width: 58, height: 58, fit: BoxFit.cover),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: names[entry.name],
                              decoration:
                                  const InputDecoration(labelText: 'Nombre'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 180,
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: assignments[entry.name],
                              items: folders
                                  .map((folder) => DropdownMenuItem(
                                        value: folder.id,
                                        child: Text(folder.nombre),
                                      ))
                                  .toList(),
                              onChanged: (value) => setDialogState(
                                  () => assignments[entry.name] = value),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: assignments.values.any((value) => value == null)
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('Aprobar e importar'),
            ),
          ],
        ),
      ),
    );
    if (result != true) {
      for (final controller in names.values) {
        controller.dispose();
      }
      return;
    }
    final renamed = <String, String>{
      for (final entry in _entries)
        entry.name: names[entry.name]!.text.trim().isEmpty
            ? entry.name.split('/').last
            : names[entry.name]!.text.trim(),
    };
    for (final controller in names.values) {
      controller.dispose();
    }
    final service = context.read<GalleryService>();
    final auth = context.read<AuthService>();
    try {
      if (request.estado == GalleryUploadRequestStatus.pendiente) {
        await service.approveRequest(
          request: request,
          reviewerId: auth.userId ?? '',
        );
      }
      final destinationIds = <String>{};
      var completed = 0;
      for (final entry in _entries) {
        final folderId = assignments[entry.name];
        if (folderId == null) continue;
        await service.importModeratedImage(
          request: request,
          folderId: folderId,
          bytes: entry.bytes,
          fileName: renamed[entry.name]!,
        );
        destinationIds.add(folderId);
        completed++;
        if (mounted) {
          setState(() => _status = 'Importando $completed/${_entries.length}…');
        }
      }
      await service.setRequestDestinationFolders(request.id, destinationIds);
      await service.marcarProcesado(request.id, reviewerId: auth.userId);
      if (mounted) {
        setState(() {
          _entries = const [];
          _selectedRequest = null;
          _status = 'Envío importado correctamente.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _status =
            'Importación parcial. Puedes reintentar sin duplicar las imágenes ya importadas: $error');
      }
    }
  }

  Future<void> _reject(GalleryUploadRequest request) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rechazar envío'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Motivo obligatorio',
            hintText: 'Explica al usuario qué debe corregir.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null) return;
    try {
      await context.read<GalleryService>().rejectRequest(
            request: request,
            reviewerId: context.read<AuthService>().userId ?? '',
            motivo: reason,
          );
    } catch (error) {
      if (mounted) setState(() => _status = 'No se pudo rechazar: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GalleryUploadRequest>>(
      stream: context.read<GalleryService>().watchPendingRequests(),
      builder: (context, snapshot) {
        final requests = snapshot.data ?? const [];
        return Card(
          child: ExpansionTile(
            leading: const Icon(Icons.fact_check_outlined),
            title: Text('Bandeja de envíos (${requests.length})'),
            subtitle: const Text('Revisa, reparte e importa fotografías'),
            children: [
              if (snapshot.hasError)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error: ${snapshot.error}'),
                ),
              for (final request in requests)
                ListTile(
                  title: Text(request.titulo),
                  subtitle: Text(
                    '${request.createdByNombre.isEmpty ? request.createdByEmail : request.createdByNombre} · '
                    '${request.numFotosEstimadas ?? '?'} fotos · '
                    '${_formatBytes(request.zipSizeBytes)}\n'
                    '${request.descripcion ?? 'Sin descripción'}'
                    '${request.fechaEvento == null ? '' : ' · Evento: ${request.fechaEvento!.day}/${request.fechaEvento!.month}/${request.fechaEvento!.year}'}',
                  ),
                  isThreeLine: true,
                  trailing: Wrap(
                    children: [
                      IconButton(
                        tooltip: 'Descargar ZIP',
                        onPressed: _loading ? null : () => _download(request),
                        icon: const Icon(Icons.download),
                      ),
                      IconButton(
                        tooltip: 'Previsualizar',
                        onPressed: _loading ? null : () => _preview(request),
                        icon: const Icon(Icons.preview),
                      ),
                      IconButton(
                        tooltip: 'Rechazar',
                        onPressed: _loading ? null : () => _reject(request),
                        icon: const Icon(Icons.cancel_outlined),
                      ),
                      FilledButton(
                        onPressed: _loading ? null : () => _approve(request),
                        child: Text(request.estado ==
                                GalleryUploadRequestStatus.aprobado
                            ? 'Continuar'
                            : 'Aprobar'),
                      ),
                    ],
                  ),
                ),
              if (_selectedRequest != null && _entries.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Vista previa de ${_selectedRequest!.titulo}',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 150,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _entries.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 8),
                          itemBuilder: (_, index) => Image.memory(
                            _entries[index].thumbnail,
                            width: 150,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              if (_status.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_status),
                ),
            ],
          ),
        );
      },
    );
  }
}
