import 'dart:typed_data';
import 'dart:math' as math;

import 'package:archive/archive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:boanerges1714/models/gallery.dart';
import 'package:boanerges1714/services/storage_service.dart';

class GalleryThumbnail {
  final Uint8List bytes;
  final int width;
  final int height;

  const GalleryThumbnail({
    required this.bytes,
    required this.width,
    required this.height,
  });
}

class GalleryImagePage {
  final List<GalleryImage> images;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;

  const GalleryImagePage({
    required this.images,
    required this.lastDocument,
    required this.hasMore,
  });
}

class GalleryZipValidationResult {
  final int imageCount;

  const GalleryZipValidationResult({required this.imageCount});
}

class GalleryService {
  static const int maxImageSizeBytes = 15 * 1024 * 1024;
  static const int maxZipSizeBytes = 50 * 1024 * 1024;
  static const int maxBatchOperations = 400;
  static const int thumbnailMaxSide = 600;
  static const int maxZipImages = 1000;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final StorageService _storage;

  GalleryService({StorageService? storage})
      : _storage = storage ?? StorageService();

  CollectionReference<Map<String, dynamic>> get _folders =>
      _db.collection('gallery_folders');
  CollectionReference<Map<String, dynamic>> get _images =>
      _db.collection('gallery_images');
  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection('gallery_upload_requests');

  Stream<List<GalleryFolder>> watchFolders({
    bool onlyPublic = false,
    bool includeAdmin = false,
  }) {
    Query<Map<String, dynamic>> query =
        _folders.where('deleted', isEqualTo: false).orderBy('orden');
    if (!includeAdmin) {
      query = _folders
          .where('solo_admin', isEqualTo: false)
          .where('deleted', isEqualTo: false)
          .orderBy('orden');
    }
    if (onlyPublic) {
      query = _folders
          .where('publica', isEqualTo: true)
          .where('solo_admin', isEqualTo: false)
          .where('deleted', isEqualTo: false)
          .orderBy('orden');
    }
    return query.snapshots().map((snapshot) => snapshot.docs
        .map(GalleryFolder.fromFirestore)
        .where(
            (folder) => !folder.deleted && (includeAdmin || !folder.soloAdmin))
        .toList());
  }

  Future<void> ensureSystemFolders() async {
    final root = await _ensureSystemFolder(
      slug: 'admin_root',
      system: GalleryFolderSystem.adminRoot,
      name: 'Administración interna',
    );
    await _ensureSystemFolder(
      slug: 'banco_interno',
      system: GalleryFolderSystem.bancoInterno,
      name: 'Banco interno',
      parentId: root.id,
    );
    await _ensureSystemFolder(
      slug: 'carrusel_inicio',
      system: GalleryFolderSystem.carruselInicio,
      name: 'Carrusel de inicio',
      parentId: root.id,
    );
  }

  Future<GalleryFolder> _ensureSystemFolder({
    required String slug,
    required GalleryFolderSystem system,
    required String name,
    String? parentId,
  }) async {
    final existing =
        await _folders.where('slug', isEqualTo: slug).limit(1).get();
    if (existing.docs.isNotEmpty)
      return GalleryFolder.fromFirestore(existing.docs.first);
    final now = DateTime.now();
    final ref = _folders.doc();
    final folder = GalleryFolder(
      id: ref.id,
      nombre: name,
      parentId: parentId,
      slug: slug,
      soloAdmin: true,
      sistema: system,
      fechaCreacion: now,
      fechaActualizacion: now,
    );
    await ref.set(folder.toFirestore());
    return folder;
  }

  Stream<GalleryFolder?> watchFolder(String id) {
    return _folders.doc(id).snapshots().map(
          (doc) => doc.exists ? GalleryFolder.fromFirestore(doc) : null,
        );
  }

  Future<String> createFolder(GalleryFolder folder) async {
    final ref = folder.id.isEmpty ? _folders.doc() : _folders.doc(folder.id);
    final now = DateTime.now();
    final normalized = folder.copyWith(
      id: ref.id,
      fechaCreacion: folder.fechaCreacion,
      fechaActualizacion: now,
      deleted: false,
      relocating: false,
      orden: folder.orden,
      numFotos: folder.numFotos,
    );
    await ref.set(normalized.toFirestore());
    return ref.id;
  }

  Future<void> updateFolder(String id, Map<String, dynamic> data) async {
    final snapshot = await _folders.doc(id).get();
    if (snapshot.exists) {
      final folder = GalleryFolder.fromFirestore(snapshot);
      if (folder.sistema != GalleryFolderSystem.ninguno &&
          (data.containsKey('nombre') ||
              data.containsKey('slug') ||
              data.containsKey('sistema') ||
              data.containsKey('solo_admin') ||
              data.containsKey('publica'))) {
        throw StateError(
            'Las carpetas de sistema no se pueden renombrar ni modificar.');
      }
    }
    await _folders.doc(id).update({
      ...data,
      'fecha_actualizacion': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteFolder(String id) async {
    final snapshot = await _folders.doc(id).get();
    if (snapshot.exists &&
        GalleryFolder.fromFirestore(snapshot).sistema !=
            GalleryFolderSystem.ninguno) {
      throw StateError('Las carpetas de sistema no se pueden eliminar.');
    }
    await _folders.doc(id).update({
      'deleted': true,
      'fecha_actualizacion': FieldValue.serverTimestamp(),
    });
  }

  Future<void> reorderFolders(List<String> folderIds) async {
    await _commitInChunks(folderIds, (batch, index, id) {
      batch.update(_folders.doc(id), {
        'orden': index,
        'fecha_actualizacion': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> setFolderCover({
    required String folderId,
    required String imageId,
    required String imageUrl,
  }) async {
    await _folders.doc(folderId).update({
      'cover_image_id': imageId,
      'cover_image_url': imageUrl,
      'fecha_actualizacion': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setFolderVisibility({
    required String folderId,
    required bool publica,
  }) async {
    final snapshot = await _folders.doc(folderId).get();
    if (snapshot.exists &&
        GalleryFolder.fromFirestore(snapshot).sistema !=
            GalleryFolderSystem.ninguno) {
      throw StateError(
          'Las carpetas de sistema no pueden cambiar de visibilidad.');
    }
    await _folders.doc(folderId).update({
      'publica': publica,
      'relocating': true,
      'fecha_actualizacion': FieldValue.serverTimestamp(),
    });

    try {
      final snapshot =
          await _images.where('folder_id', isEqualTo: folderId).get();
      await _commitInChunks(snapshot.docs, (batch, _, doc) {
        // Hide while paths are being moved so public clients never receive
        // an image whose Storage URL still belongs to the old privacy prefix.
        batch.update(doc.reference, {'publica': false});
      });

      await relocateFolderFiles(folderId: folderId, publica: publica);
    } catch (_) {
      // Keep relocating=true so a later maintenance operation can retry it.
      rethrow;
    }
  }

  Future<List<GalleryImage>> fetchImagesPage({
    required String folderId,
    DocumentSnapshot? startAfter,
    int limit = 30,
    bool onlyPublic = false,
  }) async {
    final page = await fetchImagesPageWithCursor(
      folderId: folderId,
      startAfter: startAfter,
      limit: limit,
      onlyPublic: onlyPublic,
    );
    return page.images;
  }

  Future<GalleryImagePage> fetchImagesPageWithCursor({
    required String folderId,
    DocumentSnapshot? startAfter,
    int limit = 30,
    bool onlyPublic = false,
    bool includeAdmin = false,
  }) async {
    Query<Map<String, dynamic>> query = _images
        .where('folder_id', isEqualTo: folderId)
        .where('deleted', isEqualTo: false)
        .orderBy('orden')
        .orderBy(FieldPath.documentId)
        .limit(limit);
    if (!onlyPublic && !includeAdmin) {
      query = _images
          .where('folder_id', isEqualTo: folderId)
          .where('solo_admin', isEqualTo: false)
          .where('deleted', isEqualTo: false)
          .orderBy('orden')
          .orderBy(FieldPath.documentId)
          .limit(limit);
    }
    if (onlyPublic) {
      query = _images
          .where('folder_id', isEqualTo: folderId)
          .where('publica', isEqualTo: true)
          .where('estado', isEqualTo: GalleryImageStatus.aprobada.name)
          .where('deleted', isEqualTo: false)
          .orderBy('orden')
          .orderBy(FieldPath.documentId)
          .limit(limit);
    }
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    final snapshot = await query.get();
    return GalleryImagePage(
      images: snapshot.docs.map(GalleryImage.fromFirestore).toList(),
      lastDocument: snapshot.docs.isEmpty ? null : snapshot.docs.last,
      hasMore: snapshot.docs.length == limit,
    );
  }

  Stream<List<GalleryImage>> watchImagesPreview(
    String folderId, {
    int limit = 12,
    bool onlyPublic = false,
    bool includeAdmin = false,
  }) {
    Query<Map<String, dynamic>> query = _images
        .where('folder_id', isEqualTo: folderId)
        .where('deleted', isEqualTo: false)
        .orderBy('orden')
        .orderBy(FieldPath.documentId)
        .limit(limit);
    if (!onlyPublic && !includeAdmin) {
      query = _images
          .where('folder_id', isEqualTo: folderId)
          .where('solo_admin', isEqualTo: false)
          .where('deleted', isEqualTo: false)
          .orderBy('orden')
          .orderBy(FieldPath.documentId)
          .limit(limit);
    }
    if (onlyPublic) {
      query = _images
          .where('folder_id', isEqualTo: folderId)
          .where('publica', isEqualTo: true)
          .where('estado', isEqualTo: GalleryImageStatus.aprobada.name)
          .where('deleted', isEqualTo: false)
          .orderBy('orden')
          .orderBy(FieldPath.documentId)
          .limit(limit);
    }
    return query.snapshots().map(
          (snapshot) => snapshot.docs.map(GalleryImage.fromFirestore).toList(),
        );
  }

  Stream<List<GalleryImage>> watchCarouselImages({int limit = 20}) {
    return _images
        .where('carrusel', isEqualTo: true)
        .where('deleted', isEqualTo: false)
        .orderBy('orden')
        .limit(limit)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(GalleryImage.fromFirestore).toList());
  }

  Future<String> addImage(GalleryImage image) async {
    if (image.storagePath.trim().isEmpty || image.url.trim().isEmpty) {
      throw StateError('La imagen no tiene una referencia válida en Storage.');
    }
    if (image.thumbPath?.trim().isEmpty != false ||
        image.thumbUrl?.trim().isEmpty != false) {
      throw StateError(
          'La miniatura no tiene una referencia válida en Storage.');
    }
    final ref = image.id.isEmpty ? _images.doc() : _images.doc(image.id);
    final folderRef = _folders.doc(image.folderId);
    final batch = _db.batch();
    batch.set(ref, image.copyWith(id: ref.id).toFirestore());
    if (!image.deleted) {
      batch.update(folderRef, {
        'num_fotos': FieldValue.increment(1),
        'fecha_actualizacion': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    return ref.id;
  }

  Future<bool> deleteImage(GalleryImage image) async {
    var deletedNow = false;
    await _db.runTransaction((transaction) async {
      final imageRef = _images.doc(image.id);
      final snapshot = await transaction.get(imageRef);
      final current =
          snapshot.exists ? GalleryImage.fromFirestore(snapshot) : image;
      if (current.deleted) return;
      deletedNow = true;
      transaction.update(imageRef, {
        'deleted': true,
      });
      transaction.update(_folders.doc(current.folderId), {
        'num_fotos': FieldValue.increment(-1),
        'fecha_actualizacion': FieldValue.serverTimestamp(),
      });
    });
    if (!deletedNow) return true;
    final originalDeleted = await _deleteStorageFile(image.url);
    final thumbnailDeleted = await _deleteStorageFile(image.thumbUrl);
    return originalDeleted && thumbnailDeleted;
  }

  Future<void> moveImage({
    required GalleryImage image,
    required String destinationFolderId,
    bool allowPublishingFromInternalBank = false,
  }) async {
    var destinationFolder = GalleryFolder(
      id: '',
      nombre: '',
      fechaCreacion: DateTime.now(),
      fechaActualizacion: DateTime.now(),
    );
    var sourceFolder = destinationFolder;
    var moved = false;
    await _db.runTransaction((transaction) async {
      final imageRef = _images.doc(image.id);
      final sourceRef = _folders.doc(image.folderId);
      final destinationRef = _folders.doc(destinationFolderId);
      final imageSnapshot = await transaction.get(imageRef);
      final destinationSnapshot = await transaction.get(destinationRef);
      if (!imageSnapshot.exists || !destinationSnapshot.exists) {
        throw StateError('La imagen o la carpeta de destino no existe.');
      }
      final current = GalleryImage.fromFirestore(imageSnapshot);
      sourceFolder =
          GalleryFolder.fromFirestore(await transaction.get(sourceRef));
      final destination = GalleryFolder.fromFirestore(destinationSnapshot);
      if (current.deleted || current.folderId == destinationFolderId) return;
      if (sourceFolder.sistema == GalleryFolderSystem.bancoInterno &&
          !destination.soloAdmin &&
          !allowPublishingFromInternalBank) {
        throw StateError(
          'Confirma explícitamente la publicación de una foto del Banco interno.',
        );
      }
      destinationFolder = destination;
      moved = true;
      transaction.update(imageRef, {
        'folder_id': destinationFolderId,
        'publica': false,
        'solo_admin': destination.soloAdmin,
        'carrusel': destination.sistema == GalleryFolderSystem.carruselInicio,
      });
      transaction.update(sourceRef, {
        'num_fotos': FieldValue.increment(-1),
        'fecha_actualizacion': FieldValue.serverTimestamp(),
      });
      transaction.update(destinationRef, {
        'num_fotos': FieldValue.increment(1),
        'fecha_actualizacion': FieldValue.serverTimestamp(),
      });
    });
    if (!moved) return;
    await _folders.doc(destinationFolderId).update({'relocating': true});
    try {
      await relocateImageFiles(
        imageId: image.id,
        folder: destinationFolder,
      );
      await _folders.doc(destinationFolderId).update({'relocating': false});
    } catch (_) {
      rethrow;
    }
  }

  Future<void> relocateFolderFiles({
    required String folderId,
    required bool publica,
    void Function(int completed, int total)? onProgress,
  }) async {
    final folderSnapshot = await _folders.doc(folderId).get();
    if (!folderSnapshot.exists) throw StateError('La carpeta no existe.');
    final folder = GalleryFolder.fromFirestore(folderSnapshot);
    await _folders.doc(folderId).update({'relocating': true});
    final snapshot = await _images
        .where('folder_id', isEqualTo: folderId)
        .where('deleted', isEqualTo: false)
        .get();
    for (var index = 0; index < snapshot.docs.length; index++) {
      await _relocateImageDocument(
        snapshot.docs[index],
        folder: folder,
      );
      onProgress?.call(index + 1, snapshot.docs.length);
    }
    await _commitInChunks(snapshot.docs, (batch, _, doc) {
      batch.update(doc.reference, {
        'publica': folder.sistema == GalleryFolderSystem.carruselInicio
            ? true
            : publica,
        'solo_admin': folder.soloAdmin,
        'carrusel': folder.sistema == GalleryFolderSystem.carruselInicio,
      });
    });
    await _folders.doc(folderId).update({
      'relocating': false,
      'fecha_actualizacion': FieldValue.serverTimestamp(),
    });
  }

  Future<void> relocateImageFiles({
    required String imageId,
    required GalleryFolder folder,
  }) async {
    final snapshot = await _images.doc(imageId).get();
    if (!snapshot.exists) return;
    await _relocateImageDocument(
      snapshot,
      folder: folder,
    );
    await _images.doc(imageId).update({
      'publica': folder.sistema == GalleryFolderSystem.carruselInicio
          ? true
          : folder.publica,
      'solo_admin': folder.soloAdmin,
      'carrusel': folder.sistema == GalleryFolderSystem.carruselInicio,
    });
  }

  Future<void> _relocateImageDocument(
    DocumentSnapshot<Map<String, dynamic>> snapshot, {
    required GalleryFolder folder,
  }) async {
    final image = GalleryImage.fromFirestore(snapshot);
    final prefix = 'gallery/${_storagePrefixFor(folder)}/${folder.id}';
    final oldOriginalPath = image.storagePath;
    final oldThumbPath = image.thumbPath;
    final originalName = oldOriginalPath.split('/').last;
    final thumbName = (oldThumbPath ?? originalName).split('/').last;
    final newOriginalPath = '$prefix/$originalName';
    final newThumbPath = '$prefix/thumbs/$thumbName';

    if (oldOriginalPath == newOriginalPath &&
        (oldThumbPath == null || oldThumbPath == newThumbPath)) {
      return;
    }

    final originalBytes = oldOriginalPath == newOriginalPath
        ? null
        : await _storage.downloadBytes(oldOriginalPath);
    final thumbBytes = oldThumbPath == null || oldThumbPath == newThumbPath
        ? null
        : await _storage.downloadBytes(oldThumbPath);
    final newOriginal = originalBytes == null
        ? {'storage_path': newOriginalPath, 'url': image.url}
        : await _storage.uploadBytesAtPath(
            fullPath: newOriginalPath,
            bytes: originalBytes,
            contentType: _contentTypeForPath(oldOriginalPath),
          );
    final newThumb = thumbBytes == null
        ? null
        : await _storage.uploadBytesAtPath(
            fullPath: newThumbPath,
            bytes: thumbBytes,
            contentType: 'image/jpeg',
          );

    await _images.doc(image.id).update({
      'storage_path': newOriginal['storage_path'],
      'url': newOriginal['url'],
      'thumb_path': newThumb?['storage_path'],
      'thumb_url': newThumb?['url'],
      'publica': folder.sistema == GalleryFolderSystem.carruselInicio
          ? true
          : folder.publica,
      'solo_admin': folder.soloAdmin,
      'carrusel': folder.sistema == GalleryFolderSystem.carruselInicio,
    });
    if (oldOriginalPath != newOriginalPath) {
      await _deleteStorageFile(image.url);
    }
    if (oldThumbPath != null && oldThumbPath != newThumbPath) {
      await _deleteStorageFile(image.thumbUrl);
    }
  }

  String _storagePrefixFor(GalleryFolder folder) {
    if (folder.sistema == GalleryFolderSystem.carruselInicio) {
      // El carrusel está oculto de los listados, pero sus imágenes son públicas.
      return 'public';
    }
    if (folder.soloAdmin) return 'admin';
    return folder.publica ? 'public' : 'private';
  }

  String _contentTypeForPath(String path) {
    final extension = path.split('.').last.toLowerCase();
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  Future<void> reorderImages(List<String> imageIds) async {
    await _commitInChunks(imageIds, (batch, index, id) {
      batch.update(_images.doc(id), {'orden': index});
    });
  }

  Future<Uint8List> downloadFolderZip({
    required String folderId,
    bool includeAdmin = false,
    void Function(int completed, int total)? onProgress,
  }) async {
    final archive = Archive();
    DocumentSnapshot? cursor;
    final images = <GalleryImage>[];
    do {
      final page = await fetchImagesPageWithCursor(
        folderId: folderId,
        startAfter: cursor,
        limit: 100,
        includeAdmin: includeAdmin,
      );
      images.addAll(page.images);
      cursor = page.lastDocument;
      if (!page.hasMore) break;
    } while (cursor != null);

    for (var index = 0; index < images.length; index++) {
      final image = images[index];
      final bytes = await _storage.downloadBytes(image.storagePath);
      archive.addFile(ArchiveFile(image.nombre, bytes.length, bytes));
      onProgress?.call(index + 1, images.length);
    }
    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) throw StateError('No se pudo generar el ZIP.');
    return Uint8List.fromList(encoded);
  }

  Future<GalleryImage> uploadImage({
    required String folderId,
    required Uint8List bytes,
    required String fileName,
    String? uploadedByNombre,
    GalleryImageStatus estado = GalleryImageStatus.aprobada,
    List<String> tags = const [],
    String? eventId,
    int? anio,
    String? autor,
  }) async {
    final folder = await _folders.doc(folderId).get();
    if (!folder.exists) throw StateError('La carpeta no existe.');
    final folderModel = GalleryFolder.fromFirestore(folder);
    final prefix = 'gallery/${_storagePrefixFor(folderModel)}';
    final original = await _storage.uploadFile(
      path: '$prefix/$folderId',
      bytes: bytes,
      fileName: fileName,
      allowedExtensions: {'jpg', 'jpeg', 'png', 'webp'},
      maxSizeBytes: maxImageSizeBytes,
    );
    final thumbnail = await createThumbnail(bytes);
    final originalPath = original['storage_path'];
    final originalUrl = original['url'];
    if (originalPath == null ||
        originalPath.isEmpty ||
        originalUrl == null ||
        originalUrl.isEmpty) {
      throw StateError(
          'Storage no devolvió una referencia válida para la imagen.');
    }
    String? thumbUrl;
    try {
      final baseName = originalPath.split('/').last;
      final thumbStoragePath = '$prefix/$folderId/thumbs/$baseName';
      final thumb = await _storage.uploadBytesAtPath(
        fullPath: thumbStoragePath,
        bytes: thumbnail.bytes,
        contentType: 'image/jpeg',
      );
      final thumbPath = thumb['storage_path'];
      thumbUrl = thumb['url'];
      if (thumbPath == null ||
          thumbPath.isEmpty ||
          thumbUrl == null ||
          thumbUrl.isEmpty) {
        throw StateError(
            'Storage no devolvió una referencia válida para la miniatura.');
      }
      final user = FirebaseAuth.instance.currentUser;
      final image = GalleryImage(
        id: '',
        folderId: folderId,
        nombre: fileName,
        storagePath: originalPath,
        url: originalUrl,
        thumbPath: thumbPath,
        thumbUrl: thumbUrl,
        uploadedBy: user?.uid ?? '',
        uploadedByNombre: uploadedByNombre,
        fechaSubida: DateTime.now(),
        tamanoBytes: bytes.length,
        width: thumbnail.width,
        height: thumbnail.height,
        estado: estado,
        publica: folderModel.sistema == GalleryFolderSystem.carruselInicio
            ? true
            : folderModel.publica,
        soloAdmin: folderModel.soloAdmin,
        carrusel: folderModel.sistema == GalleryFolderSystem.carruselInicio,
        tags: tags,
        eventId: eventId,
        anio: anio,
        autor: autor,
      );
      final id = await addImage(image);
      return image.copyWith(id: id);
    } catch (_) {
      await _storage.deleteFile(originalUrl);
      if (thumbUrl != null && thumbUrl!.isNotEmpty) {
        await _storage.deleteFile(thumbUrl!);
      }
      rethrow;
    }
  }

  Future<Map<String, String>> uploadZip({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Debes iniciar sesión.');
    final normalizedName = fileName.replaceFirst(
      RegExp(r'\.zip$', caseSensitive: false),
      '.zip',
    );
    return _storage.uploadFile(
      path: 'gallery_uploads/${user.uid}',
      bytes: bytes,
      fileName: normalizedName,
      contentType: 'application/zip',
      allowedExtensions: {'zip'},
      maxSizeBytes: maxZipSizeBytes,
    );
  }

  Future<GalleryThumbnail> createThumbnail(Uint8List bytes) async {
    final original = img.decodeImage(bytes);
    if (original == null) {
      throw StateError('No se pudo decodificar la imagen.');
    }
    final originalWidth = original.width;
    final originalHeight = original.height;
    final scale = thumbnailMaxSide /
        (original.width > original.height ? original.width : original.height);
    final width = scale < 1 ? (original.width * scale).round() : original.width;
    final height =
        scale < 1 ? (original.height * scale).round() : original.height;
    final resized = img.copyResize(
      original,
      width: width,
      height: height,
      interpolation: img.Interpolation.average,
    );
    final data = img.encodeJpg(resized, quality: 80);
    return GalleryThumbnail(
      bytes: Uint8List.fromList(data),
      width: originalWidth,
      height: originalHeight,
    );
  }

  Future<GalleryZipValidationResult> validateZip(Uint8List bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    const extensions = {'jpg', 'jpeg', 'png', 'webp'};
    var count = 0;
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final name = file.name;
      final baseName = name.split('/').last;
      if (name.startsWith('__MACOSX/') ||
          baseName == '.DS_Store' ||
          baseName.startsWith('.')) {
        continue;
      }
      final extension =
          name.contains('.') ? name.split('.').last.toLowerCase() : '';
      if (!extensions.contains(extension)) {
        throw StateError(
          'El ZIP contiene «$name», que no es una imagen JPG, JPEG, PNG o WebP.',
        );
      }
      final content = file.content;
      if (content is! List<int> || !_hasSupportedImageHeader(content)) {
        throw StateError('La imagen «$name» no tiene una cabecera válida.');
      }
      count++;
      if (count > maxZipImages) {
        throw StateError(
          'El ZIP contiene más de $maxZipImages imágenes. '
          'Divide el envío en varios ZIPs.',
        );
      }
    }
    if (count == 0) {
      throw StateError('El ZIP no contiene imágenes válidas.');
    }
    return GalleryZipValidationResult(imageCount: count);
  }

  bool _hasSupportedImageHeader(List<int> bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return true;
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return true;
    }
    return bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50;
  }

  Future<String> createUploadRequest(GalleryUploadRequest request) async {
    final ref =
        request.id.isEmpty ? _requests.doc() : _requests.doc(request.id);
    await ref.set(request
        .copyWith(id: ref.id, estado: GalleryUploadRequestStatus.pendiente)
        .toFirestore());
    return ref.id;
  }

  Stream<List<GalleryUploadRequest>> watchMyRequests(String uid) {
    return _requests
        .where('created_by', isEqualTo: uid)
        .orderBy('fecha_creacion', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(GalleryUploadRequest.fromFirestore).toList());
  }

  Stream<List<GalleryUploadRequest>> watchPendingRequests() {
    return _requests
        .orderBy('fecha_creacion', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map(GalleryUploadRequest.fromFirestore)
            .where((request) =>
                request.estado == GalleryUploadRequestStatus.pendiente ||
                request.estado == GalleryUploadRequestStatus.aprobado)
            .toList());
  }

  Future<Uint8List> downloadUploadRequestZip(
    GalleryUploadRequest request,
  ) =>
      _storage.downloadBytes(request.zipPath);

  Future<GalleryImage> importModeratedImage({
    required GalleryUploadRequest request,
    required String folderId,
    required Uint8List bytes,
    required String fileName,
    String? uploadedByNombre,
  }) async {
    final existing =
        await _images.where('source_request_id', isEqualTo: request.id).get();
    for (final document in existing.docs) {
      final image = GalleryImage.fromFirestore(document);
      if (!image.deleted && image.sourceEntryName == fileName) {
        return image;
      }
    }
    final image = await uploadImage(
      folderId: folderId,
      bytes: bytes,
      fileName: fileName,
      uploadedByNombre: uploadedByNombre ?? request.createdByNombre,
      estado: GalleryImageStatus.aprobada,
    );
    await _images.doc(image.id).update({
      'source_request_id': request.id,
      'source_entry_name': fileName,
    });
    return image.copyWith(
      sourceRequestId: request.id,
      sourceEntryName: fileName,
    );
  }

  Future<void> setRequestDestinationFolders(
    String requestId,
    Iterable<String> folderIds,
  ) async {
    await _requests.doc(requestId).update({
      'folder_destino_ids': folderIds.toSet().toList(),
    });
  }

  Future<void> approveRequest({
    required GalleryUploadRequest request,
    required String reviewerId,
  }) async {
    await _requests.doc(request.id).update({
      'estado': GalleryUploadRequestStatus.aprobado.name,
      'fecha_revision': FieldValue.serverTimestamp(),
      'revisado_por': reviewerId,
      'motivo_rechazo': null,
    });
    await _createRequestNovedad(
      request,
      'Solicitud de galería aprobada',
      'Tu envío «${request.titulo}» ha sido aprobado.',
      'gallery_request_approved_${request.id}',
    );
  }

  Future<void> rejectRequest({
    required GalleryUploadRequest request,
    required String reviewerId,
    required String motivo,
  }) async {
    await _requests.doc(request.id).update({
      'estado': GalleryUploadRequestStatus.rechazado.name,
      'motivo_rechazo': motivo,
      'fecha_revision': FieldValue.serverTimestamp(),
      'revisado_por': reviewerId,
    });
    await _createRequestNovedad(
      request,
      'Solicitud de galería rechazada',
      'Tu envío «${request.titulo}» ha sido rechazado. Motivo: $motivo',
      'gallery_request_rejected_${request.id}',
    );
  }

  Future<void> marcarProcesado(String requestId, {String? reviewerId}) async {
    await _requests.doc(requestId).update({
      'estado': GalleryUploadRequestStatus.procesado.name,
      'fecha_revision': FieldValue.serverTimestamp(),
      if (reviewerId != null) 'revisado_por': reviewerId,
    });
  }

  Future<void> _createRequestNovedad(
    GalleryUploadRequest request,
    String title,
    String description,
    String referenceId,
  ) async {
    final existing = await _db
        .collection('novedades')
        .where('tipo', isEqualTo: 'galeria')
        .where('referencia_id', isEqualTo: referenceId)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return;
    await _db.collection('novedades').add({
      'tipo': 'galeria',
      'titulo': title,
      'descripcion': description,
      'referencia_id': referenceId,
      'ruta': '/gallery',
      'fecha_creacion': FieldValue.serverTimestamp(),
      'visible_para': 'cofrade',
      'cofrade_id': request.createdBy,
    });
  }

  Future<bool> _deleteStorageFile(String? url) async {
    if (url == null || url.isEmpty) return true;
    try {
      final deleted = await _storage.deleteFileReporting(url);
      if (!deleted) {
        debugPrint('[GalleryService] No se pudo eliminar el fichero $url.');
      }
      return deleted;
    } catch (error) {
      debugPrint('[GalleryService] Error eliminando $url: $error');
      return false;
    }
  }

  Future<void> _commitInChunks<T>(
    List<T> items,
    void Function(WriteBatch batch, int index, T item) write,
  ) async {
    for (var offset = 0; offset < items.length; offset += maxBatchOperations) {
      final batch = _db.batch();
      final end = math.min(offset + maxBatchOperations, items.length);
      for (var index = offset; index < end; index++) {
        write(batch, index, items[index]);
      }
      await batch.commit();
    }
  }
}
