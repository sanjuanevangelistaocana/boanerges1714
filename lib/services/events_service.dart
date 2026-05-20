import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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

  double _memberBasePrice(EventCampaign campaign) => campaign.type == 'palmas'
      ? campaign.palmMemberPrice
      : campaign.memberPrice;

  double _externalBasePrice(EventCampaign campaign) => campaign.type == 'palmas'
      ? campaign.palmExternalPrice
      : campaign.guestPrice;

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
        'requiresRegistration': true,
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
    return _campaigns.snapshots().map((s) {
      final campaigns = s.docs
          .map((doc) => EventCampaign.fromFirestore(doc))
          .where((campaign) => type == null || campaign.type == type)
          .toList()
        ..sort(_campaignPrioritySort);
      return campaigns;
    });
  }

  Stream<List<Map<String, dynamic>>> watchAttachments(String campaignId) {
    return _campaigns
        .doc(campaignId)
        .collection('attachments')
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  Stream<List<EventCampaign>> watchPopupCandidates(String cofradeId) {
    return _campaigns.snapshots().asyncMap((s) async {
      final campaigns = s.docs
          .map((doc) => EventCampaign.fromFirestore(doc))
          .where((campaign) {
        final popup = campaign.popupConfig;
        final isJunta = campaign.type == 'junta_general_ordinaria';
        if (campaign.deleted || (!isJunta && popup['enabled'] != true)) {
          return false;
        }
        if (!campaign.isVisibleToCofrade) return false;
        if (campaign.eventDate != null) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final eventDay = DateTime(campaign.eventDate!.year,
              campaign.eventDate!.month, campaign.eventDate!.day);
          if (today.isAfter(eventDay)) return false;
        }
        final now = DateTime.now();
        final startsAt = _dateFromAny(popup['startsAt']);
        final endsAt = _dateFromAny(popup['endsAt']);
        if (startsAt != null && now.isBefore(startsAt)) return false;
        if (endsAt != null && now.isAfter(endsAt)) return false;
        return true;
      }).toList();
      final visible = <EventCampaign>[];
      for (final campaign in campaigns) {
        final target = '${campaign.popupConfig['target'] ?? 'todos'}';
        if (target != 'todos') {
          final registration = await getRegistrationIncludingCofrade(
            campaignId: campaign.id,
            cofradeId: cofradeId,
          );
          final hasRegistration = campaign.type == 'junta_general_ordinaria'
              ? await getRegistrationForCofrade(
                    campaignId: campaign.id,
                    cofradeId: cofradeId,
                  ) !=
                  null
              : registration != null;
          if (target == 'no_inscritos' && hasRegistration) continue;
          if (target == 'inscritos' && !hasRegistration) continue;
          if (target == 'no_respondidos' && hasRegistration) continue;
        }
        final juntaNeedsAction = campaign.type == 'junta_general_ordinaria' &&
            await _juntaNeedsPopupAction(campaign.id, cofradeId);
        if (campaign.popupConfig['enabled'] != true && !juntaNeedsAction) {
          continue;
        }
        final seen = await _campaigns
            .doc(campaign.id)
            .collection('popup_views')
            .doc(cofradeId)
            .get();
        final repeat = campaign.popupConfig['repeatUntilAction'] == true;
        if (juntaNeedsAction ||
            !seen.exists ||
            repeat && seen.data()?['actionTaken'] != true) {
          visible.add(campaign);
        }
      }
      visible.sort(_campaignPrioritySort);
      return visible;
    });
  }

  Stream<int> watchPendingActionCount(String cofradeId) {
    return _campaigns.snapshots().asyncMap((snapshot) async {
      var count = 0;
      final campaigns = snapshot.docs
          .map((doc) => EventCampaign.fromFirestore(doc))
          .where((campaign) =>
              !campaign.deleted &&
              campaign.status != 'archived' &&
              campaign.isVisibleToCofrade)
          .toList();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      for (final campaign in campaigns) {
        if (campaign.eventDate != null) {
          final eventDay = DateTime(campaign.eventDate!.year,
              campaign.eventDate!.month, campaign.eventDate!.day);
          if (today.isAfter(eventDay)) continue;
        }
        if (campaign.type == 'junta_general_ordinaria') {
          if (await _juntaNeedsPopupAction(campaign.id, cofradeId)) {
            count++;
          }
          continue;
        }
        if (!campaign.isOpen) continue;
        final registration = await getRegistrationIncludingCofrade(
          campaignId: campaign.id,
          cofradeId: cofradeId,
        );
        if (registration == null) count++;
      }
      return count;
    });
  }

  Future<bool> _juntaNeedsPopupAction(
    String campaignId,
    String cofradeId,
  ) async {
    final own = await getRegistrationForCofrade(
      campaignId: campaignId,
      cofradeId: cofradeId,
    );
    if (own == null) return true;
    final regs =
        await _registrations.where('campaignId', isEqualTo: campaignId).get();
    for (final doc in regs.docs) {
      final votes = doc.data()['delegatedVotes'];
      if (votes is Iterable &&
          votes.whereType<Map>().any((vote) =>
              '${vote['delegatingCofradeId'] ?? ''}' == cofradeId &&
              '${vote['status'] ?? 'requested'}' == 'requested')) {
        return true;
      }
    }
    return false;
  }

  Stream<EventCampaign?> watchActiveCampaign(String type) {
    return _campaigns.snapshots().map((s) {
      final campaigns = s.docs
          .map((doc) => EventCampaign.fromFirestore(doc))
          .where((campaign) =>
              campaign.type == type &&
              !campaign.deleted &&
              campaign.status != 'archived')
          .toList();
      campaigns.sort(_campaignPrioritySort);
      return campaigns.isEmpty ? null : campaigns.first;
    });
  }

  Stream<List<EventCampaign>> watchVisibleCampaigns(String type) {
    return _campaigns.snapshots().map((s) {
      final campaigns = s.docs
          .map((doc) => EventCampaign.fromFirestore(doc))
          .where((campaign) =>
              campaign.type == type &&
              !campaign.deleted &&
              campaign.status != 'archived' &&
              (campaign.isVisibleToCofrade || campaign.status == 'finished'))
          .toList();
      campaigns.sort(_campaignPrioritySort);
      return campaigns;
    });
  }

  static String routeForCampaign(EventCampaign campaign) {
    return '/eventos?type=${Uri.encodeComponent(campaign.type)}&campaignId=${Uri.encodeComponent(campaign.id)}';
  }

  int _campaignPrioritySort(EventCampaign a, EventCampaign b) {
    final p = _campaignPriority(a).compareTo(_campaignPriority(b));
    if (p != 0) return p;
    final year = b.year.compareTo(a.year);
    if (year != 0) return year;
    final aDate = a.eventDate ?? a.startDate ?? DateTime(1900);
    final bDate = b.eventDate ?? b.startDate ?? DateTime(1900);
    return bDate.compareTo(aDate);
  }

  int _campaignPriority(EventCampaign campaign) {
    if (campaign.isOpen) return 0;
    if (campaign.status == 'published' || campaign.active) return 1;
    if (campaign.status == 'closed') return 3;
    if (campaign.status == 'finished') return 4;
    if (campaign.status == 'archived') return 5;
    return 2;
  }

  Future<void> saveCampaign(EventCampaign campaign) async {
    final ref =
        campaign.id.isEmpty ? _campaigns.doc() : _campaigns.doc(campaign.id);
    final isNew = campaign.id.isEmpty;
    final previous = isNew ? null : (await ref.get()).data();
    final previousMenus = previous?['menus'];
    final previousFields = previous?['customFields'];
    final payload = campaign.toFirestore();
    debugPrint('[EventsService] Saving event campaign payload: $payload');
    await ref.set(payload, SetOptions(merge: true));
    try {
      await _createAuditLog(
        action: isNew ? 'event_campaign_created' : 'event_campaign_updated',
        targetId: ref.id,
        targetType: 'event_campaign',
        changedBy: 'system',
        metadata: {
          'type': campaign.type,
          'year': campaign.year,
          'status': campaign.status,
          'menusCount': campaign.menus.length,
          'customFieldsCount': campaign.customFields.length,
        },
      );
      if (isNew && campaign.menus.isNotEmpty) {
        await _createAuditLog(
          action: 'event_menus_config_created',
          targetId: ref.id,
          targetType: 'event_campaign',
          changedBy: 'system',
          metadata: {'menus': campaign.menus},
        );
      } else if (!isNew && '$previousMenus' != '${campaign.menus}') {
        await _createAuditLog(
          action: 'event_menus_config_updated',
          targetId: ref.id,
          targetType: 'event_campaign',
          changedBy: 'system',
          metadata: {
            'oldValue': previousMenus,
            'newValue': campaign.menus,
          },
        );
      }
      if (isNew && campaign.customFields.isNotEmpty) {
        await _createAuditLog(
          action: 'event_custom_fields_config_created',
          targetId: ref.id,
          targetType: 'event_campaign',
          changedBy: 'system',
          metadata: {'customFields': campaign.customFields},
        );
      } else if (!isNew && '$previousFields' != '${campaign.customFields}') {
        await _createAuditLog(
          action: 'event_custom_fields_config_updated',
          targetId: ref.id,
          targetType: 'event_campaign',
          changedBy: 'system',
          metadata: {
            'oldValue': previousFields,
            'newValue': campaign.customFields,
          },
        );
      }
    } catch (e, st) {
      debugPrint('[EventsService] Audit log after event save failed: $e\n$st');
    }
    if (campaign.showBanner &&
        (campaign.active ||
            campaign.published ||
            campaign.status == 'open' ||
            campaign.status == 'published')) {
      try {
        await _createNovedad(
          tipo: 'evento',
          titulo: 'Inscripciones abiertas: ${campaign.name}',
          descripcion: campaign.bannerText.trim().isNotEmpty
              ? campaign.bannerText.trim()
              : 'Ya puedes realizar tu inscripción.',
          referenciaId: 'event_campaign_open_${ref.id}',
          ruta: routeForCampaign(EventCampaign(
            id: ref.id,
            type: campaign.type,
            year: campaign.year,
            name: campaign.name,
          )),
          visiblePara: 'cofrade',
        );
      } catch (e, st) {
        debugPrint('[EventsService] Novelty after event save failed: $e\n$st');
      }
    }
  }

  Future<void> deleteCampaign(
    EventCampaign campaign, {
    required String reason,
    String changedBy = 'system',
  }) async {
    final ref = _campaigns.doc(campaign.id);
    final regs =
        await _registrations.where('campaignId', isEqualTo: campaign.id).get();
    final attachments = await ref.collection('attachments').limit(1).get();
    final hasActivity = regs.docs.isNotEmpty || attachments.docs.isNotEmpty;
    if (hasActivity) {
      await ref.update({
        'status': 'archived',
        'active': false,
        'published': false,
        'deleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedBy': changedBy,
        'deleteReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.delete();
    }
    await _createAuditLog(
      action: hasActivity
          ? 'event_campaign_logically_deleted'
          : 'event_campaign_deleted',
      targetId: campaign.id,
      targetType: 'event_campaign',
      changedBy: changedBy,
      metadata: {
        'type': campaign.type,
        'reason': reason,
        'hadActivity': hasActivity,
      },
    );
  }

  Future<void> addAttachment({
    required String campaignId,
    required Map<String, dynamic> metadata,
  }) async {
    await _campaigns.doc(campaignId).collection('attachments').add({
      ...metadata,
      'uploadedAt': FieldValue.serverTimestamp(),
      'status': 'active',
    });
    await _createAuditLog(
      action: 'event_attachment_uploaded',
      targetId: campaignId,
      targetType: 'event_campaign',
      changedBy: '${metadata['uploadedBy'] ?? 'system'}',
      metadata: metadata,
    );
  }

  Future<void> deleteAttachment({
    required String campaignId,
    required String attachmentId,
    String changedBy = 'system',
  }) async {
    await _campaigns
        .doc(campaignId)
        .collection('attachments')
        .doc(attachmentId)
        .update({
      'status': 'deleted',
      'deletedAt': FieldValue.serverTimestamp(),
      'deletedBy': changedBy,
    });
    await _createAuditLog(
      action: 'event_attachment_deleted',
      targetId: campaignId,
      targetType: 'event_campaign',
      changedBy: changedBy,
      metadata: {'attachmentId': attachmentId},
    );
  }

  Future<void> updateCoverImage({
    required String campaignId,
    required String storagePath,
    required String url,
    String changedBy = 'system',
  }) async {
    await _campaigns.doc(campaignId).update({
      'coverImagePath': storagePath,
      'coverImageUrl': url,
      'coverImageUpdatedAt': FieldValue.serverTimestamp(),
      'coverImageUpdatedBy': changedBy,
    });
    await _createAuditLog(
      action: 'event_cover_image_updated',
      targetId: campaignId,
      targetType: 'event_campaign',
      changedBy: changedBy,
      metadata: {'storagePath': storagePath},
    );
  }

  Future<void> clearCoverImage({
    required String campaignId,
    String changedBy = 'system',
  }) async {
    await _campaigns.doc(campaignId).update({
      'coverImagePath': '',
      'coverImageUrl': '',
      'coverImageUpdatedAt': FieldValue.serverTimestamp(),
      'coverImageUpdatedBy': changedBy,
    });
    await _createAuditLog(
      action: 'event_cover_image_deleted',
      targetId: campaignId,
      targetType: 'event_campaign',
      changedBy: changedBy,
    );
  }

  Future<void> markPopupSeen({
    required String campaignId,
    required String cofradeId,
    bool actionTaken = false,
  }) async {
    await _campaigns
        .doc(campaignId)
        .collection('popup_views')
        .doc(cofradeId)
        .set({
      'cofradeId': cofradeId,
      'seenAt': FieldValue.serverTimestamp(),
      'lastSeenAt': FieldValue.serverTimestamp(),
      'actionTaken': actionTaken,
      if (actionTaken) 'actionAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  DateTime? _dateFromAny(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
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

  Stream<List<EventRegistration>> watchRegistrationsByType(String type) {
    return _registrations.snapshots().map((s) {
      final regs = s.docs
          .map((d) => EventRegistration.fromFirestore(d))
          .where(
              (registration) => type == '__all__' || registration.type == type)
          .toList();
      return regs;
    });
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
    if (registration.participants.any((participant) =>
        participant['type'] == 'cofrade' &&
        participant['cofradeId'] == cofradeId)) {
      return true;
    }
    return registration.delegatedVotes.any((vote) =>
        '${vote['delegatingCofradeId'] ?? ''}' == cofradeId ||
        '${vote['delegatedToCofradeId'] ?? ''}' == cofradeId);
  }

  Future<void> addDelegatedVote({
    required EventCampaign campaign,
    required String registrationId,
    required Cofrade delegatingCofrade,
    required Cofrade delegatedTo,
    required String registeredBy,
    String source = 'private',
    String status = 'requested',
    bool force = false,
    String overrideReason = '',
    String observations = '',
  }) async {
    if (campaign.type != 'junta_general_ordinaria') {
      throw Exception('Los votos delegados solo aplican a Junta General.');
    }
    if (delegatingCofrade.id == delegatedTo.id) {
      throw Exception('Un cofrade no puede delegar el voto en sí mismo.');
    }
    if (force && overrideReason.trim().isEmpty) {
      throw Exception('Indica el motivo del override administrativo.');
    }

    final regsSnap =
        await _registrations.where('campaignId', isEqualTo: campaign.id).get();
    final conflictingDelegations =
        <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    QueryDocumentSnapshot<Map<String, dynamic>>? targetDoc;
    bool delegatingCofradeAttends = false;

    for (final doc in regsSnap.docs) {
      if (doc.id == registrationId) targetDoc = doc;
      final reg = EventRegistration.fromFirestore(doc);
      if ((reg.cofradeId == delegatingCofrade.id &&
              reg.status != 'not_attending') ||
          reg.participants.any((participant) =>
              participant['type'] == 'cofrade' &&
              participant['cofradeId'] == delegatingCofrade.id)) {
        delegatingCofradeAttends = true;
      }
      if (reg.delegatedVotes.any((vote) =>
          '${vote['delegatingCofradeId'] ?? ''}' == delegatingCofrade.id &&
          !{'rejected', 'cancelled'}
              .contains('${vote['status'] ?? 'requested'}'))) {
        conflictingDelegations.add(doc);
      }
    }
    if (targetDoc == null) {
      throw Exception('No se ha encontrado la inscripción de asistencia.');
    }
    if (delegatingCofradeAttends && !force) {
      throw Exception(
          '${delegatingCofrade.nombreCompleto} ya figura como asistente presencial.');
    }
    final targetData = targetDoc.data();
    final delegatedVotes =
        (targetData['delegatedVotes'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
    if (delegatedVotes.any((vote) =>
        '${vote['delegatingCofradeId'] ?? ''}' == delegatingCofrade.id &&
        !{'rejected', 'cancelled'}
            .contains('${vote['status'] ?? 'requested'}'))) {
      throw Exception('${delegatingCofrade.nombreCompleto} ya está añadido.');
    }
    if (conflictingDelegations.isNotEmpty && !force) {
      final owner =
          EventRegistration.fromFirestore(conflictingDelegations.first);
      throw Exception(
          '${delegatingCofrade.nombreCompleto} ya delegó su voto en ${owner.cofradeName}.');
    }

    if (force) {
      for (final doc in conflictingDelegations) {
        if (doc.id == registrationId) continue;
        final current = (doc.data()['delegatedVotes'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .where((vote) =>
                '${vote['delegatingCofradeId'] ?? ''}' != delegatingCofrade.id)
            .toList();
        await doc.reference.update({
          'delegatedVotes': current,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    final vote = {
      'delegatingCofradeId': delegatingCofrade.id,
      'delegatingCofradeName': delegatingCofrade.nombreCompleto,
      'delegatingCofradeNumber': delegatingCofrade.numero,
      'delegatingCofradeDni': delegatingCofrade.dni ?? '',
      'delegatedToCofradeId': delegatedTo.id,
      'delegatedToCofradeName': delegatedTo.nombreCompleto,
      'registeredAt': Timestamp.now(),
      'registeredBy': registeredBy,
      'source': source,
      'status': force ? 'accepted' : status,
      if (force) 'override': true,
      if (force) 'overrideReason': overrideReason.trim(),
      if (observations.trim().isNotEmpty) 'observations': observations.trim(),
    };
    delegatedVotes.add(vote);
    await _registrations.doc(registrationId).update({
      'delegatedVotes': delegatedVotes,
      'updatedBy': registeredBy,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _createAuditLog(
      action: force
          ? 'event_delegated_vote_override'
          : status == 'accepted'
              ? 'event_delegated_vote_accepted'
              : 'event_delegated_vote_requested',
      targetId: registrationId,
      targetType: 'event_registration',
      changedBy: registeredBy,
      metadata: {
        'campaignId': campaign.id,
        'delegatingCofradeId': delegatingCofrade.id,
        'delegatedToCofradeId': delegatedTo.id,
        'source': source,
        if (force) 'overrideReason': overrideReason.trim(),
      },
    );
    if (status == 'requested') {
      await _createNovedad(
        tipo: 'junta_general_ordinaria',
        titulo: 'Solicitud de delegación de voto',
        descripcion:
            '${delegatedTo.nombreCompleto} solicita que delegues tu voto en él para ${campaign.name}.',
        referenciaId:
            'junta_delegation_request_${campaign.id}_${delegatingCofrade.id}_${registrationId}',
        ruta: routeForCampaign(campaign),
        visiblePara: 'cofrade',
        cofradeId: delegatingCofrade.id,
      );
    } else {
      await _createNovedad(
        tipo: 'junta_general_ordinaria',
        titulo: 'Voto delegado recibido',
        descripcion:
            '${delegatingCofrade.nombreCompleto} ha delegado su voto en ti para ${campaign.name}.',
        referenciaId:
            'junta_delegation_accepted_${campaign.id}_${delegatedTo.id}_${delegatingCofrade.id}',
        ruta: routeForCampaign(campaign),
        visiblePara: 'cofrade',
        cofradeId: delegatedTo.id,
      );
    }
  }

  Future<void> respondDelegatedVote({
    required String registrationId,
    required String delegatingCofradeId,
    required String changedBy,
    required bool accept,
  }) async {
    final ref = _registrations.doc(registrationId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final data = snap.data() ?? const <String, dynamic>{};
    final votes = (data['delegatedVotes'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    var delegatedTo = '';
    Map<String, dynamic>? oldValue;
    Map<String, dynamic>? newValue;
    final now = Timestamp.now();
    for (var i = 0; i < votes.length; i++) {
      if ('${votes[i]['delegatingCofradeId'] ?? ''}' == delegatingCofradeId) {
        final currentStatus = '${votes[i]['status'] ?? 'requested'}';
        if (currentStatus != 'requested') {
          throw Exception('Esta solicitud de delegación ya fue respondida.');
        }
        delegatedTo = '${votes[i]['delegatedToCofradeId'] ?? ''}';
        oldValue = Map<String, dynamic>.from(votes[i]);
        votes[i] = {
          ...votes[i],
          'status': accept ? 'accepted' : 'rejected',
          'respondedAt': now,
          'respondedBy': changedBy,
          if (accept) ...{
            'acceptedAt': now,
            'acceptedBy': changedBy,
          } else ...{
            'rejectedAt': now,
            'rejectedBy': changedBy,
          },
        };
        newValue = Map<String, dynamic>.from(votes[i]);
      }
    }
    if (oldValue == null || newValue == null) {
      throw Exception('No se ha encontrado la solicitud de delegación.');
    }
    await ref.update({
      'delegatedVotes': votes,
      'updatedBy': changedBy,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _createAuditLog(
      action: accept
          ? 'event_delegated_vote_accepted'
          : 'event_delegated_vote_rejected',
      targetId: registrationId,
      targetType: 'event_registration',
      changedBy: changedBy,
      metadata: {
        'delegatingCofradeId': delegatingCofradeId,
        'oldValue': oldValue,
        'newValue': newValue,
      },
    );
    if (delegatedTo.isNotEmpty) {
      await _createNovedad(
        tipo: 'junta_general_ordinaria',
        titulo: accept ? 'Delegación aceptada' : 'Delegación rechazada',
        descripcion: accept
            ? 'Han aceptado una delegación de voto solicitada.'
            : 'Han rechazado una delegación de voto solicitada.',
        referenciaId:
            'junta_delegation_response_${registrationId}_${delegatingCofradeId}_${accept ? 'accepted' : 'rejected'}',
        ruta: '/eventos?type=junta_general_ordinaria',
        visiblePara: 'cofrade',
        cofradeId: delegatedTo,
      );
    }
  }

  Future<void> confirmJuntaAttendance({
    required EventCampaign campaign,
    required Cofrade cofrade,
    required String changedBy,
  }) async {
    final existing = await getRegistrationForCofrade(
      campaignId: campaign.id,
      cofradeId: cofrade.id,
    );
    if (existing != null) {
      await updateRegistration(existing.id, {
        'status': 'attending',
        'attendanceStatus': 'attending',
        'updatedBy': changedBy,
      });
    } else {
      await registerCofrade(
        campaign: campaign,
        cofrade: cofrade,
        addedBy: cofrade,
        status: 'attending',
      );
    }
    await _cancelJuntaDelegations(
      campaignId: campaign.id,
      cofradeId: cofrade.id,
      changedBy: changedBy,
      asDelegating: true,
      reason: 'El cofrade ha confirmado asistencia presencial.',
    );
  }

  Future<void> markJuntaNotAttending({
    required EventCampaign campaign,
    required Cofrade cofrade,
    required String changedBy,
  }) async {
    final existing = await getRegistrationForCofrade(
      campaignId: campaign.id,
      cofradeId: cofrade.id,
    );
    if (existing != null) {
      await updateRegistration(existing.id, {
        'status': 'not_attending',
        'attendanceStatus': 'not_attending',
        'updatedBy': changedBy,
      });
    } else {
      await registerCofrade(
        campaign: campaign,
        cofrade: cofrade,
        addedBy: cofrade,
        status: 'not_attending',
      );
    }
    await _cancelJuntaDelegations(
      campaignId: campaign.id,
      cofradeId: cofrade.id,
      changedBy: changedBy,
      asDelegateTo: true,
      reason: 'El cofrade ha indicado que no asistirá.',
    );
  }

  Future<void> _cancelJuntaDelegations({
    required String campaignId,
    required String cofradeId,
    required String changedBy,
    bool asDelegating = false,
    bool asDelegateTo = false,
    String reason = '',
  }) async {
    final regs =
        await _registrations.where('campaignId', isEqualTo: campaignId).get();
    final now = Timestamp.now();
    for (final doc in regs.docs) {
      final data = doc.data();
      final votes = (data['delegatedVotes'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      var changed = false;
      final updated = votes.map((vote) {
        final status = '${vote['status'] ?? 'requested'}';
        final matchesDelegating =
            asDelegating && '${vote['delegatingCofradeId'] ?? ''}' == cofradeId;
        final matchesDelegateTo = asDelegateTo &&
            '${vote['delegatedToCofradeId'] ?? ''}' == cofradeId;
        if ((matchesDelegating || matchesDelegateTo) &&
            status != 'cancelled' &&
            status != 'rejected') {
          changed = true;
          return {
            ...vote,
            'status': 'cancelled',
            'cancelledAt': now,
            'cancelledBy': changedBy,
            if (reason.trim().isNotEmpty) 'cancelReason': reason.trim(),
          };
        }
        return vote;
      }).toList();
      if (changed) {
        await doc.reference.update({
          'delegatedVotes': updated,
          'updatedBy': changedBy,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await _createAuditLog(
          action: 'event_delegated_vote_cancelled',
          targetId: doc.id,
          targetType: 'event_registration',
          changedBy: changedBy,
          metadata: {
            'campaignId': campaignId,
            'cofradeId': cofradeId,
            'reason': reason,
          },
        );
      }
    }
  }

  Future<void> delegateOwnVoteToAttendee({
    required EventCampaign campaign,
    required Cofrade delegatingCofrade,
    required EventRegistration attendeeRegistration,
    required String changedBy,
  }) async {
    if (attendeeRegistration.status == 'not_attending') {
      throw Exception('Solo puedes delegar en un cofrade que vaya a asistir.');
    }
    final attendeeDoc = await _db
        .collection('cofrades')
        .doc(attendeeRegistration.cofradeId)
        .get();
    if (!attendeeDoc.exists) {
      throw Exception('No se ha encontrado el cofrade asistente.');
    }
    await markJuntaNotAttending(
      campaign: campaign,
      cofrade: delegatingCofrade,
      changedBy: changedBy,
    );
    await addDelegatedVote(
      campaign: campaign,
      registrationId: attendeeRegistration.id,
      delegatingCofrade: delegatingCofrade,
      delegatedTo: Cofrade.fromFirestore(attendeeDoc),
      registeredBy: changedBy,
      source: 'private',
      status: 'accepted',
    );
  }

  Future<void> removeDelegatedVote({
    required String registrationId,
    required String delegatingCofradeId,
    required String changedBy,
    String reason = '',
  }) async {
    final ref = _registrations.doc(registrationId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final data = snap.data() ?? const <String, dynamic>{};
    final votes = (data['delegatedVotes'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final removed = <Map<String, dynamic>>[];
    final now = Timestamp.now();
    final matchingVotes = votes
        .where((vote) =>
            '${vote['delegatingCofradeId'] ?? ''}' == delegatingCofradeId)
        .toList();
    if (matchingVotes.isEmpty) return;
    final allMatchingAlreadyCancelled = matchingVotes
        .every((vote) => '${vote['status'] ?? 'requested'}' == 'cancelled');
    if (allMatchingAlreadyCancelled) {
      votes.removeWhere((vote) =>
          '${vote['delegatingCofradeId'] ?? ''}' == delegatingCofradeId);
      await ref.update({
        'delegatedVotes': votes,
        'updatedBy': changedBy,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _createAuditLog(
        action: 'event_delegated_vote_deleted',
        targetId: registrationId,
        targetType: 'event_registration',
        changedBy: changedBy,
        metadata: {
          'delegatingCofradeId': delegatingCofradeId,
          if (reason.trim().isNotEmpty) 'reason': reason.trim(),
        },
      );
      return;
    }
    final updatedVotes = votes.map((vote) {
      if ('${vote['delegatingCofradeId'] ?? ''}' != delegatingCofradeId) {
        return vote;
      }
      removed.add(Map<String, dynamic>.from(vote));
      return {
        ...vote,
        'status': 'cancelled',
        'cancelledAt': now,
        'cancelledBy': changedBy,
        if (reason.trim().isNotEmpty) 'cancelReason': reason.trim(),
      };
    }).toList();
    if (removed.isEmpty) return;
    await ref.update({
      'delegatedVotes': updatedVotes,
      'updatedBy': changedBy,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _createAuditLog(
      action: 'event_delegated_vote_removed',
      targetId: registrationId,
      targetType: 'event_registration',
      changedBy: changedBy,
      metadata: {
        'delegatingCofradeId': delegatingCofradeId,
        'removed': removed,
        if (reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
  }

  Future<void> deleteJuntaRegistration({
    required String registrationId,
    required String changedBy,
  }) async {
    final ref = _registrations.doc(registrationId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final reg = EventRegistration.fromFirestore(snap);
    if (reg.type != 'junta_general_ordinaria') {
      throw Exception('Esta acción solo aplica a Junta General.');
    }
    if (reg.status != 'cancelled') {
      throw Exception('Solo se pueden borrar asistencias canceladas.');
    }
    await ref.delete();
    await _createAuditLog(
      action: 'event_junta_attendance_deleted',
      targetId: registrationId,
      targetType: 'event_registration',
      changedBy: changedBy,
      metadata: {
        'campaignId': reg.campaignId,
        'cofradeId': reg.cofradeId,
        'oldValue': {
          'status': reg.status,
          'delegatedVotes': reg.delegatedVotes,
        },
      },
    );
  }

  Future<void> registerCofrade({
    required EventCampaign campaign,
    required Cofrade cofrade,
    required Cofrade addedBy,
    int? heightCm,
    String status = 'solicitada',
    Map<String, dynamic>? menu,
    Map<String, dynamic> answers = const {},
    Map<String, dynamic> participantAnswers = const {},
  }) async {
    final existing = await getRegistrationIncludingCofrade(
      campaignId: campaign.id,
      cofradeId: cofrade.id,
    );
    if (existing != null) {
      throw Exception('${cofrade.nombreCompleto} ya figura en esta campaña.');
    }
    if (campaign.type == 'junta_general_ordinaria') {
      final regs = await _registrations
          .where('campaignId', isEqualTo: campaign.id)
          .get();
      for (final doc in regs.docs) {
        final votes = doc.data()['delegatedVotes'];
        if (votes is Iterable &&
            votes.whereType<Map>().any((vote) =>
                '${vote['delegatingCofradeId'] ?? ''}' == cofrade.id &&
                '${vote['status'] ?? 'requested'}' == 'accepted')) {
          throw Exception(
              '${cofrade.nombreCompleto} ya tiene el voto delegado en otro asistente.');
        }
      }
    }
    final ref = _registrations.doc();
    final menuPrice = (menu?['price'] as num?)?.toDouble() ?? 0.0;
    final price = campaign.requiresPayment
        ? _memberBasePrice(campaign) + menuPrice
        : menuPrice;
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
      'paidAmount': 0,
      'paymentNotes': '',
      'answers': answers,
      'participants': [
        {
          'type': 'cofrade',
          'cofradeId': cofrade.id,
          'name': cofrade.nombreCompleto,
          'cofradeNumber': cofrade.numero,
          'dni': cofrade.dni ?? '',
          'price': price,
          if (menu != null) ...{
            'menuId': menu['id'],
            'menuName': menu['name'],
            'menuPrice': menuPrice,
            'menuSnapshot': menu,
          },
          'answers': participantAnswers,
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
      ruta: routeForCampaign(campaign),
      visiblePara: 'cofrade',
      cofradeId: cofrade.id,
    );
  }

  Future<void> addCofradeToRegistration({
    required String registrationId,
    required EventCampaign campaign,
    required Cofrade cofrade,
    required Cofrade addedBy,
    Map<String, dynamic>? menu,
    Map<String, dynamic> participantAnswers = const {},
  }) async {
    final existing = await getRegistrationIncludingCofrade(
      campaignId: campaign.id,
      cofradeId: cofrade.id,
    );
    if (existing != null) {
      final owner = existing.cofradeName.isEmpty
          ? 'otra petición'
          : 'la petición de ${existing.cofradeName}';
      throw Exception('${cofrade.nombreCompleto} ya figura en $owner.');
    }

    final ref = _registrations.doc(registrationId);
    final snap = await ref.get();
    if (!snap.exists) {
      throw Exception('No se ha encontrado la petición.');
    }
    final data = snap.data() ?? const <String, dynamic>{};
    final participants = (data['participants'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    if (participants.any((item) => item['cofradeId'] == cofrade.id)) {
      throw Exception('${cofrade.nombreCompleto} ya está añadido.');
    }
    final menuPrice = (menu?['price'] as num?)?.toDouble() ?? 0.0;
    final price = campaign.requiresPayment
        ? _memberBasePrice(campaign) + menuPrice
        : menuPrice;
    participants.add({
      'type': 'cofrade',
      'cofradeId': cofrade.id,
      'name': cofrade.nombreCompleto,
      'cofradeNumber': cofrade.numero,
      'dni': cofrade.dni ?? '',
      'price': price,
      if (menu != null) ...{
        'menuId': menu['id'],
        'menuName': menu['name'],
        'menuPrice': menuPrice,
        'menuSnapshot': menu,
      },
      'answers': participantAnswers,
      'paymentStatus': campaign.requiresPayment ? 'pending' : 'not_required',
      'metadata': {'addedById': addedBy.id},
    });
    final currentTotal = (data['totalAmount'] as num?)?.toDouble() ?? 0;
    await updateRegistration(registrationId, {
      'participants': participants,
      'totalAmount': currentTotal + price,
      'updatedBy': addedBy.id,
    });
    await _createAuditLog(
      action: 'event_registration_participant_added',
      targetId: registrationId,
      targetType: 'event_registration',
      changedBy: addedBy.id,
      metadata: {
        'campaignId': campaign.id,
        'cofradeId': cofrade.id,
        'cofradeName': cofrade.nombreCompleto,
      },
    );
    await _createNovedad(
      tipo: 'evento',
      titulo: 'Te han incluido en ${campaign.name}',
      descripcion: '${addedBy.nombreCompleto} te ha añadido a su petición.',
      referenciaId: 'event_registration_added_${registrationId}_${cofrade.id}',
      ruta: routeForCampaign(campaign),
      visiblePara: 'cofrade',
      cofradeId: cofrade.id,
    );
  }

  Future<void> removeCofradeFromRegistration({
    required String registrationId,
    required EventCampaign campaign,
    required String cofradeId,
    required String changedBy,
  }) async {
    final ref = _registrations.doc(registrationId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final data = snap.data() ?? const <String, dynamic>{};
    if ('${data['cofradeId'] ?? ''}' == cofradeId) {
      throw Exception('No se puede quitar al titular de la petición.');
    }
    final participants = (data['participants'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final removed =
        participants.where((item) => item['cofradeId'] == cofradeId).toList();
    if (removed.isEmpty) return;
    participants.removeWhere((item) => item['cofradeId'] == cofradeId);
    final removedAmount = removed.fold<double>(
      0,
      (total, item) => total + ((item['price'] as num?)?.toDouble() ?? 0),
    );
    final currentTotal = (data['totalAmount'] as num?)?.toDouble() ?? 0;
    await updateRegistration(registrationId, {
      'participants': participants,
      'totalAmount': (currentTotal - removedAmount).clamp(0, double.infinity),
      'updatedBy': changedBy,
    });
    await _createAuditLog(
      action: 'event_registration_participant_removed',
      targetId: registrationId,
      targetType: 'event_registration',
      changedBy: changedBy,
      metadata: {
        'campaignId': campaign.id,
        'cofradeId': cofradeId,
        'removed': removed,
      },
    );
  }

  Future<void> addExternalParticipantToRegistration({
    required String registrationId,
    required EventCampaign campaign,
    required String name,
    String dni = '',
    required String changedBy,
  }) async {
    if (!campaign.allowExternalGuests) {
      throw Exception('Este evento no permite personas externas.');
    }
    final cleanName = name.trim();
    final cleanDni = dni.trim();
    if (cleanName.isEmpty) {
      throw Exception('Indica el nombre de la persona.');
    }
    final ref = _registrations.doc(registrationId);
    final snap = await ref.get();
    if (!snap.exists) {
      throw Exception('No se ha encontrado la petición.');
    }
    final data = snap.data() ?? const <String, dynamic>{};
    final participants = (data['participants'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final normalizedName = cleanName.toLowerCase();
    final duplicated = participants.any((item) {
      final existingDni = '${item['dni'] ?? ''}'.trim().toLowerCase();
      final existingName = '${item['name'] ?? ''}'.trim().toLowerCase();
      return cleanDni.isNotEmpty
          ? existingDni == cleanDni.toLowerCase()
          : existingName == normalizedName;
    });
    if (duplicated) {
      throw Exception('$cleanName ya figura en esta petición.');
    }
    final price = campaign.requiresPayment ? _externalBasePrice(campaign) : 0.0;
    participants.add({
      'type': 'external_guest',
      'name': cleanName,
      if (cleanDni.isNotEmpty) 'dni': cleanDni,
      'price': price,
      'paymentStatus': campaign.requiresPayment ? 'pending' : 'not_required',
      'metadata': {'addedById': changedBy},
    });
    final currentTotal = (data['totalAmount'] as num?)?.toDouble() ?? 0;
    await updateRegistration(registrationId, {
      'participants': participants,
      'totalAmount': currentTotal + price,
      'updatedBy': changedBy,
    });
    await _createAuditLog(
      action: 'event_registration_external_participant_added',
      targetId: registrationId,
      targetType: 'event_registration',
      changedBy: changedBy,
      metadata: {
        'campaignId': campaign.id,
        'name': cleanName,
        'dni': cleanDni,
      },
    );
  }

  Future<bool> isMenuUsed(String campaignId, String menuId) async {
    final regs =
        await _registrations.where('campaignId', isEqualTo: campaignId).get();
    for (final doc in regs.docs) {
      final participants = doc.data()['participants'];
      if (participants is Iterable) {
        for (final participant in participants.whereType<Map>()) {
          if ('${participant['menuId'] ?? ''}' == menuId) return true;
        }
      }
    }
    return false;
  }

  Future<bool> isCustomFieldUsed(String campaignId, String fieldKey) async {
    final regs =
        await _registrations.where('campaignId', isEqualTo: campaignId).get();
    for (final doc in regs.docs) {
      final data = doc.data();
      final answers = data['answers'];
      if (answers is Map && answers.containsKey(fieldKey)) return true;
      final participants = data['participants'];
      if (participants is Iterable) {
        for (final participant in participants.whereType<Map>()) {
          final participantAnswers = participant['answers'];
          if (participantAnswers is Map &&
              participantAnswers.containsKey(fieldKey)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  Future<void> updateRegistration(
    String registrationId,
    Map<String, dynamic> data,
  ) async {
    final ref = _registrations.doc(registrationId);
    final beforeSnap = await ref.get();
    final before = beforeSnap.data() ?? const <String, dynamic>{};
    final oldStatus = before['status'];
    final oldPaymentStatus =
        before['paymentStatus'] ?? before['payment_status'];
    await _registrations.doc(registrationId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final after = {...before, ...data};
    await _notifyRegistrationChange(
      registrationId: registrationId,
      before: before,
      after: after,
      oldStatus: oldStatus,
      oldPaymentStatus: oldPaymentStatus,
    );
    await _createAuditLog(
      action: 'event_registration_updated',
      targetId: registrationId,
      targetType: 'event_registration',
      changedBy: 'system',
      metadata: data,
    );
  }

  Future<int> sendReminderToNotRegistered(EventCampaign campaign) async {
    final regs =
        await _registrations.where('campaignId', isEqualTo: campaign.id).get();
    final registeredIds = <String>{};
    for (final doc in regs.docs) {
      registeredIds.addAll(_participantIdsFromRegistration(doc.data()));
    }
    final cofradesSnap = await _db.collection('cofrades').get();
    final targets = cofradesSnap.docs.where((doc) {
      if (registeredIds.contains(doc.id)) return false;
      final data = doc.data();
      final estado = '${data['estado'] ?? data['status'] ?? ''}'.toLowerCase();
      final isService = data['es_cuenta_servicio'] == true ||
          data['isServiceAccount'] == true ||
          doc.id.startsWith('ADM-');
      final hasDigitalAccess = data['gdprDigitalRevoked'] != true &&
          data['gdprDigitalStatus'] != 'revoked';
      return !isService &&
          estado != 'baja' &&
          estado != 'inactive' &&
          estado != 'inactivo' &&
          hasDigitalAccess;
    }).toList();
    for (final doc in targets) {
      await _createNovedad(
        tipo: campaign.type,
        titulo: 'Recordatorio: ${campaign.name}',
        descripcion: campaign.isOpen
            ? 'Todavía puedes inscribirte en ${campaign.name}.'
            : 'Tienes información disponible sobre ${campaign.name}.',
        referenciaId: 'event_reminder_${campaign.id}_${doc.id}',
        ruta: routeForCampaign(campaign),
        visiblePara: 'cofrade',
        cofradeId: doc.id,
      );
    }
    await _createAuditLog(
      action: 'event_reminder_to_not_registered_sent',
      targetId: campaign.id,
      targetType: 'event_campaign',
      changedBy: 'system',
      metadata: {
        'type': campaign.type,
        'targetCount': targets.length,
        'registeredCount': registeredIds.length,
      },
    );
    return targets.length;
  }

  Future<void> _notifyRegistrationChange({
    required String registrationId,
    required Map<String, dynamic> before,
    required Map<String, dynamic> after,
    required dynamic oldStatus,
    required dynamic oldPaymentStatus,
  }) async {
    final newStatus = after['status'];
    final newPaymentStatus = after['paymentStatus'] ?? after['payment_status'];
    final changed = <String, Map<String, dynamic>>{};
    if (oldStatus != newStatus && newStatus != null) {
      changed['status'] = {'old': oldStatus, 'new': newStatus};
    }
    if (oldPaymentStatus != newPaymentStatus && newPaymentStatus != null) {
      changed['paymentStatus'] = {
        'old': oldPaymentStatus,
        'new': newPaymentStatus,
      };
    }
    if (before['paidAmount'] != after['paidAmount'] &&
        after['paidAmount'] != null) {
      changed['paidAmount'] = {
        'old': before['paidAmount'],
        'new': after['paidAmount'],
      };
    }
    if (changed.isEmpty) return;
    final campaignId = '${after['campaignId'] ?? ''}';
    final campaign = campaignId.isEmpty
        ? null
        : (await _campaigns.doc(campaignId).get()).data();
    final campaignName = campaign?['name'] ?? after['type'] ?? 'evento';
    final campaignType = '${campaign?['type'] ?? after['type'] ?? ''}';
    final notified = _participantIdsFromRegistration(after);
    for (final cofradeId in notified) {
      final isPayment = changed.containsKey('paymentStatus') ||
          changed.containsKey('paidAmount');
      await _createNovedad(
        tipo: 'evento',
        titulo: isPayment
            ? 'Pago actualizado: $campaignName'
            : 'Inscripción actualizada: $campaignName',
        descripcion: _registrationChangeMessage(
          campaignType: campaignType,
          campaignName: '$campaignName',
          isPayment: isPayment,
          status: '$newStatus',
          paymentStatus: '$newPaymentStatus',
        ),
        referenciaId:
            'event_registration_change_${registrationId}_${cofradeId}_${changed.keys.join("_")}_${DateTime.now().millisecondsSinceEpoch}',
        ruta: campaignId.isEmpty
            ? '/eventos'
            : '/eventos?type=${Uri.encodeComponent(campaignType)}&campaignId=${Uri.encodeComponent(campaignId)}',
        visiblePara: 'cofrade',
        cofradeId: cofradeId,
      );
    }
    await _createAuditLog(
      action: 'event_registration_change_notified',
      targetId: registrationId,
      targetType: 'event_registration',
      changedBy: 'system',
      metadata: {
        'changes': changed,
        'notifiedCofradeIds': notified.toList(),
      },
    );
  }

  String _registrationChangeMessage({
    required String campaignType,
    required String campaignName,
    required bool isPayment,
    required String status,
    required String paymentStatus,
  }) {
    if (campaignType == 'junta_general_ordinaria') {
      switch (status) {
        case 'attending':
        case 'confirmed':
        case 'confirmada':
          return 'Has confirmado tu asistencia a $campaignName.';
        case 'not_attending':
          return 'Has indicado que no asistirás a $campaignName.';
        case 'delegated':
          return 'Has delegado tu voto para $campaignName.';
        case 'cancelled':
          return 'Tu respuesta a $campaignName se ha cancelado.';
        default:
          return 'Tu respuesta a $campaignName se ha actualizado.';
      }
    }
    if (isPayment) {
      return 'El estado de pago de tu inscripción ha cambiado a ${_eventPaymentStatusLabel(paymentStatus)}.';
    }
    return 'El estado de tu inscripción ha cambiado a ${_eventRegistrationStatusLabel(status)}.';
  }

  String _eventRegistrationStatusLabel(String status) {
    switch (status) {
      case 'pending_response':
        return 'Pendiente de respuesta';
      case 'attending':
        return 'Asistiré';
      case 'not_attending':
        return 'No asistiré';
      case 'delegated':
        return 'Voto delegado';
      case 'cancelled':
      case 'cancelada':
        return 'Cancelado';
      case 'confirmed':
      case 'confirmada':
        return 'Confirmada';
      case 'requested':
      case 'solicitada':
        return 'Solicitada';
      case 'rejected':
      case 'rechazada':
        return 'Rechazada';
      default:
        return status.isEmpty ? 'Actualizado' : status;
    }
  }

  String _eventPaymentStatusLabel(String status) {
    switch (status) {
      case 'paid':
      case 'pagado':
        return 'Pagado';
      case 'partial':
      case 'parcial':
        return 'Parcial';
      case 'refunded':
      case 'devuelto':
        return 'Devuelto';
      case 'not_required':
        return 'No requerido';
      default:
        return 'Pendiente';
    }
  }

  Set<String> _participantIdsFromRegistration(Map<String, dynamic> data) {
    final ids = <String>{};
    final titular = '${data['cofradeId'] ?? data['cofrade_id'] ?? ''}';
    if (titular.isNotEmpty) ids.add(titular);
    final main = '${data['mainCofradeId'] ?? ''}';
    if (main.isNotEmpty) ids.add(main);
    final participants = data['participants'];
    if (participants is Iterable) {
      for (final participant in participants.whereType<Map>()) {
        final id =
            '${participant['cofradeId'] ?? participant['cofrade_id'] ?? ''}';
        if (id.isNotEmpty) ids.add(id);
      }
    }
    return ids;
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
        ruta: routeForCampaign(campaign),
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
