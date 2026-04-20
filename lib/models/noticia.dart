import 'package:cloud_firestore/cloud_firestore.dart';

class Noticia {
  final String id;
  final String titulo;
  final String contenido;
  final DateTime fecha;
  final String? imagenUrl;
  final bool publicado;
  final bool soloCofrades;
  final DateTime? fechaCreacion;

  Noticia({
    required this.id,
    required this.titulo,
    required this.contenido,
    required this.fecha,
    this.imagenUrl,
    this.publicado = true,
    this.soloCofrades = false,
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
      soloCofrades: data['solo_cofrades'] ?? false,
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
      'solo_cofrades': soloCofrades,
      'fecha_creacion': fechaCreacion != null
          ? Timestamp.fromDate(fechaCreacion!)
          : FieldValue.serverTimestamp(),
    };
  }
}
