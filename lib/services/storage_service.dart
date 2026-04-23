import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<Map<String, String>> uploadFile({
    required String path,
    required Uint8List bytes,
    required String fileName,
    String? contentType,
  }) async {
    final ref = _storage.ref().child(path).child(fileName);
    final metadata = contentType != null
        ? SettableMetadata(contentType: contentType)
        : null;
    await ref.putData(bytes, metadata);
    final url = await ref.getDownloadURL();
    return {
      'nombre': fileName,
      'url': url,
      'tipo': contentType ?? _inferContentType(fileName),
    };
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
