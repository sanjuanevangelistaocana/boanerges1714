import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _ts(dynamic value) => value is Timestamp ? value.toDate() : null;

// ---------------------------------------------------------------------------
//  TurnoAndasEvento — top-level document in turnos_andas/{eventoId}
// ---------------------------------------------------------------------------

class TurnoAndasEvento {
  final String id;
  final String titulo;
  final String descripcion;
  final String estado; // borrador | abierto | cerrado | propuesta_generada | en_revision | publicado | archivado
  final DateTime? fechaProcesion;
  final DateTime? deadlineInscripcion;
  final int anio;
  final ConfiguracionTurno turno1;
  final ConfiguracionTurno turno2;
  final bool mostrarAndaVisualACofrades;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String createdBy;

  const TurnoAndasEvento({
    required this.id,
    required this.titulo,
    this.descripcion = '',
    this.estado = 'borrador',
    this.fechaProcesion,
    this.deadlineInscripcion,
    required this.anio,
    required this.turno1,
    required this.turno2,
    this.mostrarAndaVisualACofrades = false,
    this.createdAt,
    this.updatedAt,
    this.createdBy = '',
  });

  bool get isOpen => estado == 'abierto';
  bool get isPublished => estado == 'publicado';
  bool get isClosed => estado == 'cerrado' || estado == 'propuesta_generada' || estado == 'en_revision';
  bool get acceptsInscriptions => isOpen && (deadlineInscripcion == null || deadlineInscripcion!.isAfter(DateTime.now()));

  factory TurnoAndasEvento.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return TurnoAndasEvento(
      id: doc.id,
      titulo: '${d['titulo'] ?? ''}',
      descripcion: '${d['descripcion'] ?? ''}',
      estado: '${d['estado'] ?? 'borrador'}',
      fechaProcesion: _ts(d['fechaProcesion']),
      deadlineInscripcion: _ts(d['deadlineInscripcion']),
      anio: (d['anio'] as int?) ?? DateTime.now().year,
      turno1: ConfiguracionTurno.fromMap(d['configuracionTurnos']?['turno1'] as Map<String, dynamic>? ?? {}),
      turno2: ConfiguracionTurno.fromMap(d['configuracionTurnos']?['turno2'] as Map<String, dynamic>? ?? {}),
      mostrarAndaVisualACofrades: d['mostrarAndaVisualACofrades'] == true,
      createdAt: _ts(d['createdAt']),
      updatedAt: _ts(d['updatedAt']),
      createdBy: '${d['createdBy'] ?? ''}',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'titulo': titulo,
        'descripcion': descripcion,
        'estado': estado,
        'fechaProcesion': fechaProcesion != null ? Timestamp.fromDate(fechaProcesion!) : null,
        'deadlineInscripcion': deadlineInscripcion != null ? Timestamp.fromDate(deadlineInscripcion!) : null,
        'anio': anio,
        'configuracionTurnos': {
          'turno1': turno1.toMap(),
          'turno2': turno2.toMap(),
        },
        'mostrarAndaVisualACofrades': mostrarAndaVisualACofrades,
        'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdBy': createdBy,
      };
}

// ---------------------------------------------------------------------------
//  ConfiguracionTurno — sub-document inside evento
// ---------------------------------------------------------------------------

class ConfiguracionTurno {
  final int numeroPuestos;
  final int mediaObjetivoCm;
  final int alturaMinObjetivoCm;
  final int alturaMaxObjetivoCm;
  final int posicionesLaterales;

  const ConfiguracionTurno({
    this.numeroPuestos = 24,
    this.mediaObjetivoCm = 175,
    this.alturaMinObjetivoCm = 165,
    this.alturaMaxObjetivoCm = 195,
    this.posicionesLaterales = 4,
  });

  factory ConfiguracionTurno.fromMap(Map<String, dynamic> m) => ConfiguracionTurno(
        numeroPuestos: (m['numeroPuestos'] as int?) ?? 24,
        mediaObjetivoCm: (m['mediaObjetivoCm'] as int?) ?? 175,
        alturaMinObjetivoCm: (m['alturaMinObjetivoCm'] as int?) ?? 165,
        alturaMaxObjetivoCm: (m['alturaMaxObjetivoCm'] as int?) ?? 195,
        posicionesLaterales: (m['posicionesLaterales'] as int?) ?? 4,
      );

  Map<String, dynamic> toMap() => {
        'numeroPuestos': numeroPuestos,
        'mediaObjetivoCm': mediaObjetivoCm,
        'alturaMinObjetivoCm': alturaMinObjetivoCm,
        'alturaMaxObjetivoCm': alturaMaxObjetivoCm,
        'posicionesLaterales': posicionesLaterales,
      };
}

// ---------------------------------------------------------------------------
//  InscripcionTurno — sub-collection turnos_andas/{id}/inscripciones/{cofradeId}
// ---------------------------------------------------------------------------

class InscripcionTurno {
  final String id;
  final String cofradeId;
  final String nombre;
  final String apellidos;
  final int? estaturaPerfilCm;
  final int? estaturaConfirmadaCm;
  final bool estaturaActualizada;
  final bool portadorPerfil;
  final bool quierePortarEsteAnio;
  final bool requiereRevisionPortador;
  final DisponibilidadTurno disponibilidad;
  final String restricciones;
  final String observaciones;
  final String preferenciaLateral;
  final String estado; // solicitado | asignado | reserva | sustituto | descartado
  final AsignacionPuesto? asignacion;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const InscripcionTurno({
    required this.id,
    required this.cofradeId,
    required this.nombre,
    this.apellidos = '',
    this.estaturaPerfilCm,
    this.estaturaConfirmadaCm,
    this.estaturaActualizada = false,
    this.portadorPerfil = false,
    this.quierePortarEsteAnio = true,
    this.requiereRevisionPortador = false,
    required this.disponibilidad,
    this.restricciones = '',
    this.observaciones = '',
    this.preferenciaLateral = '',
    this.estado = 'solicitado',
    this.asignacion,
    this.createdAt,
    this.updatedAt,
  });

  String get nombreCompleto => '$nombre $apellidos'.trim();
  int get estaturaCm => estaturaConfirmadaCm ?? estaturaPerfilCm ?? 0;

  factory InscripcionTurno.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final disp = d['disponibilidad'] as Map<String, dynamic>? ?? {};
    final asig = d['asignacion'] as Map<String, dynamic>?;
    return InscripcionTurno(
      id: doc.id,
      cofradeId: '${d['cofradeId'] ?? doc.id}',
      nombre: '${d['nombre'] ?? ''}',
      apellidos: '${d['apellidos'] ?? ''}',
      estaturaPerfilCm: d['estaturaPerfilCm'] as int?,
      estaturaConfirmadaCm: d['estaturaConfirmadaCm'] as int?,
      estaturaActualizada: d['estaturaActualizada'] == true,
      portadorPerfil: d['portadorPerfil'] == true,
      quierePortarEsteAnio: d['quierePortarEsteAnio'] != false,
      requiereRevisionPortador: d['requiereRevisionPortador'] == true,
      disponibilidad: DisponibilidadTurno.fromMap(disp),
      restricciones: '${d['restricciones'] ?? ''}',
      observaciones: '${d['observaciones'] ?? ''}',
      preferenciaLateral: '${d['preferenciaLateral'] ?? ''}',
      estado: '${d['estado'] ?? 'solicitado'}',
      asignacion: asig != null ? AsignacionPuesto.fromMap(asig) : null,
      createdAt: _ts(d['createdAt']),
      updatedAt: _ts(d['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'cofradeId': cofradeId,
        'nombre': nombre,
        'apellidos': apellidos,
        'estaturaPerfilCm': estaturaPerfilCm,
        'estaturaConfirmadaCm': estaturaConfirmadaCm,
        'estaturaActualizada': estaturaActualizada,
        'portadorPerfil': portadorPerfil,
        'quierePortarEsteAnio': quierePortarEsteAnio,
        'requiereRevisionPortador': requiereRevisionPortador,
        'disponibilidad': disponibilidad.toMap(),
        'restricciones': restricciones,
        'observaciones': observaciones,
        'preferenciaLateral': preferenciaLateral,
        'estado': estado,
        if (asignacion != null) 'asignacion': asignacion!.toMap(),
        'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

// ---------------------------------------------------------------------------
//  DisponibilidadTurno
// ---------------------------------------------------------------------------

class DisponibilidadTurno {
  final bool primerTurno;
  final bool segundoTurno;
  final bool sustituciones;
  final bool reserva;

  const DisponibilidadTurno({
    this.primerTurno = false,
    this.segundoTurno = false,
    this.sustituciones = false,
    this.reserva = false,
  });

  factory DisponibilidadTurno.fromMap(Map<String, dynamic> m) => DisponibilidadTurno(
        primerTurno: m['primerTurno'] == true,
        segundoTurno: m['segundoTurno'] == true,
        sustituciones: m['sustituciones'] == true,
        reserva: m['reserva'] == true,
      );

  Map<String, dynamic> toMap() => {
        'primerTurno': primerTurno,
        'segundoTurno': segundoTurno,
        'sustituciones': sustituciones,
        'reserva': reserva,
      };
}

// ---------------------------------------------------------------------------
//  AsignacionPuesto — inline in inscripcion
// ---------------------------------------------------------------------------

class AsignacionPuesto {
  final int turno; // 1 or 2
  final int posicion;
  final String tipo; // titular | sustituto | reserva

  const AsignacionPuesto({
    required this.turno,
    required this.posicion,
    this.tipo = 'titular',
  });

  factory AsignacionPuesto.fromMap(Map<String, dynamic> m) => AsignacionPuesto(
        turno: (m['turno'] as int?) ?? 1,
        posicion: (m['posicion'] as int?) ?? 0,
        tipo: '${m['tipo'] ?? 'titular'}',
      );

  Map<String, dynamic> toMap() => {
        'turno': turno,
        'posicion': posicion,
        'tipo': tipo,
      };
}

// ---------------------------------------------------------------------------
//  Puesto — sub-collection turnos_andas/{id}/turnos/{turnoId}/puestos/{puestoId}
// ---------------------------------------------------------------------------

class Puesto {
  final String id;
  final int numero;
  final int turno; // 1 or 2
  final String? cofradeId;
  final String nombreCompleto;
  final int estaturaCm;
  final String tipo; // titular | sustituto | reserva
  final bool lateral;
  final bool locked;
  final String observaciones;
  final String? updatedBy;
  final DateTime? updatedAt;

  const Puesto({
    required this.id,
    required this.numero,
    this.turno = 1,
    this.cofradeId,
    this.nombreCompleto = '',
    this.estaturaCm = 0,
    this.tipo = 'titular',
    this.lateral = false,
    this.locked = false,
    this.observaciones = '',
    this.updatedBy,
    this.updatedAt,
  });

  bool get isEmpty => cofradeId == null || cofradeId!.isEmpty;

  factory Puesto.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Puesto(
      id: doc.id,
      numero: (d['numero'] as int?) ?? 0,
      turno: (d['turno'] as int?) ?? (doc.id.startsWith('t1') ? 1 : 2),
      cofradeId: d['cofradeId'] as String?,
      nombreCompleto: '${d['nombreCompleto'] ?? ''}',
      estaturaCm: (d['estaturaCm'] as int?) ?? 0,
      tipo: '${d['tipo'] ?? 'titular'}',
      lateral: d['lateral'] == true,
      locked: d['locked'] == true,
      observaciones: '${d['observaciones'] ?? ''}',
      updatedBy: d['updatedBy'] as String?,
      updatedAt: _ts(d['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'numero': numero,
        'turno': turno,
        'cofradeId': cofradeId,
        'nombreCompleto': nombreCompleto,
        'estaturaCm': estaturaCm,
        'tipo': tipo,
        'lateral': lateral,
        'locked': locked,
        'observaciones': observaciones,
        'updatedBy': updatedBy,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

// ---------------------------------------------------------------------------
//  Sustitucion — stored in array inside evento document
// ---------------------------------------------------------------------------

class Sustitucion {
  final String saleCofradeId;
  final String saleNombre;
  final String entraCofradeId;
  final String entraNombre;
  final String momento;
  final String ubicacion;
  final int turno;

  const Sustitucion({
    required this.saleCofradeId,
    this.saleNombre = '',
    required this.entraCofradeId,
    this.entraNombre = '',
    this.momento = '',
    this.ubicacion = '',
    this.turno = 1,
  });

  factory Sustitucion.fromMap(Map<String, dynamic> m) => Sustitucion(
        saleCofradeId: '${m['saleCofradeId'] ?? ''}',
        saleNombre: '${m['saleNombre'] ?? ''}',
        entraCofradeId: '${m['entraCofradeId'] ?? ''}',
        entraNombre: '${m['entraNombre'] ?? ''}',
        momento: '${m['momento'] ?? ''}',
        ubicacion: '${m['ubicacion'] ?? ''}',
        turno: (m['turno'] as int?) ?? 1,
      );

  Map<String, dynamic> toMap() => {
        'saleCofradeId': saleCofradeId,
        'saleNombre': saleNombre,
        'entraCofradeId': entraCofradeId,
        'entraNombre': entraNombre,
        'momento': momento,
        'ubicacion': ubicacion,
        'turno': turno,
      };
}
