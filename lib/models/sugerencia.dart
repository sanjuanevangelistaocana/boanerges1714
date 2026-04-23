import 'package:cloud_firestore/cloud_firestore.dart';

class Sugerencia {
  final String id;
  final String cofradeId;
  final String cofradeNombre;
  final String tipo; // 'sugerencia' or 'peticion'
  final String titulo;
  final String mensaje;
  final DateTime fecha;
  final String estado; // 'pendiente', 'leida', 'respondida'
  final String? respuestaAdmin;
  final DateTime? fechaRespuesta;

  Sugerencia({
    required this.id,
    required this.cofradeId,
    required this.cofradeNombre,
    required this.tipo,
    required this.titulo,
    required this.mensaje,
    required this.fecha,
    this.estado = 'pendiente',
    this.respuestaAdmin,
    this.fechaRespuesta,
  });

  factory Sugerencia.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Sugerencia(
      id: doc.id,
      cofradeId: data['cofrade_id'] ?? '',
      cofradeNombre: data['cofrade_nombre'] ?? '',
      tipo: data['tipo'] ?? 'sugerencia',
      titulo: data['titulo'] ?? '',
      mensaje: data['mensaje'] ?? '',
      fecha: (data['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
      estado: data['estado'] ?? 'pendiente',
      respuestaAdmin: data['respuesta_admin'] as String?,
      fechaRespuesta: (data['fecha_respuesta'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'cofrade_id': cofradeId,
      'cofrade_nombre': cofradeNombre,
      'tipo': tipo,
      'titulo': titulo,
      'mensaje': mensaje,
      'fecha': Timestamp.fromDate(fecha),
      'estado': estado,
      'respuesta_admin': respuestaAdmin,
      'fecha_respuesta': fechaRespuesta != null
          ? Timestamp.fromDate(fechaRespuesta!)
          : null,
    };
  }
}
