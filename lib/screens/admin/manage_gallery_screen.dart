import 'package:cached_network_image/cached_network_image.dart';
import 'package:boanerges1714/widgets/responsive_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/models/gallery.dart';
import 'package:boanerges1714/screens/admin/gallery_moderation_section.dart';
import 'package:boanerges1714/services/gallery_service.dart';
import 'package:boanerges1714/utils/gallery_download.dart';
import 'package:boanerges1714/utils/gallery_error.dart';

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
  String _progress = '';
  bool _mutating = false;

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('permission-denied') ||
        text.contains('permission_denied') ||
        text.contains('unauthorized')) {
      return 'Tu usuario no tiene permisos de administrador para esta acción.';
    }
    return text.startsWith('Bad state: ')
        ? text.substring('Bad state: '.length)
        : text;
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<GalleryService>().ensureSystemFolders().then((_) {
          _showMessage('Carpetas internas preparadas.');
        }).catchError((error) {
          _showMessage(
            'No se pudieron preparar las carpetas internas: '
            '${_friendlyError(error)}',
            error: true,
          );
        });
      }
    });
  }

  GalleryFolder? _selectedFolder(List<GalleryFolder> folders) {
    final selectable = folders
        .where((folder) => folder.sistema != GalleryFolderSystem.adminRoot)
        .toList();
    if (selectable.isEmpty) return null;
    return selectable.firstWhere(
      (folder) => folder.id == _selectedFolderId,
      orElse: () => selectable.first,
    );
  }

  Future<void> _loadImages(GalleryFolder folder, {bool append = false}) async {
    if (_loadingImages) return;
    setState(() => _loadingImages = true);
    try {
      final page =
          await context.read<GalleryService>().fetchImagesPageWithCursor(
                folderId: folder.id,
                startAfter: append ? _lastImage : null,
                limit: 40,
                includeAdmin: true,
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
        _progress = 'No se pudieron cargar las fotografías: '
            '${galleryErrorMessage(error)}';
      });
      debugPrint(
          '[ManageGalleryScreen] query gallery_images folder_id=${folder.id} '
          'deleted=false orderBy=orden,__name__ includeAdmin=true error: $error');
      _showMessage(galleryErrorMessage(error), error: true);
    }
  }

  Future<void> _reloadImages(GalleryFolder folder) async {
    if (!mounted) return;
    setState(() {
      _images = [];
      _lastImage = null;
      _hasMoreImages = true;
    });
    await _loadImages(folder);
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
          content: ResponsiveDialogBox(
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
                  onChanged: (value) => setDialogState(() => isPublic = value),
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
    if (folder != null && folder.sistema != GalleryFolderSystem.ninguno) {
      return;
    }
    final service = context.read<GalleryService>();
    if (mounted) setState(() => _mutating = true);
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
      _showMessage(
        folder == null
            ? 'Carpeta creada correctamente.'
            : 'Carpeta actualizada correctamente.',
      );
    } catch (error) {
      _showMessage(_friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _deleteFolder(GalleryFolder folder) async {
    if (folder.sistema != GalleryFolderSystem.ninguno) return;
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
      if (mounted) setState(() => _mutating = true);
      try {
        await context.read<GalleryService>().deleteFolder(folder.id);
        _showMessage('Carpeta borrada correctamente.');
      } catch (error) {
        _showMessage(_friendlyError(error), error: true);
      } finally {
        if (mounted) setState(() => _mutating = false);
      }
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
    if (mounted) setState(() => _mutating = true);
    var success = 0;
    final failures = <String>[];
    for (var index = 0; index < files.length; index++) {
      final file = files[index];
      final bytes = file.bytes;
      if (mounted) {
        setState(() =>
            _progress = 'Subiendo ${index + 1}/${files.length}: ${file.name}');
      }
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
    setState(
        () => _progress = 'Completadas: $success · Fallidas: ${failures.length}'
            '${failures.isEmpty ? '' : '\n${failures.join('\n')}'}');
    _showMessage(
      failures.isEmpty
          ? '$success fotografía(s) subida(s) correctamente.'
          : 'Se subieron $success fotografía(s); fallaron ${failures.length}.',
      error: failures.isNotEmpty,
    );
    await _reloadImages(folder);
    if (mounted) setState(() => _mutating = false);
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
    if (mounted) setState(() => _mutating = true);
    try {
      var storageWarnings = 0;
      for (final image in selected) {
        final storageDeleted =
            await context.read<GalleryService>().deleteImage(image);
        if (!storageDeleted) storageWarnings++;
      }
      _showMessage(
        storageWarnings == 0
            ? '${selected.length} fotografía(s) eliminada(s).'
            : '${selected.length} fotografía(s) eliminada(s) del catálogo, '
                'pero no se pudo borrar el fichero físico de '
                '$storageWarnings.',
        error: storageWarnings > 0,
      );
    } catch (error) {
      _showMessage(_friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
    if (!mounted) return;
    setState(() => _selectedImages.clear());
    await _reloadImages(folder);
  }

  Future<void> _moveSelected(GalleryFolder destination) async {
    final selected =
        _images.where((image) => _selectedImages.contains(image.id)).toList();
    final source = await context
        .read<GalleryService>()
        .watchFolder(
          _selectedFolderId!,
        )
        .first;
    if (source == null) return;
    var allowPublishing = false;
    if (source.sistema == GalleryFolderSystem.bancoInterno &&
        !destination.soloAdmin) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Publicar fotografías internas'),
          content: const Text(
            'Estas fotografías proceden del Banco interno y pasarán a una '
            'carpeta visible para cofrades o visitantes. Esta acción las hará '
            'públicas fuera del espacio exclusivo de administradores. ¿Continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar publicación'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      allowPublishing = true;
    }
    if (mounted) setState(() => _mutating = true);
    try {
      for (final image in selected) {
        await context.read<GalleryService>().moveImage(
              image: image,
              destinationFolderId: destination.id,
              allowPublishingFromInternalBank: allowPublishing,
            );
      }
      _showMessage('${selected.length} fotografía(s) movida(s).');
    } catch (error) {
      _showMessage(_friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
    if (mounted) setState(() => _selectedImages.clear());
    await _reloadImages(source);
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
            includeAdmin: true,
            onProgress: (done, total) {
              if (mounted)
                setState(() => _progress = 'Comprimiendo $done/$total');
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
      stream: service.watchFolders(includeAdmin: true),
      builder: (context, snapshot) {
        final allFolders = snapshot.data ?? const [];
        final folders = allFolders
            .where((item) => item.sistema == GalleryFolderSystem.ninguno)
            .toList();
        final systemFolders = allFolders
            .where((item) => item.sistema != GalleryFolderSystem.ninguno)
            .toList();
        final folder = _selectedFolder(allFolders);
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
                        onPressed: _mutating
                            ? null
                            : () => _createOrEditFolder(context),
                        icon: const Icon(Icons.create_new_folder),
                        label: const Text('Nueva carpeta'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (snapshot.hasError)
                    Text('Error cargando carpetas: '
                        '${galleryErrorMessage(snapshot.error!)}'),
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
                            try {
                              await service.reorderFolders(
                                  reordered.map((item) => item.id).toList());
                              _showMessage('Orden de carpetas guardado.');
                            } catch (error) {
                              _showMessage(_friendlyError(error), error: true);
                            }
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
                  _buildInternalAdministration(context, systemFolders),
                  const SizedBox(height: 20),
                  GalleryModerationSection(folders: folders),
                  if (folder != null) ...[
                    const SizedBox(height: 24),
                    _buildImageManagement(context, folder, allFolders),
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
              onPressed: _mutating ? null : () => _uploadImages(folder),
              icon: const Icon(Icons.upload),
              label: const Text('Subir fotografías'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: _mutating ? null : () => _uploadImages(folder),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.primaryColor.withAlpha(80)),
              borderRadius: BorderRadius.circular(10),
              color: AppTheme.primaryColor.withAlpha(8),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_upload_outlined),
                SizedBox(width: 8),
                Text('Pulsa para seleccionar fotografías'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_selectedImages.isNotEmpty)
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _mutating ? null : () => _deleteSelected(folder),
                icon: const Icon(Icons.delete_outline),
                label: Text('Eliminar (${_selectedImages.length})'),
              ),
              PopupMenuButton<GalleryFolder>(
                onSelected: _moveSelected,
                itemBuilder: (_) => folders
                    .where((item) =>
                        item.id != folder.id &&
                        item.sistema != GalleryFolderSystem.adminRoot)
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
                if (!mounted) return;
                setState(() {
                  _images = reordered;
                  _mutating = true;
                });
                try {
                  await context.read<GalleryService>().reorderImages(
                      reordered.map((image) => image.id).toList());
                  _showMessage('Orden de fotografías guardado.');
                  await _reloadImages(folder);
                } catch (error) {
                  _showMessage(_friendlyError(error), error: true);
                } finally {
                  if (mounted) setState(() => _mutating = false);
                }
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
                              onPressed: _mutating
                                  ? null
                                  : () async {
                                      try {
                                        await context
                                            .read<GalleryService>()
                                            .setFolderCover(
                                              folderId: folder.id,
                                              imageId: image.id,
                                              imageUrl: image.url,
                                            );
                                        _showMessage(
                                            'Portada de carpeta actualizada.');
                                      } catch (error) {
                                        _showMessage(_friendlyError(error),
                                            error: true);
                                      }
                                    },
                              icon: const Icon(Icons.star_border,
                                  color: Colors.white),
                            ),
                            IconButton(
                              tooltip: image.publica
                                  ? 'Hacer privada'
                                  : 'Hacer pública',
                              onPressed: _mutating
                                  ? null
                                  : () async {
                                      try {
                                        setState(() => _mutating = true);
                                        await context
                                            .read<GalleryService>()
                                            .setImageVisibility(
                                              imageId: image.id,
                                              publica: !image.publica,
                                            );
                                        _showMessage(
                                          image.publica
                                              ? 'Fotografía marcada como privada.'
                                              : 'Fotografía marcada como pública.',
                                        );
                                        await _reloadImages(folder);
                                      } catch (error) {
                                        _showMessage(_friendlyError(error),
                                            error: true);
                                      } finally {
                                        if (mounted) {
                                          setState(() => _mutating = false);
                                        }
                                      }
                                    },
                              icon: Icon(
                                image.publica
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: Colors.white,
                              ),
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

  Widget _buildInternalAdministration(
    BuildContext context,
    List<GalleryFolder> systemFolders,
  ) {
    final internal = systemFolders
        .where((folder) =>
            folder.sistema == GalleryFolderSystem.bancoInterno ||
            folder.sistema == GalleryFolderSystem.carruselInicio)
        .toList();
    if (internal.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryDark.withAlpha(12),
        border: Border.all(color: AppTheme.primaryDark.withAlpha(50)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.admin_panel_settings,
                  color: AppTheme.primaryDark),
              const SizedBox(width: 8),
              Text(
                'Administración interna',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.primaryDark,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Espacio exclusivo de administradores. Estas carpetas no aparecen '
            'en la galería pública ni en la galería de cofrades.',
          ),
          const SizedBox(height: 12),
          ...internal.map(
            (folder) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  folder.sistema == GalleryFolderSystem.bancoInterno
                      ? Icons.lock
                      : Icons.view_carousel,
                  color: AppTheme.primaryColor,
                ),
                title: Text(folder.nombre),
                subtitle: Text(
                  folder.sistema == GalleryFolderSystem.carruselInicio
                      ? '${folder.numFotos} fotos · El orden define el carrusel de inicio'
                      : '${folder.numFotos} fotos · Solo administradores',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => setState(() {
                  _selectedFolderId = folder.id;
                  _images = [];
                  _lastImage = null;
                  _hasMoreImages = true;
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
