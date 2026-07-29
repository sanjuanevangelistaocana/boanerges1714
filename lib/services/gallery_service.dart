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

  Stream<List<GalleryFolder>> watchFolders({bool onlyPublic = false}) {
    Query<Map<String, dynamic>> query = _folders
        .where('deleted', isEqualTo: false)
        .orderBy('orden');
    if (onlyPublic) {
      query = _folders
          .where('publica', isEqualTo: true)
          .where('deleted', isEqualTo: false)
          .orderBy('orden');
    }
    return query.snapshots().map((snapshot) => snapshot.docs
        .map(GalleryFolder.fromFirestore)
        .where((folder) => !folder.deleted)
        .toList());
  }

  Stream<GalleryFolder?> watchFolder(String id) {
    return _folders.doc(id).snapshots().map(
          (doc) => doc.exists ? GalleryFolder.fromFirestore(doc) : null,
        );
  }

  Future<String> createFolder(GalleryFolder folder) async {
    final ref = folder.id.isEmpty ? _folders.doc() : _folders.doc(folder.id);
    final now = DateTime.now();
    await ref.set(folder
        .copyWith(
          id: ref.id,
          fechaCreacion: folder.fechaCreacion,
          fechaActualizacion: now,
        )
        .toFirestore());
    return ref.id;
  }

  Future<void> updateFolder(String id, Map<String, dynamic> data) async {
    await _folders.doc(id).update({
      ...data,
      'fecha_actualizacion': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteFolder(String id) async {
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
    await _folders.doc(folderId).update({
      'publica': publica,
      'relocating': true,
      'fecha_actualizacion': FieldValue.serverTimestamp(),
    });

    try {
      final snapshot =
          await _images.where('folder_id', isEqualTo: folderId).get();
      await _commitInChunks(snapshot.docs, (batch, _, doc) {
        batch.update(doc.reference, {'publica': publica});
      });

      // TODO(fase-3): mover físicamente original y thumbnail entre
      // gallery/public y gallery/private antes de finalizar la reubicación.
      await _folders.doc(folderId).update({
        'relocating': false,
        'fecha_actualizacion': FieldValue.serverTimestamp(),
      });
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
  }) async {
    Query<Map<String, dynamic>> query = _images
        .where('folder_id', isEqualTo: folderId)
        .where('deleted', isEqualTo: false)
        .orderBy('orden')
        .orderBy(FieldPath.documentId)
        .limit(limit);
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
  }) {
    Query<Map<String, dynamic>> query = _images
        .where('folder_id', isEqualTo: folderId)
        .where('deleted', isEqualTo: false)
        .orderBy('orden')
        .orderBy(FieldPath.documentId)
        .limit(limit);
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

  Future<String> addImage(GalleryImage image) async {
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

  Future<void> deleteImage(GalleryImage image) async {
    var deletedNow = false;
    await _db.runTransaction((transaction) async {
      final imageRef = _images.doc(image.id);
      final snapshot = await transaction.get(imageRef);
      final current = snapshot.exists
          ? GalleryImage.fromFirestore(snapshot)
          : image;
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
    if (deletedNow) {
      await _deleteStorageFile(image.storagePath, image.url);
      await _deleteStorageFile(image.thumbPath, image.thumbUrl);
    }
  }

  Future<void> moveImage({
    required GalleryImage image,
    required String destinationFolderId,
  }) async {
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
      final destination = GalleryFolder.fromFirestore(destinationSnapshot);
      if (current.deleted || current.folderId == destinationFolderId) return;
      transaction.update(imageRef, {
        'folder_id': destinationFolderId,
        'publica': destination.publica,
      });
      transaction.update(sourceRef, {
        'num_fotos': FieldValue.increment(-1),
        'fecha_actualizacion': FieldValue.serverTimestamp(),
      });
      transaction.update(destinationRef, {
        'num_fotos': FieldValue.increment(1),
        'fecha_actualizacion': FieldValue.serverTimestamp(),
      });
      // TODO(fase-3): si cambia entre privada/pública, reubicar original y
      // thumbnail al nuevo prefijo Storage, igual que setFolderVisibility.
    });
  }

  Future<void> reorderImages(List<String> imageIds) async {
    await _commitInChunks(imageIds, (batch, index, id) {
      batch.update(_images.doc(id), {'orden': index});
    });
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
    final visibility = folderModel.publica ? 'public' : 'private';
    final original = await _storage.uploadFile(
      path: 'gallery/$visibility/$folderId',
      bytes: bytes,
      fileName: fileName,
      allowedExtensions: {'jpg', 'jpeg', 'png', 'webp'},
      maxSizeBytes: maxImageSizeBytes,
    );
    final thumbnail = await createThumbnail(bytes);
    final originalPath = original['storage_path'] ?? '';
    final baseName = originalPath.split('/').last;
    final thumbPath = 'gallery/$visibility/$folderId/thumbs/$baseName';
    final thumb = await _storage.uploadBytesAtPath(
      fullPath: thumbPath,
      bytes: thumbnail.bytes,
      contentType: 'image/jpeg',
    );
    final user = FirebaseAuth.instance.currentUser;
    final image = GalleryImage(
      id: '',
      folderId: folderId,
      nombre: fileName,
      storagePath: originalPath,
      url: original['url'] ?? '',
      thumbPath: thumb['storage_path'],
      thumbUrl: thumb['url'],
      uploadedBy: user?.uid ?? '',
      uploadedByNombre: uploadedByNombre,
      fechaSubida: DateTime.now(),
      tamanoBytes: bytes.length,
      width: thumbnail.width,
      height: thumbnail.height,
      estado: estado,
      publica: folderModel.publica,
      tags: tags,
      eventId: eventId,
      anio: anio,
      autor: autor,
    );
    final id = await addImage(image);
    return image.copyWith(id: id);
  }

  Future<Map<String, String>> uploadZip({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Debes iniciar sesión.');
    return _storage.uploadFile(
      path: 'gallery_uploads/${user.uid}',
      bytes: bytes,
      fileName: fileName,
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
    final scale = thumbnailMaxSide / (original.width > original.height
        ? original.width
        : original.height);
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
      final extension =
          name.contains('.') ? name.split('.').last.toLowerCase() : '';
      if (!extensions.contains(extension)) {
        throw StateError(
          'El ZIP contiene «$name», que no es una imagen JPG, JPEG, PNG o WebP.',
        );
      }
      final image = img.decodeImage(file.content as List<int>);
      if (image == null) {
        throw StateError('No se pudo leer la imagen «$name».');
      }
      count++;
    }
    if (count == 0) {
      throw StateError('El ZIP no contiene imágenes válidas.');
    }
    return GalleryZipValidationResult(imageCount: count);
  }

  Future<String> createUploadRequest(GalleryUploadRequest request) async {
    final ref = request.id.isEmpty ? _requests.doc() : _requests.doc(request.id);
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
                request.estado == GalleryUploadRequestStatus.pendiente)
            .toList());
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
      'Tu envío «${request.titulo}» ha sido rechazado.',
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

  Future<void> _deleteStorageFile(String? path, String? url) async {
    if (url == null || url.isEmpty) return;
    try {
      await _storage.deleteFile(url);
    } catch (error) {
      debugPrint('[GalleryService] Error eliminando $path: $error');
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
