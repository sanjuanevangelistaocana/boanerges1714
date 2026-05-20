import 'package:cloud_firestore/cloud_firestore.dart';

class SurveyOption {
  final String id;
  final String text;
  final int order;

  const SurveyOption({
    required this.id,
    required this.text,
    required this.order,
  });

  factory SurveyOption.fromMap(Map<String, dynamic> data, int fallbackOrder) {
    return SurveyOption(
      id: '${data['id'] ?? 'option_$fallbackOrder'}',
      text: '${data['text'] ?? data['label'] ?? ''}',
      order: (data['order'] as num?)?.toInt() ?? fallbackOrder,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'order': order,
      };
}

class Convocatoria {
  final String id;
  final String titulo;
  final String descripcion;
  final String tipo; // general, procesion, evento, consulta
  final DateTime fechaEvento;
  final DateTime fechaLimite;
  final List<String>
      opciones; // e.g. ["Sí", "No"] or ["Turno 1", "Turno 2", "No puedo"]
  final List<SurveyOption> surveyOptions;
  final bool activa;
  final String status;
  final String creadaPor;
  final DateTime fechaCreacion;
  final int totalRespuestas;
  final List<Map<String, String>> adjuntos;
  final String? coverImageUrl;
  final String? coverImagePath;
  final bool mostrarResultados;

  Convocatoria({
    required this.id,
    required this.titulo,
    required this.descripcion,
    this.tipo = 'general',
    required this.fechaEvento,
    required this.fechaLimite,
    this.opciones = const ['Sí', 'No'],
    List<SurveyOption>? surveyOptions,
    this.activa = true,
    this.status = 'active',
    required this.creadaPor,
    required this.fechaCreacion,
    this.totalRespuestas = 0,
    this.adjuntos = const [],
    this.coverImageUrl,
    this.coverImagePath,
    this.mostrarResultados = false,
  }) : surveyOptions = surveyOptions ??
            const [
              SurveyOption(id: 'option_1', text: 'Sí', order: 1),
              SurveyOption(id: 'option_2', text: 'No', order: 2),
            ];

  bool get isVigente =>
      status == 'active' && activa && DateTime.now().isBefore(fechaLimite);

  String get statusLabel {
    switch (status) {
      case 'draft':
        return 'Borrador';
      case 'closed':
        return 'Cerrada';
      case 'archived':
        return 'Archivada';
      default:
        return 'Activa';
    }
  }

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
    final rawStructured = data['surveyOptions'];
    final rawLegacy = data['opciones'];
    final structured = rawStructured is List
        ? rawStructured
            .whereType<Map>()
            .toList()
            .asMap()
            .entries
            .map((entry) => SurveyOption.fromMap(
                Map<String, dynamic>.from(entry.value), entry.key + 1))
            .where((option) => option.text.trim().isNotEmpty)
            .toList()
        : <SurveyOption>[];
    final legacyOptions = rawLegacy is List
        ? rawLegacy
            .map((item) => '$item')
            .where((item) => item.isNotEmpty)
            .toList()
        : (rawLegacy is String
            ? rawLegacy
                .split(',')
                .map((item) => item.trim())
                .where((item) => item.isNotEmpty)
                .toList()
            : <String>[]);
    final options = structured.isNotEmpty
        ? structured
        : legacyOptions
            .asMap()
            .entries
            .map((entry) => SurveyOption(
                  id: 'option_${entry.key + 1}',
                  text: entry.value,
                  order: entry.key + 1,
                ))
            .toList();
    final status = '${data['status'] ?? ''}'.trim().isEmpty
        ? (data['activa'] == false ? 'closed' : 'active')
        : '${data['status']}';
    final limit = (data['fecha_limite'] as Timestamp?)?.toDate() ??
        (data['fecha_evento'] as Timestamp?)?.toDate() ??
        DateTime.now();
    return Convocatoria(
      id: doc.id,
      titulo: data['titulo'] ?? '',
      descripcion: data['descripcion'] ?? '',
      tipo: data['tipo'] ?? 'general',
      fechaEvento: (data['fecha_evento'] as Timestamp?)?.toDate() ?? limit,
      fechaLimite: limit,
      opciones: options.map((option) => option.text).toList(),
      surveyOptions: options,
      activa: data['activa'] ?? status == 'active',
      status: status,
      creadaPor: data['creada_por'] ?? '',
      fechaCreacion:
          (data['fecha_creacion'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalRespuestas: data['total_respuestas'] ?? 0,
      adjuntos: ((data['adjuntos'] as List<dynamic>?) ?? [])
          .map((a) => Map<String, String>.from(a as Map))
          .toList(),
      coverImageUrl: data['coverImageUrl'] ?? data['cover_image_url'],
      coverImagePath: data['coverImagePath'] ?? data['cover_image_path'],
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
      'surveyOptions': surveyOptions.map((option) => option.toMap()).toList(),
      'activa': activa,
      'status': status,
      'creada_por': creadaPor,
      'fecha_creacion': Timestamp.fromDate(fechaCreacion),
      'total_respuestas': totalRespuestas,
      'adjuntos': adjuntos,
      'coverImageUrl': coverImageUrl,
      'coverImagePath': coverImagePath,
      'mostrar_resultados': mostrarResultados,
    };
  }
}

class RespuestaConvocatoria {
  final String id;
  final String cofradeId;
  final String cofradeNombre;
  final String respuesta;
  final String selectedOptionId;
  final String selectedOptionText;
  final String? comentario;
  final DateTime fechaRespuesta;
  final DateTime? updatedAt;

  RespuestaConvocatoria({
    required this.id,
    required this.cofradeId,
    required this.cofradeNombre,
    required this.respuesta,
    this.selectedOptionId = '',
    String? selectedOptionText,
    this.comentario,
    required this.fechaRespuesta,
    this.updatedAt,
  }) : selectedOptionText = selectedOptionText ?? respuesta;

  factory RespuestaConvocatoria.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RespuestaConvocatoria(
      id: doc.id,
      cofradeId: data['cofrade_id'] ?? '',
      cofradeNombre: data['cofrade_nombre'] ?? '',
      respuesta: data['respuesta'] ?? data['selectedOptionText'] ?? '',
      selectedOptionId: data['selectedOptionId'] ?? '',
      selectedOptionText: data['selectedOptionText'] ?? data['respuesta'] ?? '',
      comentario: data['comentario'] as String?,
      fechaRespuesta: (data['fecha_respuesta'] as Timestamp?)?.toDate() ??
          (data['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'cofrade_id': cofradeId,
      'cofrade_nombre': cofradeNombre,
      'respuesta': respuesta,
      'selectedOptionId': selectedOptionId,
      'selectedOptionText': selectedOptionText,
      'comentario': comentario,
      'fecha_respuesta': Timestamp.fromDate(fechaRespuesta),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }
}
