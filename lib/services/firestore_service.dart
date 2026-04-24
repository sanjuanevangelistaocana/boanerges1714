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
    await _db.collection('cofrades').doc(id).update(data);
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
    await _db.collection('eventos').add(evento.toFirestore());
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
    await _db.collection('convocatorias').add(convocatoria.toFirestore());
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
    await _db.collection('proveedores_tunicas').add(proveedor.toFirestore());
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
}
