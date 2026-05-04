import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boanerges1714/models/cofrade.dart';
import 'package:boanerges1714/models/cofradia_event.dart';

class EventsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _campaigns =>
      _db.collection('event_campaigns');
  CollectionReference<Map<String, dynamic>> get _registrations =>
      _db.collection('event_registrations');

  Stream<List<EventCampaign>> watchCampaigns({String? type}) {
    Query<Map<String, dynamic>> query =
        _campaigns.orderBy('year', descending: true);
    if (type != null) query = query.where('type', isEqualTo: type);
    return query.snapshots().map(
        (s) => s.docs.map((doc) => EventCampaign.fromFirestore(doc)).toList());
  }

  Stream<EventCampaign?> watchActiveCampaign(String type) {
    return _campaigns
        .where('type', isEqualTo: type)
        .where('active', isEqualTo: true)
        .limit(1)
        .snapshots()
        .map((s) =>
            s.docs.isEmpty ? null : EventCampaign.fromFirestore(s.docs.first));
  }

  Future<void> saveCampaign(EventCampaign campaign) async {
    final ref =
        campaign.id.isEmpty ? _campaigns.doc() : _campaigns.doc(campaign.id);
    await ref.set(campaign.toFirestore(), SetOptions(merge: true));
    if (campaign.active) {
      await _createNovedad(
        tipo: 'evento',
        titulo: 'Inscripciones abiertas: ${campaign.name}',
        descripcion: campaign.type == 'andas'
            ? 'Ya puedes apuntarte a los turnos de andas y confirmar tu altura.'
            : 'Ya puedes realizar tu inscripción.',
        referenciaId: 'event_campaign_open_${ref.id}',
        ruta: '/eventos',
        visiblePara: 'cofrade',
      );
    }
  }

  Future<void> deleteCampaign(String id) async {
    final regs =
        await _registrations.where('campaignId', isEqualTo: id).limit(1).get();
    if (regs.docs.isNotEmpty) {
      throw Exception('No se puede eliminar una campaña con inscripciones.');
    }
    await _campaigns.doc(id).delete();
  }

  Stream<List<EventRegistration>> watchRegistrations(String campaignId) {
    return _registrations
        .where('campaignId', isEqualTo: campaignId)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => EventRegistration.fromFirestore(d)).toList()
              ..sort((a, b) {
                final height = (a.heightCm ?? 999).compareTo(b.heightCm ?? 999);
                if (height != 0) return height;
                return (a.position ?? 999).compareTo(b.position ?? 999);
              }));
  }

  Stream<List<EventRegistration>> watchMyRegistrations(String cofradeId) {
    return _registrations
        .where('cofradeId', isEqualTo: cofradeId)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => EventRegistration.fromFirestore(d)).toList()
              ..sort((a, b) => b.year.compareTo(a.year)));
  }

  Future<EventRegistration?> getRegistrationForCofrade({
    required String campaignId,
    required String cofradeId,
  }) async {
    final snap = await _registrations
        .where('campaignId', isEqualTo: campaignId)
        .where('cofradeId', isEqualTo: cofradeId)
        .limit(1)
        .get();
    return snap.docs.isEmpty
        ? null
        : EventRegistration.fromFirestore(snap.docs.first);
  }

  Future<void> registerCofrade({
    required EventCampaign campaign,
    required Cofrade cofrade,
    required Cofrade addedBy,
    int? heightCm,
    String status = 'solicitada',
  }) async {
    final existing = await getRegistrationForCofrade(
      campaignId: campaign.id,
      cofradeId: cofrade.id,
    );
    if (existing != null) {
      throw Exception('${cofrade.nombreCompleto} ya figura en esta campaña.');
    }
    final ref = _registrations.doc();
    await ref.set({
      'campaignId': campaign.id,
      'type': campaign.type,
      'year': campaign.year,
      'cofradeId': cofrade.id,
      'cofradeName': cofrade.nombreCompleto,
      'addedById': addedBy.id,
      'addedByName': addedBy.nombreCompleto,
      'status': status,
      'heightCm': heightCm,
      'role': 'titular',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (campaign.type == 'andas' && heightCm != null) {
      await _db.collection('cofrades').doc(cofrade.id).update({
        'estatura': heightCm,
        'fecha_actualizacion': FieldValue.serverTimestamp(),
      });
    }
    await _createNovedad(
      tipo: 'evento',
      titulo: campaign.type == 'andas'
          ? 'Inscripción en turnos de andas'
          : 'Inscripción en ${campaign.name}',
      descripcion: addedBy.id == cofrade.id
          ? 'Tu inscripción ha quedado registrada.'
          : '${addedBy.nombreCompleto} te ha añadido a esta inscripción.',
      referenciaId: 'event_registration_${ref.id}_${cofrade.id}',
      ruta: '/eventos',
      visiblePara: 'cofrade',
      cofradeId: cofrade.id,
    );
  }

  Future<void> updateRegistration(
    String registrationId,
    Map<String, dynamic> data,
  ) async {
    await _registrations.doc(registrationId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> publishCampaignResults(EventCampaign campaign) async {
    final regs =
        await _registrations.where('campaignId', isEqualTo: campaign.id).get();
    for (final doc in regs.docs) {
      final reg = EventRegistration.fromFirestore(doc);
      await _createNovedad(
        tipo: 'evento',
        titulo: 'Resultados publicados: ${campaign.name}',
        descripcion: campaign.type == 'andas'
            ? 'Ya puedes consultar tu turno y si eres titular o reserva.'
            : 'Ya puedes consultar el estado actualizado de tu inscripción.',
        referenciaId: 'event_results_${campaign.id}_${reg.cofradeId}',
        ruta: '/eventos',
        visiblePara: 'cofrade',
        cofradeId: reg.cofradeId,
      );
    }
    await _campaigns.doc(campaign.id).update({
      'published': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _createNovedad({
    required String tipo,
    required String titulo,
    required String descripcion,
    required String referenciaId,
    required String ruta,
    String visiblePara = 'todos',
    String? cofradeId,
  }) async {
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
      'ruta': ruta,
      'fecha_creacion': FieldValue.serverTimestamp(),
      'visible_para': visiblePara,
      'cofrade_id': cofradeId,
      'prioridad':
          ['festividad', 'palmas', 'andas'].contains(tipo) ? 'alta' : 'normal',
    });
  }
}
