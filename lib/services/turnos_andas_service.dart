import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boanerges1714/models/turno_andas.dart';

class TurnosAndasService {
  final _col = FirebaseFirestore.instance.collection('turnos_andas');

  // ---------------------------------------------------------------------------
  //  Evento CRUD
  // ---------------------------------------------------------------------------

  Stream<List<TurnoAndasEvento>> watchEventos() {
    return _col.orderBy('anio', descending: true).snapshots().map(
          (s) => s.docs.map((d) => TurnoAndasEvento.fromFirestore(d)).toList(),
        );
  }

  Stream<TurnoAndasEvento?> watchEvento(String eventoId) {
    return _col.doc(eventoId).snapshots().map(
          (d) => d.exists ? TurnoAndasEvento.fromFirestore(d) : null,
        );
  }

  Stream<TurnoAndasEvento?> watchEventoActivo() {
    return _col.snapshots().map((s) {
      final activos = s.docs
          .map((d) => TurnoAndasEvento.fromFirestore(d))
          .where((e) =>
              e.estado != 'archivado' &&
              e.estado != 'borrador')
          .toList()
        ..sort((a, b) => b.anio.compareTo(a.anio));
      return activos.isEmpty ? null : activos.first;
    });
  }

  Future<String> crearEvento(TurnoAndasEvento evento) async {
    final ref = await _col.add(evento.toFirestore());
    return ref.id;
  }

  Future<void> actualizarEvento(String eventoId, Map<String, dynamic> data) {
    return _col.doc(eventoId).update({...data, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> cambiarEstado(String eventoId, String nuevoEstado) {
    return actualizarEvento(eventoId, {'estado': nuevoEstado});
  }

  // ---------------------------------------------------------------------------
  //  Inscripciones
  // ---------------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> _inscCol(String eventoId) =>
      _col.doc(eventoId).collection('inscripciones');

  Stream<List<InscripcionTurno>> watchInscripciones(String eventoId) {
    return _inscCol(eventoId).snapshots().map(
          (s) => s.docs.map((d) => InscripcionTurno.fromFirestore(d)).toList(),
        );
  }

  Stream<InscripcionTurno?> watchMiInscripcion(String eventoId, String cofradeId) {
    return _inscCol(eventoId).doc(cofradeId).snapshots().map(
          (d) => d.exists ? InscripcionTurno.fromFirestore(d) : null,
        );
  }

  Future<void> inscribirse(String eventoId, InscripcionTurno inscripcion) {
    return _inscCol(eventoId).doc(inscripcion.cofradeId).set(inscripcion.toFirestore());
  }

  Future<void> actualizarInscripcion(
      String eventoId, String cofradeId, Map<String, dynamic> data) {
    return _inscCol(eventoId).doc(cofradeId).update({...data, 'updatedAt': FieldValue.serverTimestamp()});
  }

  // ---------------------------------------------------------------------------
  //  Puestos — turnos_andas/{id}/puestos/{puestoId}
  //  Stored flat with a 'turno' field (1 or 2) for simpler queries
  // ---------------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> _puestosCol(String eventoId) =>
      _col.doc(eventoId).collection('puestos');

  Stream<List<Puesto>> watchPuestos(String eventoId) {
    return _puestosCol(eventoId).orderBy('turno').orderBy('numero').snapshots().map(
          (s) => s.docs.map((d) => Puesto.fromFirestore(d)).toList(),
        );
  }

  Future<void> guardarPuesto(String eventoId, Puesto puesto) {
    return _puestosCol(eventoId).doc(puesto.id).set(puesto.toFirestore());
  }

  Future<void> actualizarPuesto(String eventoId, String puestoId, Map<String, dynamic> data) {
    return _puestosCol(eventoId).doc(puestoId).update({...data, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> intercambiarPuestos(String eventoId, Puesto puestoA, Puesto puestoB) {
    final batch = FirebaseFirestore.instance.batch();
    final refA = _puestosCol(eventoId).doc(puestoA.id);
    final refB = _puestosCol(eventoId).doc(puestoB.id);
    batch.update(refA, {
      'cofradeId': puestoB.cofradeId,
      'nombreCompleto': puestoB.nombreCompleto,
      'estaturaCm': puestoB.estaturaCm,
      'tipo': puestoB.tipo,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.update(refB, {
      'cofradeId': puestoA.cofradeId,
      'nombreCompleto': puestoA.nombreCompleto,
      'estaturaCm': puestoA.estaturaCm,
      'tipo': puestoA.tipo,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return batch.commit();
  }

  // ---------------------------------------------------------------------------
  //  Sustituciones — stored as array in evento document
  // ---------------------------------------------------------------------------

  Future<void> guardarSustituciones(String eventoId, List<Sustitucion> sustituciones) {
    return actualizarEvento(eventoId, {
      'sustituciones': sustituciones.map((s) => s.toMap()).toList(),
    });
  }

  Stream<List<Sustitucion>> watchSustituciones(String eventoId) {
    return _col.doc(eventoId).snapshots().map((d) {
      final data = d.data();
      if (data == null) return <Sustitucion>[];
      final raw = data['sustituciones'];
      if (raw is! List) return <Sustitucion>[];
      return raw
          .whereType<Map<String, dynamic>>()
          .map((m) => Sustitucion.fromMap(m))
          .toList();
    });
  }

  // ---------------------------------------------------------------------------
  //  Motor automático de asignación
  // ---------------------------------------------------------------------------

  Future<AsignacionResult> generarDistribucion(String eventoId) async {
    final eventoDoc = await _col.doc(eventoId).get();
    if (!eventoDoc.exists) throw Exception('Evento no encontrado');
    final evento = TurnoAndasEvento.fromFirestore(eventoDoc);

    final inscDocs = await _inscCol(eventoId).get();
    final inscripciones = inscDocs.docs
        .map((d) => InscripcionTurno.fromFirestore(d))
        .where((i) => i.quierePortarEsteAnio && i.estaturaCm > 0)
        .toList();

    // Get currently locked positions
    final puestosDocs = await _puestosCol(eventoId).get();
    final lockedPuestos = puestosDocs.docs
        .map((d) => Puesto.fromFirestore(d))
        .where((p) => p.locked && !p.isEmpty)
        .toList();
    final lockedCofradeIds = lockedPuestos.map((p) => p.cofradeId).toSet();

    // Filter out locked cofrades from auto-assignment
    final disponibles = inscripciones
        .where((i) => !lockedCofradeIds.contains(i.cofradeId))
        .toList();

    // Sort by height
    disponibles.sort((a, b) => a.estaturaCm.compareTo(b.estaturaCm));

    final config1 = evento.turno1;
    final config2 = evento.turno2;
    final totalPuestos1 = config1.numeroPuestos;
    final totalPuestos2 = config2.numeroPuestos;

    // Count locked positions per turn
    final locked1 = lockedPuestos.where((p) => _puestoTurno(p, puestosDocs.docs) == 1).length;
    final locked2 = lockedPuestos.where((p) => _puestoTurno(p, puestosDocs.docs) == 2).length;
    final free1 = totalPuestos1 - locked1;
    final free2 = totalPuestos2 - locked2;

    // Separate by availability preference
    final onlyT1 = disponibles.where((i) => i.disponibilidad.primerTurno && !i.disponibilidad.segundoTurno).toList();
    final onlyT2 = disponibles.where((i) => i.disponibilidad.segundoTurno && !i.disponibilidad.primerTurno).toList();
    final ambos = disponibles
        .where((i) =>
            (i.disponibilidad.primerTurno && i.disponibilidad.segundoTurno) ||
            (!i.disponibilidad.primerTurno && !i.disponibilidad.segundoTurno))
        .toList();
    final reservas = disponibles.where((i) => i.disponibilidad.reserva && !i.disponibilidad.primerTurno && !i.disponibilidad.segundoTurno).toList();

    // Assign exclusive preferences first
    final asignados1 = <InscripcionTurno>[];
    final asignados2 = <InscripcionTurno>[];
    final asignadosReserva = <InscripcionTurno>[];

    for (final insc in onlyT1) {
      if (asignados1.length < free1) {
        asignados1.add(insc);
      } else {
        asignadosReserva.add(insc);
      }
    }
    for (final insc in onlyT2) {
      if (asignados2.length < free2) {
        asignados2.add(insc);
      } else {
        asignadosReserva.add(insc);
      }
    }

    // Fill remaining with flexible cofrades — shorter to T1, taller to T2
    ambos.sort((a, b) => a.estaturaCm.compareTo(b.estaturaCm));
    for (final insc in ambos) {
      if (asignados1.length < free1) {
        asignados1.add(insc);
      } else if (asignados2.length < free2) {
        asignados2.add(insc);
      } else {
        asignadosReserva.add(insc);
      }
    }
    for (final insc in reservas) {
      if (!asignados1.any((a) => a.cofradeId == insc.cofradeId) &&
          !asignados2.any((a) => a.cofradeId == insc.cofradeId)) {
        asignadosReserva.add(insc);
      }
    }

    // Sort each turn by height for position assignment
    asignados1.sort((a, b) => a.estaturaCm.compareTo(b.estaturaCm));
    asignados2.sort((a, b) => a.estaturaCm.compareTo(b.estaturaCm));

    // Generate puestos
    final batch = FirebaseFirestore.instance.batch();
    final alertas = <String>[];
    int posCounter = 0;

    // Generate turn 1 positions
    for (int i = 0; i < totalPuestos1; i++) {
      final puestoId = 't1_${i + 1}';
      final ref = _puestosCol(eventoId).doc(puestoId);
      final existingLocked = lockedPuestos.where((p) => p.id == puestoId).toList();
      if (existingLocked.isNotEmpty) continue;

      final asignado = i < asignados1.length ? asignados1[i] : null;
      batch.set(ref, {
        'numero': i + 1,
        'turno': 1,
        'cofradeId': asignado?.cofradeId,
        'nombreCompleto': asignado?.nombreCompleto ?? '',
        'estaturaCm': asignado?.estaturaCm ?? 0,
        'tipo': 'titular',
        'lateral': i < config1.posicionesLaterales || i >= totalPuestos1 - config1.posicionesLaterales,
        'locked': false,
        'observaciones': '',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      posCounter++;
    }

    // Generate turn 2 positions
    for (int i = 0; i < totalPuestos2; i++) {
      final puestoId = 't2_${i + 1}';
      final ref = _puestosCol(eventoId).doc(puestoId);
      final existingLocked = lockedPuestos.where((p) => p.id == puestoId).toList();
      if (existingLocked.isNotEmpty) continue;

      final asignado = i < asignados2.length ? asignados2[i] : null;
      batch.set(ref, {
        'numero': i + 1,
        'turno': 2,
        'cofradeId': asignado?.cofradeId,
        'nombreCompleto': asignado?.nombreCompleto ?? '',
        'estaturaCm': asignado?.estaturaCm ?? 0,
        'tipo': 'titular',
        'lateral': i < config2.posicionesLaterales || i >= totalPuestos2 - config2.posicionesLaterales,
        'locked': false,
        'observaciones': '',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      posCounter++;
    }

    // Update inscripciones with assignment info
    for (int i = 0; i < asignados1.length; i++) {
      final insc = asignados1[i];
      batch.update(_inscCol(eventoId).doc(insc.cofradeId), {
        'estado': 'asignado',
        'asignacion': {'turno': 1, 'posicion': i + 1, 'tipo': 'titular'},
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    for (int i = 0; i < asignados2.length; i++) {
      final insc = asignados2[i];
      batch.update(_inscCol(eventoId).doc(insc.cofradeId), {
        'estado': 'asignado',
        'asignacion': {'turno': 2, 'posicion': i + 1, 'tipo': 'titular'},
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    for (final insc in asignadosReserva) {
      batch.update(_inscCol(eventoId).doc(insc.cofradeId), {
        'estado': 'reserva',
        'asignacion': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // Update evento estado
    batch.update(_col.doc(eventoId), {
      'estado': 'propuesta_generada',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // Compute alerts
    final media1 = asignados1.isEmpty
        ? 0.0
        : asignados1.fold<int>(0, (s, i) => s + i.estaturaCm) / asignados1.length;
    final media2 = asignados2.isEmpty
        ? 0.0
        : asignados2.fold<int>(0, (s, i) => s + i.estaturaCm) / asignados2.length;

    if (asignados1.length < free1) alertas.add('Turno 1: faltan ${free1 - asignados1.length} portadores');
    if (asignados2.length < free2) alertas.add('Turno 2: faltan ${free2 - asignados2.length} portadores');
    if (asignadosReserva.isEmpty) alertas.add('No hay reservas disponibles');

    // Height difference alerts
    if (asignados1.length >= 2) {
      final maxDiff = asignados1.last.estaturaCm - asignados1.first.estaturaCm;
      if (maxDiff > 15) alertas.add('Turno 1: diferencia de altura excesiva (${maxDiff}cm)');
    }
    if (asignados2.length >= 2) {
      final maxDiff = asignados2.last.estaturaCm - asignados2.first.estaturaCm;
      if (maxDiff > 15) alertas.add('Turno 2: diferencia de altura excesiva (${maxDiff}cm)');
    }

    return AsignacionResult(
      turno1Count: asignados1.length,
      turno2Count: asignados2.length,
      reservaCount: asignadosReserva.length,
      mediaTurno1: media1,
      mediaTurno2: media2,
      alertas: alertas,
      totalPuestos: posCounter,
    );
  }

  int _puestoTurno(Puesto puesto, List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final doc = docs.where((d) => d.id == puesto.id).toList();
    if (doc.isEmpty) return puesto.id.startsWith('t1') ? 1 : 2;
    return (doc.first.data()['turno'] as int?) ?? (puesto.id.startsWith('t1') ? 1 : 2);
  }

  // ---------------------------------------------------------------------------
  //  Actualizar estatura del cofrade en colección principal
  // ---------------------------------------------------------------------------

  Future<void> actualizarEstaturaCofrade(String cofradeId, int estaturaCm) {
    return FirebaseFirestore.instance
        .collection('cofrades')
        .doc(cofradeId)
        .update({'estatura': estaturaCm});
  }

  // ---------------------------------------------------------------------------
  //  Leer campo portador del cofrade
  // ---------------------------------------------------------------------------

  Future<bool> esPortador(String cofradeId) async {
    final doc = await FirebaseFirestore.instance
        .collection('cofrades')
        .doc(cofradeId)
        .get();
    return doc.data()?['portador'] == true;
  }

  Future<int?> getEstaturaCofrade(String cofradeId) async {
    final doc = await FirebaseFirestore.instance
        .collection('cofrades')
        .doc(cofradeId)
        .get();
    return doc.data()?['estatura'] as int?;
  }
}

// ---------------------------------------------------------------------------
//  Result of auto-assignment
// ---------------------------------------------------------------------------

class AsignacionResult {
  final int turno1Count;
  final int turno2Count;
  final int reservaCount;
  final double mediaTurno1;
  final double mediaTurno2;
  final List<String> alertas;
  final int totalPuestos;

  const AsignacionResult({
    required this.turno1Count,
    required this.turno2Count,
    required this.reservaCount,
    required this.mediaTurno1,
    required this.mediaTurno2,
    required this.alertas,
    required this.totalPuestos,
  });
}
