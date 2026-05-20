import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:boanerges1714/models/encuesta.dart';
import 'package:boanerges1714/models/cofrade.dart';
import 'package:boanerges1714/models/tag_config.dart';

class EncuestaService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const _collection = 'convocatorias';

  // ---------------------------------------------------------------------------
  // CRUD
  // ---------------------------------------------------------------------------

  Stream<List<Encuesta>> getAllEncuestas() {
    return _db
        .collection(_collection)
        .snapshots()
        .map((snap) {
      final list = <Encuesta>[];
      for (final doc in snap.docs) {
        try {
          list.add(Encuesta.fromFirestore(doc));
        } catch (e) {
          debugPrint('[EncuestaService] parse error ${doc.id}: $e');
        }
      }
      list.sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));
      return list;
    });
  }

  Stream<List<Encuesta>> getEncuestasActivas() {
    // Don't filter by 'estado' field — old docs use 'activa' bool + 'status' string
    return _db
        .collection(_collection)
        .snapshots()
        .map((snap) {
      final now = DateTime.now();
      final list = <Encuesta>[];
      for (final doc in snap.docs) {
        try {
          final e = Encuesta.fromFirestore(doc);
          final withinDeadline =
              e.fechaLimite == null || now.isBefore(e.fechaLimite!);
          if (withinDeadline) list.add(e);
        } catch (e) {
          debugPrint('[EncuestaService] parse error ${doc.id}: $e');
        }
      }
      list.sort((a, b) {
        final aLimit = a.fechaLimite ?? DateTime(2099);
        final bLimit = b.fechaLimite ?? DateTime(2099);
        return aLimit.compareTo(bLimit);
      });
      return list;
    });
  }

  /// Active surveys filtered by cofrade's tags
  Stream<List<Encuesta>> getEncuestasParaCofrade(Cofrade cofrade) {
    final allTags = [...cofrade.tagsManual, ...cofrade.tagsAuto];
    return getEncuestasActivas().map((encuestas) =>
        encuestas.where((e) => e.canCofradeAccess(allTags)).toList());
  }

  Future<Encuesta?> getEncuesta(String id) async {
    final doc = await _db.collection(_collection).doc(id).get();
    if (!doc.exists) return null;
    return Encuesta.fromFirestore(doc);
  }

  Future<void> createEncuesta(Encuesta encuesta) async {
    final ref = encuesta.id.isNotEmpty
        ? _db.collection(_collection).doc(encuesta.id)
        : _db.collection(_collection).doc();
    await ref.set(encuesta.toFirestore());
  }

  Future<void> updateEncuesta(String id, Map<String, dynamic> data) async {
    await _db.collection(_collection).doc(id).update(data);
  }

  Future<void> deleteEncuesta(String id) async {
    final respSnap =
        await _db.collection(_collection).doc(id).collection('respuestas').get();
    final batch = _db.batch();
    for (final doc in respSnap.docs) {
      batch.delete(doc.reference);
    }
    final votersSnap =
        await _db.collection(_collection).doc(id).collection('voters').get();
    for (final doc in votersSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_db.collection(_collection).doc(id));
    await batch.commit();
  }

  // ---------------------------------------------------------------------------
  // Audit
  // ---------------------------------------------------------------------------

  Future<void> addAuditEntry(
    String encuestaId, {
    required String action,
    required String userId,
    required String userName,
    Map<String, dynamic> details = const {},
  }) async {
    final entry = EncuestaAuditEntry(
      action: action,
      userId: userId,
      userName: userName,
      timestamp: DateTime.now(),
      details: details,
    );
    await _db.collection(_collection).doc(encuestaId).update({
      'auditLog': FieldValue.arrayUnion([entry.toMap()]),
    });
  }

  // ---------------------------------------------------------------------------
  // Responses
  // ---------------------------------------------------------------------------

  Stream<List<RespuestaEncuesta>> getRespuestas(String encuestaId) {
    return _db
        .collection(_collection)
        .doc(encuestaId)
        .collection('respuestas')
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => RespuestaEncuesta.fromFirestore(d))
              .toList();
          list.sort((a, b) => b.fechaRespuesta.compareTo(a.fechaRespuesta));
          return list;
        });
  }

  Future<RespuestaEncuesta?> getMiRespuesta(
      String encuestaId, String cofradeId) async {
    // For anonymous surveys the response doc ID is the cofrade ID in the
    // 'voters' subcollection, not in 'respuestas'.
    final encuesta = await getEncuesta(encuestaId);
    if (encuesta == null) return null;

    if (encuesta.esAnonima) {
      // Check 'voters' to see if cofrade already voted
      final voterDoc = await _db
          .collection(_collection)
          .doc(encuestaId)
          .collection('voters')
          .doc(cofradeId)
          .get();
      if (!voterDoc.exists) return null;
      // Return a synthetic response — we know they voted but not what
      final data = voterDoc.data() ?? {};
      return RespuestaEncuesta(
        id: voterDoc.id,
        cofradeId: cofradeId,
        cofradeNombre: '',
        selectedOptionId: data['selectedOptionId'] as String?,
        selectedOptionText: data['selectedOptionText'] as String?,
        selectedOptionIds:
            List<String>.from(data['selectedOptionIds'] ?? []),
        selectedOptionTexts:
            List<String>.from(data['selectedOptionTexts'] ?? []),
        textoAbierto: data['textoAbierto'] as String?,
        reaccion: data['reaccion'] as String?,
        fechaRespuesta:
            (data['fechaRespuesta'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    } else {
      final doc = await _db
          .collection(_collection)
          .doc(encuestaId)
          .collection('respuestas')
          .doc(cofradeId)
          .get();
      if (!doc.exists) return null;
      return RespuestaEncuesta.fromFirestore(doc);
    }
  }

  /// Submit or update a response. For anonymous surveys, stores the response
  /// without cofrade identity in 'respuestas' and marks 'voters/{cofradeId}'
  /// to prevent duplicates.
  Future<void> responder(
    String encuestaId,
    Cofrade cofrade,
    RespuestaEncuesta respuesta,
  ) async {
    final encuesta = await getEncuesta(encuestaId);
    if (encuesta == null) return;

    if (encuesta.esAnonima) {
      final voterRef = _db
          .collection(_collection)
          .doc(encuestaId)
          .collection('voters')
          .doc(cofrade.id);
      final voterSnap = await voterRef.get();
      final isUpdate = voterSnap.exists;

      final batch = _db.batch();

      // Store the cofrade's choice privately so they can see their own response
      batch.set(voterRef, {
        'votedAt': FieldValue.serverTimestamp(),
        if (respuesta.selectedOptionId != null)
          'selectedOptionId': respuesta.selectedOptionId,
        if (respuesta.selectedOptionText != null)
          'selectedOptionText': respuesta.selectedOptionText,
        if (respuesta.selectedOptionIds.isNotEmpty)
          'selectedOptionIds': respuesta.selectedOptionIds,
        if (respuesta.selectedOptionTexts.isNotEmpty)
          'selectedOptionTexts': respuesta.selectedOptionTexts,
        if (respuesta.textoAbierto != null)
          'textoAbierto': respuesta.textoAbierto,
        if (respuesta.reaccion != null) 'reaccion': respuesta.reaccion,
        'fechaRespuesta': Timestamp.fromDate(respuesta.fechaRespuesta),
      });

      if (!isUpdate) {
        // Add anonymous response doc with auto-ID (no cofrade info)
        final anonRef = _db
            .collection(_collection)
            .doc(encuestaId)
            .collection('respuestas')
            .doc();
        batch.set(anonRef, respuesta.toFirestore(anonymous: true));
        batch.update(_db.collection(_collection).doc(encuestaId), {
          'totalRespuestas': FieldValue.increment(1),
        });
      }

      await batch.commit();
    } else {
      final ref = _db
          .collection(_collection)
          .doc(encuestaId)
          .collection('respuestas')
          .doc(cofrade.id);
      final existing = await ref.get();
      final isUpdate = existing.exists;

      await ref.set(respuesta.toFirestore());

      if (!isUpdate) {
        await _db.collection(_collection).doc(encuestaId).update({
          'totalRespuestas': FieldValue.increment(1),
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Results / aggregation
  // ---------------------------------------------------------------------------

  /// Counts per option ID for single/multi/reaction surveys
  Future<Map<String, int>> getResultCounts(String encuestaId) async {
    final result = <String, int>{};
    try {
      final snap = await _db
          .collection(_collection)
          .doc(encuestaId)
          .collection('respuestas')
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        // Multi-response
        final multiIds = data['selectedOptionIds'];
        if (multiIds is List && multiIds.isNotEmpty) {
          for (final optId in multiIds) {
            final key = '$optId';
            result[key] = (result[key] ?? 0) + 1;
          }
          continue;
        }
        // Reaction
        final reaccion = data['reaccion'];
        if (reaccion is String && reaccion.isNotEmpty) {
          result[reaccion] = (result[reaccion] ?? 0) + 1;
          continue;
        }
        // Single-choice
        final key =
            '${data['selectedOptionId'] ?? data['selectedOptionText'] ?? ''}';
        if (key.isNotEmpty) {
          result[key] = (result[key] ?? 0) + 1;
        }
      }
    } on FirebaseException catch (e) {
      debugPrint('[EncuestaService] getResultCounts error: ${e.code}');
    }
    return result;
  }

  /// Open-text responses
  Future<List<String>> getOpenTextResponses(String encuestaId) async {
    final list = <String>[];
    try {
      final snap = await _db
          .collection(_collection)
          .doc(encuestaId)
          .collection('respuestas')
          .get();
      for (final doc in snap.docs) {
        final text = doc.data()['textoAbierto'];
        if (text is String && text.trim().isNotEmpty) list.add(text);
      }
    } on FirebaseException catch (e) {
      debugPrint('[EncuestaService] getOpenTextResponses error: ${e.code}');
    }
    return list;
  }

  // ---------------------------------------------------------------------------
  // Participation metrics
  // ---------------------------------------------------------------------------

  /// Total cofrades targeted (approximate — uses passed cofrades list)
  int countTargetedCofrades(Encuesta encuesta, List<Cofrade> allCofrades) {
    return allCofrades
        .where((c) =>
            c.isActivo &&
            encuesta.canCofradeAccess([...c.tagsManual, ...c.tagsAuto]))
        .length;
  }

  double participationRate(Encuesta encuesta, List<Cofrade> allCofrades) {
    final targeted = countTargetedCofrades(encuesta, allCofrades);
    if (targeted == 0) return 0;
    return encuesta.totalRespuestas / targeted;
  }

  // ---------------------------------------------------------------------------
  // Scheduling helpers
  // ---------------------------------------------------------------------------

  /// Activate surveys whose scheduled publish date has arrived
  Future<int> activateScheduledSurveys() async {
    final now = DateTime.now();
    final snap = await _db
        .collection(_collection)
        .get();
    int activated = 0;
    for (final doc in snap.docs) {
      final estado = doc.data()['estado'] ?? '';
      if (estado != EncuestaEstado.programada.name) continue;
      final pubDate = (doc.data()['fechaPublicacion'] as Timestamp?)?.toDate();
      if (pubDate != null && now.isAfter(pubDate)) {
        await doc.reference.update({
          'estado': EncuestaEstado.activa.name,
          'activa': true,
        });
        activated++;
      }
    }
    return activated;
  }

  /// Close surveys whose deadline has passed
  Future<int> closeExpiredSurveys() async {
    final now = DateTime.now();
    final snap = await _db
        .collection(_collection)
        .get();
    int closed = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      final isActive = data['activa'] == true ||
          data['estado'] == EncuestaEstado.activa.name;
      if (!isActive) continue;
      final limit = (data['fechaLimite'] ?? data['fecha_limite'] as Timestamp?)?.toDate();
      if (limit != null && now.isAfter(limit)) {
        await doc.reference.update({
          'estado': EncuestaEstado.cerrada.name,
          'activa': false,
        });
        closed++;
      }
    }
    return closed;
  }

  // ---------------------------------------------------------------------------
  // Export helpers
  // ---------------------------------------------------------------------------

  /// Generate CSV content string for an encuesta's responses
  Future<String> exportCsv(Encuesta encuesta) async {
    final respuestas = await _db
        .collection(_collection)
        .doc(encuesta.id)
        .collection('respuestas')
        .get();

    final buf = StringBuffer();
    if (encuesta.tipoRespuesta == EncuestaTipoRespuesta.abierta) {
      buf.writeln(encuesta.esAnonima
          ? 'Fecha,Respuesta'
          : 'Cofrade,Fecha,Respuesta');
      for (final doc in respuestas.docs) {
        final d = doc.data();
        final fecha = (d['fechaRespuesta'] as Timestamp?)
                ?.toDate()
                .toIso8601String() ??
            '';
        final text = _csvEscape('${d['textoAbierto'] ?? ''}');
        if (encuesta.esAnonima) {
          buf.writeln('$fecha,$text');
        } else {
          buf.writeln('${_csvEscape('${d['cofradeNombre'] ?? ''}')},$fecha,$text');
        }
      }
    } else if (encuesta.tipoRespuesta == EncuestaTipoRespuesta.multiple) {
      buf.writeln(encuesta.esAnonima
          ? 'Fecha,Opciones seleccionadas'
          : 'Cofrade,Fecha,Opciones seleccionadas');
      for (final doc in respuestas.docs) {
        final d = doc.data();
        final fecha = (d['fechaRespuesta'] as Timestamp?)
                ?.toDate()
                .toIso8601String() ??
            '';
        final texts = List<String>.from(d['selectedOptionTexts'] ?? []);
        final joined = _csvEscape(texts.join('; '));
        if (encuesta.esAnonima) {
          buf.writeln('$fecha,$joined');
        } else {
          buf.writeln('${_csvEscape('${d['cofradeNombre'] ?? ''}')},$fecha,$joined');
        }
      }
    } else if (encuesta.tipoRespuesta == EncuestaTipoRespuesta.reaccion) {
      buf.writeln(encuesta.esAnonima
          ? 'Fecha,Reacción'
          : 'Cofrade,Fecha,Reacción');
      for (final doc in respuestas.docs) {
        final d = doc.data();
        final fecha = (d['fechaRespuesta'] as Timestamp?)
                ?.toDate()
                .toIso8601String() ??
            '';
        final reac = d['reaccion'] ?? '';
        if (encuesta.esAnonima) {
          buf.writeln('$fecha,$reac');
        } else {
          buf.writeln('${_csvEscape('${d['cofradeNombre'] ?? ''}')},$fecha,$reac');
        }
      }
    } else {
      buf.writeln(encuesta.esAnonima
          ? 'Fecha,Opción'
          : 'Cofrade,Fecha,Opción');
      for (final doc in respuestas.docs) {
        final d = doc.data();
        final fecha = (d['fechaRespuesta'] as Timestamp?)
                ?.toDate()
                .toIso8601String() ??
            '';
        final opt = _csvEscape(
            '${d['selectedOptionText'] ?? d['selectedOptionId'] ?? ''}');
        if (encuesta.esAnonima) {
          buf.writeln('$fecha,$opt');
        } else {
          buf.writeln('${_csvEscape('${d['cofradeNombre'] ?? ''}')},$fecha,$opt');
        }
      }
    }
    return buf.toString();
  }

  String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  // ---------------------------------------------------------------------------
  // Dashboard metrics
  // ---------------------------------------------------------------------------

  /// Returns aggregated participation metrics across all surveys
  Future<Map<String, dynamic>> getDashboardMetrics(
      List<Cofrade> cofrades) async {
    final allSnap = await _db.collection(_collection).get();
    final encuestas =
        allSnap.docs.map((d) => Encuesta.fromFirestore(d)).toList();

    if (encuestas.isEmpty) {
      return {
        'totalEncuestas': 0,
        'participacionMedia': 0.0,
        'masParticipacion': <String, dynamic>{},
        'menosParticipacion': <String, dynamic>{},
        'porTag': <String, double>{},
      };
    }

    final activeCofrades = cofrades.where((c) => c.isActivo).toList();
    double totalRate = 0;
    String? topId;
    double topRate = -1;
    String? bottomId;
    double bottomRate = double.infinity;

    for (final e in encuestas) {
      final targeted = countTargetedCofrades(e, activeCofrades);
      if (targeted == 0) continue;
      final rate = e.totalRespuestas / targeted;
      totalRate += rate;
      if (rate > topRate) {
        topRate = rate;
        topId = e.id;
      }
      if (rate < bottomRate) {
        bottomRate = rate;
        bottomId = e.id;
      }
    }

    final avgRate = totalRate / encuestas.length;

    // Participation by tag group
    final tagParticipation = <String, List<double>>{};
    for (final e in encuestas) {
      for (final tag in e.targeting.tags) {
        tagParticipation.putIfAbsent(tag, () => []);
        final tagged =
            activeCofrades.where((c) {
              final allTags = [...c.tagsManual, ...c.tagsAuto];
              return allTags.contains(tag);
            }).length;
        if (tagged > 0) {
          tagParticipation[tag]!.add(e.totalRespuestas / tagged);
        }
      }
    }
    final avgByTag = tagParticipation.map((tag, rates) {
      final avg = rates.fold<double>(0, (a, b) => a + b) / rates.length;
      return MapEntry(tag, avg);
    });

    return {
      'totalEncuestas': encuestas.length,
      'participacionMedia': avgRate,
      'masParticipacion': topId != null
          ? {
              'id': topId,
              'titulo':
                  encuestas.firstWhere((e) => e.id == topId).titulo,
              'rate': topRate,
            }
          : null,
      'menosParticipacion': bottomId != null
          ? {
              'id': bottomId,
              'titulo':
                  encuestas.firstWhere((e) => e.id == bottomId).titulo,
              'rate': bottomRate,
            }
          : null,
      'porTag': avgByTag,
    };
  }

  // ---------------------------------------------------------------------------
  // Tags (read from existing system)
  // ---------------------------------------------------------------------------

  Stream<List<TagConfig>> getAvailableTags() {
    return _db
        .collection('tags_config')
        .where('activo', isEqualTo: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => TagConfig.fromFirestore(d)).toList());
  }
}
