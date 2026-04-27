import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boanerges1714/models/cofrade.dart';
import 'package:boanerges1714/models/evento.dart';
import 'package:boanerges1714/models/noticia.dart';
import 'package:boanerges1714/models/cuota.dart';
import 'package:boanerges1714/models/documento.dart';
import 'package:boanerges1714/models/solicitud.dart';
import 'package:boanerges1714/models/convocatoria.dart';
import 'package:boanerges1714/models/sugerencia.dart';
import 'package:boanerges1714/models/proveedor.dart';
import 'package:boanerges1714/models/revista.dart';
import 'package:boanerges1714/models/loteria.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- Cofrades ---
  Stream<List<Cofrade>> getCofrades() {
    return _db
        .collection('cofrades')
        .orderBy('apellidos')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Cofrade.fromFirestore(doc)).toList());
  }

  Future<Cofrade?> getCofrade(String id) async {
    final doc = await _db.collection('cofrades').doc(id).get();
    if (doc.exists) {
      return Cofrade.fromFirestore(doc);
    }
    return null;
  }

  Future<void> updateCofrade(String id, Map<String, dynamic> data) async {
    data['fecha_actualizacion'] = FieldValue.serverTimestamp();
    // Skip null values to avoid accidentally deleting fields that were not
    // part of this edit.  Only include non-null entries so Firestore update()
    // only touches the fields the caller explicitly provided.
    final cleaned = <String, dynamic>{};
    for (final entry in data.entries) {
      if (entry.value != null) {
        cleaned[entry.key] = entry.value;
      }
    }
    debugPrint('[Firestore] updateCofrade($id): ${cleaned.keys.join(', ')}');
    await _db.collection('cofrades').doc(id).update(cleaned);
    debugPrint('[Firestore] updateCofrade($id): OK');
  }

  Future<void> deleteCofrade(String id) async {
    await _db.collection('cofrades').doc(id).delete();
  }

  // --- Eventos ---
  Stream<List<Evento>> getEventos({bool soloPublicados = true}) {
    Query query = _db.collection('eventos');
    if (soloPublicados) {
      query = query.where('publicado', isEqualTo: true);
    }
    query = query.orderBy('fecha', descending: true);
    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Evento.fromFirestore(doc)).toList());
  }

  Stream<List<Evento>> getProximosEventos() {
    return _db
        .collection('eventos')
        .where('publicado', isEqualTo: true)
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.now())
        .orderBy('fecha')
        .limit(5)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Evento.fromFirestore(doc)).toList());
  }

  Future<void> createEvento(Evento evento) async {
    final docRef = await _db.collection('eventos').add(evento.toFirestore());
    await crearNovedad(
      tipo: 'evento',
      titulo: evento.titulo,
      descripcion: 'Nuevo evento: ${evento.titulo}',
      referenciaId: docRef.id,
      ruta: '/events',
    );
  }

  Future<void> updateEvento(String id, Map<String, dynamic> data) async {
    await _db.collection('eventos').doc(id).update(data);
  }

  Future<void> deleteEvento(String id) async {
    await _db.collection('eventos').doc(id).delete();
  }

  // --- Noticias ---
  Stream<List<Noticia>> getNoticias({bool soloPublicadas = true}) {
    Query query = _db.collection('noticias');
    if (soloPublicadas) {
      query = query.where('publicado', isEqualTo: true);
    }
    query = query.orderBy('fecha', descending: true);
    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Noticia.fromFirestore(doc)).toList());
  }

  Stream<List<Noticia>> getUltimasNoticias({int limit = 3, bool incluirSoloCofrades = false}) {
    return _db
        .collection('noticias')
        .where('publicado', isEqualTo: true)
        .orderBy('fecha', descending: true)
        .limit(incluirSoloCofrades ? limit : limit + 10)
        .snapshots()
        .map((snapshot) {
          var noticias = snapshot.docs.map((doc) => Noticia.fromFirestore(doc)).toList();
          if (!incluirSoloCofrades) {
            noticias = noticias.where((n) => n.soloCofrades != true).toList();
          }
          return noticias.take(limit).toList();
        });
  }

  Future<void> createNoticia(Noticia noticia) async {
    await _db.collection('noticias').add(noticia.toFirestore());
  }

  Future<void> updateNoticia(String id, Map<String, dynamic> data) async {
    await _db.collection('noticias').doc(id).update(data);
  }

  Future<void> deleteNoticia(String id) async {
    await _db.collection('noticias').doc(id).delete();
  }

  // --- Cuotas ---
  Stream<List<Cuota>> getCuotasCofrade(String cofradeId) {
    return _db
        .collection('cuotas')
        .where('cofrade_id', isEqualTo: cofradeId)
        .orderBy('anio', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Cuota.fromFirestore(doc)).toList());
  }

  Stream<List<Cuota>> getAllCuotas() {
    return _db
        .collection('cuotas')
        .orderBy('anio', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Cuota.fromFirestore(doc)).toList());
  }

  Future<void> createCuota(Cuota cuota) async {
    await _db.collection('cuotas').add(cuota.toFirestore());
  }

  Future<void> updateCuota(String id, Map<String, dynamic> data) async {
    await _db.collection('cuotas').doc(id).update(data);
  }

  // --- Documentos ---
  Stream<List<Documento>> getDocumentos() {
    return _db
        .collection('documentos')
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Documento.fromFirestore(doc)).toList());
  }

  Future<void> createDocumento(Documento documento) async {
    await _db.collection('documentos').add(documento.toFirestore());
  }

  Future<void> updateDocumento(String id, Map<String, dynamic> data) async {
    await _db.collection('documentos').doc(id).update(data);
  }

  Future<void> deleteDocumento(String id) async {
    await _db.collection('documentos').doc(id).delete();
  }

  // --- Aggregated stats ---
  Future<int> getCofradesActivosCount() async {
    final snapshot = await _db
        .collection('cofrades')
        .where('estado', isEqualTo: 'Activo')
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  Future<int> getTotalCofradesCount() async {
    final snapshot = await _db.collection('cofrades').count().get();
    return snapshot.count ?? 0;
  }

  Stream<List<Cofrade>> getAllCofradesStream() {
    return _db
        .collection('cofrades')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Cofrade.fromFirestore(doc)).toList());
  }

  // --- Noticias privadas (solo cofrades) ---
  Stream<List<Noticia>> getNoticiasCofrades() {
    return _db
        .collection('noticias')
        .where('publicado', isEqualTo: true)
        .where('solo_cofrades', isEqualTo: true)
        .orderBy('fecha', descending: true)
        .limit(5)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Noticia.fromFirestore(doc)).toList());
  }

  // --- Solicitudes de alta ---
  Stream<List<Solicitud>> getSolicitudes({String? estado}) {
    Query query = _db
        .collection('solicitudes')
        .orderBy('fecha_solicitud', descending: true);
    if (estado != null) {
      query = query.where('estado', isEqualTo: estado);
    }
    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Solicitud.fromFirestore(doc)).toList());
  }

  Stream<List<Solicitud>> getSolicitudesPendientes() {
    return getSolicitudes(estado: 'pendiente');
  }

  Future<void> createSolicitud(Solicitud solicitud) async {
    await _db.collection('solicitudes').add(solicitud.toFirestore());
  }

  Future<void> aprobarSolicitud(String solicitudId, String aprobadaPor) async {
    final solicitudDoc =
        await _db.collection('solicitudes').doc(solicitudId).get();
    if (!solicitudDoc.exists) return;

    final solicitud = Solicitud.fromFirestore(solicitudDoc);

    await _db.collection('solicitudes').doc(solicitudId).update({
      'estado': 'aprobada',
      'aprobada_por': aprobadaPor,
      'fecha_resolucion': FieldValue.serverTimestamp(),
    });

    final lastNum = await _db
        .collection('cofrades')
        .orderBy('numero', descending: true)
        .limit(1)
        .get();
    final nextNum =
        lastNum.docs.isNotEmpty ? ((lastNum.docs.first.data()['numero'] ?? 0) + 1) : 1;

    await _db.collection('cofrades').add({
      'numero': nextNum,
      'nombre': solicitud.nombre,
      'apellidos': solicitud.apellidos,
      'email': solicitud.email,
      'telefono_movil': solicitud.telefono ?? '',
      'domicilio': solicitud.domicilio ?? '',
      'localidad': solicitud.localidad ?? '',
      'codigo_postal': solicitud.codigoPostal ?? '',
      'fecha_nacimiento': solicitud.fechaNacimiento != null
          ? Timestamp.fromDate(solicitud.fechaNacimiento!)
          : null,
      'dni': solicitud.dni ?? '',
      'estado': 'Activo',
      'anio_alta': DateTime.now().year,
      'genero': '',
      'tiene_cuota': false,
      'gdpr_firmado': false,
      'gdpr_firmado_digital': false,
      'notificaciones_activas': true,
      'tiene_tunica_propia': false,
      'rol': 'cofrade',
      'fecha_actualizacion': FieldValue.serverTimestamp(),
    });
  }

  Future<void> rechazarSolicitud(
      String solicitudId, String motivoRechazo) async {
    await _db.collection('solicitudes').doc(solicitudId).update({
      'estado': 'rechazada',
      'motivo_rechazo': motivoRechazo,
      'fecha_resolucion': FieldValue.serverTimestamp(),
    });
  }

  // --- Convocatorias ---
  Stream<List<Convocatoria>> getConvocatorias({bool soloActivas = false}) {
    Query query = _db
        .collection('convocatorias')
        .orderBy('fecha_evento', descending: true);
    if (soloActivas) {
      query = query.where('activa', isEqualTo: true);
    }
    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => Convocatoria.fromFirestore(doc))
        .toList());
  }

  Stream<List<Convocatoria>> getAllConvocatorias() {
    return _db
        .collection('convocatorias')
        .orderBy('fecha_evento', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Convocatoria.fromFirestore(doc))
            .toList());
  }

  Stream<List<Convocatoria>> getConvocatoriasActivas() {
    return _db
        .collection('convocatorias')
        .where('activa', isEqualTo: true)
        .orderBy('fecha_evento')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Convocatoria.fromFirestore(doc))
            .toList());
  }

  Future<void> createConvocatoria(Convocatoria convocatoria) async {
    final docRef = await _db.collection('convocatorias').add(convocatoria.toFirestore());
    await crearNovedad(
      tipo: 'convocatoria',
      titulo: convocatoria.titulo,
      descripcion: 'Nueva convocatoria: ${convocatoria.titulo}',
      referenciaId: docRef.id,
      ruta: '/convocatorias',
    );
  }

  Future<void> updateConvocatoria(
      String id, Map<String, dynamic> data) async {
    await _db.collection('convocatorias').doc(id).update(data);
  }

  Future<void> deleteConvocatoria(String id) async {
    await _db.collection('convocatorias').doc(id).delete();
  }

  // --- Respuestas a convocatorias ---
  Stream<List<RespuestaConvocatoria>> getRespuestas(String convocatoriaId) {
    return _db
        .collection('convocatorias')
        .doc(convocatoriaId)
        .collection('respuestas')
        .orderBy('fecha_respuesta', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RespuestaConvocatoria.fromFirestore(doc))
            .toList());
  }

  Future<RespuestaConvocatoria?> getMiRespuesta(
      String convocatoriaId, String cofradeId) async {
    final snapshot = await _db
        .collection('convocatorias')
        .doc(convocatoriaId)
        .collection('respuestas')
        .where('cofrade_id', isEqualTo: cofradeId)
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) {
      return RespuestaConvocatoria.fromFirestore(snapshot.docs.first);
    }
    return null;
  }

  // --- Evangelio del Día ---
  Stream<Map<String, dynamic>?> getEvangelioDelDia() {
    final hoy = DateTime.now();
    final fechaStr = '${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}';
    return _db
        .collection('evangelio_dia')
        .doc(fechaStr)
        .snapshots()
        .map((doc) => doc.exists ? doc.data() : null);
  }

  // --- Contacto ---
  Future<void> sendContactMessage({
    required String nombre,
    required String email,
    required String mensaje,
    String? telefono,
    String? asunto,
  }) async {
    await _db.collection('contacto').add({
      'nombre': nombre,
      'email': email,
      'mensaje': mensaje,
      'telefono': telefono ?? '',
      'asunto': asunto ?? '',
      'fecha': FieldValue.serverTimestamp(),
      'leido': false,
    });
  }

  // --- Sugerencias / Peticiones ---
  Stream<List<Sugerencia>> getSugerencias({String? cofradeId}) {
    Query query = _db.collection('sugerencias').orderBy('fecha', descending: true);
    if (cofradeId != null) {
      query = query.where('cofrade_id', isEqualTo: cofradeId);
    }
    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Sugerencia.fromFirestore(doc)).toList());
  }

  Stream<List<Sugerencia>> getSugerenciasPendientes() {
    return _db
        .collection('sugerencias')
        .where('estado', isEqualTo: 'pendiente')
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Sugerencia.fromFirestore(doc)).toList());
  }

  Future<void> createSugerencia(Sugerencia sugerencia) async {
    await _db.collection('sugerencias').add(sugerencia.toFirestore());
  }

  Future<void> responderSugerencia(String id, String respuesta) async {
    await _db.collection('sugerencias').doc(id).update({
      'estado': 'respondida',
      'respuesta_admin': respuesta,
      'fecha_respuesta': FieldValue.serverTimestamp(),
    });
  }

  Future<void> marcarSugerenciaLeida(String id) async {
    await _db.collection('sugerencias').doc(id).update({
      'estado': 'leida',
    });
  }

  Future<void> cerrarSugerencia(String id, String cerradaPor) async {
    await _db.collection('sugerencias').doc(id).update({
      'estado': 'cerrada',
      'cerrada_por': cerradaPor,
      'fecha_cierre': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<MensajeSugerencia>> getMensajesSugerencia(String sugerenciaId) {
    return _db
        .collection('sugerencias')
        .doc(sugerenciaId)
        .collection('mensajes')
        .orderBy('fecha')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MensajeSugerencia.fromFirestore(doc))
            .toList());
  }

  Future<void> enviarMensajeSugerencia({
    required String sugerenciaId,
    required String autor,
    required String autorNombre,
    required String mensaje,
  }) async {
    await _db
        .collection('sugerencias')
        .doc(sugerenciaId)
        .collection('mensajes')
        .add({
      'autor': autor,
      'autor_nombre': autorNombre,
      'mensaje': mensaje,
      'fecha': FieldValue.serverTimestamp(),
    });
    final nuevoEstado = autor == 'admin' ? 'respondida' : 'pendiente';
    final updateData = <String, dynamic>{'estado': nuevoEstado};
    if (autor == 'admin') {
      updateData['respuesta_admin'] = mensaje;
      updateData['fecha_respuesta'] = FieldValue.serverTimestamp();
    }
    await _db.collection('sugerencias').doc(sugerenciaId).update(updateData);
  }

  // --- Tablón de Anuncios ---
  Stream<List<Map<String, dynamic>>> getAnuncios({bool soloAprobados = false}) {
    Query query = _db.collection('tablon_anuncios').orderBy('fecha', descending: true);
    if (soloAprobados) {
      query = query.where('aprobado', isEqualTo: true);
    }
    return query.snapshots().map((snapshot) => snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList());
  }

  Future<void> crearAnuncio({
    required String cofradeId,
    required String cofradeNombre,
    required String titulo,
    required String mensaje,
    String? categoria,
  }) async {
    await _db.collection('tablon_anuncios').add({
      'cofrade_id': cofradeId,
      'cofrade_nombre': cofradeNombre,
      'titulo': titulo,
      'mensaje': mensaje,
      'categoria': categoria ?? 'general',
      'fecha': FieldValue.serverTimestamp(),
      'aprobado': false,
      'visible': true,
    });
  }

  Future<void> aprobarAnuncio(String id) async {
    await _db.collection('tablon_anuncios').doc(id).update({'aprobado': true});
    final doc = await _db.collection('tablon_anuncios').doc(id).get();
    final data = doc.data();
    await crearNovedad(
      tipo: 'anuncio',
      titulo: data?['titulo'] ?? 'Nuevo anuncio',
      descripcion: 'Nuevo anuncio en el tablón de la cofradía.',
      referenciaId: id,
      ruta: '/tablon',
    );
  }

  Future<void> rechazarAnuncio(String id) async {
    await _db.collection('tablon_anuncios').doc(id).update({'visible': false, 'aprobado': false});
  }

  Future<void> eliminarAnuncio(String id) async {
    await _db.collection('tablon_anuncios').doc(id).delete();
  }

  // --- Admin Badge Counts ---
  Future<int> getSolicitudesPendientesCount() async {
    final snapshot = await _db
        .collection('solicitudes')
        .where('estado', isEqualTo: 'pendiente')
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  Future<int> getSugerenciasPendientesCount() async {
    final snapshot = await _db
        .collection('sugerencias')
        .where('estado', isEqualTo: 'pendiente')
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  Future<int> getAnunciosPendientesCount() async {
    final snapshot = await _db
        .collection('tablon_anuncios')
        .where('aprobado', isEqualTo: false)
        .where('visible', isEqualTo: true)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  Stream<int> getSolicitudesPendientesCountStream() {
    return _db
        .collection('solicitudes')
        .where('estado', isEqualTo: 'pendiente')
        .snapshots()
        .map((s) => s.docs.length);
  }

  Stream<int> getSugerenciasPendientesCountStream() {
    return _db
        .collection('sugerencias')
        .where('estado', isEqualTo: 'pendiente')
        .snapshots()
        .map((s) => s.docs.length);
  }

  Stream<int> getAnunciosPendientesCountStream() {
    return _db
        .collection('tablon_anuncios')
        .where('aprobado', isEqualTo: false)
        .where('visible', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs.length);
  }

  // --- Proveedores Túnicas ---
  Stream<List<Proveedor>> getProveedores({bool soloActivos = false}) {
    Query query = _db.collection('proveedores_tunicas').orderBy('nombre');
    if (soloActivos) {
      query = query.where('activo', isEqualTo: true);
    }
    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Proveedor.fromFirestore(doc)).toList());
  }

  Future<void> createProveedor(Proveedor proveedor) async {
    final docRef = await _db.collection('proveedores_tunicas').add(proveedor.toFirestore());
    await crearNovedad(
      tipo: 'proveedor',
      titulo: proveedor.nombre,
      descripcion: 'Nuevo proveedor de túnicas: ${proveedor.nombre}',
      referenciaId: docRef.id,
      ruta: '/tunicas',
    );
  }

  Future<void> updateProveedor(String id, Map<String, dynamic> data) async {
    await _db.collection('proveedores_tunicas').doc(id).update(data);
  }

  Future<void> deleteProveedor(String id) async {
    await _db.collection('proveedores_tunicas').doc(id).delete();
  }

  // --- Revistas (Boanerges) ---
  Stream<List<Revista>> getRevistas() {
    return _db
        .collection('revistas')
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Revista.fromFirestore(doc)).toList());
  }

  Future<void> createRevista(Revista revista) async {
    await _db.collection('revistas').add(revista.toFirestore());
  }

  Future<void> updateRevista(String id, Map<String, dynamic> data) async {
    await _db.collection('revistas').doc(id).update(data);
  }

  Future<void> deleteRevista(String id) async {
    await _db.collection('revistas').doc(id).delete();
  }

  // --- Páginas estáticas (La Rosa, etc.) ---
  Stream<Map<String, dynamic>?> getPaginaEstatica(String slug) {
    return _db
        .collection('paginas_estaticas')
        .doc(slug)
        .snapshots()
        .map((doc) => doc.exists ? doc.data() : null);
  }

  Future<void> updatePaginaEstatica(String slug, Map<String, dynamic> data) async {
    await _db.collection('paginas_estaticas').doc(slug).set(data, SetOptions(merge: true));
  }

  // --- Novedades read tracking ---
  Future<Set<String>> getNovedadesLeidas(String cofradeId) async {
    final doc = await _db.collection('cofrades').doc(cofradeId)
        .collection('preferencias').doc('novedades_leidas').get();
    if (!doc.exists) return {};
    final data = doc.data();
    final list = data?['ids'] as List<dynamic>? ?? [];
    return list.map((e) => e.toString()).toSet();
  }

  Future<void> marcarNovedadLeida(String cofradeId, String novedadId) async {
    await _db.collection('cofrades').doc(cofradeId)
        .collection('preferencias').doc('novedades_leidas')
        .set({
      'ids': FieldValue.arrayUnion([novedadId]),
      'ultima_actualizacion': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> marcarTodasNovedadesLeidas(String cofradeId, List<String> ids) async {
    await _db.collection('cofrades').doc(cofradeId)
        .collection('preferencias').doc('novedades_leidas')
        .set({
      'ids': FieldValue.arrayUnion(ids),
      'ultima_actualizacion': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // --- Sugerencias con respuesta (para novedades) ---
  Stream<List<Sugerencia>> getSugerenciasRespondidas(String cofradeId) {
    return _db
        .collection('sugerencias')
        .where('cofrade_id', isEqualTo: cofradeId)
        .where('estado', isEqualTo: 'respondida')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Sugerencia.fromFirestore(doc)).toList());
  }

  // --- Banco de Túnicas ---
  Stream<List<Map<String, dynamic>>> getBancoTunicas({required String tipo}) {
    return _db
        .collection('banco_tunicas')
        .where('tipo', isEqualTo: tipo)
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  Future<void> crearOferta({
    required String cofradeId,
    required String nombrePublicador,
    required String telefonoPublicador,
    required List<String> elementos,
    required String talla,
    required Map<String, String> tallasPorElemento,
    required String estadoConservacion,
    required String observaciones,
    required String propiedad,
  }) async {
    await _db.collection('banco_tunicas').add({
      'tipo': 'oferta',
      'cofrade_id': cofradeId,
      'nombre_publicador': nombrePublicador,
      'telefono_publicador': telefonoPublicador,
      'elementos': elementos,
      'talla': talla,
      'tallas_por_elemento': tallasPorElemento,
      'estado_conservacion': estadoConservacion,
      'observaciones': observaciones,
      'propiedad': propiedad,
      'estado': 'disponible',
      'fecha': FieldValue.serverTimestamp(),
    });
    await crearNovedad(
      tipo: 'oferta',
      titulo: 'Nueva oferta de túnica',
      descripcion: 'Oferta de $nombrePublicador: ${elementos.join(", ")}',
      referenciaId: '${cofradeId}_oferta_${DateTime.now().millisecondsSinceEpoch}',
      ruta: '/banco-tunicas',
    );
  }

  Future<void> crearDemanda({
    required String cofradeId,
    required String nombreDemandante,
    required String telefonoDemandante,
    required List<String> elementos,
    required String talla,
    required Map<String, String> tallasPorElemento,
    required String observaciones,
  }) async {
    await _db.collection('banco_tunicas').add({
      'tipo': 'demanda',
      'cofrade_id': cofradeId,
      'nombre_demandante': nombreDemandante,
      'telefono_demandante': telefonoDemandante,
      'elementos': elementos,
      'talla': talla,
      'tallas_por_elemento': tallasPorElemento,
      'observaciones': observaciones,
      'estado': 'activa',
      'fecha': FieldValue.serverTimestamp(),
    });
    await crearNovedad(
      tipo: 'demanda',
      titulo: 'Nueva demanda de túnica',
      descripcion: 'Demanda de $nombreDemandante: ${elementos.join(", ")}',
      referenciaId: '${cofradeId}_demanda_${DateTime.now().millisecondsSinceEpoch}',
      ruta: '/banco-tunicas',
    );
  }

  Future<void> cambiarEstadoPublicacionBanco(String id, String nuevoEstado) async {
    await _db.collection('banco_tunicas').doc(id).update({'estado': nuevoEstado});
  }

  Future<void> eliminarPublicacionBanco(String id) async {
    await _db.collection('banco_tunicas').doc(id).delete();
  }

  Future<void> editarPublicacionBanco(String id, Map<String, dynamic> data) async {
    await _db.collection('banco_tunicas').doc(id).update(data);
  }

  Stream<List<Map<String, dynamic>>> getAllBancoTunicas() {
    return _db
        .collection('banco_tunicas')
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  Future<void> responderConvocatoria({
    required String convocatoriaId,
    required String cofradeId,
    required String cofradeNombre,
    required String respuesta,
    String? comentario,
  }) async {
    final existing = await _db
        .collection('convocatorias')
        .doc(convocatoriaId)
        .collection('respuestas')
        .where('cofrade_id', isEqualTo: cofradeId)
        .limit(1)
        .get();

    final data = {
      'cofrade_id': cofradeId,
      'cofrade_nombre': cofradeNombre,
      'respuesta': respuesta,
      'comentario': comentario,
      'fecha_respuesta': FieldValue.serverTimestamp(),
    };

    if (existing.docs.isNotEmpty) {
      await existing.docs.first.reference.update(data);
    } else {
      await _db
          .collection('convocatorias')
          .doc(convocatoriaId)
          .collection('respuestas')
          .add(data);
      await _db.collection('convocatorias').doc(convocatoriaId).update({
        'total_respuestas': FieldValue.increment(1),
      });
    }
  }

  // =============================================
  // --- Festividad San Juan Evangelista ---
  // =============================================

  // --- Ediciones del evento ---
  Stream<List<Map<String, dynamic>>> getFestividadEdiciones() {
    return _db
        .collection('festividad_sje')
        .orderBy('anio', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) {
              final data = d.data();
              data['id'] = d.id;
              return data;
            }).toList());
  }

  Future<Map<String, dynamic>?> getFestividadEdicionActiva() async {
    final snap = await _db
        .collection('festividad_sje')
        .where('estado', whereIn: ['abierto', 'cerrado'])
        .orderBy('anio', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final data = snap.docs.first.data();
    data['id'] = snap.docs.first.id;
    return data;
  }

  Stream<Map<String, dynamic>?> getFestividadEdicionActivaStream() {
    return _db
        .collection('festividad_sje')
        .orderBy('anio', descending: true)
        .limit(1)
        .snapshots()
        .map((s) {
      if (s.docs.isEmpty) return null;
      final data = s.docs.first.data();
      data['id'] = s.docs.first.id;
      return data;
    });
  }

  Future<Map<String, dynamic>?> getFestividadEdicion(String id) async {
    final doc = await _db.collection('festividad_sje').doc(id).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    data['id'] = doc.id;
    return data;
  }

  Future<String> createFestividadEdicion(Map<String, dynamic> data) async {
    data['created_at'] = FieldValue.serverTimestamp();
    data['updated_at'] = FieldValue.serverTimestamp();
    final ref = await _db.collection('festividad_sje').add(data);
    return ref.id;
  }

  Future<void> updateFestividadEdicion(String id, Map<String, dynamic> data) async {
    data['updated_at'] = FieldValue.serverTimestamp();
    await _db.collection('festividad_sje').doc(id).update(data);
  }

  // --- Menús de una edición ---
  Stream<List<Map<String, dynamic>>> getFestividadMenus(String edicionId) {
    return _db
        .collection('festividad_sje')
        .doc(edicionId)
        .collection('menus')
        .orderBy('orden')
        .snapshots()
        .map((s) => s.docs.map((d) {
              final data = d.data();
              data['id'] = d.id;
              return data;
            }).toList());
  }

  Future<String> createFestividadMenu(String edicionId, Map<String, dynamic> data) async {
    data['created_at'] = FieldValue.serverTimestamp();
    final ref = await _db
        .collection('festividad_sje')
        .doc(edicionId)
        .collection('menus')
        .add(data);
    return ref.id;
  }

  Future<void> updateFestividadMenu(String edicionId, String menuId, Map<String, dynamic> data) async {
    await _db
        .collection('festividad_sje')
        .doc(edicionId)
        .collection('menus')
        .doc(menuId)
        .update(data);
  }

  Future<void> deleteFestividadMenu(String edicionId, String menuId) async {
    await _db
        .collection('festividad_sje')
        .doc(edicionId)
        .collection('menus')
        .doc(menuId)
        .delete();
  }

  Future<bool> isMenuUsedInInscripciones(String edicionId, String menuId) async {
    final snap = await _db
        .collection('festividad_sje')
        .doc(edicionId)
        .collection('inscripciones')
        .limit(100)
        .get();
    for (final doc in snap.docs) {
      final asistentes = List<Map<String, dynamic>>.from(
          (doc.data()['asistentes'] as List<dynamic>?) ?? []);
      for (final a in asistentes) {
        if (a['menu_id'] == menuId) return true;
      }
    }
    return false;
  }

  // --- Inscripciones ---
  Stream<List<Map<String, dynamic>>> getFestividadInscripciones(String edicionId) {
    return _db
        .collection('festividad_sje')
        .doc(edicionId)
        .collection('inscripciones')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) {
              final data = d.data();
              data['id'] = d.id;
              return data;
            }).toList());
  }

  Future<Map<String, dynamic>?> getMiInscripcionFestividad(String edicionId, String cofradeId) async {
    final snap = await _db
        .collection('festividad_sje')
        .doc(edicionId)
        .collection('inscripciones')
        .where('cofrade_id', isEqualTo: cofradeId)
        .where('estado', whereIn: ['pendiente', 'confirmada'])
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final data = snap.docs.first.data();
    data['id'] = snap.docs.first.id;
    return data;
  }

  Future<bool> isCofradeInscritoFestividad(String edicionId, String cofradeId) async {
    final allInsc = await _db
        .collection('festividad_sje')
        .doc(edicionId)
        .collection('inscripciones')
        .where('estado', whereIn: ['pendiente', 'confirmada'])
        .get();
    for (final doc in allInsc.docs) {
      final asistentes = List<Map<String, dynamic>>.from(
          (doc.data()['asistentes'] as List<dynamic>?) ?? []);
      for (final a in asistentes) {
        if (a['cofrade_id'] == cofradeId) return true;
      }
    }
    return false;
  }

  Future<String> createFestividadInscripcion(String edicionId, Map<String, dynamic> data) async {
    data['created_at'] = FieldValue.serverTimestamp();
    data['updated_at'] = FieldValue.serverTimestamp();
    final ref = await _db
        .collection('festividad_sje')
        .doc(edicionId)
        .collection('inscripciones')
        .add(data);
    return ref.id;
  }

  Future<void> updateFestividadInscripcion(String edicionId, String inscId, Map<String, dynamic> data) async {
    data['updated_at'] = FieldValue.serverTimestamp();
    await _db
        .collection('festividad_sje')
        .doc(edicionId)
        .collection('inscripciones')
        .doc(inscId)
        .update(data);
  }

  Future<void> deleteFestividadInscripcion(String edicionId, String inscId) async {
    await _db
        .collection('festividad_sje')
        .doc(edicionId)
        .collection('inscripciones')
        .doc(inscId)
        .delete();
  }

  // =============================================
  // --- Novedades (centralized notification system) ---
  // =============================================

  Stream<List<Map<String, dynamic>>> getNovedades({int limit = 50}) {
    return _db
        .collection('novedades')
        .orderBy('fecha_creacion', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) {
              final data = d.data();
              data['id'] = d.id;
              return data;
            }).toList());
  }

  Future<void> crearNovedad({
    required String tipo,
    required String titulo,
    required String descripcion,
    required String referenciaId,
    String? ruta,
  }) async {
    // Prevent duplicate novedades for the same resource
    final existing = await _db
        .collection('novedades')
        .where('tipo', isEqualTo: tipo)
        .where('referencia_id', isEqualTo: referenciaId)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return;

    await _db.collection('novedades').add({
      'tipo': tipo,
      'titulo': titulo,
      'descripcion': descripcion,
      'referencia_id': referenciaId,
      'ruta': ruta ?? '',
      'fecha_creacion': FieldValue.serverTimestamp(),
      'visible_para': 'todos',
    });
  }

  // --- Lotería de Navidad ---

  // Campañas
  Stream<List<CampanaLoteria>> getCampanasLoteria() {
    return _db
        .collection('campanas_loteria')
        .orderBy('fecha_inicio', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => CampanaLoteria.fromFirestore(d)).toList());
  }

  Stream<CampanaLoteria?> getCampanaActiva() {
    return _db
        .collection('campanas_loteria')
        .where('estado', isEqualTo: 'activa')
        .limit(1)
        .snapshots()
        .map((s) => s.docs.isNotEmpty ? CampanaLoteria.fromFirestore(s.docs.first) : null);
  }

  Future<CampanaLoteria?> getCampanaById(String id) async {
    final doc = await _db.collection('campanas_loteria').doc(id).get();
    if (doc.exists) return CampanaLoteria.fromFirestore(doc);
    return null;
  }

  Future<String> createCampanaLoteria(CampanaLoteria campana) async {
    final docRef = await _db.collection('campanas_loteria').add(campana.toFirestore());
    return docRef.id;
  }

  Future<void> updateCampanaLoteria(String id, Map<String, dynamic> data) async {
    await _db.collection('campanas_loteria').doc(id).update(data);
  }

  Future<void> deleteCampanaLoteria(String id) async {
    await _db.collection('campanas_loteria').doc(id).delete();
  }

  // Sábanas
  Stream<List<Sabana>> getSabanas(String campanaId) {
    return _db
        .collection('sabanas')
        .where('campana_id', isEqualTo: campanaId)
        .snapshots()
        .map((s) => s.docs.map((d) => Sabana.fromFirestore(d)).toList());
  }

  Future<String> createSabana(Sabana sabana) async {
    final docRef = await _db.collection('sabanas').add(sabana.toFirestore());
    return docRef.id;
  }

  Future<void> updateSabana(String id, Map<String, dynamic> data) async {
    await _db.collection('sabanas').doc(id).update(data);
  }

  Future<void> deleteSabana(String id) async {
    await _db.collection('sabanas').doc(id).delete();
  }

  // Vendedores
  Stream<List<VendedorLoteria>> getVendedoresLoteria() {
    return _db
        .collection('vendedores_loteria')
        .orderBy('nombre')
        .snapshots()
        .map((s) => s.docs.map((d) => VendedorLoteria.fromFirestore(d)).toList());
  }

  Future<VendedorLoteria?> getVendedorById(String id) async {
    final doc = await _db.collection('vendedores_loteria').doc(id).get();
    if (doc.exists) return VendedorLoteria.fromFirestore(doc);
    return null;
  }

  Future<VendedorLoteria?> getVendedorByAuthUid(String authUid) async {
    final snap = await _db
        .collection('vendedores_loteria')
        .where('usuario_auth_id', isEqualTo: authUid)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) return VendedorLoteria.fromFirestore(snap.docs.first);
    return null;
  }

  Future<String> createVendedorLoteria(VendedorLoteria vendedor) async {
    final docRef = await _db.collection('vendedores_loteria').add(vendedor.toFirestore());
    return docRef.id;
  }

  Future<void> updateVendedorLoteria(String id, Map<String, dynamic> data) async {
    await _db.collection('vendedores_loteria').doc(id).update(data);
  }

  Future<void> deleteVendedorLoteria(String id) async {
    await _db.collection('vendedores_loteria').doc(id).delete();
  }

  // Asignaciones
  Stream<List<AsignacionLoteria>> getAsignaciones(String campanaId) {
    return _db
        .collection('asignaciones_loteria')
        .where('campana_id', isEqualTo: campanaId)
        .snapshots()
        .map((s) => s.docs.map((d) => AsignacionLoteria.fromFirestore(d)).toList());
  }

  Stream<List<AsignacionLoteria>> getAsignacionesVendedor(String vendedorId) {
    return _db
        .collection('asignaciones_loteria')
        .where('vendedor_id', isEqualTo: vendedorId)
        .snapshots()
        .map((s) => s.docs.map((d) => AsignacionLoteria.fromFirestore(d)).toList());
  }

  Future<AsignacionLoteria?> getAsignacionByToken(String token) async {
    final snap = await _db
        .collection('asignaciones_loteria')
        .where('token_acceso', isEqualTo: token)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) return AsignacionLoteria.fromFirestore(snap.docs.first);
    return null;
  }

  Future<String> createAsignacion(AsignacionLoteria asignacion) async {
    final docRef = await _db.collection('asignaciones_loteria').add(asignacion.toFirestore());
    // Update sabana estado to 'asignada'
    await _db.collection('sabanas').doc(asignacion.sabanaId).update({'estado': 'asignada'});
    return docRef.id;
  }

  Future<void> updateAsignacion(String id, Map<String, dynamic> data) async {
    data['ultima_actualizacion'] = FieldValue.serverTimestamp();
    await _db.collection('asignaciones_loteria').doc(id).update(data);
  }

  Future<void> actualizarVentasAsignacion(String id, int vendidos, int devueltos) async {
    await _db.collection('asignaciones_loteria').doc(id).update({
      'decimos_vendidos': vendidos,
      'decimos_devueltos': devueltos,
      'ultima_actualizacion': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteAsignacion(String id) async {
    // Get asignacion to restore sabana
    final doc = await _db.collection('asignaciones_loteria').doc(id).get();
    if (doc.exists) {
      final sabanaId = doc.data()?['sabana_id'] as String?;
      if (sabanaId != null) {
        await _db.collection('sabanas').doc(sabanaId).update({'estado': 'disponible'});
      }
    }
    await _db.collection('asignaciones_loteria').doc(id).delete();
  }

  // Search cofrades for autocomplete
  Future<List<Cofrade>> searchCofrades(String query) async {
    final trimmed = query.trim().toLowerCase();
    debugPrint('[Firestore] searchCofrades("$query")');
    // Fetch all cofrades and filter client-side for case-insensitive matching
    // (handles both 'Activo' and 'activo' estado values).
    final snap = await _db
        .collection('cofrades')
        .orderBy('apellidos')
        .get();
    final all = snap.docs
        .map((d) => Cofrade.fromFirestore(d))
        .where((c) => c.isActivo)
        .toList();
    debugPrint('[Firestore] searchCofrades: ${all.length} active cofrades found');
    if (trimmed.isEmpty) return all;
    return all
        .where((c) =>
            c.nombre.toLowerCase().contains(trimmed) ||
            c.apellidos.toLowerCase().contains(trimmed) ||
            c.nombreCompleto.toLowerCase().contains(trimmed))
        .toList();
  }
}
