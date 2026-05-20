import 'package:cloud_firestore/cloud_firestore.dart';

/// Types of survey questions
enum EncuestaTipoRespuesta {
  unica,
  multiple,
  abierta,
  reaccion,
}

/// Survey lifecycle states
enum EncuestaEstado {
  borrador,
  programada,
  activa,
  cerrada,
  archivada,
}

/// Tag-based targeting rule (prepared for future AND/exclusion)
class EncuestaTargeting {
  final bool allCofrades;
  final List<String> tags;
  final String combineMode; // 'or' now; 'and', 'exclude' in future

  const EncuestaTargeting({
    this.allCofrades = true,
    this.tags = const [],
    this.combineMode = 'or',
  });

  factory EncuestaTargeting.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const EncuestaTargeting();
    return EncuestaTargeting(
      allCofrades: data['allCofrades'] ?? true,
      tags: List<String>.from(data['tags'] ?? []),
      combineMode: data['combineMode'] ?? 'or',
    );
  }

  Map<String, dynamic> toMap() => {
        'allCofrades': allCofrades,
        'tags': tags,
        'combineMode': combineMode,
      };

  bool cofradeMatchesTags(List<String> cofradeTags) {
    if (allCofrades) return true;
    if (tags.isEmpty) return true;
    // OR mode: cofrade must have at least one of the target tags
    return tags.any((tag) => cofradeTags.contains(tag));
  }
}

/// An option that can optionally include an image URL
class EncuestaOpcion {
  final String id;
  final String text;
  final int order;
  final String? imageUrl;
  final String? imagePath;

  const EncuestaOpcion({
    required this.id,
    required this.text,
    required this.order,
    this.imageUrl,
    this.imagePath,
  });

  factory EncuestaOpcion.fromMap(Map<String, dynamic> data, int fallbackOrder) {
    return EncuestaOpcion(
      id: '${data['id'] ?? 'option_$fallbackOrder'}',
      text: '${data['text'] ?? ''}',
      order: (data['order'] as num?)?.toInt() ?? fallbackOrder,
      imageUrl: data['imageUrl'] as String?,
      imagePath: data['imagePath'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'order': order,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (imagePath != null) 'imagePath': imagePath,
      };
}

/// Audit entry for survey changes
class EncuestaAuditEntry {
  final String action; // created, edited, status_changed, etc.
  final String userId;
  final String userName;
  final DateTime timestamp;
  final Map<String, dynamic> details;

  const EncuestaAuditEntry({
    required this.action,
    required this.userId,
    required this.userName,
    required this.timestamp,
    this.details = const {},
  });

  factory EncuestaAuditEntry.fromMap(Map<String, dynamic> data) {
    return EncuestaAuditEntry(
      action: data['action'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      details:
          (data['details'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Map<String, dynamic> toMap() => {
        'action': action,
        'userId': userId,
        'userName': userName,
        'timestamp': Timestamp.fromDate(timestamp),
        'details': details,
      };
}

class Encuesta {
  final String id;
  final String titulo;
  final String descripcion;
  final String tipo; // opinion, preferencias, valoracion, consulta
  final EncuestaTipoRespuesta tipoRespuesta;
  final EncuestaEstado estado;
  final bool esAnonima;
  final EncuestaTargeting targeting;
  final List<EncuestaOpcion> opciones;
  final List<String> reactionEmojis; // for reaction-type surveys
  final DateTime fechaCreacion;
  final DateTime? fechaPublicacion;
  final DateTime? fechaLimite;
  final bool publicacionInmediata;
  final String creadaPor;
  final String creadaPorId;
  final bool mostrarResultados;
  final int totalRespuestas;
  final List<Map<String, String>> adjuntos;
  final String? coverImageUrl;
  final String? coverImagePath;
  final List<EncuestaAuditEntry> auditLog;
  // Legacy compatibility
  final bool activa;

  Encuesta({
    required this.id,
    required this.titulo,
    required this.descripcion,
    this.tipo = 'opinion',
    this.tipoRespuesta = EncuestaTipoRespuesta.unica,
    this.estado = EncuestaEstado.activa,
    this.esAnonima = false,
    this.targeting = const EncuestaTargeting(),
    this.opciones = const [],
    this.reactionEmojis = const ['👍', '👎', '❤️'],
    required this.fechaCreacion,
    this.fechaPublicacion,
    this.fechaLimite,
    this.publicacionInmediata = true,
    required this.creadaPor,
    this.creadaPorId = '',
    this.mostrarResultados = false,
    this.totalRespuestas = 0,
    this.adjuntos = const [],
    this.coverImageUrl,
    this.coverImagePath,
    this.auditLog = const [],
    this.activa = true,
  });

  bool get isVigente {
    if (estado != EncuestaEstado.activa) return false;
    if (fechaLimite != null && DateTime.now().isAfter(fechaLimite!)) {
      return false;
    }
    return true;
  }

  String get estadoLabel {
    switch (estado) {
      case EncuestaEstado.borrador:
        return 'Borrador';
      case EncuestaEstado.programada:
        return 'Programada';
      case EncuestaEstado.activa:
        return 'Activa';
      case EncuestaEstado.cerrada:
        return 'Cerrada';
      case EncuestaEstado.archivada:
        return 'Archivada';
    }
  }

  String get tipoRespuestaLabel {
    switch (tipoRespuesta) {
      case EncuestaTipoRespuesta.unica:
        return 'Respuesta única';
      case EncuestaTipoRespuesta.multiple:
        return 'Respuesta múltiple';
      case EncuestaTipoRespuesta.abierta:
        return 'Pregunta abierta';
      case EncuestaTipoRespuesta.reaccion:
        return 'Reacción rápida';
    }
  }

  bool canCofradeAccess(List<String> cofradeTags) {
    return targeting.cofradeMatchesTags(cofradeTags);
  }

  factory Encuesta.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final rawOpciones = data['opciones'];
    final opciones = rawOpciones is List
        ? rawOpciones
            .whereType<Map>()
            .toList()
            .asMap()
            .entries
            .map((e) => EncuestaOpcion.fromMap(
                Map<String, dynamic>.from(e.value), e.key + 1))
            .where((o) => o.text.trim().isNotEmpty)
            .toList()
        : <EncuestaOpcion>[];

    final rawAudit = data['auditLog'];
    final auditLog = rawAudit is List
        ? rawAudit
            .whereType<Map>()
            .map((e) => EncuestaAuditEntry.fromMap(
                Map<String, dynamic>.from(e)))
            .toList()
        : <EncuestaAuditEntry>[];

    final rawEmojis = data['reactionEmojis'];
    final reactionEmojis = rawEmojis is List
        ? rawEmojis.map((e) => '$e').toList()
        : const ['👍', '👎', '❤️'];

    final estadoStr = '${data['estado'] ?? 'activa'}'.trim();
    final estado = EncuestaEstado.values.firstWhere(
      (e) => e.name == estadoStr,
      orElse: () => data['activa'] == false
          ? EncuestaEstado.cerrada
          : EncuestaEstado.activa,
    );

    final tipoRespStr = '${data['tipoRespuesta'] ?? 'unica'}'.trim();
    final tipoRespuesta = EncuestaTipoRespuesta.values.firstWhere(
      (e) => e.name == tipoRespStr,
      orElse: () => EncuestaTipoRespuesta.unica,
    );

    return Encuesta(
      id: doc.id,
      titulo: data['titulo'] ?? '',
      descripcion: data['descripcion'] ?? '',
      tipo: data['tipo'] ?? 'opinion',
      tipoRespuesta: tipoRespuesta,
      estado: estado,
      esAnonima: data['esAnonima'] ?? false,
      targeting: EncuestaTargeting.fromMap(
          (data['targeting'] as Map?)?.cast<String, dynamic>()),
      opciones: opciones,
      reactionEmojis: reactionEmojis,
      fechaCreacion:
          (data['fechaCreacion'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fechaPublicacion: (data['fechaPublicacion'] as Timestamp?)?.toDate(),
      fechaLimite: (data['fechaLimite'] as Timestamp?)?.toDate(),
      publicacionInmediata: data['publicacionInmediata'] ?? true,
      creadaPor: data['creadaPor'] ?? '',
      creadaPorId: data['creadaPorId'] ?? '',
      mostrarResultados: data['mostrarResultados'] ?? false,
      totalRespuestas: (data['totalRespuestas'] as num?)?.toInt() ?? 0,
      adjuntos: ((data['adjuntos'] as List<dynamic>?) ?? [])
          .map((a) => Map<String, String>.from(a as Map))
          .toList(),
      coverImageUrl: data['coverImageUrl'] as String?,
      coverImagePath: data['coverImagePath'] as String?,
      auditLog: auditLog,
      activa: data['activa'] ?? estado == EncuestaEstado.activa,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'titulo': titulo,
      'descripcion': descripcion,
      'tipo': tipo,
      'tipoRespuesta': tipoRespuesta.name,
      'estado': estado.name,
      'esAnonima': esAnonima,
      'targeting': targeting.toMap(),
      'opciones': opciones.map((o) => o.toMap()).toList(),
      'reactionEmojis': reactionEmojis,
      'fechaCreacion': Timestamp.fromDate(fechaCreacion),
      if (fechaPublicacion != null)
        'fechaPublicacion': Timestamp.fromDate(fechaPublicacion!),
      if (fechaLimite != null)
        'fechaLimite': Timestamp.fromDate(fechaLimite!),
      'publicacionInmediata': publicacionInmediata,
      'creadaPor': creadaPor,
      'creadaPorId': creadaPorId,
      'mostrarResultados': mostrarResultados,
      'totalRespuestas': totalRespuestas,
      'adjuntos': adjuntos,
      'coverImageUrl': coverImageUrl,
      'coverImagePath': coverImagePath,
      'auditLog': auditLog.map((e) => e.toMap()).toList(),
      'activa': estado == EncuestaEstado.activa,
    };
  }
}

/// Response to a survey — supports single, multi, open-text and reaction
class RespuestaEncuesta {
  final String id;
  final String cofradeId;
  final String cofradeNombre;
  // For single-choice
  final String? selectedOptionId;
  final String? selectedOptionText;
  // For multi-choice
  final List<String> selectedOptionIds;
  final List<String> selectedOptionTexts;
  // For open-text
  final String? textoAbierto;
  // For reactions
  final String? reaccion;
  // Common
  final String? comentario;
  final DateTime fechaRespuesta;
  final DateTime? updatedAt;

  RespuestaEncuesta({
    required this.id,
    required this.cofradeId,
    required this.cofradeNombre,
    this.selectedOptionId,
    this.selectedOptionText,
    this.selectedOptionIds = const [],
    this.selectedOptionTexts = const [],
    this.textoAbierto,
    this.reaccion,
    this.comentario,
    required this.fechaRespuesta,
    this.updatedAt,
  });

  factory RespuestaEncuesta.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RespuestaEncuesta(
      id: doc.id,
      cofradeId: data['cofradeId'] ?? '',
      cofradeNombre: data['cofradeNombre'] ?? '',
      selectedOptionId: data['selectedOptionId'] as String?,
      selectedOptionText: data['selectedOptionText'] as String?,
      selectedOptionIds: List<String>.from(data['selectedOptionIds'] ?? []),
      selectedOptionTexts:
          List<String>.from(data['selectedOptionTexts'] ?? []),
      textoAbierto: data['textoAbierto'] as String?,
      reaccion: data['reaccion'] as String?,
      comentario: data['comentario'] as String?,
      fechaRespuesta: (data['fechaRespuesta'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore({bool anonymous = false}) {
    return {
      if (!anonymous) 'cofradeId': cofradeId,
      if (!anonymous) 'cofradeNombre': cofradeNombre,
      if (selectedOptionId != null) 'selectedOptionId': selectedOptionId,
      if (selectedOptionText != null)
        'selectedOptionText': selectedOptionText,
      if (selectedOptionIds.isNotEmpty) 'selectedOptionIds': selectedOptionIds,
      if (selectedOptionTexts.isNotEmpty)
        'selectedOptionTexts': selectedOptionTexts,
      if (textoAbierto != null) 'textoAbierto': textoAbierto,
      if (reaccion != null) 'reaccion': reaccion,
      if (comentario != null) 'comentario': comentario,
      'fechaRespuesta': Timestamp.fromDate(fechaRespuesta),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }
}
