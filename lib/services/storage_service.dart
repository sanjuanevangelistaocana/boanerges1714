import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<Map<String, String>> uploadFile({
    required String path,
    required Uint8List bytes,
    required String fileName,
    String? contentType,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Debes iniciar sesi\u00f3n para subir archivos.');
    }

    // Force token refresh before any upload attempt
    await user.getIdToken(true);
    // Small delay to ensure token propagation
    await Future.delayed(const Duration(milliseconds: 500));

    final ref = _storage.ref().child(path).child(fileName);
    final ct = contentType ?? _inferContentType(fileName);
    final metadata = SettableMetadata(contentType: ct);

    try {
      await ref.putData(bytes, metadata);
      final url = await ref.getDownloadURL();
      return {
        'nombre': fileName,
        'url': url,
        'tipo': ct,
      };
    } on FirebaseException catch (e) {
      if (e.code == 'unauthorized' || e.code == 'storage/unauthorized') {
        // Retry once with fresh token after a longer delay
        await user.getIdToken(true);
        await Future.delayed(const Duration(seconds: 1));
        try {
          await ref.putData(bytes, metadata);
          final url = await ref.getDownloadURL();
          return {
            'nombre': fileName,
            'url': url,
            'tipo': ct,
          };
        } on FirebaseException catch (_) {
          throw Exception(
            'Error de autorizaci\u00f3n en Storage. '
            'Verifica que Firebase Storage est\u00e9 activado y las reglas permitan escritura a usuarios autenticados.'
          );
        }
      }
      rethrow;
    }
  }

  Future<void> deleteFile(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (_) {}
  }

  String _inferContentType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
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
