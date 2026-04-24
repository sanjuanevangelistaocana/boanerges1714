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
    try {
      // Force token refresh to ensure valid auth state for Storage
      await user.getIdToken(true);

      final ref = _storage.ref().child(path).child(fileName);
      final ct = contentType ?? _inferContentType(fileName);
      final metadata = SettableMetadata(contentType: ct);
      await ref.putData(bytes, metadata);
      final url = await ref.getDownloadURL();
      return {
        'nombre': fileName,
        'url': url,
        'tipo': ct,
      };
    } on FirebaseException catch (e) {
      if (e.code == 'unauthorized' || e.code == 'storage/unauthorized') {
        // Retry once with fresh token
        await user.getIdToken(true);
        final ref = _storage.ref().child(path).child(fileName);
        final ct = contentType ?? _inferContentType(fileName);
        final metadata = SettableMetadata(contentType: ct);
        await ref.putData(bytes, metadata);
        final url = await ref.getDownloadURL();
        return {
          'nombre': fileName,
          'url': url,
          'tipo': ct,
        };
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
