import 'package:cloud_firestore/cloud_firestore.dart';

class Documento {
  final String id;
  final String titulo;
  final String tipo;
  final String archivoUrl;
  final DateTime fecha;
  final String? descripcion;
  final String? archivoNombre;
  final String? storagePath;
  final String? contentType;
  final int? tamanoBytes;
  final String? subidoPor;
  final String? modulo;

  Documento({
    required this.id,
    required this.titulo,
    required this.tipo,
    required this.archivoUrl,
    required this.fecha,
    this.descripcion,
    this.archivoNombre,
    this.storagePath,
    this.contentType,
    this.tamanoBytes,
    this.subidoPor,
    this.modulo,
  });

  factory Documento.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Documento(
      id: doc.id,
      titulo: data['titulo'] ?? '',
      tipo: data['tipo'] ?? 'otro',
      archivoUrl: data['archivo_url'] ?? '',
      fecha: (data['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
      descripcion: data['descripcion'],
      archivoNombre: data['archivo_nombre'],
      storagePath: data['storage_path'],
      contentType: data['content_type'],
      tamanoBytes: (data['tamano_bytes'] as num?)?.toInt(),
      subidoPor: data['subido_por'],
      modulo: data['modulo'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'titulo': titulo,
      'tipo': tipo,
      'archivo_url': archivoUrl,
      'fecha': Timestamp.fromDate(fecha),
      'descripcion': descripcion,
      'archivo_nombre': archivoNombre,
      'storage_path': storagePath,
      'content_type': contentType,
      'tamano_bytes': tamanoBytes,
      'subido_por': subidoPor,
      'modulo': modulo,
    };
  }
}
