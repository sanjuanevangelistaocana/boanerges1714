import 'package:cloud_firestore/cloud_firestore.dart';

class Evento {
  final String id;
  final String titulo;
  final String descripcion;
  final DateTime fecha;
  final DateTime? fechaFin;
  final String? hora;
  final String? lugar;
  final String? imagenUrl;
  final bool publicado;
  final bool soloCofrades;
  final bool inscripcionActiva;
  final bool esPublico;
  final String tipo;
  final List<Map<String, String>> adjuntos;
  final DateTime? fechaCreacion;

  Evento({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.fecha,
    this.fechaFin,
    this.hora,
    this.lugar,
    this.imagenUrl,
    this.publicado = true,
    this.soloCofrades = false,
    this.inscripcionActiva = false,
    this.esPublico = true,
    this.tipo = 'general',
    this.adjuntos = const [],
    this.fechaCreacion,
  });

  factory Evento.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Evento(
      id: doc.id,
      titulo: data['titulo'] ?? '',
      descripcion: data['descripcion'] ?? '',
      fecha: (data['fecha'] as Timestamp).toDate(),
      fechaFin: (data['fecha_fin'] as Timestamp?)?.toDate(),
      hora: data['hora'],
      lugar: data['lugar'],
      imagenUrl: data['imagen_url'],
      publicado: data['publicado'] ?? true,
      soloCofrades: data['solo_cofrades'] ?? false,
      inscripcionActiva: data['inscripcion_activa'] ?? false,
      esPublico: data['es_publico'] ?? !(data['solo_cofrades'] == true),
      tipo: data['tipo'] ?? 'general',
      adjuntos: ((data['adjuntos'] as List<dynamic>?) ?? [])
          .map((a) => Map<String, String>.from(a as Map))
          .toList(),
      fechaCreacion: (data['fecha_creacion'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'titulo': titulo,
      'descripcion': descripcion,
      'fecha': Timestamp.fromDate(fecha),
      'fecha_fin': fechaFin != null ? Timestamp.fromDate(fechaFin!) : null,
      'hora': hora,
      'lugar': lugar,
      'imagen_url': imagenUrl,
      'publicado': publicado,
      'solo_cofrades': soloCofrades,
      'inscripcion_activa': inscripcionActiva,
      'es_publico': esPublico,
      'tipo': tipo,
      'adjuntos': adjuntos,
      'fecha_creacion': fechaCreacion != null
          ? Timestamp.fromDate(fechaCreacion!)
          : FieldValue.serverTimestamp(),
    };
  }
}
