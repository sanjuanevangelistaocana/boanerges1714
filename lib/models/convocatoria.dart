import 'package:cloud_firestore/cloud_firestore.dart';

class Convocatoria {
  final String id;
  final String titulo;
  final String descripcion;
  final String tipo; // general, procesion, evento, consulta
  final DateTime fechaEvento;
  final DateTime fechaLimite;
  final List<String> opciones; // e.g. ["Sí", "No"] or ["Turno 1", "Turno 2", "No puedo"]
  final bool activa;
  final String creadaPor;
  final DateTime fechaCreacion;
  final int totalRespuestas;
  final List<Map<String, String>> adjuntos;
  final bool mostrarResultados;

  Convocatoria({
    required this.id,
    required this.titulo,
    required this.descripcion,
    this.tipo = 'general',
    required this.fechaEvento,
    required this.fechaLimite,
    this.opciones = const ['Sí', 'No'],
    this.activa = true,
    required this.creadaPor,
    required this.fechaCreacion,
    this.totalRespuestas = 0,
    this.adjuntos = const [],
    this.mostrarResultados = false,
  });

  bool get isVigente =>
      activa && DateTime.now().isBefore(fechaLimite);

  String get tipoLabel {
    switch (tipo) {
      case 'procesion':
        return 'Procesión';
      case 'evento':
        return 'Evento';
      case 'consulta':
        return 'Consulta';
      default:
        return 'General';
    }
  }

  factory Convocatoria.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Convocatoria(
      id: doc.id,
      titulo: data['titulo'] ?? '',
      descripcion: data['descripcion'] ?? '',
      tipo: data['tipo'] ?? 'general',
      fechaEvento: (data['fecha_evento'] as Timestamp).toDate(),
      fechaLimite: (data['fecha_limite'] as Timestamp).toDate(),
      opciones: List<String>.from(data['opciones'] ?? ['Sí', 'No']),
      activa: data['activa'] ?? true,
      creadaPor: data['creada_por'] ?? '',
      fechaCreacion: (data['fecha_creacion'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      totalRespuestas: data['total_respuestas'] ?? 0,
      adjuntos: ((data['adjuntos'] as List<dynamic>?) ?? [])
          .map((a) => Map<String, String>.from(a as Map))
          .toList(),
      mostrarResultados: data['mostrar_resultados'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'titulo': titulo,
      'descripcion': descripcion,
      'tipo': tipo,
      'fecha_evento': Timestamp.fromDate(fechaEvento),
      'fecha_limite': Timestamp.fromDate(fechaLimite),
      'opciones': opciones,
      'activa': activa,
      'creada_por': creadaPor,
      'fecha_creacion': Timestamp.fromDate(fechaCreacion),
      'total_respuestas': totalRespuestas,
      'adjuntos': adjuntos,
      'mostrar_resultados': mostrarResultados,
    };
  }
}

class RespuestaConvocatoria {
  final String id;
  final String cofradeId;
  final String cofradeNombre;
  final String respuesta;
  final String? comentario;
  final DateTime fechaRespuesta;

  RespuestaConvocatoria({
    required this.id,
    required this.cofradeId,
    required this.cofradeNombre,
    required this.respuesta,
    this.comentario,
    required this.fechaRespuesta,
  });

  factory RespuestaConvocatoria.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RespuestaConvocatoria(
      id: doc.id,
      cofradeId: data['cofrade_id'] ?? '',
      cofradeNombre: data['cofrade_nombre'] ?? '',
      respuesta: data['respuesta'] ?? '',
      comentario: data['comentario'] as String?,
      fechaRespuesta:
          (data['fecha_respuesta'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'cofrade_id': cofradeId,
      'cofrade_nombre': cofradeNombre,
      'respuesta': respuesta,
      'comentario': comentario,
      'fecha_respuesta': Timestamp.fromDate(fechaRespuesta),
    };
  }
}
