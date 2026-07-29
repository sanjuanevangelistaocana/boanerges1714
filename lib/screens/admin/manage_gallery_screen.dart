import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/models/gallery.dart';
import 'package:boanerges1714/screens/admin/gallery_moderation_section.dart';
import 'package:boanerges1714/services/gallery_service.dart';
import 'package:boanerges1714/utils/gallery_download.dart';

class ManageGalleryScreen extends StatefulWidget {
  const ManageGalleryScreen({super.key});

  @override
  State<ManageGalleryScreen> createState() => _ManageGalleryScreenState();
}

class _ManageGalleryScreenState extends State<ManageGalleryScreen> {
  String? _selectedFolderId;
  final _selectedImages = <String>{};
  List<GalleryImage> _images = [];
  DocumentSnapshot? _lastImage;
  bool _loadingImages = false;
  bool _hasMoreImages = true;
  bool _dropActive = false;
  String _progress = '';

  GalleryFolder? _selectedFolder(List<GalleryFolder> folders) {
    if (folders.isEmpty) return null;
    return folders.firstWhere(
      (folder) => folder.id == _selectedFolderId,
      orElse: () => folders.first,
    );
  }

  Future<void> _loadImages(GalleryFolder folder, {bool append = false}) async {
    if (_loadingImages) return;
    setState(() => _loadingImages = true);
    try {
      final page = await context.read<GalleryService>().fetchImagesPageWithCursor(
            folderId: folder.id,
            startAfter: append ? _lastImage : null,
            limit: 40,
          );
      if (!mounted) return;
      setState(() {
        if (!append) _images = [];
        _images.addAll(page.images);
        _lastImage = page.lastDocument;
        _hasMoreImages = page.hasMore;
        _loadingImages = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingImages = false;
        _progress = 'No se pudieron cargar las fotografías: $error';
      });
    }
  }

  Future<void> _createOrEditFolder(
    BuildContext context, {
    GalleryFolder? folder,
  }) async {
    final name = TextEditingController(text: folder?.nombre);
    final description = TextEditingController(text: folder?.descripcion);
    var isPublic = folder?.publica ?? false;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(folder == null ? 'Nueva carpeta' : 'Editar carpeta'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: description,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Carpeta pública'),
                  value: isPublic,
                  onChanged: (value) =>
                      setDialogState(() => isPublic = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'name': name.text.trim(),
                'description': description.text.trim(),
                'public': isPublic,
              }),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    description.dispose();
    if (result == null || result['name'] == '') return;
    final service = context.read<GalleryService>();
    try {
      if (folder == null) {
        final now = DateTime.now();
        await service.createFolder(GalleryFolder(
          id: '',
          nombre: result['name'] as String,
          descripcion: result['description'] as String,
          publica: result['public'] as bool,
          fechaCreacion: now,
          fechaActualizacion: now,
        ));
      } else {
        await service.updateFolder(folder.id, {
          'nombre': result['name'],
          'descripcion': result['description'],
        });
        if (folder.publica != result['public']) {
          await service.setFolderVisibility(
            folderId: folder.id,
            publica: result['public'] as bool,
          );
        }
      }
    } catch (error) {
      if (mounted) setState(() => _progress = '$error');
    }
  }

  Future<void> _deleteFolder(GalleryFolder folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Borrar carpeta'),
        content: Text('¿Quieres borrar «${folder.nombre}»? '
            'El borrado será lógico y no eliminará fotografías automáticamente.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Borrar')),
        ],
      ),
    );
    if (confirmed == true) {
      await context.read<GalleryService>().deleteFolder(folder.id);
    }
  }

  Future<void> _uploadImages(GalleryFolder folder) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return;
    await _uploadFiles(folder, result.files);
  }

  Future<void> _uploadFiles(
    GalleryFolder folder,
    List<PlatformFile> files,
  ) async {
    final service = context.read<GalleryService>();
    var success = 0;
    final failures = <String>[];
    for (var index = 0; index < files.length; index++) {
      final file = files[index];
      final bytes = file.bytes;
      setState(() => _progress =
          'Subiendo ${index + 1}/${files.length}: ${file.name}');
      if (bytes == null) {
        failures.add('${file.name}: no se pudieron leer los bytes');
        continue;
      }
      try {
        await service.uploadImage(
          folderId: folder.id,
          bytes: bytes,
          fileName: file.name,
          estado: GalleryImageStatus.aprobada,
        );
        success++;
      } catch (error) {
        failures.add('${file.name}: $error');
      }
    }
    if (!mounted) return;
    setState(() => _progress =
        'Completadas: $success · Fallidas: ${failures.length}'
        '${failures.isEmpty ? '' : '\n${failures.join('\n')}'}');
    _lastImage = null;
    _hasMoreImages = true;
    await _loadImages(folder);
  }

  Future<void> _deleteSelected(GalleryFolder folder) async {
    final selected =
        _images.where((image) => _selectedImages.contains(image.id)).toList();
    if (selected.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar fotografías'),
        content: Text('¿Eliminar ${selected.length} fotografía(s)?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true) return;
    for (final image in selected) {
      await context.read<GalleryService>().deleteImage(image);
    }
    setState(() => _selectedImages.clear());
    if (_selectedFolderId != null) {
      final source = await context
          .read<GalleryService>()
          .watchFolder(_selectedFolderId!)
          .first;
      if (source != null) {
        _lastImage = null;
        _hasMoreImages = true;
        await _loadImages(source);
      }
    }
  }

  Future<void> _moveSelected(GalleryFolder destination) async {
    final selected =
        _images.where((image) => _selectedImages.contains(image.id)).toList();
    for (final image in selected) {
      await context.read<GalleryService>().moveImage(
            image: image,
            destinationFolderId: destination.id,
          );
    }
    setState(() => _selectedImages.clear());
    await _loadImages(folder);
  }

  Future<void> _downloadFolder(GalleryFolder folder) async {
    final estimatedMb = folder.numFotos * 3;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descargar carpeta completa'),
        content: Text(
          'El tamaño estimado es de unos $estimatedMb MB. '
          '${estimatedMb > 500 ? 'Es una descarga grande y puede agotar la memoria del navegador. ' : ''}'
          'La generación puede tardar unos minutos. ¿Continuar?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Descargar')),
        ],
      ),
    );
    if (proceed != true) return;
    try {
      final bytes = await context.read<GalleryService>().downloadFolderZip(
        folderId: folder.id,
        onProgress: (done, total) {
          if (mounted) setState(() => _progress = 'Comprimiendo $done/$total');
        },
      );
      final downloaded =
          await downloadGalleryBytes(bytes, '${folder.nombre}.zip');
      if (mounted) {
        setState(() => _progress = downloaded
            ? 'ZIP generado correctamente.'
            : 'La descarga directa del ZIP está disponible en la versión web.');
      }
    } catch (error) {
      if (mounted) setState(() => _progress = 'Error generando ZIP: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<GalleryService>();
    return StreamBuilder<List<GalleryFolder>>(
      stream: service.watchFolders(),
      builder: (context, snapshot) {
        final folders = snapshot.data ?? const [];
        final folder = _selectedFolder(folders);
        if (folder != null && _selectedFolderId != folder.id) {
          _selectedFolderId = folder.id;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _loadImages(folder);
          });
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Gestión de Galería',
                            style: Theme.of(context).textTheme.headlineMedium),
                      ),
                      FilledButton.icon(
                        onPressed: () => _createOrEditFolder(context),
                        icon: const Icon(Icons.create_new_folder),
                        label: const Text('Nueva carpeta'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (snapshot.hasError)
                    Text('Error cargando carpetas: ${snapshot.error}'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        height: (folders.length.clamp(1, 5) * 72).toDouble(),
                        child: ReorderableListView.builder(
                          itemCount: folders.length,
                          onReorder: (oldIndex, newIndex) async {
                            if (newIndex > oldIndex) newIndex--;
                            final reordered = [...folders];
                            final moved = reordered.removeAt(oldIndex);
                            reordered.insert(newIndex, moved);
                            await service.reorderFolders(
                                reordered.map((item) => item.id).toList());
                          },
                          itemBuilder: (context, index) {
                            final item = folders[index];
                            final selected = item.id == folder?.id;
                            return ListTile(
                              key: ValueKey(item.id),
                              selected: selected,
                              selectedTileColor:
                                  AppTheme.primaryColor.withAlpha(18),
                              leading: const Icon(Icons.drag_handle),
                              title: Text(item.nombre),
                              subtitle: Text(
                                  '${item.numFotos} fotos · ${item.publica ? 'Pública' : 'Privada'}'
                                  '${item.relocating ? ' · Reubicando…' : ''}'),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _createOrEditFolder(context, folder: item);
                                  } else if (value == 'delete') {
                                    _deleteFolder(item);
                                  } else if (value == 'zip') {
                                    _downloadFolder(item);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                      value: 'edit', child: Text('Editar')),
                                  PopupMenuItem(
                                      value: 'zip',
                                      child: Text('Descargar ZIP')),
                                  PopupMenuItem(
                                      value: 'delete', child: Text('Borrar')),
                                ],
                              ),
                              onTap: () => setState(() {
                                _selectedFolderId = item.id;
                                _images = [];
                                _lastImage = null;
                                _hasMoreImages = true;
                              }),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  GalleryModerationSection(folders: folders),
                  if (folder != null) ...[
                    const SizedBox(height: 24),
                    _buildImageManagement(context, folder, folders),
                  ],
                  if (_progress.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    SelectableText(_progress),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageManagement(
      BuildContext context, GalleryFolder folder, List<GalleryFolder> folders) {
    final allSelected =
        _images.isNotEmpty && _selectedImages.length == _images.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Fotografías de ${folder.nombre}',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            OutlinedButton.icon(
              onPressed: () => _uploadImages(folder),
              icon: const Icon(Icons.upload),
              label: const Text('Subir fotografías'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        DropRegion(
          formats: Formats.standardFormats,
          onDropEnter: (_) => setState(() => _dropActive = true),
          onDropLeave: (_) => setState(() => _dropActive = false),
          onDropOver: (_) => DropOperation.copy,
          onPerformDrop: (event) async {
            setState(() => _dropActive = false);
            final files = <PlatformFile>[];
            for (final item in event.session.items) {
              final reader = item.dataReader;
              if (reader == null) continue;
              final file = await reader.getFile(Formats.fileUri);
              if (file == null) continue;
              final bytes = await file.readAll();
              files.add(PlatformFile(
                name: item.suggestedName ?? 'fotografia',
                size: bytes.length,
                bytes: bytes,
              ));
            }
            if (files.isNotEmpty && mounted) {
              await _uploadFiles(folder, files);
            }
          },
          child: InkWell(
            onTap: () => _uploadImages(folder),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _dropActive
                      ? AppTheme.primaryColor
                      : AppTheme.primaryColor.withAlpha(80),
                  width: _dropActive ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(10),
                color: _dropActive
                    ? AppTheme.primaryColor.withAlpha(25)
                    : AppTheme.primaryColor.withAlpha(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_dropActive
                      ? Icons.file_download
                      : Icons.cloud_upload_outlined),
                  const SizedBox(width: 8),
                  Text(_dropActive
                      ? 'Suelta las fotografías aquí'
                      : 'Arrastra fotografías aquí o pulsa para seleccionarlas'),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_selectedImages.isNotEmpty)
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _deleteSelected(folder),
                icon: const Icon(Icons.delete_outline),
                label: Text('Eliminar (${_selectedImages.length})'),
              ),
              PopupMenuButton<GalleryFolder>(
                onSelected: _moveSelected,
                itemBuilder: (_) => folders
                    .where((item) => item.id != folder.id)
                    .map((item) => PopupMenuItem(
                          value: item,
                          child: Text('Mover a ${item.nombre}'),
                        ))
                    .toList(),
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.drive_file_move_outline),
                  label: const Text('Mover'),
                ),
              ),
            ],
          ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: allSelected,
          onChanged: (value) => setState(() {
            if (value == true) {
              _selectedImages.addAll(_images.map((image) => image.id));
            } else {
              _selectedImages.clear();
            }
          }),
          title: const Text('Seleccionar todas las cargadas'),
        ),
        if (_loadingImages && _images.isEmpty)
          const Center(child: CircularProgressIndicator())
        else if (_images.isEmpty)
          const Text('Esta carpeta todavía no tiene fotografías.')
        else ...[
          const Padding(
            padding: EdgeInsets.only(top: 12, bottom: 6),
            child: Text('Orden de fotografías (arrastra para reordenar)'),
          ),
          SizedBox(
            height: 110,
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              buildDefaultDragHandles: true,
              itemCount: _images.length,
              onReorder: (oldIndex, newIndex) async {
                if (newIndex > oldIndex) newIndex--;
                final reordered = [..._images]
                  ..insert(newIndex, _images.removeAt(oldIndex));
                setState(() => _images = reordered);
                await context.read<GalleryService>().reorderImages(
                    reordered.map((image) => image.id).toList());
              },
              itemBuilder: (context, index) {
                final image = _images[index];
                return Padding(
                  key: ValueKey('order-${image.id}'),
                  padding: const EdgeInsets.only(right: 8),
                  child: CachedNetworkImage(
                    imageUrl: image.thumbUrl?.isNotEmpty == true
                        ? image.thumbUrl!
                        : image.url,
                    width: 100,
                    fit: BoxFit.cover,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _images.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            itemBuilder: (context, index) {
              final image = _images[index];
              final selected = _selectedImages.contains(image.id);
              return Card(
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: image.thumbUrl?.isNotEmpty == true
                          ? image.thumbUrl!
                          : image.url,
                      fit: BoxFit.cover,
                      memCacheWidth: 500,
                    ),
                    Align(
                      alignment: Alignment.topLeft,
                      child: Checkbox(
                        value: selected,
                        onChanged: (value) => setState(() {
                          if (value == true) {
                            _selectedImages.add(image.id);
                          } else {
                            _selectedImages.remove(image.id);
                          }
                        }),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: ColoredBox(
                        color: Colors.black54,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              tooltip: 'Descargar',
                              onPressed: () => launchUrl(Uri.parse(image.url)),
                              icon: const Icon(Icons.download,
                                  color: Colors.white),
                            ),
                            IconButton(
                              tooltip: 'Usar como portada',
                              onPressed: () => context
                                  .read<GalleryService>()
                                  .setFolderCover(
                                    folderId: folder.id,
                                    imageId: image.id,
                                    imageUrl: image.url,
                                  ),
                              icon: const Icon(Icons.star_border,
                                  color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
        if (_hasMoreImages)
          Center(
            child: TextButton(
              onPressed: _loadingImages
                  ? null
                  : () => _loadImages(folder, append: true),
              child: const Text('Cargar más fotografías'),
            ),
          ),
      ],
    );
  }
}
