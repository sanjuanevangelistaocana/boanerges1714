import 'package:cloud_firestore/cloud_firestore.dart';

class Evento {
  final String id;
  final String titulo;
  final String descripcion;
  final DateTime fecha;
  final String? hora;
  final String? lugar;
  final String? imagenUrl;
  final bool publicado;
  final bool soloCofrades;
  final DateTime? fechaCreacion;

  Evento({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.fecha,
    this.hora,
    this.lugar,
    this.imagenUrl,
    this.publicado = true,
    this.soloCofrades = false,
    this.fechaCreacion,
  });

  factory Evento.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Evento(
      id: doc.id,
      titulo: data['titulo'] ?? '',
      descripcion: data['descripcion'] ?? '',
      fecha: (data['fecha'] as Timestamp).toDate(),
      hora: data['hora'],
      lugar: data['lugar'],
      imagenUrl: data['imagen_url'],
      publicado: data['publicado'] ?? true,
      soloCofrades: data['solo_cofrades'] ?? false,
      fechaCreacion: (data['fecha_creacion'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'titulo': titulo,
      'descripcion': descripcion,
      'fecha': Timestamp.fromDate(fecha),
      'hora': hora,
      'lugar': lugar,
      'imagen_url': imagenUrl,
      'publicado': publicado,
      'solo_cofrades': soloCofrades,
      'fecha_creacion': fechaCreacion != null
          ? Timestamp.fromDate(fechaCreacion!)
          : FieldValue.serverTimestamp(),
    };
  }
}
