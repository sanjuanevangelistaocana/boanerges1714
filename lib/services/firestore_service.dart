import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boanerges1714/models/cofrade.dart';
import 'package:boanerges1714/models/evento.dart';
import 'package:boanerges1714/models/noticia.dart';
import 'package:boanerges1714/models/cuota.dart';
import 'package:boanerges1714/models/documento.dart';

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
    Query query = _db.collection('eventos').orderBy('fecha', descending: true);
    if (soloPublicados) {
      query = query.where('publicado', isEqualTo: true);
    }
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
    Query query = _db.collection('noticias').orderBy('fecha', descending: true);
    if (soloPublicadas) {
      query = query.where('publicado', isEqualTo: true);
    }
    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Noticia.fromFirestore(doc)).toList());
  }

  Stream<List<Noticia>> getUltimasNoticias({int limit = 3}) {
    return _db
        .collection('noticias')
        .where('publicado', isEqualTo: true)
        .orderBy('fecha', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Noticia.fromFirestore(doc)).toList());
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

  Future<void> deleteDocumento(String id) async {
    await _db.collection('documentos').doc(id).delete();
  }
}
