// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

Future<bool> downloadGalleryBytes(Uint8List bytes, String fileName) async {
  final url = html.Url.createObjectUrlFromBlob(
    html.Blob(<dynamic>[bytes], 'application/zip'),
  );
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
  return true;
}
