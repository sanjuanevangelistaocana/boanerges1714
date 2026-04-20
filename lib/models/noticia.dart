import 'package:cloud_firestore/cloud_firestore.dart';

class Noticia {
  final String id;
  final String titulo;
  final String contenido;
  final DateTime fecha;
  final String? imagenUrl;
  final bool publicado;
  final DateTime? fechaCreacion;

  Noticia({
    required this.id,
    required this.titulo,
    required this.contenido,
    required this.fecha,
    this.imagenUrl,
    this.publicado = true,
    this.fechaCreacion,
  });

  factory Noticia.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Noticia(
      id: doc.id,
      titulo: data['titulo'] ?? '',
      contenido: data['contenido'] ?? '',
      fecha: (data['fecha'] as Timestamp).toDate(),
      imagenUrl: data['imagen_url'],
      publicado: data['publicado'] ?? true,
      fechaCreacion: (data['fecha_creacion'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'titulo': titulo,
      'contenido': contenido,
      'fecha': Timestamp.fromDate(fecha),
      'imagen_url': imagenUrl,
      'publicado': publicado,
      'fecha_creacion': fechaCreacion != null
          ? Timestamp.fromDate(fechaCreacion!)
          : FieldValue.serverTimestamp(),
    };
  }
}
