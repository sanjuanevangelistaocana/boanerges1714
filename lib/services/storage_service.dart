import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<Map<String, String>> uploadFile({
    required String path,
    required Uint8List bytes,
    required String fileName,
    String? contentType,
    int maxSizeBytes = 20 * 1024 * 1024,
    Set<String>? allowedExtensions,
    Map<String, String>? customMetadata,
    void Function(int transferred, int total)? onProgress,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Debes iniciar sesi\u00f3n para subir archivos.');
    }
    if (bytes.isEmpty) {
      throw Exception('El archivo está vacío o no se pudo leer.');
    }
    if (bytes.length > maxSizeBytes) {
      final maxMb = (maxSizeBytes / (1024 * 1024)).toStringAsFixed(0);
      throw Exception(
          'El archivo supera el tamaño máximo permitido ($maxMb MB).');
    }

    final ext = _extension(fileName);
    if (allowedExtensions != null && !allowedExtensions.contains(ext)) {
      throw Exception('Tipo de archivo no permitido: .$ext');
    }

    // Force token refresh before any upload attempt
    await user.getIdToken(true);
    await Future.delayed(const Duration(milliseconds: 300));

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = '${timestamp}_${_sanitizeFileName(fileName)}';
    final ref = _storage.ref().child(path).child(safeName);
    final ct = contentType ?? _inferContentType(fileName);
    final metadata = SettableMetadata(
      contentType: ct,
      customMetadata: {
        'uploadedBy': user.uid,
        'originalName': fileName,
        ...?customMetadata,
      },
    );

    debugPrint('[Storage] uploadFile: path=$path, file=$safeName, ct=$ct');
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final task = ref.putData(bytes, metadata);
        final progressSubscription = onProgress == null
            ? null
            : task.snapshotEvents.listen((snapshot) {
                onProgress(snapshot.bytesTransferred, snapshot.totalBytes);
              });
        try {
          await task;
        } finally {
          await progressSubscription?.cancel();
        }
        final url = await ref.getDownloadURL();
        debugPrint('[Storage] uploadFile: OK → $url');
        return {
          'nombre': fileName,
          'storage_path': ref.fullPath,
          'url': url,
          'tipo': ct,
          'tamano_bytes': bytes.length.toString(),
          'uploaded_by': user.uid,
        };
      } on FirebaseException catch (e) {
        debugPrint(
            'Storage upload attempt ${attempt + 1} failed: ${e.code} - ${e.message}');
        if (e.code == 'unauthorized' || e.code == 'storage/unauthorized') {
          if (attempt < 2) {
            await user.getIdToken(true);
            await Future.delayed(Duration(seconds: 1 + attempt));
            continue;
          }
          throw Exception(
            'Error de autorizaci\u00f3n en Storage. '
            'Verifica que Firebase Storage est\u00e9 activado y las reglas permitan escritura a usuarios autenticados. '
            'C\u00f3digo: ${e.code}',
          );
        }
        rethrow;
      } catch (e) {
        debugPrint(
            'Storage upload attempt ${attempt + 1} unexpected error: $e');
        if (attempt < 2) {
          await Future.delayed(Duration(seconds: 1 + attempt));
          continue;
        }
        rethrow;
      }
    }
    throw Exception('Error inesperado al subir archivo.');
  }

  Future<Map<String, String>> uploadBytesAtPath({
    required String fullPath,
    required Uint8List bytes,
    required String contentType,
    Map<String, String>? customMetadata,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Debes iniciar sesi\u00f3n para subir archivos.');
    }
    if (bytes.isEmpty) {
      throw Exception('El archivo está vacío o no se pudo generar.');
    }

    await user.getIdToken(true);
    final ref = _storage.ref().child(fullPath);
    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'uploadedBy': user.uid,
          ...?customMetadata,
        },
      ),
    );
    final url = await ref.getDownloadURL();
    return {
      'storage_path': ref.fullPath,
      'url': url,
      'tipo': contentType,
      'tamano_bytes': bytes.length.toString(),
      'uploaded_by': user.uid,
    };
  }

  Future<void> deleteFile(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (_) {}
  }

  Future<bool> deleteFileReporting(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Uint8List> downloadBytes(
    String storagePath, {
    int maxSizeBytes = 30 * 1024 * 1024,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Debes iniciar sesión para descargar archivos.');
    }
    await user.getIdToken(true);
    final data = await _storage.ref().child(storagePath).getData(maxSizeBytes);
    if (data == null) {
      throw Exception('No se pudo descargar el archivo.');
    }
    return data;
  }

  Future<String> getDownloadUrlFromPath(String storagePath) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Debes iniciar sesión para ver este documento.');
    }
    await user.getIdToken(true);
    return _storage.ref().child(storagePath).getDownloadURL();
  }

  String _sanitizeFileName(String fileName) {
    return fileName
        .trim()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '');
  }

  String _extension(String fileName) {
    final parts = fileName.split('.');
    if (parts.length < 2) return '';
    return parts.last.toLowerCase();
  }

  String _inferContentType(String fileName) {
    final ext = _extension(fileName);
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'zip':
        return 'application/zip';
      case 'gif':
        return 'image/gif';
      case 'doc':
      case 'docx':
        return 'application/msword';
      case 'xls':
      case 'xlsx':
        return 'application/vnd.ms-excel';
      default:
        return 'application/octet-stream';
    }
  }
}
