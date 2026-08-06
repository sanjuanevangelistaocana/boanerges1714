import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
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
import 'package:boanerges1714/models/tag_config.dart';
import 'package:boanerges1714/models/cofrade_field_config.dart';
import 'package:boanerges1714/utils/madrid_date.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Map<String, Map<String, dynamic>?> _evangelioCache = {};

  // --- Cofrades ---
  Stream<List<Cofrade>> getCofrades() {
    return watchAllCofradesForAdmin();
  }

  Stream<List<Cofrade>> watchAllCofradesForAdmin() {
    debugPrint(
        '[Firestore] watchAllCofradesForAdmin query: collection=cofrades filters=NONE sort=client_numero');
    return _db.collection('cofrades').snapshots().map(
      (snapshot) {
        var discarded = 0;
        debugPrint(
            '[Firestore] watchAllCofradesForAdmin: ${snapshot.docs.length} docs recibidos antes de mapear');
        final result = <Cofrade>[];
        for (final doc in snapshot.docs) {
          try {
            result.add(Cofrade.fromFirestore(doc));
          } catch (e, st) {
            discarded++;
            debugPrint(
                '[Firestore] watchAllCofradesForAdmin parse error doc=${doc.id}: $e\n$st');
          }
        }
        debugPrint(
            '[Firestore] watchAllCofradesForAdmin: ${result.length} convertidos OK, $discarded descartados por parseo');
        return result;
      },
    ).handleError((error, stackTrace) {
      debugPrint(
          '[Firestore] watchAllCofradesForAdmin stream error: $error\n$stackTrace');
      throw error;
    });
  }

  Future<Cofrade?> getCofrade(String id) async {
    final doc = await _db.collection('cofrades').doc(id).get();
    if (doc.exists) {
      return Cofrade.fromFirestore(doc);
    }
    return null;
  }

  Future<void> updateCofrade(
    String id,
    Map<String, dynamic> data, {
    String? changedBy,
    String? changedByRole,
    bool audit = true,
    bool markPendingReview = true,
  }) async {
    final ref = _db.collection('cofrades').doc(id);
    final beforeSnap = audit ? await ref.get() : null;
    final before = beforeSnap?.data();
    if (data.containsKey('dni')) {
      data['dni_normalizado'] = _normalizeDni(data['dni']?.toString() ?? '');
    }
    final hasBirthDateUpdate = data.containsKey('fecha_nacimiento') ||
        data.containsKey('fecha_nacimiento_str');
    if (hasBirthDateUpdate) {
      final birth = Cofrade.parseBirthDate(
        data['fecha_nacimiento'] ?? data['fecha_nacimiento_str'],
      );
      data.addAll(Cofrade.birthDateFields(birth));
    }
    final actorRole = (changedByRole ?? '').toLowerCase();
    final isSelfProfileEdit =
        markPendingReview && changedBy == id && !actorRole.contains('admin');
    if (isSelfProfileEdit) {
      data['hasPendingProfileReview'] = true;
      data['lastProfileChangeAt'] = FieldValue.serverTimestamp();
      data['lastProfileChangeBy'] = changedBy;
    }
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
    if (hasBirthDateUpdate) {
      final birth = Cofrade.parseBirthDate(
        data['fecha_nacimiento'] ?? data['fecha_nacimiento_str'],
      );
      if (birth == null) {
        cleaned['fecha_nacimiento'] = FieldValue.delete();
        cleaned['fecha_nacimiento_str'] = '';
      }
    }
    debugPrint('[Firestore] updateCofrade($id): ${cleaned.keys.join(', ')}');
    await ref.update(cleaned);
    if (audit && before != null) {
      final changes = _diffChanges(before, cleaned);
      if (changes.isNotEmpty) {
        final targetNombre =
            '${before['nombre'] ?? ''} ${before['apellidos'] ?? ''}'.trim();
        await _db.collection('audit_logs').add({
          'action': 'cofrade_field_updated',
          'target_id': id,
          'target_type': 'cofrade',
          'target_nombre': targetNombre,
          'changed_by': changedBy ?? 'system',
          'changed_by_role': changedByRole ?? 'system',
          'changed_at': FieldValue.serverTimestamp(),
          'changes': changes,
        });
        for (final change in changes) {
          await _db.collection('audit_logs').add({
            'entityType': 'cofrade',
            'entityId': id,
            'action': 'cofrade_field_updated',
            'fieldKey': change['field'],
            'fieldLabel': _humanizeFieldKey('${change['field']}'),
            'oldValue': change['old_value'],
            'newValue': change['new_value'],
            'target_id': id,
            'target_type': 'cofrade',
            'target_nombre': targetNombre,
            'changed_by': changedBy ?? 'system',
            'changed_by_role': changedByRole ?? 'system',
            'changed_at': FieldValue.serverTimestamp(),
            'metadata': {
              'source': isSelfProfileEdit ? 'private_profile' : 'admin_panel',
            },
          });
        }
      }
    }
    debugPrint('[Firestore] updateCofrade($id): OK');
  }

  List<Map<String, dynamic>> _diffChanges(
    Map<String, dynamic> before,
    Map<String, dynamic> after,
  ) {
    const ignored = {'fecha_actualizacion'};
    final changes = <Map<String, dynamic>>[];
    for (final entry in after.entries) {
      if (ignored.contains(entry.key)) continue;
      final oldValue = before[entry.key];
      final newValue = entry.value;
      if ('$oldValue' != '$newValue') {
        changes.add({
          'field': entry.key,
          'fieldLabel': _humanizeFieldKey(entry.key),
          'old_value': oldValue,
          'new_value': newValue,
        });
      }
    }
    return changes;
  }

  Future<void> markProfileChangesReviewed({
    required Cofrade cofrade,
    required String changedBy,
    required String changedByRole,
  }) async {
    await updateCofrade(
      cofrade.id,
      {
        'hasPendingProfileReview': false,
        'profileReviewedAt': FieldValue.serverTimestamp(),
        'profileReviewedBy': changedBy,
      },
      changedBy: changedBy,
      changedByRole: changedByRole,
      markPendingReview: false,
    );
    await createAuditLog(
      action: 'cofrade_profile_changes_reviewed',
      targetId: cofrade.id,
      targetType: 'cofrade',
      targetNombre: cofrade.nombreCompleto,
      changedBy: changedBy,
      newValue: {
        'hasPendingProfileReview': false,
        'profileReviewedBy': changedBy,
      },
      metadata: {'changedByRole': changedByRole},
    );
  }

  Future<void> changeCofradeNumber({
    required Cofrade cofrade,
    required int newNumber,
    required String reason,
    required String changedBy,
    required String changedByRole,
  }) async {
    if (newNumber <= 0) {
      throw Exception('El número de cofrade debe ser mayor que cero.');
    }
    final cleanReason = reason.trim();
    if (cleanReason.isEmpty) {
      throw Exception('Indica el motivo de la modificación.');
    }
    final duplicated = await _db
        .collection('cofrades')
        .where('numero', isEqualTo: newNumber)
        .limit(2)
        .get();
    QueryDocumentSnapshot<Map<String, dynamic>>? conflict;
    for (final doc in duplicated.docs) {
      if (doc.id != cofrade.id) {
        conflict = doc;
        break;
      }
    }
    if (conflict != null) {
      throw Exception('Ya existe otro cofrade con el número $newNumber.');
    }
    final oldNumber = cofrade.numero;
    if (oldNumber == newNumber) return;
    await updateCofrade(
      cofrade.id,
      {
        'numero': newNumber,
        'numero_anterior': oldNumber,
        'numberChangedAt': FieldValue.serverTimestamp(),
        'numberChangedBy': changedBy,
        'numberChangeReason': cleanReason,
      },
      changedBy: changedBy,
      changedByRole: changedByRole,
      markPendingReview: false,
    );
    await createAuditLog(
      action: 'cofrade_number_changed',
      targetId: cofrade.id,
      targetType: 'cofrade',
      targetNombre: cofrade.nombreCompleto,
      changedBy: changedBy,
      oldValue: {'numero': oldNumber},
      newValue: {'numero': newNumber},
      metadata: {
        'changedByRole': changedByRole,
        'reason': cleanReason,
        'source': 'admin_panel',
        'requiresTraceabilityReview': true,
      },
    );
  }

  Future<void> setAdminRole(
    Cofrade cofrade, {
    required bool enabled,
    required String changedBy,
  }) async {
    final currentRoles = cofrade.roles.toSet();
    if (enabled) {
      currentRoles.add('admin');
    } else {
      currentRoles.removeWhere((role) => role.toLowerCase() == 'admin');
    }
    final oldValue = {
      'rol': cofrade.rol,
      'role': cofrade.rol,
      'roles': cofrade.roles,
    };
    final newValue = {
      'rol': enabled ? 'admin' : 'cofrade',
      'role': enabled ? 'admin' : 'cofrade',
      'roles': currentRoles.toList()..sort(),
    };
    await updateCofrade(cofrade.id, newValue);
    await createAuditLog(
      action: enabled ? 'admin_granted' : 'admin_revoked',
      targetId: cofrade.id,
      targetNombre: cofrade.nombreCompleto,
      changedBy: changedBy,
      oldValue: oldValue,
      newValue: newValue,
    );
  }

  Future<void> updateRolesAndPermissions({
    required Cofrade cofrade,
    required List<String> roles,
    required Map<String, dynamic> permissions,
    required String changedBy,
    required String changedByRole,
  }) async {
    if (cofrade.id == 'ADM-000000' || cofrade.esCuentaServicio) {
      throw StateError('El Administrador Sistema es inmutable desde la UI.');
    }
    final normalizedPermissions = _normalizeAdminPermissions(permissions);
    final roleLower = roles.map((r) => r.toLowerCase()).toSet();
    final newRol = roleLower.contains('admin')
        ? 'admin'
        : roleLower.contains('tesorería')
            ? 'tesorero'
            : roleLower.contains('junta')
                ? 'junta'
                : 'cofrade';
    final oldValue = {
      'rol': cofrade.rol,
      'role': cofrade.rol,
      'roles': cofrade.roles,
    };
    final newValue = {
      'rol': newRol,
      'role': newRol,
      'roles': roles,
      'admin_permissions': normalizedPermissions,
    };
    await updateCofrade(
      cofrade.id,
      newValue,
      changedBy: changedBy,
      changedByRole: changedByRole,
    );
    await createAuditLog(
      action: 'permissions_updated',
      targetId: cofrade.id,
      targetType: 'cofrade',
      targetNombre: cofrade.nombreCompleto,
      changedBy: changedBy,
      oldValue: oldValue,
      newValue: newValue,
    );
  }

  Map<String, dynamic> _normalizeAdminPermissions(
    Map<String, dynamic> permissions,
  ) {
    final normalized = <String, dynamic>{};
    for (final entry in permissions.entries) {
      final raw = (entry.value as Map).cast<String, dynamic>();
      final write = raw['write'] == true || raw['edit'] == true;
      final read = raw['read'] == true || write;
      normalized[entry.key] = {
        'read': read,
        'write': write,
      };
    }
    return normalized;
  }

  Future<void> darDeBajaCofrade({
    required String cofradeId,
    required String causaBaja,
    required String changedBy,
    required String changedByRole,
  }) async {
    final targetRef = _db.collection('cofrades').doc(cofradeId);
    final targetSnap = await targetRef.get();
    if (!targetSnap.exists) return;
    final target = Cofrade.fromFirestore(targetSnap);
    final oldNumber = target.numero;
    final now = FieldValue.serverTimestamp();
    if (oldNumber == null) {
      await updateCofrade(
        cofradeId,
        {
          'estado': 'Baja',
          'status': 'baja',
          'isActive': false,
          'bajaAt': now,
          'bajaReason': causaBaja,
          'bajaBy': changedBy,
          'causa_baja': causaBaja,
          'fecha_baja_str': _todayString(),
        },
        changedBy: changedBy,
        changedByRole: changedByRole,
      );
      return;
    }

    final affected = await _db
        .collection('cofrades')
        .where('numero', isGreaterThan: oldNumber)
        .get();
    final batch = _db.batch();
    batch.update(targetRef, {
      'estado': 'Baja',
      'status': 'baja',
      'isActive': false,
      'bajaAt': now,
      'bajaReason': causaBaja,
      'bajaBy': changedBy,
      'numero': null,
      'numero_anterior': oldNumber,
      'fecha_baja_str': _todayString(),
      'causa_baja': causaBaja,
      'fecha_actualizacion': FieldValue.serverTimestamp(),
    });
    var recalculated = 0;
    for (final doc in affected.docs) {
      if (doc.id.startsWith('ADM-') ||
          doc.data()['es_cuenta_servicio'] == true) {
        continue;
      }
      final affectedCofrade = Cofrade.fromFirestore(doc);
      if (!affectedCofrade.isActivo) continue;
      final current = (doc.data()['numero'] as num?)?.toInt();
      if (current == null) continue;
      batch.update(doc.reference, {
        'numero': current - 1,
        'fecha_actualizacion': FieldValue.serverTimestamp(),
      });
      recalculated++;
    }
    await batch.commit();
    await createAuditLog(
      action: 'cofrade_deactivated',
      targetId: cofradeId,
      targetType: 'cofrade',
      targetNombre: target.nombreCompleto,
      changedBy: changedBy,
      oldValue: {
        'estado': target.estado,
        'numero': oldNumber,
      },
      newValue: {
        'estado': 'Baja',
        'status': 'baja',
        'isActive': false,
        'numero': null,
        'numero_anterior': oldNumber,
      },
      metadata: {
        'causa_baja': causaBaja,
        'recalculated_count': recalculated,
      },
    );
    await createAuditLog(
      action: 'cofrade_numbers_recalculated',
      targetId: cofradeId,
      targetType: 'cofrade',
      targetNombre: target.nombreCompleto,
      changedBy: changedBy,
      oldValue: oldNumber,
      newValue: oldNumber,
      metadata: {'recalculated_count': recalculated},
    );
  }

  Future<List<Map<String, dynamic>>> previewBajaNumbering(
    String cofradeId,
  ) async {
    final targetSnap = await _db.collection('cofrades').doc(cofradeId).get();
    if (!targetSnap.exists) return [];
    final oldNumber = (targetSnap.data()?['numero'] as num?)?.toInt();
    if (oldNumber == null) return [];
    final affected = await _db
        .collection('cofrades')
        .where('numero', isGreaterThan: oldNumber)
        .get();
    final rows = affected.docs
        .where((doc) =>
            !doc.id.startsWith('ADM-') &&
            doc.data()['es_cuenta_servicio'] != true &&
            Cofrade.fromFirestore(doc).isActivo)
        .map((doc) {
      final current = (doc.data()['numero'] as num?)?.toInt();
      return {
        'id': doc.id,
        'nombre':
            '${doc.data()['nombre'] ?? ''} ${doc.data()['apellidos'] ?? ''}'
                .trim(),
        'oldNumber': current,
        'newNumber': current == null ? null : current - 1,
      };
    }).toList();
    rows.sort((a, b) => ((a['oldNumber'] as int?) ?? 0)
        .compareTo((b['oldNumber'] as int?) ?? 0));
    return rows;
  }

  Future<void> reactivarCofrade({
    required String cofradeId,
    required bool recuperarNumeroAnterior,
    required String changedBy,
    required String changedByRole,
  }) async {
    final targetRef = _db.collection('cofrades').doc(cofradeId);
    final targetSnap = await targetRef.get();
    if (!targetSnap.exists) return;
    final targetData = targetSnap.data()!;
    final target = Cofrade.fromFirestore(targetSnap);
    final previous = (targetData['numero_anterior'] as num?)?.toInt();

    if (recuperarNumeroAnterior && previous != null) {
      final affected = await _db
          .collection('cofrades')
          .where('numero', isGreaterThanOrEqualTo: previous)
          .get();
      final batch = _db.batch();
      for (final doc in affected.docs) {
        if (doc.id.startsWith('ADM-') ||
            doc.data()['es_cuenta_servicio'] == true) {
          continue;
        }
        final active = Cofrade.fromFirestore(doc).isActivo;
        if (!active) continue;
        final current = (doc.data()['numero'] as num?)?.toInt();
        if (current == null) continue;
        batch.update(doc.reference, {
          'numero': current + 1,
          'fecha_actualizacion': FieldValue.serverTimestamp(),
        });
      }
      batch.update(targetRef, {
        'estado': 'Activo',
        'status': 'active',
        'isActive': true,
        'numero': previous,
        'fecha_baja_str': '',
        'causa_baja': '',
        'gdprDigitalAccepted': false,
        'gdprDigitalStatus': 'pending_reacceptance',
        'gdprDigitalReacceptanceRequired': true,
        'reactivatedAt': FieldValue.serverTimestamp(),
        'reactivatedBy': changedBy,
        'fecha_actualizacion': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      await createAuditLog(
        action: 'cofrade_reactivated_previous_number',
        targetId: cofradeId,
        targetType: 'cofrade',
        targetNombre: target.nombreCompleto,
        changedBy: changedBy,
        oldValue: {'estado': target.estado, 'numero': target.numero},
        newValue: {
          'estado': 'Activo',
          'status': 'active',
          'numero': previous,
          'gdprDigitalStatus': 'pending_reacceptance',
        },
      );
      return;
    }

    final last = await _db
        .collection('cofrades')
        .where('estado', isEqualTo: 'Activo')
        .get();
    final lastNumber = last.docs
        .where((doc) =>
            !doc.id.startsWith('ADM-') &&
            doc.data()['es_cuenta_servicio'] != true)
        .map((doc) => (doc.data()['numero'] as num?)?.toInt() ?? 0)
        .fold<int>(0, (max, value) => value > max ? value : max);
    final newNumber = lastNumber + 1;
    await updateCofrade(
      cofradeId,
      {
        'estado': 'Activo',
        'status': 'active',
        'isActive': true,
        'numero': newNumber,
        'fecha_baja_str': '',
        'causa_baja': '',
        'gdprDigitalAccepted': false,
        'gdprDigitalStatus': 'pending_reacceptance',
        'gdprDigitalReacceptanceRequired': true,
        'reactivatedAt': FieldValue.serverTimestamp(),
        'reactivatedBy': changedBy,
      },
      changedBy: changedBy,
      changedByRole: changedByRole,
    );
    await createAuditLog(
      action: 'cofrade_reactivated_new_number',
      targetId: cofradeId,
      targetType: 'cofrade',
      targetNombre: target.nombreCompleto,
      changedBy: changedBy,
      oldValue: {'estado': target.estado, 'numero': target.numero},
      newValue: {
        'estado': 'Activo',
        'status': 'active',
        'numero': newNumber,
        'gdprDigitalStatus': 'pending_reacceptance',
      },
    );
  }

  Future<void> createServiceAdminAccount({
    required String email,
    required String changedBy,
  }) async {
    const id = 'ADM-000000';
    final ref = _db.collection('cofrades').doc(id);
    final snap = await ref.get();
    final data = {
      'id_interno': id,
      'nombre': 'Administrador',
      'apellidos': 'Sistema',
      'rol': 'admin',
      'role': 'admin',
      'roles': ['admin', 'superadmin'],
      'estado': 'Activo',
      'status': 'active',
      'numero': null,
      'email': email.trim(),
      'notificaciones_activas': false,
      'tiene_cuota': false,
      'cuota_domiciliada': false,
      'cuota_metalico': false,
      'gdpr_firmado': true,
      'tutelado_digital': false,
      'es_cuenta_servicio': true,
      'fecha_actualizacion': FieldValue.serverTimestamp(),
      if (!snap.exists) 'fecha_creacion': FieldValue.serverTimestamp(),
    };
    await ref.set(data, SetOptions(merge: true));
    await createAuditLog(
      action: 'service_admin_created',
      targetId: id,
      targetNombre: 'Administrador Sistema',
      changedBy: changedBy,
      oldValue: snap.data(),
      newValue: data,
    );
  }

  Future<void> deleteCofrade(String id) async {
    await _db.collection('cofrades').doc(id).delete();
  }

  Future<String> createCofradeForAdmin(Map<String, dynamic> data) async {
    if (data.containsKey('fecha_nacimiento') ||
        data.containsKey('fecha_nacimiento_str')) {
      final birth = Cofrade.parseBirthDate(
        data['fecha_nacimiento'] ?? data['fecha_nacimiento_str'],
      );
      data.addAll(Cofrade.birthDateFields(birth));
    }
    if (data['numero'] == null) {
      final active = await _db
          .collection('cofrades')
          .where('estado', isEqualTo: 'Activo')
          .get();
      final maxNumber = active.docs
          .where((doc) =>
              !doc.id.startsWith('ADM-') &&
              doc.data()['es_cuenta_servicio'] != true)
          .map((doc) => (doc.data()['numero'] as num?)?.toInt() ?? 0)
          .fold<int>(0, (max, value) => value > max ? value : max);
      data['numero'] = maxNumber + 1;
    }
    final createdId = await _db.runTransaction<String>((transaction) async {
      final counterRef = _db.collection('app_config').doc('cofrades_counter');
      final counterSnap = await transaction.get(counterRef);
      final last = counterSnap.exists
          ? (counterSnap.data()?['last_internal_id'] as num?)?.toInt() ?? 0
          : 0;
      var next = last + 1;
      late DocumentReference<Map<String, dynamic>> cofradeRef;
      late String internalId;
      var attempts = 0;

      do {
        internalId = 'COF-${next.toString().padLeft(6, '0')}';
        cofradeRef = _db.collection('cofrades').doc(internalId);
        final existing = await transaction.get(cofradeRef);
        if (!existing.exists) break;
        next++;
        attempts++;
      } while (attempts < 1000);

      if (attempts >= 1000) {
        throw StateError(
            'No se pudo generar un ID interno libre para cofrades.');
      }

      transaction.set(
          counterRef,
          {
            'last_internal_id': next,
            'fecha_actualizacion': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
      transaction.set(cofradeRef, {
        ...data,
        'id_interno': internalId,
        'rol': data['rol'] ?? 'cofrade',
        'role': data['role'] ?? data['rol'] ?? 'cofrade',
        'roles': data['roles'] ?? <String>[],
        'estado': data['estado'] ?? 'Activo',
        'status': data['status'] ?? 'active',
        'isActive': data['isActive'] ?? true,
        'cuotaActiva': data['cuotaActiva'] ?? true,
        'tiene_cuota': data['tiene_cuota'] ?? true,
        'tags_manual': data['tags_manual'] ?? <String>[],
        'tags_auto': data['tags_auto'] ?? <String>[],
        'fecha_creacion': FieldValue.serverTimestamp(),
        'fecha_actualizacion': FieldValue.serverTimestamp(),
      });
      debugPrint(
          '[Firestore] createCofradeForAdmin transaction: created $internalId from counter last=$last');
      return internalId;
    });
    await createAuditLog(
      action: 'cofrade_created',
      targetId: createdId,
      targetType: 'cofrade',
      targetNombre: '${data['nombre'] ?? ''} ${data['apellidos'] ?? ''}'.trim(),
      changedBy: 'system',
      oldValue: null,
      newValue: data,
    );
    return createdId;
  }

  Future<void> createWelcomeNovedadForCofrade(String cofradeId) async {
    final existing = await _db
        .collection('novedades')
        .where('tipo', isEqualTo: 'cofrade_created')
        .where('target_cofrade_id', isEqualTo: cofradeId)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return;
    await _db.collection('novedades').add({
      'tipo': 'cofrade_created',
      'titulo': 'Bienvenido/a',
      'mensaje':
          'Tu perfil de cofrade ha sido creado. Revisa y completa tus datos.',
      'target_cofrade_id': cofradeId,
      'created_at': FieldValue.serverTimestamp(),
      'read': false,
      'active': true,
    });
  }

  // --- Tags cofrades ---
  Stream<List<TagConfig>> getTagsConfig() {
    return _db.collection('tags_config').orderBy('nombre').snapshots().map(
          (snapshot) =>
              snapshot.docs.map((doc) => TagConfig.fromFirestore(doc)).toList(),
        );
  }

  Stream<List<TagConfig>> getUsedTagsConfig() {
    return _db
        .collection('tags_config')
        .orderBy('nombre')
        .snapshots()
        .asyncMap((snapshot) async {
      final used = <TagConfig>[];
      for (final doc in snapshot.docs) {
        final tag = TagConfig.fromFirestore(doc);
        if (tag.id == 'faltan_datos') continue;
        if (await countCofradesWithTag(tag.id) > 0) {
          used.add(tag);
        }
      }
      return used;
    });
  }

  Future<void> saveTagConfig(TagConfig tag) async {
    if (tag.nombre.trim().isEmpty) {
      throw ArgumentError('El nombre del tag es obligatorio.');
    }
    final ref = tag.id.isEmpty
        ? _db.collection('tags_config').doc()
        : _db.collection('tags_config').doc(tag.id);
    final payload = {
      ...tag.toFirestore(),
      'id': ref.id,
      'nombre': tag.nombre.trim(),
      'descripcion': tag.descripcion.trim(),
      'color': _normalizeHexColor(tag.color),
    };
    debugPrint(
        '[Firestore] saveTagConfig: doc=${ref.id} nombre=${payload['nombre']} tipo=${payload['tipo']}');
    await ref.set(payload, SetOptions(merge: true));
    await createAuditLog(
      action: tag.id.isEmpty ? 'tag_created' : 'tag_updated',
      targetId: ref.id,
      targetType: 'tags_config',
      targetNombre: tag.nombre.trim(),
      changedBy: 'system',
      newValue: payload,
    );
    debugPrint('[Firestore] saveTagConfig: OK doc=${ref.id}');
  }

  String _normalizeHexColor(String value) {
    final raw = value.trim();
    final hex = raw.startsWith('#') ? raw : '#$raw';
    return RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(hex)
        ? hex.toUpperCase()
        : '#607D8B';
  }

  Future<void> deleteTagConfig(String tagId,
      {required String changedBy}) async {
    final tagRef = _db.collection('tags_config').doc(tagId);
    final tagSnap = await tagRef.get();
    if (!tagSnap.exists) return;
    final manualSnap = await _db
        .collection('cofrades')
        .where('tags_manual', arrayContains: tagId)
        .get();
    final autoSnap = await _db
        .collection('cofrades')
        .where('tags_auto', arrayContains: tagId)
        .get();
    final affected = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in manualSnap.docs) {
      affected[doc.id] = doc;
    }
    for (final doc in autoSnap.docs) {
      affected[doc.id] = doc;
    }
    final batch = _db.batch();
    for (final doc in affected.values) {
      batch.update(doc.reference, {
        'tags_manual': FieldValue.arrayRemove([tagId]),
        'tags_auto': FieldValue.arrayRemove([tagId]),
        'fecha_actualizacion': FieldValue.serverTimestamp(),
      });
    }
    batch.delete(tagRef);
    await batch.commit();
    await createAuditLog(
      action: 'tag_deleted',
      targetId: tagId,
      targetType: 'tags_config',
      targetNombre: '${tagSnap.data()?['nombre'] ?? tagId}',
      changedBy: changedBy,
      oldValue: tagSnap.data(),
      metadata: {'affected_cofrades': affected.length},
    );
  }

  Stream<List<CofradeFieldConfig>> getCofradeFieldsConfig() {
    return _db
        .collection('cofrade_fields_config')
        .orderBy('order')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CofradeFieldConfig.fromFirestore(doc))
            .toList());
  }

  Future<void> saveCofradeFieldConfig(CofradeFieldConfig config) async {
    if (config.fieldKey.trim().isEmpty || config.label.trim().isEmpty) {
      throw ArgumentError('La clave y la etiqueta son obligatorias.');
    }
    final ref = config.id.isEmpty
        ? _db.collection('cofrade_fields_config').doc(config.fieldKey.trim())
        : _db.collection('cofrade_fields_config').doc(config.id);
    final before = await ref.get();
    await ref.set(config.toFirestore(), SetOptions(merge: true));
    await createAuditLog(
      action: 'required_fields_config_updated',
      targetId: ref.id,
      targetType: 'cofrade_fields_config',
      targetNombre: config.label,
      changedBy: 'system',
      oldValue: before.data(),
      newValue: {
        'field_key': config.fieldKey,
        'label': config.label,
        'required': config.required,
        'active': config.active,
      },
    );
  }

  Future<void> seedDefaultCofradeFieldsConfig() async {
    final detected = <String>{};
    final cofradesSnap = await _db.collection('cofrades').limit(200).get();
    for (final doc in cofradesSnap.docs) {
      detected.addAll(doc.data().keys);
    }
    final existingSnap = await _db.collection('cofrade_fields_config').get();
    final existingKeys = existingSnap.docs.map((doc) => doc.id).toSet();
    final fields = <List<Object>>[
      ['nombre', 'Nombre', 'string', true],
      ['apellidos', 'Apellidos', 'string', true],
      ['dni', 'DNI/NIF', 'string', false],
      ['email', 'Email', 'string', true],
      ['telefono_movil', 'Teléfono móvil', 'string', true],
      ['telefono_fijo', 'Teléfono fijo', 'string', false],
      ['fecha_nacimiento_str', 'Fecha de nacimiento', 'date', true],
      ['genero', 'Género', 'select', false],
      ['domicilio', 'Domicilio', 'string', false],
      ['localidad', 'Localidad', 'string', false],
      ['numero', 'Número de cofrade', 'number', false],
      ['anio_alta', 'Año de alta', 'number', false],
      ['anios_hermandad', 'Años en hermandad', 'number', false],
      ['anio_mayordomia', 'Año de mayordomía', 'number', false],
      ['cuotaActiva', 'Cuota activa', 'boolean', false],
      ['tiene_cuota', 'Tiene cuota', 'boolean', false],
      ['cuota_metalico', 'Cuota metálico', 'boolean', false],
      ['cuota_domiciliada', 'Cuota domiciliada', 'boolean', false],
      ['iban', 'IBAN', 'string', false],
      ['titular_iban', 'Titular IBAN', 'string', false],
      ['gdpr_papel', 'GDPR firmado en papel', 'boolean', false],
      ['gdprDigitalAccepted', 'GDPR digital aceptado', 'boolean', false],
      ['requiresDigitalTutor', 'Requiere tutela digital', 'boolean', false],
      ['digitalTutorName', 'Nombre tutor', 'string', false],
      ['digitalTutorDni', 'DNI tutor', 'string', false],
      ['digitalTutorPhone', 'Teléfono tutor', 'string', false],
      ['digitalTutorEmail', 'Email tutor', 'string', false],
      ['digitalTutorRelationship', 'Parentesco tutor', 'string', false],
      ['portador', 'Portador', 'boolean', false],
      ['tiene_tunica_propia', 'Túnica propia', 'boolean', false],
      ['lastLoginAt', 'Último acceso', 'date', false],
      ['firstLoginAt', 'Primer acceso', 'date', false],
      ['hasLoggedIn', 'Ha accedido a la app', 'boolean', false],
      ['loginCount', 'Número de accesos', 'number', false],
      ['lastLoginMethod', 'Último método de acceso', 'select', false],
      ['linkedAuthProviders', 'Métodos de acceso vinculados', 'string', false],
      for (final key in detected)
        if (!_knownFieldKeys.contains(key))
          [key, _humanizeFieldKey(key), _inferFieldType(key), false],
    ];
    final batch = _db.batch();
    for (var i = 0; i < fields.length; i++) {
      final field = fields[i];
      final key = field[0] as String;
      if (existingKeys.contains(key)) continue;
      final ref = _db.collection('cofrade_fields_config').doc(key);
      batch.set(
        ref,
        CofradeFieldConfig(
          id: key,
          fieldKey: key,
          label: field[1] as String,
          type: field[2] as String,
          required: field[3] as bool,
          order: i,
          options: key == 'genero'
              ? const ['Hombre', 'Mujer']
              : key == 'lastLoginMethod'
                  ? const ['google', 'password', 'dni']
                  : const [],
        ).toFirestore(),
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  static const Set<String> _knownFieldKeys = {
    'nombre',
    'apellidos',
    'dni',
    'email',
    'telefono_movil',
    'telefono_fijo',
    'fecha_nacimiento_str',
    'genero',
    'domicilio',
    'localidad',
    'numero',
    'anio_alta',
    'anios_hermandad',
    'anio_mayordomia',
    'cuotaActiva',
    'tiene_cuota',
    'cuota_metalico',
    'cuota_domiciliada',
    'iban',
    'titular_iban',
    'gdpr_papel',
    'gdprDigitalAccepted',
    'requiresDigitalTutor',
    'digitalTutorName',
    'digitalTutorDni',
    'digitalTutorPhone',
    'digitalTutorEmail',
    'digitalTutorRelationship',
    'portador',
    'tiene_tunica_propia',
    'lastLoginAt',
    'firstLoginAt',
    'hasLoggedIn',
    'loginCount',
    'lastLoginMethod',
    'linkedAuthProviders',
  };

  String _humanizeFieldKey(String key) {
    return key
        .replaceAll('_', ' ')
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'),
            (match) => '${match.group(1)} ${match.group(2)}')
        .trim()
        .split(' ')
        .map((part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String _inferFieldType(String key) {
    final lower = key.toLowerCase();
    if (lower.contains('date') ||
        lower.contains('fecha') ||
        lower.endsWith('at')) {
      return 'date';
    }
    if (lower.startsWith('is') ||
        lower.startsWith('has') ||
        lower.contains('gdpr') ||
        lower.contains('cuota') ||
        lower.contains('tutor')) {
      return 'boolean';
    }
    if (lower.contains('numero') ||
        lower.contains('anio') ||
        lower.contains('count') ||
        lower.contains('edad')) {
      return 'number';
    }
    return 'string';
  }

  List<CofradeFieldConfig> getMissingRequiredFields(
    Cofrade cofrade,
    List<CofradeFieldConfig> fieldsConfig,
  ) {
    return fieldsConfig.where((field) {
      if (!field.active || !field.required || !field.visibleInPrivateProfile) {
        return false;
      }
      if (_isGdprRequiredField(field.fieldKey)) {
        return !cofrade.gdprPapel;
      }
      if (_isAnyGdprRequiredField(field.fieldKey)) {
        return !(cofrade.gdprPapel ||
            cofrade.gdprDigitalAccepted ||
            cofrade.gdprFirmado);
      }
      final value = cofrade.valueForFieldKey(field.fieldKey);
      if (value == null) return true;
      if (value is String) return value.trim().isEmpty;
      if (value is Iterable) return value.isEmpty;
      if (field.fieldKey == 'gdpr_firmado' && value is bool) return !value;
      return false;
    }).toList();
  }

  bool _isGdprRequiredField(String key) {
    return {
      'gdpr_papel',
      'gdprPapel',
      'gdprFirmadoPapel',
    }.contains(key);
  }

  bool _isAnyGdprRequiredField(String key) {
    return {
      'gdpr_firmado',
      'gdpr_firmado_digital',
      'gdprDigitalAccepted',
    }.contains(key);
  }

  Future<void> createAuditLog({
    required String action,
    required String targetId,
    String targetType = '',
    required String targetNombre,
    required String changedBy,
    Object? oldValue,
    Object? newValue,
    Map<String, dynamic>? metadata,
  }) async {
    await _db.collection('audit_logs').add({
      'action': action,
      'target_id': targetId,
      'target_type': targetType,
      'target_nombre': targetNombre,
      'changed_by': changedBy,
      'changed_at': FieldValue.serverTimestamp(),
      'old_value': _safeAuditValue(oldValue),
      'new_value': _safeAuditValue(newValue),
      'metadata': metadata ?? {},
    });
  }

  bool _isActiveGdprPaperDocument(Map<String, dynamic> data) {
    final type = '${data['type'] ?? ''}';
    final subtype = '${data['subtype'] ?? ''}';
    final status = '${data['status'] ?? ''}';
    final isPaper = type == 'GDPR_PAPEL' ||
        subtype == 'GDPR_PAPEL' ||
        (type == 'GDPR' && subtype == 'GDPR_PAPEL');
    return isPaper &&
        const {'valid', 'active', 'pending_validation'}.contains(status);
  }

  Future<void> syncGdprPaperStatus({
    required String cofradeId,
    String changedBy = 'system',
  }) async {
    final docs = await _db
        .collection('cofrades')
        .doc(cofradeId)
        .collection('documents')
        .get();
    final activePaperDocs = docs.docs
        .where((doc) => _isActiveGdprPaperDocument(doc.data()))
        .toList();
    final hasPaper = activePaperDocs.isNotEmpty;
    final cofradeRef = _db.collection('cofrades').doc(cofradeId);
    final cofradeSnap = await cofradeRef.get();
    final data = cofradeSnap.data() ?? {};
    final current = data['gdprPapel'] == true ||
        data['gdprFirmadoPapel'] == true ||
        data['gdpr_papel'] == true;
    final currentDocId = data['gdprPapelDocumentId'];
    final nextDocId = hasPaper ? activePaperDocs.first.id : null;
    if (current == hasPaper && currentDocId == nextDocId) return;
    await updateCofrade(
      cofradeId,
      {
        'gdpr_papel': hasPaper,
        'gdprPapel': hasPaper,
        'gdprFirmadoPapel': hasPaper,
        'gdpr_firmado': hasPaper,
        'gdprPapelUpdatedAt': FieldValue.serverTimestamp(),
        'gdprPapelDocumentId': nextDocId,
      },
      changedBy: changedBy,
      changedByRole: 'system',
    );
  }

  Future<Map<String, dynamic>> resolveGdprPapelStatus(String cofradeId) async {
    final docs = await _db
        .collection('cofrades')
        .doc(cofradeId)
        .collection('documents')
        .get();
    final activePaperDocs = docs.docs
        .where((doc) => _isActiveGdprPaperDocument(doc.data()))
        .toList();
    if (activePaperDocs.isNotEmpty) {
      await syncGdprPaperStatus(cofradeId: cofradeId);
      return {
        'hasGdprPapel': true,
        'documentId': activePaperDocs.first.id,
        'source': 'document',
      };
    }
    final cofradeSnap = await _db.collection('cofrades').doc(cofradeId).get();
    final data = cofradeSnap.data() ?? {};
    final hasField = data['gdprPapel'] == true ||
        data['gdprFirmadoPapel'] == true ||
        data['gdpr_papel'] == true;
    return {
      'hasGdprPapel': hasField,
      'documentId': data['gdprPapelDocumentId'],
      'source': hasField ? 'field' : 'none',
    };
  }

  Stream<Map<String, dynamic>?> watchGdprPaperDocument(String cofradeId) {
    return _db
        .collection('cofrades')
        .doc(cofradeId)
        .collection('documents')
        .snapshots()
        .asyncMap((snapshot) async {
      final docs = snapshot.docs
          .where((doc) => _isActiveGdprPaperDocument(doc.data()))
          .toList();
      docs.sort((a, b) {
        final at = a.data()['uploadedAt'] ?? a.data()['createdAt'];
        final bt = b.data()['uploadedAt'] ?? b.data()['createdAt'];
        if (at is Timestamp && bt is Timestamp) return bt.compareTo(at);
        return 0;
      });
      await syncGdprPaperStatus(cofradeId: cofradeId);
      if (docs.isEmpty) return null;
      return {'id': docs.first.id, ...docs.first.data()};
    });
  }

  Stream<List<Map<String, dynamic>>> watchGdprDocuments(String cofradeId) {
    return _db
        .collection('cofrades')
        .doc(cofradeId)
        .collection('documents')
        .snapshots()
        .map((snapshot) {
      final docs = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .where((doc) =>
              (['GDPR_PAPEL', 'GDPR_DIGITAL'].contains(doc['type']) ||
                  (doc['type'] == 'GDPR' &&
                      ['GDPR_PAPEL', 'GDPR_DIGITAL']
                          .contains(doc['subtype']))) &&
              ['valid', 'active', 'pending_validation'].contains(doc['status']))
          .toList();
      docs.sort((a, b) => '${a['type']}'.compareTo('${b['type']}'));
      return docs;
    });
  }

  Stream<List<Map<String, dynamic>>> watchPrivateDocuments(
    String cofradeId, {
    bool onlyVisibleToCofrade = false,
  }) {
    return _db
        .collection('cofrades')
        .doc(cofradeId)
        .collection('documents')
        .snapshots()
        .map((snapshot) {
      final docs = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .where((doc) =>
              doc['isPrivate'] == true &&
              doc['status'] == 'active' &&
              (!onlyVisibleToCofrade || doc['visibleToCofrade'] == true))
          .toList();
      docs.sort((a, b) {
        final at = a['uploadedAt'] ?? a['createdAt'];
        final bt = b['uploadedAt'] ?? b['createdAt'];
        if (at is Timestamp && bt is Timestamp) return bt.compareTo(at);
        return '${a['title'] ?? ''}'.compareTo('${b['title'] ?? ''}');
      });
      return docs;
    });
  }

  Future<void> savePrivateDocument({
    required String cofradeId,
    required Map<String, String> upload,
    required String title,
    required String type,
    String subtype = '',
    bool visibleToCofrade = true,
    String comments = '',
    required String performedBy,
  }) async {
    final docsRef =
        _db.collection('cofrades').doc(cofradeId).collection('documents');
    final payload = {
      'cofradeId': cofradeId,
      'title': title.trim().isEmpty ? upload['nombre'] : title.trim(),
      'type': type,
      'subtype': subtype,
      'storagePath': upload['storage_path'],
      'downloadUrl': upload['url'],
      'fileName': upload['nombre'],
      'mimeType': upload['tipo'],
      'sizeBytes': int.tryParse(upload['tamano_bytes'] ?? ''),
      'uploadedAt': FieldValue.serverTimestamp(),
      'uploadedBy': performedBy,
      'visibleToCofrade': visibleToCofrade,
      'isPrivate': true,
      'status': 'active',
      'comments': comments,
    };
    final doc = await docsRef.add(payload);
    if (type == 'GDPR_PAPEL' || subtype == 'GDPR_PAPEL') {
      await syncGdprPaperStatus(cofradeId: cofradeId, changedBy: performedBy);
    }
    await createAuditLog(
      action: 'private_document_uploaded',
      targetId: cofradeId,
      targetType: 'cofrade',
      targetNombre: cofradeId,
      changedBy: performedBy,
      newValue: payload,
      metadata: {'document_id': doc.id, 'storagePath': upload['storage_path']},
    );
  }

  Future<void> deletePrivateDocument({
    required String cofradeId,
    required String documentId,
    required String performedBy,
  }) async {
    final ref = _db
        .collection('cofrades')
        .doc(cofradeId)
        .collection('documents')
        .doc(documentId);
    final before = await ref.get();
    await ref.update({
      'status': 'deleted',
      'deletedAt': FieldValue.serverTimestamp(),
      'deletedBy': performedBy,
    });
    final beforeData = before.data();
    if (beforeData != null && _isActiveGdprPaperDocument(beforeData)) {
      await syncGdprPaperStatus(cofradeId: cofradeId, changedBy: performedBy);
    }
    await createAuditLog(
      action: 'private_document_deleted',
      targetId: cofradeId,
      targetType: 'cofrade',
      targetNombre: cofradeId,
      changedBy: performedBy,
      oldValue: before.data(),
      metadata: {'document_id': documentId},
    );
  }

  Future<void> saveGdprPaperDocument({
    required String cofradeId,
    required Map<String, String> upload,
    required String performedBy,
    required String source,
    bool pendingValidation = false,
  }) async {
    final docsRef =
        _db.collection('cofrades').doc(cofradeId).collection('documents');
    final existingAll = await docsRef.get();
    final existingDocs = existingAll.docs
        .where((doc) => _isActiveGdprPaperDocument(doc.data()))
        .toList();
    final isReplacement = existingDocs.isNotEmpty;
    if (isReplacement) {
      await existingDocs.first.reference.update({
        'status': 'deleted',
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedBy': performedBy,
      });
    }
    final payload = {
      'type': 'GDPR_PAPEL',
      'subtype': 'GDPR_PAPEL',
      'title': 'GDPR firmado en papel',
      'cofradeId': cofradeId,
      'storagePath': upload['storage_path'],
      'downloadUrl': upload['url'],
      'fileName': upload['nombre'],
      'mimeType': upload['tipo'],
      'sizeBytes': int.tryParse(upload['tamano_bytes'] ?? ''),
      'uploadedAt': FieldValue.serverTimestamp(),
      'uploadedBy': performedBy,
      'validatedAt': pendingValidation ? null : FieldValue.serverTimestamp(),
      'validatedBy': pendingValidation ? null : performedBy,
      'status': pendingValidation ? 'pending_validation' : 'valid',
      'isPrivate': true,
      'visibleToCofrade': true,
    };
    final doc = await docsRef.add(payload);
    await updateCofrade(
      cofradeId,
      {
        'gdpr_papel': true,
        'gdprPapel': true,
        'gdprFirmadoPapel': true,
        'gdpr_firmado': true,
        'gdprPapelUpdatedAt': FieldValue.serverTimestamp(),
        'gdprPapelDocumentId': doc.id,
      },
      changedBy: performedBy,
      changedByRole: source,
    );
    await createAuditLog(
      action:
          isReplacement ? 'gdpr_document_replaced' : 'gdpr_document_uploaded',
      targetId: cofradeId,
      targetType: 'cofrade',
      targetNombre: cofradeId,
      changedBy: performedBy,
      oldValue: isReplacement ? existingDocs.first.data() : null,
      newValue: payload,
      metadata: {
        'document_id': doc.id,
        'storagePath': upload['storage_path'],
        'source': source,
      },
    );
  }

  Future<void> deleteGdprPaperDocument({
    required String cofradeId,
    required String documentId,
    required String performedBy,
  }) async {
    final ref = _db
        .collection('cofrades')
        .doc(cofradeId)
        .collection('documents')
        .doc(documentId);
    final before = await ref.get();
    await ref.update({
      'status': 'deleted',
      'deletedAt': FieldValue.serverTimestamp(),
      'deletedBy': performedBy,
    });
    final remaining = await _db
        .collection('cofrades')
        .doc(cofradeId)
        .collection('documents')
        .get();
    final hasRemaining =
        remaining.docs.any((doc) => _isActiveGdprPaperDocument(doc.data()));
    if (!hasRemaining) {
      await updateCofrade(
        cofradeId,
        {
          'gdpr_papel': false,
          'gdprPapel': false,
          'gdprFirmadoPapel': false,
          'gdpr_firmado': false,
          'gdprPapelUpdatedAt': FieldValue.serverTimestamp(),
          'gdprPapelDocumentId': null,
        },
        changedBy: performedBy,
        changedByRole: 'admin_panel',
      );
    }
    await createAuditLog(
      action: 'gdpr_document_deleted',
      targetId: cofradeId,
      targetType: 'cofrade',
      targetNombre: cofradeId,
      changedBy: performedBy,
      oldValue: before.data(),
      metadata: {'document_id': documentId, 'source': 'admin_panel'},
    );
  }

  Future<void> acceptDigitalGdprConsent({
    required Cofrade cofrade,
    required String acceptedByUid,
    required String acceptedByEmail,
    required Map<String, dynamic> consent,
    required Map<String, bool> checkboxes,
    String? documentId,
  }) async {
    final version = '${consent['versionId'] ?? 'gdpr-rgpd-v1'}';
    final legalText = '${consent['legalText'] ?? ''}';
    final hash = sha256.convert(utf8.encode(legalText)).toString();
    final isTutorSignature = cofrade.requiresDigitalTutor;
    if (isTutorSignature &&
        (cofrade.digitalTutorName.trim().isEmpty ||
            cofrade.digitalTutorDni.trim().isEmpty ||
            cofrade.digitalTutorRelationship.trim().isEmpty)) {
      throw StateError(
        'Faltan datos obligatorios del tutor digital. Contacta con la Cofradía.',
      );
    }
    final consentRef = _db
        .collection('cofrades')
        .doc(cofrade.id)
        .collection('consents')
        .doc(version);
    final snap = await consentRef.get();
    final payload = {
      'cofradeId': cofrade.id,
      'consentVersionId': version,
      'accepted': true,
      'acceptedAt': FieldValue.serverTimestamp(),
      'acceptedByUid': acceptedByUid,
      'acceptedByEmail': acceptedByEmail,
      'legalTextHash': hash,
      'legalTextSnapshot': legalText,
      'checkboxesAccepted': checkboxes,
      'signedByType': isTutorSignature ? 'digital_tutor' : 'cofrade',
      'signedByName':
          isTutorSignature ? cofrade.digitalTutorName : cofrade.nombreCompleto,
      'signedByDni':
          isTutorSignature ? cofrade.digitalTutorDni : (cofrade.dni ?? ''),
      'signedForCofradeId': cofrade.id,
      'signedForCofradeName': cofrade.nombreCompleto,
      'signedByRelationship':
          isTutorSignature ? cofrade.digitalTutorRelationship : '',
      'source': 'private_app',
      'status': 'accepted',
      'revokedAt': null,
      'revocationRequestedAt': null,
      'revocationReason': null,
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (!(snap.exists && snap.data()?['accepted'] == true)) {
      await consentRef.set(payload);
    }
    await updateCofrade(
      cofrade.id,
      {
        'gdpr_firmado_digital': true,
        'gdprDigitalAccepted': true,
        'gdprDigitalAcceptedAt': FieldValue.serverTimestamp(),
        'gdprDigitalConsentVersion': version,
        'gdprDigitalConsentHash': hash,
        if (documentId != null) 'gdprDigitalDocumentId': documentId,
        'gdprDigitalRevoked': false,
        'communications_consent': checkboxes['communications'] == true,
        'gdprDigitalStatus': 'accepted',
        'gdprDigitalReacceptanceRequired': false,
      },
      changedBy: cofrade.id,
      changedByRole: 'cofrade',
      markPendingReview: false,
    );
    await createAuditLog(
      action: 'gdpr_digital_consent_accepted',
      targetId: cofrade.id,
      targetType: 'cofrade',
      targetNombre: cofrade.nombreCompleto,
      changedBy: cofrade.id,
      newValue: {
        'consentVersion': version,
        'legalTextHash': hash,
        'signedByType': isTutorSignature ? 'digital_tutor' : 'cofrade',
      },
      metadata: {'source': 'private_app'},
    );
  }

  Future<String> saveGdprDigitalDocument({
    required Cofrade cofrade,
    required Map<String, String> upload,
    required String consentVersion,
    required String legalTextHash,
    required String performedBy,
    Map<String, dynamic>? signatureMetadata,
  }) async {
    final docsRef =
        _db.collection('cofrades').doc(cofrade.id).collection('documents');
    final safeVersion =
        consentVersion.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
    final docRef = docsRef.doc('gdpr_digital_$safeVersion');
    final existing = await docRef.get();
    if (existing.exists && existing.data()?['status'] == 'valid') {
      return docRef.id;
    }
    final payload = {
      'type': 'GDPR',
      'subtype': 'GDPR_DIGITAL',
      'title': 'Consentimiento digital',
      'cofradeId': cofrade.id,
      'storagePath': upload['storage_path'],
      'downloadUrl': upload['url'],
      'fileName': upload['nombre'] ?? 'Consentimiento digital.pdf',
      'mimeType': upload['tipo'],
      'sizeBytes': int.tryParse(upload['tamano_bytes'] ?? ''),
      'consentVersion': consentVersion,
      'acceptedAt': FieldValue.serverTimestamp(),
      'uploadedAt': FieldValue.serverTimestamp(),
      'uploadedBy': performedBy,
      'validatedAt': FieldValue.serverTimestamp(),
      'validatedBy': performedBy,
      'legalTextHash': legalTextHash,
      if (signatureMetadata != null) ...signatureMetadata,
      'status': 'valid',
      'isPrivate': true,
      'visibleToCofrade': true,
    };
    await docRef.set(payload, SetOptions(merge: true));
    await createAuditLog(
      action: 'gdpr_digital_consent_pdf_generated',
      targetId: cofrade.id,
      targetType: 'cofrade',
      targetNombre: cofrade.nombreCompleto,
      changedBy: performedBy,
      newValue: payload,
      metadata: {
        'document_id': docRef.id,
        'storagePath': upload['storage_path'],
        'source': 'private_app',
      },
    );
    return docRef.id;
  }

  Future<void> requestGdprDigitalRevocation({
    required Cofrade cofrade,
    required String performedBy,
    String performedByRole = 'cofrade',
    String reason = '',
  }) async {
    final version = cofrade.gdprDigitalConsentVersion ?? 'gdpr-rgpd-v1';
    final consentRef = _db
        .collection('cofrades')
        .doc(cofrade.id)
        .collection('consents')
        .doc(version);
    final consentSnap = await consentRef.get();
    final oldConsent = consentSnap.data();
    final updatePayload = {
      'cofradeId': cofrade.id,
      'consentVersionId': version,
      'status': 'revocation_requested',
      'consentStatus': 'revocation_requested',
      'revocationRequestedAt': FieldValue.serverTimestamp(),
      'revocationRequestedBy': performedBy,
      'revocationRequestedByRole': performedByRole,
      'originalSignedAt': cofrade.gdprDigitalAcceptedAt != null
          ? Timestamp.fromDate(cofrade.gdprDigitalAcceptedAt!)
          : oldConsent?['acceptedAt'],
      'updatedAt': FieldValue.serverTimestamp(),
      if (reason.trim().isNotEmpty) 'revocationReason': reason.trim(),
    };
    await consentRef.set(updatePayload, SetOptions(merge: true));
    await updateCofrade(
      cofrade.id,
      {
        'gdprDigitalStatus': 'revocation_requested',
        'communications_consent': false,
        'gdprDigitalRevocationRequestedAt': FieldValue.serverTimestamp(),
        'gdprDigitalRevocationRequestedBy': performedBy,
      },
      changedBy: performedBy,
      changedByRole: performedByRole,
      markPendingReview: false,
    );
    await createAuditLog(
      action: 'consent_revocation_requested',
      targetId: cofrade.id,
      targetType: 'consent',
      targetNombre: cofrade.nombreCompleto,
      changedBy: performedBy,
      oldValue: {'gdprDigitalStatus': cofrade.gdprDigitalStatus},
      newValue: {
        'gdprDigitalStatus': 'revocation_requested',
        'consentId': version,
      },
      metadata: {
        'entityType': 'consent',
        'entityId': version,
        'cofradeId': cofrade.id,
        'changedByRole': performedByRole,
        'reason': reason,
        'source':
            performedByRole == 'admin' ? 'admin_panel' : 'private_profile',
      },
    );
  }

  Future<void> reacceptDigitalConsentByAdmin({
    required Cofrade cofrade,
    required String changedBy,
    required String changedByRole,
    required String reason,
    required String notes,
  }) async {
    if (reason.trim().isEmpty || notes.trim().isEmpty) {
      throw StateError('Motivo y observaciones son obligatorios.');
    }
    final version = cofrade.gdprDigitalConsentVersion ?? 'gdpr-rgpd-v1';
    final consentRef = _db
        .collection('cofrades')
        .doc(cofrade.id)
        .collection('consents')
        .doc(version);
    final before = await consentRef.get();
    await consentRef.set({
      'cofradeId': cofrade.id,
      'consentVersionId': version,
      'status': 'accepted',
      'consentStatus': 'signed',
      'accepted': true,
      'acceptedAgainAt': FieldValue.serverTimestamp(),
      'acceptedAgainBy': changedBy,
      'acceptedAgainReason': reason.trim(),
      'acceptedAgainNotes': notes.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await updateCofrade(
      cofrade.id,
      {
        'gdprDigitalAccepted': true,
        'gdpr_firmado_digital': true,
        'gdprDigitalRevoked': false,
        'gdprDigitalStatus': 'accepted',
        'gdprDigitalReacceptanceRequired': false,
        'gdprDigitalAcceptedAgainAt': FieldValue.serverTimestamp(),
        'gdprDigitalAcceptedAgainBy': changedBy,
        'gdprDigitalAcceptedAgainReason': reason.trim(),
        'gdprDigitalAcceptedAgainNotes': notes.trim(),
      },
      changedBy: changedBy,
      changedByRole: changedByRole,
      markPendingReview: false,
    );
    await createAuditLog(
      action: 'consent_reaccepted_by_admin',
      targetId: cofrade.id,
      targetType: 'consent',
      targetNombre: cofrade.nombreCompleto,
      changedBy: changedBy,
      oldValue: before.data() ?? {'status': cofrade.gdprDigitalStatus},
      newValue: {'status': 'signed'},
      metadata: {
        'entityType': 'consent',
        'entityId': version,
        'cofradeId': cofrade.id,
        'changedByRole': changedByRole,
        'reason': reason.trim(),
        'notes': notes.trim(),
      },
    );
  }

  Stream<List<Map<String, dynamic>>> watchConversations(String cofradeId) {
    return _db
        .collection('conversations')
        .where('cofradeId', isEqualTo: cofradeId)
        .snapshots()
        .map((snapshot) {
      final items =
          snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      items.sort((a, b) {
        final at = a['lastMessageAt'];
        final bt = b['lastMessageAt'];
        if (at is Timestamp && bt is Timestamp) return bt.compareTo(at);
        return 0;
      });
      return items;
    });
  }

  Stream<List<Map<String, dynamic>>> watchConversationMessages(
    String cofradeId,
    String conversationId,
  ) {
    return _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  Stream<List<Map<String, dynamic>>> watchAllConversations() {
    return _db.collection('conversations').snapshots().map((snapshot) {
      final items =
          snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      items.sort((a, b) {
        final at = a['lastMessageAt'];
        final bt = b['lastMessageAt'];
        if (at is Timestamp && bt is Timestamp) return bt.compareTo(at);
        return 0;
      });
      return items;
    });
  }

  Stream<int> getPendingConversationsForAdminCountStream() {
    return _db
        .collection('conversations')
        .where('status', isEqualTo: 'pending_admin')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<String> startConversation({
    required String cofradeId,
    required String subject,
    required String body,
    required String createdBy,
    required String createdByRole,
    String priority = 'normal',
    String type = 'admin_message',
    String origin = 'admin',
    String cofradeName = '',
  }) async {
    final convRef = _db.collection('conversations').doc();
    final isAdminOrigin = origin == 'admin';
    final batch = _db.batch();
    batch.set(convRef, {
      'cofradeId': cofradeId,
      'cofradeName': cofradeName,
      'type': type,
      'origin': origin,
      'subject': subject.trim(),
      'priority': priority,
      'status': isAdminOrigin ? 'pending_cofrade' : 'pending_admin',
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': createdBy,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageBy': createdBy,
      'unreadByAdmin': !isAdminOrigin,
      'unreadByCofrade': isAdminOrigin,
      'closedAt': null,
      'closedBy': null,
    });
    final msgRef = convRef.collection('messages').doc();
    batch.set(msgRef, {
      'body': body.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': createdBy,
      'createdByRole': createdByRole,
      'readAt': null,
      'attachments': [],
    });
    await batch.commit();
    await createAuditLog(
      action: 'private_conversation_started',
      targetId: cofradeId,
      targetType: 'cofrade',
      targetNombre: cofradeId,
      changedBy: createdBy,
      newValue: {'conversationId': convRef.id, 'subject': subject},
    );
    return convRef.id;
  }

  Future<void> replyConversation({
    required String cofradeId,
    required String conversationId,
    required String body,
    required String createdBy,
    required String createdByRole,
  }) async {
    final convRef = _db.collection('conversations').doc(conversationId);
    final convSnap = await convRef.get();
    if (convSnap.data()?['status'] == 'closed') {
      throw StateError('La conversación está cerrada.');
    }
    final isAdminReply = createdByRole.toLowerCase().contains('admin') ||
        createdByRole.toLowerCase() == 'tesorero' ||
        createdByRole.toLowerCase() == 'junta';
    await convRef.collection('messages').add({
      'body': body.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': createdBy,
      'createdByRole': createdByRole,
      'readAt': null,
      'attachments': [],
    });
    await convRef.update({
      'status': isAdminReply ? 'pending_cofrade' : 'pending_admin',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageBy': createdBy,
      'unreadByAdmin': !isAdminReply,
      'unreadByCofrade': isAdminReply,
    });
    await createAuditLog(
      action: 'private_conversation_message_sent',
      targetId: cofradeId,
      targetType: 'cofrade',
      targetNombre: cofradeId,
      changedBy: createdBy,
      metadata: {'conversationId': conversationId},
    );
  }

  Future<void> closeConversation({
    required String conversationId,
    required String cofradeId,
    required String closedBy,
  }) async {
    final ref = _db.collection('conversations').doc(conversationId);
    final before = await ref.get();
    await ref.update({
      'status': 'closed',
      'closedAt': FieldValue.serverTimestamp(),
      'closedBy': closedBy,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageBy': closedBy,
      'unreadByAdmin': false,
      'unreadByCofrade': false,
    });
    await createAuditLog(
      action: 'conversation_closed',
      targetId: cofradeId,
      targetType: 'cofrade',
      targetNombre: cofradeId,
      changedBy: closedBy,
      oldValue: before.data(),
      newValue: {'status': 'closed'},
      metadata: {'conversationId': conversationId},
    );
  }

  Future<void> reopenConversation({
    required String conversationId,
    required String cofradeId,
    required String reopenedBy,
  }) async {
    final ref = _db.collection('conversations').doc(conversationId);
    final before = await ref.get();
    await ref.update({
      'status': 'open',
      'closedAt': null,
      'closedBy': null,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageBy': reopenedBy,
      'unreadByAdmin': false,
      'unreadByCofrade': true,
    });
    await createAuditLog(
      action: 'conversation_reopened',
      targetId: cofradeId,
      targetType: 'cofrade',
      targetNombre: cofradeId,
      changedBy: reopenedBy,
      oldValue: before.data(),
      newValue: {'status': 'open'},
      metadata: {'conversationId': conversationId},
    );
  }

  Object? _safeAuditValue(Object? value) {
    if (value == null) return null;
    if (value is FieldValue) return '<serverTimestamp>';
    if (value is Timestamp ||
        value is String ||
        value is num ||
        value is bool) {
      return value;
    }
    if (value is Map) {
      return value.map((key, item) => MapEntry('$key', _safeAuditValue(item)));
    }
    if (value is Iterable) {
      return value.map(_safeAuditValue).toList();
    }
    return '$value';
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/${now.year}';
  }

  Stream<List<Map<String, dynamic>>> watchRoleAuditEntries() {
    return _db.collection('cofrades').snapshots().map((snapshot) {
      final entries = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final rol = '${data['rol'] ?? 'cofrade'}';
        final roles = (data['roles'] as List<dynamic>? ?? []).map((e) => '$e');
        final normalizedRoles = roles.map((role) => role.toLowerCase());
        final isService = data['es_cuenta_servicio'] == true;
        final isAdminAccount = rol.toLowerCase() == 'admin' ||
            normalizedRoles.contains('admin') ||
            normalizedRoles.contains('superadmin') ||
            isService;
        if (isAdminAccount) {
          entries.add({
            'id': doc.id,
            ...data,
            'roles': roles.toList(),
          });
        }
      }
      entries.sort((a, b) => '${a['id']}'.compareTo('${b['id']}'));
      return entries;
    });
  }

  Future<void> toggleTagConfig(String id, bool activo) async {
    await _db.collection('tags_config').doc(id).update({
      'activo': activo,
      'fecha_actualizacion': FieldValue.serverTimestamp(),
    });
  }

  Future<int> countCofradesWithTag(String tagId) async {
    final manual = await _db
        .collection('cofrades')
        .where('tags_manual', arrayContains: tagId)
        .count()
        .get();
    final auto = await _db
        .collection('cofrades')
        .where('tags_auto', arrayContains: tagId)
        .count()
        .get();
    return (manual.count ?? 0) + (auto.count ?? 0);
  }

  Future<void> seedDefaultManualTags() async {
    const names = [
      'Junta de Gobierno',
      'Protocolo',
      'Juventud',
      'Andas',
      'Costalero',
      'Música',
      'Coro',
      'Cultos',
      'Caridad',
      'Lotería',
      'Túnicas',
      'Colaborador habitual',
      'Donante',
      'Proveedor',
      'Pendiente contactar',
      'Datos incompletos',
      'Requiere revisión',
      'Familia vinculada',
      'Mayordomía',
      'Prioridad secretaría',
      'Prioridad tesorería',
    ];
    final existing = await _db.collection('tags_config').get();
    final existingNames = existing.docs
        .map((doc) => '${doc.data()['nombre']}'.toLowerCase())
        .toSet();
    final batch = _db.batch();
    for (final name in names) {
      if (existingNames.contains(name.toLowerCase())) continue;
      final ref = _db.collection('tags_config').doc();
      batch.set(ref, {
        ...TagConfig(id: ref.id, nombre: name).toFirestore(),
        'id': ref.id,
      });
    }
    await batch.commit();
  }

  Future<void> updateCofradeManualTags(
    String cofradeId,
    List<String> tags,
  ) async {
    final before = await _db.collection('cofrades').doc(cofradeId).get();
    final oldTags = (before.data()?['tags_manual'] as List<dynamic>? ?? [])
        .map((e) => '$e')
        .toSet();
    final newTags = tags.toSet();
    await updateCofrade(cofradeId, {'tags_manual': tags});
    for (final tag in newTags.difference(oldTags)) {
      await createAuditLog(
        action: 'manual_tag_assigned',
        targetId: cofradeId,
        targetType: 'cofrade',
        targetNombre:
            '${before.data()?['nombre'] ?? ''} ${before.data()?['apellidos'] ?? ''}'
                .trim(),
        changedBy: 'system',
        newValue: tag,
      );
    }
    for (final tag in oldTags.difference(newTags)) {
      await createAuditLog(
        action: 'manual_tag_removed',
        targetId: cofradeId,
        targetType: 'cofrade',
        targetNombre:
            '${before.data()?['nombre'] ?? ''} ${before.data()?['apellidos'] ?? ''}'
                .trim(),
        changedBy: 'system',
        oldValue: tag,
      );
    }
  }

  Future<int> recomputeAutomaticTags() async {
    await _ensureMissingDataTagConfig();
    final tagsSnap = await _db
        .collection('tags_config')
        .where('tipo', isEqualTo: 'automatico')
        .where('activo', isEqualTo: true)
        .get();
    final fieldsSnap = await _db.collection('cofrade_fields_config').get();
    final cofradesSnap = await _db.collection('cofrades').get();
    final tags =
        tagsSnap.docs.map((doc) => TagConfig.fromFirestore(doc)).toList();
    final fieldsConfig = fieldsSnap.docs
        .map((doc) => CofradeFieldConfig.fromFirestore(doc))
        .toList();
    final batch = _db.batch();
    var changed = 0;
    for (final doc in cofradesSnap.docs) {
      if (doc.id.startsWith('ADM-') ||
          doc.data()['es_cuenta_servicio'] == true) {
        continue;
      }
      final data = doc.data();
      final cofrade = Cofrade.fromFirestore(doc);
      if (!cofrade.isActivo) {
        final previous = (doc.data()['tags_auto'] as List<dynamic>? ?? [])
            .map((item) => '$item')
            .toSet();
        if (previous.isNotEmpty || doc.data()['dataQualityStatus'] != null) {
          batch.update(doc.reference, {
            'tags_auto': <String>[],
            'dataQualityStatus': 'INACTIVE',
            'anios_hermandad': cofrade.anioAlta == null
                ? null
                : DateTime.now().year - cofrade.anioAlta!,
            'fecha_actualizacion': FieldValue.serverTimestamp(),
          });
          changed++;
        }
        continue;
      }
      final autoTags = <String>[];
      final missingRequired = getMissingRequiredFields(cofrade, fieldsConfig);
      for (final tag in tags) {
        if (tag.id == 'faltan_datos') {
          if (missingRequired.isNotEmpty) {
            autoTags.add(tag.id);
          }
        } else if (_matchesAutomaticCriterion(data, tag.criterio, cofrade)) {
          autoTags.add(tag.id);
        }
      }
      final dataQualityStatus = _dataQualityStatusForCofrade(
        cofrade,
        missingRequired,
      );
      final previous = (doc.data()['tags_auto'] as List<dynamic>? ?? [])
          .map((item) => '$item')
          .toSet();
      final next = autoTags.toSet();
      final computedYears = cofrade.anioAlta == null
          ? null
          : DateTime.now().year - cofrade.anioAlta!;
      if (previous.length == next.length &&
          previous.containsAll(next) &&
          doc.data()['dataQualityStatus'] == dataQualityStatus &&
          doc.data()['anios_hermandad'] == computedYears) {
        continue;
      }
      batch.update(doc.reference, {
        'tags_auto': autoTags,
        'dataQualityStatus': dataQualityStatus,
        'anios_hermandad': computedYears,
        'fecha_actualizacion': FieldValue.serverTimestamp(),
      });
      changed++;
    }
    if (changed > 0) {
      await batch.commit();
      await createAuditLog(
        action: 'auto_tags_recalculated',
        targetId: 'tags_auto',
        targetType: 'tags_config',
        targetNombre: 'Tags automáticas',
        changedBy: 'system',
        metadata: {
          'cofrades_count': cofradesSnap.docs.length,
          'changed_count': changed,
        },
      );
    }
    return changed;
  }

  String _dataQualityStatusForCofrade(
    Cofrade cofrade,
    List<CofradeFieldConfig> missing,
  ) {
    if (missing.isEmpty) return 'COMPLETE';
    return 'INCOMPLETE';
  }

  Future<void> _ensureMissingDataTagConfig() async {
    final ref = _db.collection('tags_config').doc('faltan_datos');
    final snap = await ref.get();
    if (snap.exists) return;
    await ref.set({
      'id': 'faltan_datos',
      'nombre': 'Faltan datos',
      'descripcion': 'Campos obligatorios configurados pendientes de completar',
      'tipo': 'automatico',
      'color': '#D97706',
      'activo': true,
      'criterio': {'campo': 'tiene_datos_obligatorios_pendientes'},
      'fecha_creacion': FieldValue.serverTimestamp(),
      'fecha_actualizacion': FieldValue.serverTimestamp(),
    });
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
  Stream<List<Noticia>> getNoticias({
    bool soloPublicadas = true,
    bool incluirSoloCofrades = false,
  }) {
    Query query = _db.collection('noticias');
    if (soloPublicadas) {
      query = query.where('publicado', isEqualTo: true);
    }
    if (!incluirSoloCofrades) {
      query = query.where('solo_cofrades', isEqualTo: false);
    }
    query = query.orderBy('fecha', descending: true);
    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Noticia.fromFirestore(doc)).toList());
  }

  Stream<List<Noticia>> getUltimasNoticias(
      {int limit = 3, bool incluirSoloCofrades = false}) {
    return _db
        .collection('noticias')
        .where('publicado', isEqualTo: true)
        .orderBy('fecha', descending: true)
        .limit(incluirSoloCofrades ? limit : limit + 10)
        .snapshots()
        .map((snapshot) {
      var noticias =
          snapshot.docs.map((doc) => Noticia.fromFirestore(doc)).toList();
      if (!incluirSoloCofrades) {
        noticias = noticias.where((n) => n.soloCofrades != true).toList();
      }
      return noticias.take(limit).toList();
    });
  }

  Future<void> createNoticia(Noticia noticia) async {
    final doc = await _db.collection('noticias').add(noticia.toFirestore());
    if (noticia.publicado) {
      await _db.collection('novedades').add({
        'tipo': 'noticia',
        'titulo': noticia.titulo,
        'descripcion': noticia.contenido,
        'referencia_id': 'noticia_${doc.id}',
        'ruta': '/news',
        'visible_para': noticia.soloCofrades ? 'cofrades' : 'todos',
        'created_at': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> updateNoticia(String id, Map<String, dynamic> data) async {
    await _db.collection('noticias').doc(id).update(data);
  }

  Future<void> deleteNoticia(String id) async {
    await _db.collection('noticias').doc(id).delete();
  }

  Future<Set<String>> getNewsReadIds(String cofradeId) async {
    final doc = await _db
        .collection('cofrades')
        .doc(cofradeId)
        .collection('preferencias')
        .doc('noticias_leidas')
        .get();
    final list = doc.data()?['ids'] as List<dynamic>? ?? const [];
    return list.map((item) => '$item').toSet();
  }

  Future<void> markNewsRead(String cofradeId, String noticiaId) async {
    await _db
        .collection('cofrades')
        .doc(cofradeId)
        .collection('preferencias')
        .doc('noticias_leidas')
        .set({
      'ids': FieldValue.arrayUnion([noticiaId]),
      'ultima_actualizacion': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await marcarNovedadLeida(cofradeId, 'noticia_$noticiaId');
  }

  Future<Noticia?> getLatestUnreadNewsForCofrade(String cofradeId) async {
    final read = await getNewsReadIds(cofradeId);
    final snapshot = await _db
        .collection('noticias')
        .where('publicado', isEqualTo: true)
        .orderBy('fecha', descending: true)
        .limit(8)
        .get();
    for (final doc in snapshot.docs) {
      if (read.contains(doc.id)) continue;
      return Noticia.fromFirestore(doc);
    }
    return null;
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
    return _db.collection('cofrades').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Cofrade.fromFirestore(doc)).toList());
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchPublicBirthdays() {
    return _db.collection('cumpleanos_publicos').snapshots();
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

  Future<void> aprobarSolicitud(
    String solicitudId,
    String aprobadaPor, {
    bool? requiresDigitalTutor,
    String? digitalTutorName,
    String? digitalTutorDni,
    String? digitalTutorPhone,
    String? digitalTutorEmail,
    String? digitalTutorRelationship,
  }) async {
    final solicitudDoc =
        await _db.collection('solicitudes').doc(solicitudId).get();
    if (!solicitudDoc.exists) return;

    final solicitud = Solicitud.fromFirestore(solicitudDoc);

    final lastNum = await _db
        .collection('cofrades')
        .orderBy('numero', descending: true)
        .limit(1)
        .get();
    final nextNum = lastNum.docs.isNotEmpty
        ? ((lastNum.docs.first.data()['numero'] ?? 0) + 1)
        : 1;

    final tutorRequired = requiresDigitalTutor ??
        solicitud.requiresDigitalTutor ||
            _ageFromDate(solicitud.fechaNacimiento) < 18;

    final cofradeId = await createCofradeForAdmin({
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
      'dni_normalizado': _normalizeDni(solicitud.dni ?? ''),
      'estado': 'Activo',
      'status': 'active',
      'isActive': true,
      'anio_alta': DateTime.now().year,
      'genero': solicitud.genero ?? '',
      'tiene_cuota': true,
      'cuotaActiva': true,
      'gdpr_firmado': false,
      'gdpr_firmado_digital': false,
      'notificaciones_activas': true,
      'tiene_tunica_propia': false,
      'rol': 'cofrade',
      'role': 'cofrade',
      'roles': ['cofrade'],
      'fecha_actualizacion': FieldValue.serverTimestamp(),
      'requiresDigitalTutor': tutorRequired,
      'tutelado_digital': tutorRequired,
      'digitalTutorName': digitalTutorName ?? solicitud.digitalTutorName ?? '',
      'digitalTutorDni': digitalTutorDni ?? solicitud.digitalTutorDni ?? '',
      'digitalTutorPhone':
          digitalTutorPhone ?? solicitud.digitalTutorPhone ?? '',
      'digitalTutorEmail':
          digitalTutorEmail ?? solicitud.digitalTutorEmail ?? '',
      'digitalTutorRelationship':
          digitalTutorRelationship ?? solicitud.digitalTutorRelationship ?? '',
      'dni_tutor': digitalTutorDni ?? solicitud.digitalTutorDni ?? '',
      'parentesco_tutor':
          digitalTutorRelationship ?? solicitud.digitalTutorRelationship ?? '',
      'digitalTutorConsentAccepted': false,
    });

    await _db.collection('solicitudes').doc(solicitudId).update({
      'estado': 'aprobada',
      'aprobada_por': aprobadaPor,
      'cofrade_id': cofradeId,
      'requiresDigitalTutor': tutorRequired,
      'tutelado_digital': tutorRequired,
      'digitalTutorName': digitalTutorName ?? solicitud.digitalTutorName ?? '',
      'digitalTutorDni': digitalTutorDni ?? solicitud.digitalTutorDni ?? '',
      'digitalTutorPhone':
          digitalTutorPhone ?? solicitud.digitalTutorPhone ?? '',
      'digitalTutorEmail':
          digitalTutorEmail ?? solicitud.digitalTutorEmail ?? '',
      'digitalTutorRelationship':
          digitalTutorRelationship ?? solicitud.digitalTutorRelationship ?? '',
      'fecha_resolucion': FieldValue.serverTimestamp(),
    });
    await createWelcomeNovedadForCofrade(cofradeId);
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
    return _db.collection('convocatorias').snapshots().map((snapshot) {
      final encuestas = snapshot.docs
          .map((doc) => Convocatoria.fromFirestore(doc))
          .where((e) {
        if (!soloActivas) return true;
        return e.status == 'active' && e.activa;
      }).toList()
        ..sort((a, b) => b.fechaLimite.compareTo(a.fechaLimite));
      return encuestas;
    });
  }

  Stream<List<Convocatoria>> getAllConvocatorias() {
    return getConvocatorias();
  }

  Stream<List<Convocatoria>> getConvocatoriasActivas() {
    return _db.collection('convocatorias').snapshots().map((snapshot) {
      final encuestas = snapshot.docs
          .map((doc) => Convocatoria.fromFirestore(doc))
          .where((e) => e.status == 'active' && e.activa && e.isVigente)
          .toList()
        ..sort((a, b) => a.fechaLimite.compareTo(b.fechaLimite));
      return encuestas;
    });
  }

  Future<void> createConvocatoria(Convocatoria convocatoria) async {
    final docRef = convocatoria.id.isNotEmpty
        ? _db.collection('convocatorias').doc(convocatoria.id)
        : _db.collection('convocatorias').doc();
    await docRef.set(convocatoria.toFirestore());
    await crearNovedad(
      tipo: 'encuesta',
      titulo: convocatoria.titulo,
      descripcion: 'Nueva encuesta: ${convocatoria.titulo}',
      referenciaId: docRef.id,
      ruta: '/encuestas',
    );
  }

  Future<void> updateConvocatoria(String id, Map<String, dynamic> data) async {
    if (data['status'] != null) {
      data['activa'] = data['status'] == 'active';
    }
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
    final doc = await _db
        .collection('convocatorias')
        .doc(convocatoriaId)
        .collection('respuestas')
        .doc(cofradeId)
        .get();
    if (doc.exists) return RespuestaConvocatoria.fromFirestore(doc);
    return null;
  }

  Future<Map<String, int>> getSurveyResults(String convocatoriaId) async {
    final surveyDoc =
        await _db.collection('convocatorias').doc(convocatoriaId).get();
    final aggregate = surveyDoc.data()?['result_counts'];
    if (aggregate is Map && aggregate.isNotEmpty) {
      return aggregate
          .map((key, value) => MapEntry('$key', (value as num?)?.toInt() ?? 0));
    }

    final result = <String, int>{};
    try {
      final snapshot = await _db
          .collection('convocatorias')
          .doc(convocatoriaId)
          .collection('respuestas')
          .get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final key = '${data['selectedOptionId'] ?? data['respuesta'] ?? ''}';
        if (key.isEmpty) continue;
        result[key] = (result[key] ?? 0) + 1;
      }
    } on FirebaseException catch (e) {
      debugPrint(
          '[Encuestas] No se pudieron leer respuestas individuales para resultados: ${e.code}');
    }
    return result;
  }

  // --- Evangelio del Día ---
  Stream<Map<String, dynamic>?> getEvangelioDelDia() {
    final fechaStr = MadridDate.key();
    return _db
        .collection('evangelio_dia')
        .doc(fechaStr)
        .snapshots()
        .asyncMap((doc) async {
      final stored = doc.exists ? doc.data() : null;
      if (_isUsableEvangelio(stored)) {
        _evangelioCache[fechaStr] = stored;
        return stored;
      }
      if (_evangelioCache.containsKey(fechaStr)) {
        return _evangelioCache[fechaStr];
      }
      final fetched = await refreshEvangelioDelDia();
      if (fetched != null) _evangelioCache[fechaStr] = fetched;
      return fetched;
    });
  }

  Future<Map<String, dynamic>?> refreshEvangelioDelDia({
    bool persistIfAdmin = true,
  }) async {
    final fecha = MadridDate.key();
    try {
      final response = await http.get(
        Uri.parse('https://publication.evangelizo.ws/SP/days/$fecha'),
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final raw = jsonDecode(response.body);
      final data = raw is Map && raw['data'] is Map ? raw['data'] : raw;
      final readings = data is Map ? data['readings'] : null;
      final gospel = readings is List
          ? readings.firstWhere(
              (item) =>
                  item is Map &&
                  (item['type'] == 'gospel' ||
                      item['reading_code'] == 'gospel'),
              orElse: () => null,
            )
          : null;
      final rawText = data is Map ? jsonEncode(data) : '';
      final result = <String, dynamic>{
        'fecha': fecha,
        'titulo': gospel is Map
            ? (gospel['title'] ?? 'Evangelio del día')
            : 'Evangelio del día',
        'texto': gospel is Map
            ? (gospel['text'] ?? '')
            : rawText.length > 2000
                ? rawText.substring(0, 2000)
                : rawText,
        'referencia': gospel is Map ? (gospel['reference'] ?? '') : '',
        'fuente': 'evangelizo.ws',
        'fecha_actualizacion': FieldValue.serverTimestamp(),
      };
      _evangelioCache[fecha] = result;
      if (persistIfAdmin) {
        try {
          await _db.collection('evangelio_dia').doc(fecha).set(result);
        } catch (_) {
          // The Firestore rule remains the final authorization check.
        }
      }
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveEvangelioDelDia({
    required String titulo,
    required String referencia,
    required String texto,
  }) async {
    final fecha = MadridDate.key();
    final data = {
      'fecha': fecha,
      'titulo': titulo.trim(),
      'referencia': referencia.trim(),
      'texto': texto.trim(),
      'fuente': 'manual',
      'fecha_actualizacion': FieldValue.serverTimestamp(),
    };
    await _db.collection('evangelio_dia').doc(fecha).set(data);
    _evangelioCache[fecha] = {...data, 'fecha_actualizacion': DateTime.now()};
  }

  bool _isUsableEvangelio(Map<String, dynamic>? data) {
    if (data == null || data['texto'] is! String) return false;
    if (data['fuente'] == 'manual' &&
        (data['texto'] as String).toLowerCase().contains('no se pudo')) {
      return false;
    }
    return (data['texto'] as String).trim().isNotEmpty;
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
    Query query =
        _db.collection('sugerencias').orderBy('fecha', descending: true);
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
    final legacyRef =
        await _db.collection('sugerencias').add(sugerencia.toFirestore());
    await startConversation(
      cofradeId: sugerencia.cofradeId,
      cofradeName: sugerencia.cofradeNombre,
      subject: sugerencia.titulo,
      body: sugerencia.mensaje,
      createdBy: sugerencia.cofradeId,
      createdByRole: 'cofrade',
      type: sugerencia.tipo == 'peticion' ? 'request' : 'suggestion',
      origin: 'cofrade',
    );
    await createAuditLog(
      action: 'conversation_created_from_suggestion',
      targetId: sugerencia.cofradeId,
      targetType: 'cofrade',
      targetNombre: sugerencia.cofradeNombre,
      changedBy: sugerencia.cofradeId,
      metadata: {'sugerencia_id': legacyRef.id, 'type': sugerencia.tipo},
    );
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
    Query query =
        _db.collection('tablon_anuncios').orderBy('fecha', descending: true);
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
    await _db
        .collection('tablon_anuncios')
        .doc(id)
        .update({'visible': false, 'aprobado': false});
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
    final docRef = await _db
        .collection('proveedores_tunicas')
        .add(proveedor.toFirestore());
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

  Future<void> updatePaginaEstatica(
      String slug, Map<String, dynamic> data) async {
    await _db
        .collection('paginas_estaticas')
        .doc(slug)
        .set(data, SetOptions(merge: true));
  }

  // --- Novedades read tracking ---
  Future<Set<String>> getNovedadesLeidas(String cofradeId) async {
    final doc = await _db
        .collection('cofrades')
        .doc(cofradeId)
        .collection('preferencias')
        .doc('novedades_leidas')
        .get();
    if (!doc.exists) return {};
    final data = doc.data();
    final list = data?['ids'] as List<dynamic>? ?? [];
    return list.map((e) => e.toString()).toSet();
  }

  Future<void> marcarNovedadLeida(String cofradeId, String novedadId) async {
    await _db
        .collection('cofrades')
        .doc(cofradeId)
        .collection('preferencias')
        .doc('novedades_leidas')
        .set({
      'ids': FieldValue.arrayUnion([novedadId]),
      'ultima_actualizacion': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> marcarTodasNovedadesLeidas(
      String cofradeId, List<String> ids) async {
    await _db
        .collection('cofrades')
        .doc(cofradeId)
        .collection('preferencias')
        .doc('novedades_leidas')
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
      referenciaId:
          '${cofradeId}_oferta_${DateTime.now().millisecondsSinceEpoch}',
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
      referenciaId:
          '${cofradeId}_demanda_${DateTime.now().millisecondsSinceEpoch}',
      ruta: '/banco-tunicas',
    );
  }

  Future<void> cambiarEstadoPublicacionBanco(
      String id, String nuevoEstado) async {
    await _db
        .collection('banco_tunicas')
        .doc(id)
        .update({'estado': nuevoEstado});
  }

  Future<void> eliminarPublicacionBanco(String id) async {
    await _db.collection('banco_tunicas').doc(id).delete();
  }

  Future<void> editarPublicacionBanco(
      String id, Map<String, dynamic> data) async {
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
    String? selectedOptionId,
    String? comentario,
  }) async {
    final surveyRef = _db.collection('convocatorias').doc(convocatoriaId);
    final responseRef = surveyRef.collection('respuestas').doc(cofradeId);
    final newKey = selectedOptionId ?? respuesta;

    await _db.runTransaction((transaction) async {
      final surveySnap = await transaction.get(surveyRef);
      final responseSnap = await transaction.get(responseRef);
      final rawCounts = surveySnap.data()?['result_counts'];
      final counts = rawCounts is Map
          ? rawCounts.map(
              (key, value) => MapEntry('$key', (value as num?)?.toInt() ?? 0))
          : <String, int>{};
      final existingData = responseSnap.data();
      final oldKey = existingData == null
          ? null
          : '${existingData['selectedOptionId'] ?? existingData['respuesta'] ?? ''}';

      final data = {
        'surveyId': convocatoriaId,
        'cofrade_id': cofradeId,
        'cofradeId': cofradeId,
        'cofrade_nombre': cofradeNombre,
        'respuesta': respuesta,
        'selectedOptionId': newKey,
        'selectedOptionText': respuesta,
        'comentario': comentario,
        'updatedAt': FieldValue.serverTimestamp(),
        if (!responseSnap.exists)
          'fecha_respuesta': FieldValue.serverTimestamp(),
        if (!responseSnap.exists) 'createdAt': FieldValue.serverTimestamp(),
      };

      transaction.set(responseRef, data, SetOptions(merge: true));
      if (!responseSnap.exists) {
        counts[newKey] = (counts[newKey] ?? 0) + 1;
        transaction.update(surveyRef, {
          'total_respuestas': FieldValue.increment(1),
          'result_counts': counts,
        });
      } else if (oldKey != newKey) {
        if (oldKey != null && oldKey.isNotEmpty) {
          final nextOldValue = (counts[oldKey] ?? 0) - 1;
          if (nextOldValue <= 0) {
            counts.remove(oldKey);
          } else {
            counts[oldKey] = nextOldValue;
          }
        }
        counts[newKey] = (counts[newKey] ?? 0) + 1;
        transaction.update(surveyRef, {'result_counts': counts});
      }
    });
  }

  // =============================================
  // --- Festividad San Juan Evangelista ---
  // =============================================

  // --- Ediciones del evento ---
  Stream<List<Map<String, dynamic>>> getFestividadEdiciones() {
    return _db.collection('festividad_sje').snapshots().map((s) {
      final ediciones = s.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList()
        ..sort(_compareFestividadEdicionesForPrivate);
      return ediciones;
    });
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
    return _db.collection('festividad_sje').snapshots().map((s) {
      if (s.docs.isEmpty) return null;
      final ediciones = s.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList()
        ..sort(_compareFestividadEdicionesForPrivate);
      final data = ediciones.first;
      return data;
    });
  }

  Stream<List<Map<String, dynamic>>> getFestividadEdicionesOrdenadasStream() {
    return _db.collection('festividad_sje').snapshots().map((s) {
      final ediciones = s.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList()
        ..sort(_compareFestividadEdicionesForPrivate);
      return ediciones;
    });
  }

  int _compareFestividadEdicionesForPrivate(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final p = _festividadPriority(a).compareTo(_festividadPriority(b));
    if (p != 0) return p;
    final ay = (a['anio'] as num?)?.toInt() ?? 0;
    final by = (b['anio'] as num?)?.toInt() ?? 0;
    if (by.compareTo(ay) != 0) return by.compareTo(ay);
    final ad = (a['fecha'] as Timestamp?)?.toDate() ?? DateTime(1900);
    final bd = (b['fecha'] as Timestamp?)?.toDate() ?? DateTime(1900);
    return bd.compareTo(ad);
  }

  int _festividadPriority(Map<String, dynamic> edicion) {
    final estado = '${edicion['estado'] ?? ''}'.toLowerCase();
    final now = DateTime.now();
    final limite = (edicion['fecha_limite'] as Timestamp?)?.toDate();
    final fecha = (edicion['fecha'] as Timestamp?)?.toDate();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay =
        fecha == null ? null : DateTime(fecha.year, fecha.month, fecha.day);
    final afterEventDay = eventDay != null && today.isAfter(eventDay);
    if (afterEventDay &&
        const {'abierto', 'activo', 'publicado'}.contains(estado)) {
      return 4;
    }
    final inscripcionDisponible =
        estado == 'abierto' && (limite == null || !now.isAfter(limite));
    if (inscripcionDisponible) return 0;
    if (estado == 'abierto' || estado == 'activo') return 1;
    if (estado == 'publicado') return 2;
    if (estado == 'cerrado') return 3;
    if (estado == 'finalizado') return 4;
    if (estado == 'archivado') return 5;
    return 6;
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

  Future<void> updateFestividadEdicion(
      String id, Map<String, dynamic> data) async {
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

  Future<String> createFestividadMenu(
      String edicionId, Map<String, dynamic> data) async {
    data['created_at'] = FieldValue.serverTimestamp();
    final ref = await _db
        .collection('festividad_sje')
        .doc(edicionId)
        .collection('menus')
        .add(data);
    return ref.id;
  }

  Future<void> updateFestividadMenu(
      String edicionId, String menuId, Map<String, dynamic> data) async {
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

  Future<bool> isMenuUsedInInscripciones(
      String edicionId, String menuId) async {
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
  Stream<List<Map<String, dynamic>>> getFestividadInscripciones(
      String edicionId) {
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

  Future<Map<String, dynamic>?> getMiInscripcionFestividad(
      String edicionId, String cofradeId) async {
    final snap = await _db
        .collection('festividad_sje')
        .doc(edicionId)
        .collection('inscripciones')
        .where('cofrade_id', isEqualTo: cofradeId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final data = snap.docs.first.data();
    data['id'] = snap.docs.first.id;
    return data;
  }

  Future<Map<String, dynamic>?> getInscripcionFestividadParaCofrade(
      String edicionId, String cofradeId) async {
    final titular = await getMiInscripcionFestividad(edicionId, cofradeId);
    if (titular != null) return titular;

    final allInsc = await _db
        .collection('festividad_sje')
        .doc(edicionId)
        .collection('inscripciones')
        .get();
    for (final doc in allInsc.docs) {
      final asistentes = List<Map<String, dynamic>>.from(
          (doc.data()['asistentes'] as List<dynamic>?) ?? []);
      if (asistentes.any((a) => a['cofrade_id'] == cofradeId)) {
        final data = doc.data();
        data['id'] = doc.id;
        data['access_role'] =
            data['cofrade_id'] == cofradeId ? 'titular' : 'acompanante';
        return data;
      }
    }
    return null;
  }

  Future<bool> isCofradeInscritoFestividad(
      String edicionId, String cofradeId) async {
    final allInsc = await _db
        .collection('festividad_sje')
        .doc(edicionId)
        .collection('inscripciones')
        .where('estado', whereIn: ['pendiente', 'confirmada']).get();
    for (final doc in allInsc.docs) {
      final asistentes = List<Map<String, dynamic>>.from(
          (doc.data()['asistentes'] as List<dynamic>?) ?? []);
      for (final a in asistentes) {
        if (a['cofrade_id'] == cofradeId) return true;
      }
    }
    return false;
  }

  Future<void> notifyFestividadAcompanantes({
    required String edicionId,
    required String inscripcionId,
    required String edicionNombre,
    required Iterable<Map<String, dynamic>> asistentes,
    Set<String> previousCofradeIds = const {},
  }) async {
    final targetIds = asistentes
        .map((a) => (a['cofrade_id'] ?? '').toString())
        .where((id) => id.isNotEmpty && !previousCofradeIds.contains(id))
        .toSet();
    for (final cofradeId in targetIds) {
      await crearNovedad(
        tipo: 'festividad',
        titulo: 'Te han añadido a una inscripción',
        descripcion:
            'Figuras como acompañante en la inscripción de $edicionNombre.',
        referenciaId: 'festividad_acompanante_${inscripcionId}_$cofradeId',
        ruta: '/festividad',
        visiblePara: 'cofrade',
        cofradeId: cofradeId,
      );
    }
  }

  Future<String> createFestividadInscripcion(
      String edicionId, Map<String, dynamic> data) async {
    data['created_at'] = FieldValue.serverTimestamp();
    data['updated_at'] = FieldValue.serverTimestamp();
    final ref = await _db
        .collection('festividad_sje')
        .doc(edicionId)
        .collection('inscripciones')
        .add(data);
    return ref.id;
  }

  Future<void> updateFestividadInscripcion(
      String edicionId, String inscId, Map<String, dynamic> data) async {
    final ref = _db
        .collection('festividad_sje')
        .doc(edicionId)
        .collection('inscripciones')
        .doc(inscId);
    final beforeSnap = await ref.get();
    final before = beforeSnap.data() ?? const <String, dynamic>{};
    data['updated_at'] = FieldValue.serverTimestamp();
    await ref.update(data);
    await _notifyFestividadInscripcionChange(
      edicionId: edicionId,
      inscripcionId: inscId,
      before: before,
      after: {...before, ...data},
    );
  }

  Future<void> _notifyFestividadInscripcionChange({
    required String edicionId,
    required String inscripcionId,
    required Map<String, dynamic> before,
    required Map<String, dynamic> after,
  }) async {
    final changes = <String, Map<String, dynamic>>{};
    if (before['estado'] != after['estado'] && after['estado'] != null) {
      changes['estado'] = {'old': before['estado'], 'new': after['estado']};
    }
    final oldPay = before['payment_status'] ?? before['estado_pago'];
    final newPay = after['payment_status'] ?? after['estado_pago'];
    if (oldPay != newPay && newPay != null) {
      changes['payment_status'] = {'old': oldPay, 'new': newPay};
    }
    final oldPaid = before['paid_amount'] ?? before['paidAmount'];
    final newPaid = after['paid_amount'] ?? after['paidAmount'];
    if (oldPaid != newPaid && newPaid != null) {
      changes['paid_amount'] = {'old': oldPaid, 'new': newPaid};
    }
    final oldPending = before['pending_amount'] ?? before['pendingAmount'];
    final newPending = after['pending_amount'] ?? after['pendingAmount'];
    if (oldPending != newPending && newPending != null) {
      changes['pending_amount'] = {'old': oldPending, 'new': newPending};
    }
    if (changes.isEmpty) return;
    final edicion = await getFestividadEdicion(edicionId);
    final nombre = edicion?['nombre'] ?? 'Festividad San Juan Evangelista';
    final notified = _festividadParticipantIds(after);
    for (final cofradeId in notified) {
      final payment = changes.containsKey('payment_status') ||
          changes.containsKey('paid_amount') ||
          changes.containsKey('pending_amount');
      await crearNovedad(
        tipo: 'festividad',
        titulo:
            payment ? 'Pago actualizado: $nombre' : 'Inscripción actualizada',
        descripcion: payment
            ? 'El estado de pago de tu inscripción a $nombre ha cambiado a $newPay.'
            : 'Tu inscripción a $nombre ha cambiado a ${after['estado']}.',
        referenciaId:
            'festividad_change_${inscripcionId}_${cofradeId}_${DateTime.now().millisecondsSinceEpoch}',
        ruta: '/festividad',
        visiblePara: 'cofrade',
        cofradeId: cofradeId,
      );
    }
    try {
      await createAuditLog(
        action: 'festividad_registration_changed',
        targetId: inscripcionId,
        targetType: 'festividad_inscripcion',
        targetNombre: nombre,
        changedBy: 'system',
        oldValue: changes.map((key, value) => MapEntry(key, value['old'])),
        newValue: changes.map((key, value) => MapEntry(key, value['new'])),
        metadata: {
          'edicionId': edicionId,
          'notifiedCofradeIds': notified.toList(),
        },
      );
    } catch (_) {
      // La inscripción ya se ha guardado. Si las reglas impiden auditar desde
      // un flujo privado, no bloqueamos al cofrade.
    }
  }

  Set<String> _festividadParticipantIds(Map<String, dynamic> inscripcion) {
    final ids = <String>{};
    final titular = '${inscripcion['cofrade_id'] ?? ''}';
    if (titular.isNotEmpty) ids.add(titular);
    final asistentes = inscripcion['asistentes'];
    if (asistentes is Iterable) {
      for (final asistente in asistentes.whereType<Map>()) {
        final id = '${asistente['cofrade_id'] ?? ''}';
        if (id.isNotEmpty) ids.add(id);
      }
    }
    return ids;
  }

  Future<void> deleteFestividadInscripcion(
      String edicionId, String inscId) async {
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
    String visiblePara = 'todos',
    String? cofradeId,
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
      'visible_para': visiblePara,
      'cofrade_id': cofradeId,
    });
  }

  // --- Lotería de Navidad ---

  // Campañas
  Stream<List<CampanaLoteria>> getCampanasLoteria() {
    return _db
        .collection('campanas_loteria')
        .orderBy('fecha_inicio', descending: true)
        .snapshots()
        .map(
            (s) => s.docs.map((d) => CampanaLoteria.fromFirestore(d)).toList());
  }

  Stream<CampanaLoteria?> getCampanaActiva() {
    return _db
        .collection('campanas_loteria')
        .where('estado', isEqualTo: 'activa')
        .limit(1)
        .snapshots()
        .map((s) => s.docs.isNotEmpty
            ? CampanaLoteria.fromFirestore(s.docs.first)
            : null);
  }

  Future<CampanaLoteria?> getCampanaById(String id) async {
    final doc = await _db.collection('campanas_loteria').doc(id).get();
    if (doc.exists) return CampanaLoteria.fromFirestore(doc);
    return null;
  }

  Future<String> createCampanaLoteria(CampanaLoteria campana) async {
    final docRef =
        await _db.collection('campanas_loteria').add(campana.toFirestore());
    return docRef.id;
  }

  Future<void> updateCampanaLoteria(
      String id, Map<String, dynamic> data) async {
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
    if (sabana.serie.trim().isEmpty) {
      throw Exception('La serie es obligatoria.');
    }
    final existing = await _db
        .collection('decimos_loteria')
        .where('campana_id', isEqualTo: sabana.campanaId)
        .where('numero_loteria', isEqualTo: sabana.numeroLoteria)
        .where('serie', isEqualTo: sabana.serie.trim())
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw Exception(
          'Ya existe una sábana con ese número y serie en esta campaña.');
    }

    final docRef = await _db.collection('sabanas').add(sabana.toFirestore());
    final batch = _db.batch();
    for (var i = 1; i <= sabana.totalDecimos; i++) {
      final decimoRef = _db.collection('decimos_loteria').doc();
      batch.set(
        decimoRef,
        DecimoLoteria(
          id: '',
          campanaId: sabana.campanaId,
          sabanaId: docRef.id,
          numeroLoteria: sabana.numeroLoteria,
          serie: sabana.serie.trim(),
          numeroDecimo: i,
          precioVenta: sabana.precioVentaUnidad,
        ).toFirestore(),
      );
    }
    await batch.commit();
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
        .map((s) =>
            s.docs.map((d) => VendedorLoteria.fromFirestore(d)).toList());
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
    if (snap.docs.isNotEmpty) {
      return VendedorLoteria.fromFirestore(snap.docs.first);
    }
    return null;
  }

  Future<VendedorLoteria?> getVendedorByCofradeId(String cofradeId) async {
    final snap = await _db
        .collection('vendedores_loteria')
        .where('cofrade_id', isEqualTo: cofradeId)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      return VendedorLoteria.fromFirestore(snap.docs.first);
    }
    return null;
  }

  Future<String> createVendedorLoteria(VendedorLoteria vendedor) async {
    final docRef =
        await _db.collection('vendedores_loteria').add(vendedor.toFirestore());
    return docRef.id;
  }

  Future<void> updateVendedorLoteria(
      String id, Map<String, dynamic> data) async {
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
        .map((s) =>
            s.docs.map((d) => AsignacionLoteria.fromFirestore(d)).toList());
  }

  Stream<List<AsignacionLoteria>> getAsignacionesVendedor(String vendedorId) {
    return _db
        .collection('asignaciones_loteria')
        .where('vendedor_id', isEqualTo: vendedorId)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => AsignacionLoteria.fromFirestore(d)).toList());
  }

  Future<AsignacionLoteria?> getAsignacionByToken(String token) async {
    final snap = await _db
        .collection('asignaciones_loteria')
        .where('token_acceso', isEqualTo: token)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      return AsignacionLoteria.fromFirestore(snap.docs.first);
    }
    return null;
  }

  Future<String> createAsignacion(AsignacionLoteria asignacion) async {
    final vendedor = await getVendedorById(asignacion.vendedorId);
    final decimosSnap = await _db
        .collection('decimos_loteria')
        .where('sabana_id', isEqualTo: asignacion.sabanaId)
        .where('estado', isEqualTo: 'disponible')
        .limit(asignacion.decimosAsignados)
        .get();
    if (decimosSnap.docs.length < asignacion.decimosAsignados) {
      throw Exception('No hay suficientes décimos disponibles en esta sábana.');
    }

    final docRef = await _db
        .collection('asignaciones_loteria')
        .add(asignacion.toFirestore());
    final batch = _db.batch();
    for (final doc in decimosSnap.docs) {
      batch.update(doc.reference, {
        'estado': 'asignado',
        'vendedor_id': asignacion.vendedorId,
        'cofrade_id': vendedor?.cofradeId,
        'fecha_asignacion': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    await _db
        .collection('sabanas')
        .doc(asignacion.sabanaId)
        .update({'estado': 'asignada'});
    if (vendedor?.cofradeId != null && vendedor!.cofradeId!.isNotEmpty) {
      await crearNovedad(
        tipo: 'loteria',
        titulo: 'Lotería asignada',
        descripcion:
            'Se te ha asignado lotería para vender. Accede al módulo de Lotería para gestionar tus ventas.',
        referenciaId: 'loteria_asignacion_${docRef.id}',
        ruta: '/loteria',
        visiblePara: 'cofrade',
        cofradeId: vendedor.cofradeId,
      );
    }
    return docRef.id;
  }

  Future<void> updateAsignacion(String id, Map<String, dynamic> data) async {
    data['ultima_actualizacion'] = FieldValue.serverTimestamp();
    await _db.collection('asignaciones_loteria').doc(id).update(data);
  }

  Future<void> actualizarVentasAsignacion(
      String id, int vendidos, int devueltos) async {
    await _db.collection('asignaciones_loteria').doc(id).update({
      'decimos_vendidos': vendidos,
      'decimos_devueltos': devueltos,
      'ultima_actualizacion': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<DecimoLoteria>> getDecimosVendedor(String vendedorId) {
    return _db
        .collection('decimos_loteria')
        .where('vendedor_id', isEqualTo: vendedorId)
        .snapshots()
        .map((s) => s.docs.map((d) => DecimoLoteria.fromFirestore(d)).toList()
          ..sort((a, b) {
            final byNumero = a.numeroLoteria.compareTo(b.numeroLoteria);
            if (byNumero != 0) return byNumero;
            final bySerie = a.serie.compareTo(b.serie);
            if (bySerie != 0) return bySerie;
            return a.numeroDecimo.compareTo(b.numeroDecimo);
          }));
  }

  Stream<bool> hasLoteriaAsignadaForCofrade(String cofradeId) {
    return _db
        .collection('decimos_loteria')
        .where('cofrade_id', isEqualTo: cofradeId)
        .where('estado', whereIn: [
          'asignado',
          'vendido',
          'cobrado',
          'devuelto_pendiente_revision',
        ])
        .limit(1)
        .snapshots()
        .map((s) => s.docs.isNotEmpty);
  }

  Stream<List<DecimoLoteria>> getDecimosCampana(String campanaId) {
    return _db
        .collection('decimos_loteria')
        .where('campana_id', isEqualTo: campanaId)
        .snapshots()
        .map((s) => s.docs.map((d) => DecimoLoteria.fromFirestore(d)).toList());
  }

  Stream<Map<String, dynamic>> getLoteriaCampanaStats(String campanaId) {
    return getDecimosCampana(campanaId).map((decimos) {
      final pendientes = decimos
          .where((d) =>
              d.estado == 'asignado' ||
              d.estado == 'vendido' ||
              d.estado == 'cobrado')
          .toList();
      final vendedoresConPendientes = pendientes
          .where((d) => d.vendedorId != null && d.vendedorId!.isNotEmpty)
          .map((d) => d.vendedorId!)
          .toSet()
          .length;
      final vendidos = decimos
          .where((d) => d.estado == 'vendido' || d.estado == 'cobrado')
          .length;
      final disponibles = decimos.where((d) => d.estado == 'disponible').length;
      final importeVendido = decimos
          .where((d) => d.estado == 'vendido' || d.estado == 'cobrado')
          .fold<double>(0, (total, d) => total + d.precioVenta);
      final importeCobrado = decimos
          .where((d) => d.estado == 'cobrado')
          .fold<double>(0, (total, d) => total + d.precioVenta);
      final entregadoCofradia = decimos
          .where((d) => d.paidToBrotherhood)
          .fold<double>(0, (total, d) => total + d.precioVenta);
      final entregadoAdministracion = decimos
          .where((d) => d.paidToAdministration)
          .fold<double>(0, (total, d) => total + d.precioVenta);
      return {
        'vendedores_pendientes': vendedoresConPendientes,
        'disponibles': disponibles,
        'vendidos': vendidos,
        'importe_vendido': importeVendido,
        'importe_cobrado': importeCobrado,
        'importe_pendiente_cobrar': importeVendido - importeCobrado,
        'entregado_cofradia': entregadoCofradia,
        'pendiente_entregar_cofradia': importeVendido - entregadoCofradia,
        'entregado_administracion': entregadoAdministracion,
        'pendiente_entregar_administracion':
            importeVendido - entregadoAdministracion,
      };
    });
  }

  Future<void> updateDecimoEstado(String decimoId, String estado,
      {String? actorId}) async {
    final decimoDoc =
        await _db.collection('decimos_loteria').doc(decimoId).get();
    if (!decimoDoc.exists) return;
    final current = DecimoLoteria.fromFirestore(decimoDoc);
    final data = <String, dynamic>{'estado': estado};
    if (estado == 'vendido' || estado == 'cobrado') {
      data['fecha_venta'] = FieldValue.serverTimestamp();
    } else if (estado == 'devuelto_pendiente_revision') {
      data['returnedBySeller'] = actorId;
      data['returnedAt'] = FieldValue.serverTimestamp();
      data['returnConfirmedByAdmin'] = false;
      data['returnConfirmedAt'] = null;
    } else {
      data['fecha_venta'] = null;
    }
    await decimoDoc.reference.update(data);

    if (current.vendedorId != null && current.vendedorId!.isNotEmpty) {
      final decimos = await _db
          .collection('decimos_loteria')
          .where('sabana_id', isEqualTo: current.sabanaId)
          .where('vendedor_id', isEqualTo: current.vendedorId)
          .get();
      final vendidos = decimos.docs
          .where((d) =>
              (d.id == decimoId ? estado : d.data()['estado']) == 'vendido')
          .length;
      final devueltos = decimos.docs.where((d) {
        final value = d.id == decimoId ? estado : d.data()['estado'];
        return value == 'devuelto' ||
            value == 'devuelto_pendiente_revision' ||
            value == 'devuelto_confirmado';
      }).length;
      final asigSnap = await _db
          .collection('asignaciones_loteria')
          .where('sabana_id', isEqualTo: current.sabanaId)
          .where('vendedor_id', isEqualTo: current.vendedorId)
          .limit(1)
          .get();
      if (asigSnap.docs.isNotEmpty) {
        await asigSnap.docs.first.reference.update({
          'decimos_vendidos': vendidos,
          'decimos_devueltos': devueltos,
          'ultima_actualizacion': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  Future<void> updateDecimoPayment({
    required String decimoId,
    bool? paidToBrotherhood,
    String? brotherhoodHolderId,
    String? brotherhoodHolderName,
    bool? paidToAdministration,
    String? notes,
    String? markedBy,
  }) async {
    final data = <String, dynamic>{};
    if (paidToBrotherhood != null) {
      if (paidToBrotherhood && (brotherhoodHolderId ?? '').isEmpty) {
        throw Exception(
            'Selecciona el cofrade que custodia el dinero antes de marcarlo como entregado a la Cofradía.');
      }
      data['paidToBrotherhood'] = paidToBrotherhood;
      data['paidToBrotherhoodAt'] =
          paidToBrotherhood ? FieldValue.serverTimestamp() : null;
      data['paidToBrotherhoodMarkedBy'] = paidToBrotherhood ? markedBy : null;
      data['brotherhoodHolderId'] =
          paidToBrotherhood ? brotherhoodHolderId : null;
      data['brotherhoodHolderName'] =
          paidToBrotherhood ? brotherhoodHolderName : null;
      data['brotherhoodHolderAssignedAt'] =
          paidToBrotherhood ? FieldValue.serverTimestamp() : null;
      data['brotherhoodHolderAssignedBy'] = paidToBrotherhood ? markedBy : null;
    }
    if (paidToAdministration != null) {
      data['paidToAdministration'] = paidToAdministration;
      data['paidToAdministrationAt'] =
          paidToAdministration ? FieldValue.serverTimestamp() : null;
      data['paidToAdministrationMarkedBy'] =
          paidToAdministration ? markedBy : null;
    }
    if (notes != null) data['paymentNotes'] = notes;
    await _db.collection('decimos_loteria').doc(decimoId).update(data);
  }

  Future<void> confirmDecimoReturn({
    required String decimoId,
    required bool makeAvailable,
    String? notes,
    String? adminId,
  }) async {
    final data = <String, dynamic>{
      'estado': makeAvailable ? 'disponible' : 'devuelto_confirmado',
      'returnConfirmedByAdmin': true,
      'returnConfirmedAt': FieldValue.serverTimestamp(),
      'returnConfirmedBy': adminId,
      'returnNotes': notes ?? '',
    };
    if (makeAvailable) {
      data['vendedor_id'] = null;
      data['cofrade_id'] = null;
    }
    await _db.collection('decimos_loteria').doc(decimoId).update(data);
  }

  Future<void> deleteAsignacion(String id) async {
    // Get asignacion to restore sabana
    final doc = await _db.collection('asignaciones_loteria').doc(id).get();
    if (doc.exists) {
      final sabanaId = doc.data()?['sabana_id'] as String?;
      if (sabanaId != null) {
        await _db
            .collection('sabanas')
            .doc(sabanaId)
            .update({'estado': 'disponible'});
      }
    }
    await _db.collection('asignaciones_loteria').doc(id).delete();
  }

  // Search cofrades for autocomplete
  Future<List<Cofrade>> searchCofrades(String query) async {
    final trimmed = _normalizeSearchText(query);
    debugPrint('[Firestore] searchCofrades("$query")');

    // Use the minimal search index instead of the full cofrades collection.
    // Normal authenticated users cannot list cofrades because those documents
    // contain sensitive fields. cofrades_busqueda only contains display data.
    final snap =
        await _db.collection('cofrades_busqueda').orderBy('apellidos').get();
    final all = snap.docs
        .map((d) => Cofrade.fromFirestore(d))
        .where((c) => c.isActivo)
        .toList();
    debugPrint(
        '[Firestore] searchCofrades: ${all.length} active indexed cofrades found');
    if (trimmed.isEmpty) return all;
    return all.where((c) {
      final searchable = _normalizeSearchText(
        '${c.nombre} ${c.apellidos} ${c.apellidos} ${c.nombre} '
        '${c.numero ?? ''} ${c.dni ?? ''} ${c.telefonoMovil} '
        '${c.telefonoFijo} ${c.telefonoSecundario ?? ''} ${c.email} '
        '${c.emailSecundario ?? ''}',
      );
      return searchable.contains(trimmed);
    }).toList();
  }

  String _normalizeSearchText(String value) {
    const replacements = {
      'á': 'a',
      'à': 'a',
      'ä': 'a',
      'â': 'a',
      'Á': 'a',
      'À': 'a',
      'Ä': 'a',
      'Â': 'a',
      'é': 'e',
      'è': 'e',
      'ë': 'e',
      'ê': 'e',
      'É': 'e',
      'È': 'e',
      'Ë': 'e',
      'Ê': 'e',
      'í': 'i',
      'ì': 'i',
      'ï': 'i',
      'î': 'i',
      'Í': 'i',
      'Ì': 'i',
      'Ï': 'i',
      'Î': 'i',
      'ó': 'o',
      'ò': 'o',
      'ö': 'o',
      'ô': 'o',
      'Ó': 'o',
      'Ò': 'o',
      'Ö': 'o',
      'Ô': 'o',
      'ú': 'u',
      'ù': 'u',
      'ü': 'u',
      'û': 'u',
      'Ú': 'u',
      'Ù': 'u',
      'Ü': 'u',
      'Û': 'u',
      'ñ': 'n',
      'Ñ': 'n',
      'ç': 'c',
      'Ç': 'c',
    };
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(replacements[char] ?? char.toLowerCase());
    }
    return buffer.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _matchesAutomaticCriterion(
    Map<String, dynamic> data,
    Map<String, dynamic> criterio,
    Cofrade cofrade,
  ) {
    final conditionsRaw = criterio['conditions'] ?? criterio['condiciones'];
    if (conditionsRaw is Iterable) {
      final conditions = conditionsRaw
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList();
      if (conditions.isEmpty) return false;
      final combinator =
          '${criterio['combinator'] ?? criterio['combinador'] ?? 'AND'}'
              .toUpperCase();
      final results = conditions
          .map((condition) =>
              _matchesAutomaticCriterion(data, condition, cofrade))
          .toList();
      return combinator == 'OR'
          ? results.any((result) => result)
          : results.every((result) => result);
    }
    final field = criterio['campo']?.toString() ?? '';
    final operator = criterio['operador']?.toString() ?? '==';
    final expected = criterio['valor'];
    if (field.isEmpty) return false;
    final actual = data.containsKey(field)
        ? data[field]
        : _computedTagFieldValue(field, cofrade);
    if (actual == null && operator != 'empty') return false;
    final actualNum = actual is num ? actual : num.tryParse('$actual');
    final expectedNum = expected is num ? expected : num.tryParse('$expected');
    switch (operator) {
      case '==':
        return '$actual'.toLowerCase() == '$expected'.toLowerCase();
      case '!=':
        return '$actual'.toLowerCase() != '$expected'.toLowerCase();
      case '<':
        return actualNum != null &&
            expectedNum != null &&
            actualNum < expectedNum;
      case '<=':
        return actualNum != null &&
            expectedNum != null &&
            actualNum <= expectedNum;
      case '>':
        return actualNum != null &&
            expectedNum != null &&
            actualNum > expectedNum;
      case '>=':
        return actualNum != null &&
            expectedNum != null &&
            actualNum >= expectedNum;
      case 'contains':
        return '$actual'.toLowerCase().contains('$expected'.toLowerCase());
      case 'empty':
        return actual == null || '$actual'.trim().isEmpty;
      case 'not_empty':
        return actual != null && '$actual'.trim().isNotEmpty;
      default:
        return false;
    }
  }

  Object? _computedTagFieldValue(String field, Cofrade cofrade) {
    switch (field) {
      case 'edad':
        return cofrade.edad ??
            _ageFromBirthDateString(cofrade.fechaNacimientoStr);
      case 'anios_hermandad':
        return cofrade.anioAlta == null
            ? null
            : DateTime.now().year - cofrade.anioAlta!;
      case 'tiene_datos_obligatorios_pendientes':
        return cofrade.tieneDatosIncompletos;
      case 'anio_alta':
      case 'year_joined':
        return cofrade.anioAlta;
      case 'anio_mayordomia':
      case 'year_mayordomia':
        return cofrade.anioMayordomia;
      case 'genero':
        return cofrade.genero;
      case 'estado':
      case 'status':
        return cofrade.estado;
      case 'cuota_activa':
      case 'cuotaActiva':
        return cofrade.cuotaActiva;
      case 'gdpr_papel':
      case 'gdprPapel':
        return cofrade.gdprPapel;
      case 'gdpr_digital':
      case 'gdprDigitalAccepted':
        return cofrade.gdprDigitalAccepted;
      case 'requiresDigitalTutor':
      case 'requiere_tutela_digital':
        return cofrade.requiresDigitalTutor;
      case 'tiene_tunica_propia':
        return cofrade.tieneTunicaPropia;
      case 'numero':
        return cofrade.numero;
      case 'es_baja':
        return cofrade.isBaja;
      case 'es_activo':
        return cofrade.isActivo;
      case 'tiene_iban':
        return (cofrade.iban ?? '').trim().isNotEmpty;
      case 'tiene_email':
        return cofrade.email.trim().isNotEmpty;
      case 'tiene_telefono_movil':
        return cofrade.telefonoMovil.trim().isNotEmpty;
      case 'hasLoggedIn':
        return cofrade.rawData['hasLoggedIn'] == true;
      case 'lastLoginAt':
        return cofrade.rawData['lastLoginAt'];
      case 'firstLoginAt':
        return cofrade.rawData['firstLoginAt'];
      case 'loginCount':
        return cofrade.rawData['loginCount'];
      case 'lastLoginMethod':
        return cofrade.rawData['lastLoginMethod'];
      case 'linkedAuthProviders':
        return cofrade.rawData['linkedAuthProviders'];
      default:
        return null;
    }
  }

  int? _ageFromBirthDateString(String value) {
    final parts = value.split('/');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    final now = DateTime.now();
    var age = now.year - year;
    if (now.month < month || (now.month == month && now.day < day)) {
      age--;
    }
    return age;
  }

  int _ageFromDate(DateTime? birth) {
    if (birth == null) return 99;
    final now = DateTime.now();
    var age = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      age--;
    }
    return age;
  }

  String _normalizeDni(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'[\s\-_.]'), '').trim();
  }
}
