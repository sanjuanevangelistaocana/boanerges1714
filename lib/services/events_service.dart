import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boanerges1714/models/cofrade.dart';
import 'package:boanerges1714/models/cofradia_event.dart';

class EventTypeDefinition {
  final String type;
  final String title;
  final String shortTitle;
  final String description;
  final bool legacyFestividad;
  final Map<String, dynamic> defaults;

  const EventTypeDefinition({
    required this.type,
    required this.title,
    required this.shortTitle,
    required this.description,
    this.legacyFestividad = false,
    this.defaults = const {},
  });
}

class EventsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _campaigns =>
      _db.collection('event_campaigns');
  CollectionReference<Map<String, dynamic>> get _registrations =>
      _db.collection('event_registrations');

  static const List<EventTypeDefinition> eventTypes = [
    EventTypeDefinition(
      type: 'festividad_27_diciembre',
      title: 'Festividad 27 de diciembre',
      shortTitle: 'Festividad',
      description:
          'Ediciones, menús, acompañantes, pagos e inscripciones de la Festividad.',
      legacyFestividad: true,
    ),
    EventTypeDefinition(
      type: 'palmas',
      title: 'Petición de Palmas',
      shortTitle: 'Palmas',
      description:
          'Campaña anual para solicitar palmas y añadir otros cofrades sin duplicidades.',
      defaults: {
        'allowOtherCofrades': true,
        'allowExternalGuests': false,
        'requiresPayment': false,
        'freeEvent': true,
      },
    ),
    EventTypeDefinition(
      type: 'sanjuandereta',
      title: 'SanJuandereta',
      shortTitle: 'SanJuandereta',
      description:
          'Evento anual configurable con inscripción, pagos, acompañantes y campos propios.',
      defaults: {
        'allowCompanions': true,
        'allowExternalGuests': true,
        'requiresPayment': false,
        'freeEvent': true,
      },
    ),
    EventTypeDefinition(
      type: 'junta_general_ordinaria',
      title: 'Junta General Ordinaria',
      shortTitle: 'Junta General',
      description:
          'Convocatoria anual con control de asistencia, histórico y documentación preparada.',
      defaults: {
        'allowCompanions': false,
        'allowExternalGuests': false,
        'requiresPayment': false,
        'freeEvent': true,
      },
    ),
    EventTypeDefinition(
      type: 'general',
      title: 'Otros eventos',
      shortTitle: 'Otros eventos',
      description:
          'Eventos puntuales con el mismo motor de inscripciones, pagos, plazas y banners.',
      defaults: {
        'allowCompanions': true,
        'allowExternalGuests': true,
        'requiresPayment': false,
        'freeEvent': true,
      },
    ),
  ];

  static EventTypeDefinition definitionFor(String type) {
    return eventTypes.firstWhere(
      (definition) => definition.type == type,
      orElse: () => eventTypes.last,
    );
  }

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
    await _createAuditLog(
      action: campaign.id.isEmpty
          ? 'event_campaign_created'
          : 'event_campaign_updated',
      targetId: ref.id,
      targetType: 'event_campaign',
      changedBy: 'system',
      metadata: {
        'type': campaign.type,
        'year': campaign.year,
        'status': campaign.status,
      },
    );
    if (campaign.active && campaign.showBanner) {
      await _createNovedad(
        tipo: 'evento',
        titulo: 'Inscripciones abiertas: ${campaign.name}',
        descripcion: campaign.bannerText.trim().isNotEmpty
            ? campaign.bannerText.trim()
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
    await _createAuditLog(
      action: 'event_campaign_deleted',
      targetId: id,
      targetType: 'event_campaign',
      changedBy: 'system',
    );
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
    return _registrations.snapshots().map((s) {
      final regs = s.docs
          .map((d) => EventRegistration.fromFirestore(d))
          .where((registration) => _registrationIncludesCofrade(
                registration,
                cofradeId,
              ))
          .toList()
        ..sort((a, b) => b.year.compareTo(a.year));
      return regs;
    });
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

  Future<EventRegistration?> getRegistrationIncludingCofrade({
    required String campaignId,
    required String cofradeId,
  }) async {
    final snap =
        await _registrations.where('campaignId', isEqualTo: campaignId).get();
    for (final doc in snap.docs) {
      final registration = EventRegistration.fromFirestore(doc);
      if (_registrationIncludesCofrade(registration, cofradeId)) {
        return registration;
      }
    }
    return null;
  }

  bool _registrationIncludesCofrade(
    EventRegistration registration,
    String cofradeId,
  ) {
    if (registration.cofradeId == cofradeId) return true;
    return registration.participants.any((participant) =>
        participant['type'] == 'cofrade' &&
        participant['cofradeId'] == cofradeId);
  }

  Future<void> registerCofrade({
    required EventCampaign campaign,
    required Cofrade cofrade,
    required Cofrade addedBy,
    int? heightCm,
    String status = 'solicitada',
  }) async {
    final existing = await getRegistrationIncludingCofrade(
      campaignId: campaign.id,
      cofradeId: cofrade.id,
    );
    if (existing != null) {
      throw Exception('${cofrade.nombreCompleto} ya figura en esta campaña.');
    }
    final ref = _registrations.doc();
    final price = campaign.requiresPayment ? campaign.memberPrice : 0.0;
    await ref.set({
      'campaignId': campaign.id,
      'type': campaign.type,
      'eventType': campaign.type,
      'year': campaign.year,
      'cofradeId': cofrade.id,
      'cofradeName': cofrade.nombreCompleto,
      'createdByCofradeId': addedBy.id,
      'mainCofradeId': cofrade.id,
      'addedById': addedBy.id,
      'addedByName': addedBy.nombreCompleto,
      'status': status,
      'heightCm': heightCm,
      'role': 'titular',
      'paymentStatus': campaign.requiresPayment ? 'pending' : 'not_required',
      'totalAmount': price,
      'answers': <String, dynamic>{},
      'participants': [
        {
          'type': 'cofrade',
          'cofradeId': cofrade.id,
          'name': cofrade.nombreCompleto,
          'price': price,
          'paymentStatus':
              campaign.requiresPayment ? 'pending' : 'not_required',
          'metadata': {
            if (heightCm != null) 'heightCm': heightCm,
            'addedById': addedBy.id,
          },
        }
      ],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _createAuditLog(
      action: 'event_registration_created',
      targetId: cofrade.id,
      targetType: 'cofrade',
      changedBy: cofrade.id,
      metadata: {
        'campaignId': campaign.id,
        'registrationId': ref.id,
        'eventType': campaign.type,
        'addedById': addedBy.id,
      },
    );
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
    await _createAuditLog(
      action: 'event_registration_updated',
      targetId: registrationId,
      targetType: 'event_registration',
      changedBy: 'system',
      metadata: data,
    );
  }

  Future<void> markRegistrationPaid(String registrationId, bool paid) async {
    await updateRegistration(registrationId, {
      'paymentStatus': paid ? 'paid' : 'pending',
      'payment_status': paid ? 'pagado' : 'pendiente',
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
    await _createAuditLog(
      action: 'event_results_published',
      targetId: campaign.id,
      targetType: 'event_campaign',
      changedBy: 'system',
      metadata: {'type': campaign.type, 'year': campaign.year},
    );
  }

  Future<void> _createAuditLog({
    required String action,
    required String targetId,
    required String targetType,
    required String changedBy,
    Map<String, dynamic>? metadata,
  }) async {
    await _db.collection('audit_logs').add({
      'action': action,
      'target_id': targetId,
      'target_type': targetType,
      'changed_by': changedBy,
      'changed_at': FieldValue.serverTimestamp(),
      'metadata': metadata ?? const <String, dynamic>{},
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
      'prioridad': [
        'festividad',
        'festividad_27_diciembre',
        'palmas',
        'sanjuandereta',
        'junta_general_ordinaria'
      ].contains(tipo)
          ? 'alta'
          : 'normal',
    });
  }
}
