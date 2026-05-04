import 'dart:convert';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:boanerges1714/models/cofrade.dart';
import 'package:boanerges1714/models/treasury.dart';

class TreasuryRepository {
  final FirebaseFirestore _db;

  TreasuryRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _settings =>
      _db.collection('treasury_settings');
  CollectionReference<Map<String, dynamic>> get _feeDrafts =>
      _db.collection('treasury_fee_drafts');
  CollectionReference<Map<String, dynamic>> get _invoices =>
      _db.collection('treasury_invoices');
  CollectionReference<Map<String, dynamic>> get _invoiceLines =>
      _db.collection('treasury_invoice_lines');
  CollectionReference<Map<String, dynamic>> get _bankValidations =>
      _db.collection('treasury_bank_validations');
  CollectionReference<Map<String, dynamic>> get _payments =>
      _db.collection('treasury_payments');
  CollectionReference<Map<String, dynamic>> get _returns =>
      _db.collection('treasury_returns');
  CollectionReference<Map<String, dynamic>> get _remittances =>
      _db.collection('treasury_remittances');
  CollectionReference<Map<String, dynamic>> get _movements =>
      _db.collection('treasury_accounting_movements');
  CollectionReference<Map<String, dynamic>> get _costCenters =>
      _db.collection('treasury_cost_centers');
  CollectionReference<Map<String, dynamic>> get _auditLogs =>
      _db.collection('treasury_audit_logs');
  CollectionReference<Map<String, dynamic>> get _cofrades =>
      _db.collection('cofrades');

  Stream<TreasurySettings?> watchActiveSettings() {
    return _settings
        .where('isActive', isEqualTo: true)
        .limit(1)
        .snapshots()
        .map((s) => s.docs.isEmpty
            ? null
            : TreasurySettings.fromFirestore(s.docs.first));
  }

  Future<TreasurySettings?> getActiveSettings() async {
    final snap =
        await _settings.where('isActive', isEqualTo: true).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return TreasurySettings.fromFirestore(snap.docs.first);
  }

  Future<TreasurySettings?> getSettingsByYear(int year) async {
    final snap = await _settings.where('year', isEqualTo: year).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return TreasurySettings.fromFirestore(snap.docs.first);
  }

  Stream<TreasurySettings?> watchSettingsByYear(int year) {
    return _settings.where('year', isEqualTo: year).limit(1).snapshots().map(
        (s) => s.docs.isEmpty
            ? null
            : TreasurySettings.fromFirestore(s.docs.first));
  }

  Future<String> saveSettings(TreasurySettings settings,
      {String? changedBy}) async {
    final existing = await getSettingsByYear(settings.year);
    if (settings.isActive) {
      final active = await _settings.where('isActive', isEqualTo: true).get();
      final batch = _db.batch();
      for (final doc in active.docs) {
        if (doc.id != existing?.id) {
          batch.update(doc.reference, {
            'isActive': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
      await batch.commit();
    }

    if (existing != null) {
      await _settings
          .doc(existing.id)
          .update(settings.copyWith(id: existing.id).toFirestore());
      await createAuditLog(
        entityType: 'treasury_settings',
        entityId: existing.id,
        action: 'update',
        oldValue: _settingsAuditMap(existing),
        newValue: _settingsAuditMap(settings),
        changedBy: changedBy,
      );
      return existing.id;
    }

    final ref = _settings.doc('${settings.year}');
    await ref.set(settings.toFirestore());
    await createAuditLog(
      entityType: 'treasury_settings',
      entityId: ref.id,
      action: 'create',
      newValue: _settingsAuditMap(settings),
      changedBy: changedBy,
    );
    return ref.id;
  }

  Map<String, dynamic> _settingsAuditMap(TreasurySettings settings) {
    return {
      'year': settings.year,
      'annualFeeAmount': settings.annualFeeAmount,
      'validationStartDate': settings.validationStartDate?.toIso8601String(),
      'validationEndDate': settings.validationEndDate?.toIso8601String(),
      'remittanceDate': settings.remittanceDate?.toIso8601String(),
      'allowIbanEdition': settings.allowIbanEdition,
      'isActive': settings.isActive,
      'validationMessage': settings.validationMessage,
    };
  }

  Stream<List<TreasuryInvoice>> getInvoicesByYear(int year) {
    return _invoices.where('year', isEqualTo: year).snapshots().map((s) =>
        s.docs.map((d) => TreasuryInvoice.fromFirestore(d)).toList()
          ..sort((a, b) => a.invoiceNumber.compareTo(b.invoiceNumber)));
  }

  Stream<List<TreasuryInvoice>> getInvoicesForCofrade(String cofradeId) {
    return _invoices
        .where('cofradeIds', arrayContains: cofradeId)
        .snapshots()
        .map((s) => s.docs.map((d) => TreasuryInvoice.fromFirestore(d)).toList()
          ..sort((a, b) => b.year.compareTo(a.year)));
  }

  Stream<List<TreasuryInvoice>> getInvoicesForAuthUid(String authUid) {
    return _invoices
        .where('cofradeAuthUids', arrayContains: authUid)
        .snapshots()
        .map((s) => s.docs.map((d) => TreasuryInvoice.fromFirestore(d)).toList()
          ..sort((a, b) => b.year.compareTo(a.year)));
  }

  Stream<List<Cofrade>> watchCofradesForTreasuryTracking() {
    return _cofrades.snapshots().map((s) => s.docs
        .map((d) => Cofrade.fromFirestore(d))
        .where((c) => c.isActivo)
        .toList()
      ..sort((a, b) => a.nombreCompleto.compareTo(b.nombreCompleto)));
  }

  Stream<List<TreasuryFeeDraft>> getFeeDraftsByYear(int year) {
    return _feeDrafts.where('year', isEqualTo: year).snapshots().map((s) =>
        s.docs.map((d) => TreasuryFeeDraft.fromFirestore(d)).toList()
          ..sort((a, b) => a.cofradeName.compareTo(b.cofradeName)));
  }

  Future<TreasuryInvoice?> getInvoice(String invoiceId) async {
    final doc = await _invoices.doc(invoiceId).get();
    if (!doc.exists) return null;
    return TreasuryInvoice.fromFirestore(doc);
  }

  Stream<List<TreasuryInvoiceLine>> getInvoiceLinesByYear(int year) {
    return _invoiceLines.where('year', isEqualTo: year).snapshots().map((s) =>
        s.docs.map((d) => TreasuryInvoiceLine.fromFirestore(d)).toList());
  }

  Stream<List<TreasuryInvoiceLine>> getInvoiceLines(String invoiceId) {
    return _invoiceLines
        .where('invoiceId', isEqualTo: invoiceId)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => TreasuryInvoiceLine.fromFirestore(d)).toList()
              ..sort((a, b) => a.cofradeName.compareTo(b.cofradeName)));
  }

  Future<List<TreasuryInvoiceLine>> getInvoiceLinesOnce(
      String invoiceId) async {
    final snap =
        await _invoiceLines.where('invoiceId', isEqualTo: invoiceId).get();
    return snap.docs.map((d) => TreasuryInvoiceLine.fromFirestore(d)).toList()
      ..sort((a, b) => a.cofradeName.compareTo(b.cofradeName));
  }

  Stream<List<TreasuryPayment>> getPaymentsByYear(int year) {
    return _payments.snapshots().asyncMap((s) async {
      final payments = s.docs.map((d) => TreasuryPayment.fromFirestore(d));
      final filtered = <TreasuryPayment>[];
      for (final payment in payments) {
        if (payment.paymentDate?.year == year) filtered.add(payment);
      }
      return filtered;
    });
  }

  Stream<List<TreasuryPayment>> getCollectionAttemptsByYear(int year) {
    return _payments.where('year', isEqualTo: year).snapshots().map((s) =>
        s.docs.map((d) => TreasuryPayment.fromFirestore(d)).toList()
          ..sort((a, b) => (b.createdAt ?? DateTime(1900))
              .compareTo(a.createdAt ?? DateTime(1900))));
  }

  Stream<List<TreasuryPayment>> getPaymentsForCofrade(String cofradeId) {
    return _payments.snapshots().asyncMap((s) async {
      final invoiceSnap =
          await _invoices.where('cofradeIds', arrayContains: cofradeId).get();
      final invoiceIds = invoiceSnap.docs.map((doc) => doc.id).toSet();
      return s.docs
          .map((d) => TreasuryPayment.fromFirestore(d))
          .where((payment) =>
              payment.cofradeId == cofradeId ||
              invoiceIds.contains(payment.invoiceId))
          .toList()
        ..sort((a, b) =>
            (b.resultDate ?? b.paymentDate ?? b.createdAt ?? DateTime(1900))
                .compareTo(a.resultDate ??
                    a.paymentDate ??
                    a.createdAt ??
                    DateTime(1900)));
    });
  }

  Future<void> markPaymentAttempt({
    required String paymentId,
    required String status,
    required String changedBy,
    String rejectionReason = '',
    String method = '',
    String reference = '',
  }) async {
    final paymentDoc = await _payments.doc(paymentId).get();
    if (!paymentDoc.exists) throw Exception('Recibo no encontrado.');
    final payment = TreasuryPayment.fromFirestore(paymentDoc);
    final nextMethod = method.isEmpty ? payment.method : method;
    final batch = _db.batch();
    batch.update(paymentDoc.reference, {
      'status': status,
      'method': nextMethod,
      'reference': reference,
      'rejectionReason': rejectionReason,
      'resultDate': FieldValue.serverTimestamp(),
      'paymentDate': status == 'paid' ? FieldValue.serverTimestamp() : null,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': changedBy,
    });
    if (status == 'paid') {
      batch.update(_invoices.doc(payment.invoiceId), {
        'status': 'paid',
        'paidAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final linesSnap = await _invoiceLines
          .where('invoiceId', isEqualTo: payment.invoiceId)
          .get();
      for (final line in linesSnap.docs) {
        batch.update(line.reference, {
          'status': 'paid',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } else if (status == 'rejected') {
      batch.update(_invoices.doc(payment.invoiceId), {
        'status': 'returned',
        'returnedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else if (status == 'manual_pending') {
      batch.update(_invoices.doc(payment.invoiceId), {
        'status': 'manual_pending',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else if (status == 'retry_pending') {
      batch.update(_invoices.doc(payment.invoiceId), {
        'status': 'approved',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    await _syncPaymentAccountingMovement(
      paymentId: paymentId,
      payment: payment,
      status: status,
      method: nextMethod,
      reference: reference,
      rejectionReason: rejectionReason,
      changedBy: changedBy,
    );
    await createAuditLog(
      entityType: 'treasury_payment',
      entityId: paymentId,
      action: 'update_collection_result',
      oldValue: {'status': payment.status, 'method': payment.method},
      newValue: {
        'status': status,
        'method': nextMethod,
        'rejectionReason': rejectionReason,
        'reference': reference,
      },
      changedBy: changedBy,
    );
  }

  Future<void> createManualPayment({
    required TreasuryInvoice invoice,
    required String method,
    required String reference,
    required String changedBy,
  }) async {
    if (invoice.status == 'paid') {
      throw Exception('La factura ya está cobrada.');
    }
    final ref = _payments.doc();
    final batch = _db.batch();
    batch.set(ref, {
      'year': invoice.year,
      'invoiceId': invoice.id,
      'cofradeId':
          invoice.cofradeIds.isNotEmpty ? invoice.cofradeIds.first : '',
      'invoiceNumber': invoice.invoiceNumber,
      'cofradeName': invoice.holderName,
      'amount': invoice.totalAmount,
      'method': method,
      'status': 'paid',
      'reference': reference,
      'paymentDate': FieldValue.serverTimestamp(),
      'resultDate': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': changedBy,
    });
    batch.update(_invoices.doc(invoice.id), {
      'status': 'paid',
      'paidAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final linesSnap =
        await _invoiceLines.where('invoiceId', isEqualTo: invoice.id).get();
    for (final line in linesSnap.docs) {
      batch.update(line.reference, {
        'status': 'paid',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    await _syncPaymentAccountingMovement(
      paymentId: ref.id,
      payment: TreasuryPayment(
        id: ref.id,
        year: invoice.year,
        invoiceId: invoice.id,
        cofradeId:
            invoice.cofradeIds.isNotEmpty ? invoice.cofradeIds.first : '',
        invoiceNumber: invoice.invoiceNumber,
        cofradeName: invoice.holderName,
        amount: invoice.totalAmount,
        method: method,
        status: 'paid',
        reference: reference,
      ),
      status: 'paid',
      method: method,
      reference: reference,
      changedBy: changedBy,
    );
    await createAuditLog(
      entityType: 'treasury_payment',
      entityId: ref.id,
      action: 'manual_payment_recorded',
      newValue: {
        'invoiceId': invoice.id,
        'method': method,
        'reference': reference,
        'amount': invoice.totalAmount,
      },
      changedBy: changedBy,
    );
  }

  Stream<List<Map<String, dynamic>>> getReturnsByYear(int year) {
    return _returns
        .where('year', isEqualTo: year)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Stream<List<TreasuryRemittance>> getRemittancesByYear(int year) {
    return _remittances.where('year', isEqualTo: year).snapshots().map((s) =>
        s.docs.map((d) => TreasuryRemittance.fromFirestore(d)).toList()
          ..sort((a, b) => (b.generatedAt ?? DateTime(1900))
              .compareTo(a.generatedAt ?? DateTime(1900))));
  }

  Future<List<TreasuryRemittanceRow>> getRemittanceRowsByYear(int year) async {
    final invoicesSnap = await _invoices
        .where('year', isEqualTo: year)
        .where('paymentMethod', isEqualTo: 'bank_remittance')
        .get();
    final processedSnap = await _remittances
        .where('year', isEqualTo: year)
        .where('status', isEqualTo: 'processed')
        .get();
    final processedInvoiceIds = processedSnap.docs
        .expand((d) => (d.data()['invoiceIds'] as List<dynamic>? ?? []))
        .map((id) => '$id')
        .toSet();
    final rows = <TreasuryRemittanceRow>[];
    for (final doc in invoicesSnap.docs) {
      final invoice = TreasuryInvoice.fromFirestore(doc);
      if (invoice.status == 'cancelled' ||
          invoice.status == 'paid' ||
          invoice.status == 'pending_collection' ||
          invoice.status == 'manual_pending' ||
          invoice.totalAmount <= 0 ||
          processedInvoiceIds.contains(invoice.id)) {
        continue;
      }
      final debtorIban = await _fullIbanForInvoice(invoice);
      if (debtorIban.isEmpty) continue;
      rows.add(TreasuryRemittanceRow(
        invoiceId: invoice.id,
        invoiceNumber: invoice.invoiceNumber,
        holderName: invoice.holderName,
        debtorIban: debtorIban,
        amount: invoice.totalAmount,
        concept: invoice.concept,
        hasUnvalidatedRecords: invoice.hasUnvalidatedRecords,
      ));
    }
    rows.sort((a, b) => a.invoiceNumber.compareTo(b.invoiceNumber));
    return rows;
  }

  Future<TreasuryRemittance> saveGeneratedRemittance({
    required int year,
    required List<TreasuryRemittanceRow> rows,
    required String fileUrlCsv,
    required String fileUrlXlsx,
    required String generatedBy,
    String notes = '',
  }) async {
    if (rows.isEmpty) {
      throw Exception('No hay facturas domiciliadas disponibles para remesar.');
    }
    final totalAmount =
        rows.fold<double>(0, (total, row) => total + row.amount);
    final unvalidatedRows =
        rows.where((row) => row.hasUnvalidatedRecords).toList();
    final ref = await _remittances.add({
      'year': year,
      'status': 'generated',
      'invoiceIds': rows.map((row) => row.invoiceId).toList(),
      'totalAmount': totalAmount,
      'fileUrlCsv': fileUrlCsv,
      'fileUrlXlsx': fileUrlXlsx,
      'generatedAt': FieldValue.serverTimestamp(),
      'generatedBy': generatedBy,
      'unvalidatedCount': unvalidatedRows.length,
      'unvalidatedAmount':
          unvalidatedRows.fold<double>(0, (total, row) => total + row.amount),
      'notes': notes,
    });
    final batch = _db.batch();
    final pendingAttempts = <TreasuryPayment>[];
    for (final row in rows) {
      final existingAttempt = await _payments
          .where('remittanceId', isEqualTo: ref.id)
          .where('invoiceId', isEqualTo: row.invoiceId)
          .limit(1)
          .get();
      if (existingAttempt.docs.isNotEmpty) continue;
      final paymentRef = _payments.doc();
      batch.set(paymentRef, {
        'year': year,
        'invoiceId': row.invoiceId,
        'remittanceId': ref.id,
        'invoiceNumber': row.invoiceNumber,
        'cofradeName': row.holderName,
        'amount': row.amount,
        'method': 'bank_remittance',
        'status': 'pending',
        'notes': row.concept,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': generatedBy,
      });
      pendingAttempts.add(TreasuryPayment(
        id: paymentRef.id,
        year: year,
        invoiceId: row.invoiceId,
        remittanceId: ref.id,
        invoiceNumber: row.invoiceNumber,
        cofradeName: row.holderName,
        amount: row.amount,
        method: 'bank_remittance',
        status: 'pending',
        notes: row.concept,
        createdBy: generatedBy,
      ));
      batch.update(_invoices.doc(row.invoiceId), {
        'status': 'pending_collection',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    for (final attempt in pendingAttempts) {
      await _syncPaymentAccountingMovement(
        paymentId: attempt.id,
        payment: attempt,
        status: 'pending',
        method: 'bank_remittance',
        reference: ref.id,
        changedBy: generatedBy,
      );
    }
    final doc = await ref.get();
    await createAuditLog(
      entityType: 'treasury_remittances',
      entityId: ref.id,
      action: unvalidatedRows.isEmpty
          ? 'generate_remittance'
          : 'generate_remittance_with_unvalidated_records',
      newValue: {
        'year': year,
        'invoiceCount': rows.length,
        'totalAmount': totalAmount,
        'unvalidatedCount': unvalidatedRows.length,
      },
      changedBy: generatedBy,
    );
    return TreasuryRemittance.fromFirestore(doc);
  }

  Stream<List<TreasuryAccountingMovement>> getAccountingMovementsByYear(
      int year) {
    return _movements.snapshots().map((s) => s.docs
        .map((d) => TreasuryAccountingMovement.fromFirestore(d))
        .where((m) => m.date?.year == year)
        .toList());
  }

  Stream<List<TreasuryAccountingMovement>> getAccountingMovementsForPerson({
    required String personId,
    DateTime? start,
    DateTime? end,
  }) {
    return _movements.snapshots().asyncMap((s) async {
      final invoiceSnap =
          await _invoices.where('cofradeIds', arrayContains: personId).get();
      final invoiceIds = invoiceSnap.docs.map((doc) => doc.id).toSet();
      final items = s.docs
          .map((d) => TreasuryAccountingMovement.fromFirestore(d))
          .where((movement) =>
              movement.personId == personId ||
              (movement.linkedInvoiceId != null &&
                  invoiceIds.contains(movement.linkedInvoiceId)));
      return items.where((movement) {
        final date = movement.date;
        if (date == null) return true;
        if (start != null && date.isBefore(start)) return false;
        if (end != null && date.isAfter(end)) return false;
        return true;
      }).toList()
        ..sort((a, b) =>
            (b.date ?? DateTime(1900)).compareTo(a.date ?? DateTime(1900)));
    });
  }

  Stream<List<TreasuryAuditLog>> watchAuditLogs({int limit = 80}) {
    return _auditLogs
        .orderBy('changedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => TreasuryAuditLog.fromFirestore(d)).toList());
  }

  Stream<List<Map<String, dynamic>>> watchTreasuryNotifications(
      {int limit = 50}) {
    return _db
        .collection('novedades')
        .where('tipo', isEqualTo: 'tesoreria')
        .limit(limit)
        .snapshots()
        .map((s) {
      final items = s.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      items.sort((a, b) {
        final ad = _asDate(a['fecha_creacion']) ?? DateTime(1900);
        final bd = _asDate(b['fecha_creacion']) ?? DateTime(1900);
        return bd.compareTo(ad);
      });
      return items;
    });
  }

  Future<void> saveAccountingMovement({
    String id = '',
    required TreasuryAccountingMovement movement,
    required String changedBy,
  }) async {
    if (movement.costCenterId.isEmpty) {
      throw Exception('El movimiento debe tener un centro de coste.');
    }
    final ref = id.isEmpty ? _movements.doc() : _movements.doc(id);
    await ref.set(movement.toFirestore(), SetOptions(merge: true));
    await createAuditLog(
      entityType: 'treasury_accounting_movement',
      entityId: ref.id,
      action: id.isEmpty
          ? 'create_accounting_movement'
          : 'update_accounting_movement',
      newValue: {
        'year': movement.year,
        'type': movement.type,
        'amount': movement.amount,
        'costCenterId': movement.costCenterId,
        'subCostCenterId': movement.subCostCenterId,
        'concept': movement.concept,
        'status': movement.status,
        'personType': movement.personType,
        'personId': movement.personId,
        'origin': movement.origin,
      },
      changedBy: changedBy,
    );
  }

  Future<void> updateAccountingMovementEditable({
    required String movementId,
    required Map<String, dynamic> values,
    required String changedBy,
  }) async {
    final ref = _movements.doc(movementId);
    final snap = await ref.get();
    if (!snap.exists) {
      throw Exception('El movimiento contable no existe.');
    }
    final old = snap.data() ?? {};
    final allowedKeys = {
      'concept',
      'description',
      'costCenterId',
      'subCostCenterId',
      'status',
      'reference',
      'personType',
      'personId',
      'personName',
      'updatedAt',
    };
    final sanitized = <String, dynamic>{};
    for (final entry in values.entries) {
      if (allowedKeys.contains(entry.key)) {
        sanitized[entry.key] = entry.value;
      }
    }
    if ((sanitized['costCenterId'] ?? old['costCenterId'] ?? '')
        .toString()
        .isEmpty) {
      throw Exception('El movimiento debe tener un centro de coste.');
    }
    sanitized['updatedAt'] = FieldValue.serverTimestamp();
    await ref.update(sanitized);
    await createAuditLog(
      entityType: 'treasury_accounting_movement',
      entityId: movementId,
      action: 'edit_accounting_movement',
      oldValue: {
        for (final key in sanitized.keys)
          if (key != 'updatedAt') key: old[key],
      },
      newValue: {
        for (final key in sanitized.keys)
          if (key != 'updatedAt') key: sanitized[key],
      },
      changedBy: changedBy,
    );
  }

  Stream<List<TreasuryAccountingMovement>> getAccountingMovementsInRange({
    required DateTime start,
    required DateTime end,
  }) {
    return _movements.snapshots().map((s) => s.docs
            .map((d) => TreasuryAccountingMovement.fromFirestore(d))
            .where((m) {
          final date = m.date;
          return date != null && !date.isBefore(start) && !date.isAfter(end);
        }).toList());
  }

  Stream<List<int>> watchAvailableTreasuryYears() {
    return Stream<List<int>>.multi((controller) {
      final subscriptions = <StreamSubscription<QuerySnapshot>>[];
      var closed = false;
      Future<void> emit() async {
        if (closed) return;
        try {
          final years = <int>{DateTime.now().year};
          for (final collection in [
            _settings,
            _feeDrafts,
            _invoices,
            _remittances,
          ]) {
            final snap = await collection.get();
            for (final doc in snap.docs) {
              final year = (doc.data()['year'] as num?)?.toInt();
              if (year != null) years.add(year);
            }
          }
          controller.add(years.toList()..sort((a, b) => b.compareTo(a)));
        } catch (error, stackTrace) {
          controller.addError(error, stackTrace);
        }
      }

      for (final stream in [
        _settings.snapshots(),
        _feeDrafts.snapshots(),
        _invoices.snapshots(),
        _remittances.snapshots(),
      ]) {
        subscriptions
            .add(stream.listen((_) => emit(), onError: controller.addError));
      }
      emit();
      controller.onCancel = () async {
        closed = true;
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      };
    });
  }

  Stream<List<TreasuryCostCenter>> watchCostCenters() {
    return _costCenters.snapshots().map(
        (s) => s.docs.map((d) => TreasuryCostCenter.fromFirestore(d)).toList()
          ..sort((a, b) {
            final parentCompare = a.parentId.compareTo(b.parentId);
            if (parentCompare != 0) return parentCompare;
            return a.name.compareTo(b.name);
          }));
  }

  Future<void> saveCostCenter({
    required String id,
    required String name,
    required String description,
    String parentId = '',
    double budgetAmount = 0,
    required bool isActive,
    required String changedBy,
  }) async {
    final ref = id.isEmpty ? _costCenters.doc() : _costCenters.doc(id);
    final exists = id.isNotEmpty && (await ref.get()).exists;
    await ref.set({
      'name': name.trim(),
      'description': description.trim(),
      'parentId': parentId,
      'budgetAmount': budgetAmount,
      'isActive': isActive,
      if (!exists) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await createAuditLog(
      entityType: 'treasury_cost_center',
      entityId: ref.id,
      action: exists ? 'update_cost_center' : 'create_cost_center',
      newValue: {
        'name': name.trim(),
        'description': description.trim(),
        'parentId': parentId,
        'budgetAmount': budgetAmount,
        'isActive': isActive,
      },
      changedBy: changedBy,
    );
  }

  Future<int> seedDefaultCostCenters({required String changedBy}) async {
    const defaults = {
      'Semana Santa': [
        'Andas',
        'Flores',
        'Banda de música',
        'Iluminación',
        'Vestimenta',
        'Logística',
      ],
      'Eventos y convivencias': [
        'Comida 27 diciembre',
        'Convivencias',
        'Eventos extraordinarios',
        'Actividades internas',
      ],
      'Acción social': ['La Rosa', 'Donaciones', 'Campañas solidarias'],
      'Lotería': ['Compra', 'Venta', 'Beneficio'],
      'Administración': ['Banco', 'Seguros', 'Gestoría', 'Papelería'],
      'Tecnología': ['Desarrollo app', 'Infraestructura', 'Licencias'],
      'Ingresos': ['Cuotas hermanos', 'Donaciones', 'Patrocinios'],
      'Ingresos ordinarios': [
        'Cuotas de hermanos',
        'Cobros domiciliados',
        'Cobros manuales',
        'Rechazos recuperados',
        'Ajustes de facturación',
      ],
    };
    final existing = await _costCenters.get();
    final existingKeys = existing.docs.map((doc) {
      final data = doc.data();
      return '${data['parentId'] ?? ''}|${data['name'] ?? ''}';
    }).toSet();
    final rootIds = <String, String>{};
    for (final doc in existing.docs) {
      final center = TreasuryCostCenter.fromFirestore(doc);
      if (center.parentId.isEmpty) rootIds[center.name] = center.id;
    }
    var created = 0;
    final batch = _db.batch();
    for (final entry in defaults.entries) {
      var parentId = rootIds[entry.key];
      if (parentId == null && !existingKeys.contains('|${entry.key}')) {
        final ref = _costCenters.doc();
        parentId = ref.id;
        rootIds[entry.key] = parentId;
        batch.set(ref, {
          'name': entry.key,
          'description': 'Centro base preconfigurado',
          'parentId': '',
          'budgetAmount': 0,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        created++;
      }
      for (final child in entry.value) {
        final key = '$parentId|$child';
        if (parentId == null || existingKeys.contains(key)) continue;
        final ref = _costCenters.doc();
        batch.set(ref, {
          'name': child,
          'description': 'Subcentro base de ${entry.key}',
          'parentId': parentId,
          'budgetAmount': 0,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        created++;
      }
    }
    if (created > 0) await batch.commit();
    await createAuditLog(
      entityType: 'treasury_cost_center',
      entityId: 'default_seed',
      action: 'seed_default_cost_centers',
      newValue: {'created': created},
      changedBy: changedBy,
    );
    return created;
  }

  Future<void> deleteCostCenter({
    required String id,
    required String changedBy,
  }) async {
    final children =
        await _costCenters.where('parentId', isEqualTo: id).limit(1).get();
    if (children.docs.isNotEmpty) {
      throw Exception('No se puede eliminar un centro con subcentros.');
    }
    final movements =
        await _movements.where('costCenterId', isEqualTo: id).limit(1).get();
    final subMovements =
        await _movements.where('subCostCenterId', isEqualTo: id).limit(1).get();
    if (movements.docs.isNotEmpty || subMovements.docs.isNotEmpty) {
      throw Exception('No se puede eliminar: tiene movimientos asociados.');
    }
    await _costCenters.doc(id).delete();
    await createAuditLog(
      entityType: 'treasury_cost_center',
      entityId: id,
      action: 'delete_cost_center',
      changedBy: changedBy,
    );
  }

  Stream<TreasuryDashboardSummary> watchDashboardSummary(int year) {
    return Stream<TreasuryDashboardSummary>.multi((controller) {
      final subscriptions = <StreamSubscription<QuerySnapshot>>[];
      var closed = false;

      Future<void> emit() async {
        if (closed) return;
        try {
          controller.add(await getDashboardSummary(year));
        } catch (error, stackTrace) {
          controller.addError(error, stackTrace);
        }
      }

      for (final stream in [
        _settings.where('year', isEqualTo: year).snapshots(),
        _feeDrafts.where('year', isEqualTo: year).snapshots(),
        _invoices.where('year', isEqualTo: year).snapshots(),
        _invoiceLines.where('year', isEqualTo: year).snapshots(),
        _bankValidations.where('year', isEqualTo: year).snapshots(),
        _payments.where('year', isEqualTo: year).snapshots(),
        _remittances.where('year', isEqualTo: year).snapshots(),
        _movements.snapshots(),
      ]) {
        subscriptions
            .add(stream.listen((_) => emit(), onError: controller.addError));
      }
      emit();
      controller.onCancel = () async {
        closed = true;
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      };
    });
  }

  Future<TreasuryDashboardSummary> getDashboardSummary(int year) async {
    final settings = await getSettingsByYear(year);
    final feeDraftsSnap = await _feeDrafts.where('year', isEqualTo: year).get();
    final invoicesSnap = await _invoices.where('year', isEqualTo: year).get();
    final linesSnap = await _invoiceLines.where('year', isEqualTo: year).get();
    final validationsSnap =
        await _bankValidations.where('year', isEqualTo: year).get();
    final paymentsSnap = await _payments.where('year', isEqualTo: year).get();
    final returnsSnap = await _returns.get();
    final movementsSnap = await _movements.get();
    final remittancesSnap =
        await _remittances.where('year', isEqualTo: year).get();

    final invoices =
        invoicesSnap.docs.map((d) => TreasuryInvoice.fromFirestore(d)).toList();
    final feeDrafts = feeDraftsSnap.docs
        .map((d) => TreasuryFeeDraft.fromFirestore(d))
        .toList();
    final lines = linesSnap.docs
        .map((d) => TreasuryInvoiceLine.fromFirestore(d))
        .toList();
    final payments =
        paymentsSnap.docs.map((d) => TreasuryPayment.fromFirestore(d)).toList();
    final movements = movementsSnap.docs
        .map((d) => TreasuryAccountingMovement.fromFirestore(d))
        .where((m) => m.date?.year == year || m.date == null);

    final pendingAmount = lines
        .where((l) => l.status == 'pending')
        .fold<double>(0, (total, l) => total + l.amount);
    final approvedInvoices = invoices.where((i) => i.status == 'approved');
    final bankInvoices =
        invoices.where((i) => i.paymentMethod == 'bank_remittance');
    final cashInvoices = invoices.where((i) => i.paymentMethod == 'cash');
    final validations = validationsSnap.docs
        .map((d) => TreasuryBankValidation.fromFirestore(d))
        .toList();
    final paidAmount = payments
        .where((p) => p.status == 'paid')
        .fold<double>(0, (total, p) => total + p.amount);
    final rejectedPaymentsAmount = payments
        .where((p) => p.status == 'rejected')
        .fold<double>(0, (total, p) => total + p.amount);
    final returnedAmount = rejectedPaymentsAmount +
        returnsSnap.docs.where((d) {
          final returnedAt = (d.data()['returnedAt'] as Timestamp?)?.toDate();
          return returnedAt?.year == year;
        }).fold<double>(
            0,
            (total, d) =>
                total + ((d.data()['amount'] as num?)?.toDouble() ?? 0));
    final manualPayments = payments.where((p) =>
        p.status == 'paid' &&
        (p.method == 'cash' || p.method == 'bizum' || p.method == 'transfer'));
    final incomeAmount = movements
        .where((m) => m.type == 'income')
        .fold<double>(0, (total, m) => total + m.amount);
    final expenseAmount = movements
        .where((m) => m.type == 'expense')
        .fold<double>(0, (total, m) => total + m.amount);

    return TreasuryDashboardSummary(
      year: year,
      annualFeeAmount: settings?.annualFeeAmount ?? 0,
      draftInvoicesCount: invoices.where((i) => i.status == 'draft').length,
      feeDraftsCount: feeDrafts.length,
      feeDraftsDraftCount: feeDrafts.where((d) => d.status == 'draft').length,
      feeDraftsApprovedCount:
          feeDrafts.where((d) => d.status == 'approved').length,
      feeDraftsCancelledCount:
          feeDrafts.where((d) => d.status == 'cancelled').length,
      validatedInvoicesCount:
          invoices.where((i) => i.status == 'validated').length,
      pendingAmount: pendingAmount,
      paidAmount: paidAmount,
      returnedAmount: returnedAmount,
      totalInvoicesCount: invoices.length,
      totalInvoicesAmount:
          invoices.fold<double>(0, (total, i) => total + i.totalAmount),
      approvedInvoicesCount: approvedInvoices.length,
      approvedAmount:
          approvedInvoices.fold<double>(0, (total, i) => total + i.totalAmount),
      bankInvoicesCount: bankInvoices.length,
      cashInvoicesCount: cashInvoices.length,
      bankAmount:
          bankInvoices.fold<double>(0, (total, i) => total + i.totalAmount),
      cashAmount:
          cashInvoices.fold<double>(0, (total, i) => total + i.totalAmount),
      bankValidationPendingCount:
          validations.where((v) => v.status == 'pending').length,
      bankValidationValidatedCount:
          validations.where((v) => v.status == 'validated').length,
      bankValidationModifiedCount:
          validations.where((v) => v.status == 'modified').length,
      bankValidationLockedCount:
          validations.where((v) => v.status == 'locked').length,
      finalInvoicesWithUnvalidatedCount:
          invoices.where((i) => i.hasUnvalidatedRecords).length,
      remittancesCount: remittancesSnap.docs.length,
      remittancesAmount: remittancesSnap.docs.fold<double>(
        0,
        (total, d) =>
            total + ((d.data()['totalAmount'] as num?)?.toDouble() ?? 0),
      ),
      remittanceUnvalidatedInvoicesCount: remittancesSnap.docs.fold<int>(
        0,
        (total, d) =>
            total + ((d.data()['unvalidatedCount'] as num?)?.toInt() ?? 0),
      ),
      collectionPendingCount:
          payments.where((p) => p.status == 'pending').length,
      collectionPaidCount: payments.where((p) => p.status == 'paid').length,
      collectionRejectedCount:
          payments.where((p) => p.status == 'rejected').length,
      manualPaymentsCount: manualPayments.length,
      manualPaymentsAmount:
          manualPayments.fold<double>(0, (total, p) => total + p.amount),
      incomeAmount: incomeAmount + paidAmount,
      expenseAmount: expenseAmount,
    );
  }

  Future<TreasuryGenerationResult> generateFeeDrafts({
    required int year,
    required String generatedBy,
    bool forceRegenerate = false,
  }) async {
    final settings = await getSettingsByYear(year);
    if (settings == null) {
      throw Exception('No existe configuración de tesorería para $year.');
    }
    if (settings.annualFeeAmount <= 0) {
      throw Exception('La cuota anual de $year no está definida.');
    }

    final existingSnap = await _feeDrafts
        .where('year', isEqualTo: year)
        .where('status', whereIn: ['draft', 'approved']).get();
    if (existingSnap.docs.isNotEmpty && !forceRegenerate) {
      throw Exception(
          'Ya existen precuotas activas para $year. Regenera solo si quieres cancelar las anteriores.');
    }

    final cofradesSnap = await _cofrades.get();
    final cofrades = cofradesSnap.docs
        .map((d) => Cofrade.fromFirestore(d))
        .where((c) => c.isActivo && c.tieneCuota)
        .toList()
      ..sort((a, b) => a.nombreCompleto.compareTo(b.nombreCompleto));

    final warnings = <String>[];
    var skipped = 0;

    var batch = _db.batch();
    var pendingOps = 0;
    Future<void> commitIfNeeded({bool force = false}) async {
      if (pendingOps == 0) return;
      if (force || pendingOps >= 430) {
        await batch.commit();
        batch = _db.batch();
        pendingOps = 0;
      }
    }

    Future<void> batchSet(DocumentReference<Map<String, dynamic>> ref,
        Map<String, dynamic> data) async {
      batch.set(ref, data);
      pendingOps++;
      await commitIfNeeded();
    }

    Future<void> batchUpdate(DocumentReference<Map<String, dynamic>> ref,
        Map<String, dynamic> data) async {
      batch.update(ref, data);
      pendingOps++;
      await commitIfNeeded();
    }

    var draftsCreated = 0;
    var bankDraftsCreated = 0;
    var cashDraftsCreated = 0;

    if (forceRegenerate) {
      for (final doc in existingSnap.docs) {
        await batchUpdate(doc.reference, {
          'status': 'cancelled',
          'updatedAt': FieldValue.serverTimestamp(),
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancelledBy': generatedBy,
          'cancelReason': 'Regeneración de precuotas',
        });
      }
    }

    Future<void> createFeeDraft({
      required Cofrade cofrade,
      required String paymentMethod,
      String initialIbanHash = '',
      String initialIbanMasked = '',
    }) async {
      final ref = _feeDrafts.doc();
      final validationStatus = paymentMethod == 'cash' ? 'cash' : 'pending';
      final draft = TreasuryFeeDraft(
        id: '',
        year: year,
        cofradeId: cofrade.id,
        cofradeName: cofrade.nombreCompleto,
        cofradeNumber: cofrade.numero,
        authUid: cofrade.authUid,
        amount: settings.annualFeeAmount,
        concept: 'Cuota anual $year',
        initialPaymentMethod: paymentMethod,
        initialIbanMasked: initialIbanMasked,
        initialIbanHash: initialIbanHash,
        validatedIbanMasked: paymentMethod == 'cash' ? '' : initialIbanMasked,
        validatedIbanHash: paymentMethod == 'cash' ? '' : initialIbanHash,
        validationStatus: validationStatus,
        status: 'draft',
      );
      await batchSet(ref, draft.toFirestore());
      draftsCreated++;
      if (paymentMethod == 'bank_remittance') {
        bankDraftsCreated++;
      } else {
        cashDraftsCreated++;
      }
    }

    for (final cofrade in cofrades) {
      if (cofrade.cuotaMetalico) {
        if (cofrade.anioAlta == 2023) {
          skipped++;
          warnings.add(
              '${cofrade.nombreCompleto}: efectivo excluido por año de alta 2023 según el pipeline histórico.');
          continue;
        }
        await createFeeDraft(cofrade: cofrade, paymentMethod: 'cash');
        continue;
      }
      if (cofrade.cuotaDomiciliada && (cofrade.iban ?? '').trim().isNotEmpty) {
        final normalizedIban = _normalizeIban(cofrade.iban!);
        await createFeeDraft(
          cofrade: cofrade,
          paymentMethod: 'bank_remittance',
          initialIbanHash: _ibanHash(normalizedIban),
          initialIbanMasked: _maskIban(normalizedIban),
        );
        continue;
      }
      if (cofrade.cuotaDomiciliada) {
        warnings.add(
            '${cofrade.nombreCompleto}: domiciliado sin IBAN; se genera precuota en efectivo hasta regularizar datos.');
        await createFeeDraft(cofrade: cofrade, paymentMethod: 'cash');
      } else {
        warnings.add(
            '${cofrade.nombreCompleto}: sin domiciliación; se deriva a cobro manual.');
        await createFeeDraft(cofrade: cofrade, paymentMethod: 'cash');
      }
    }

    await commitIfNeeded(force: true);
    await createAuditLog(
      entityType: 'treasury_fee_drafts',
      entityId: '$year',
      action: forceRegenerate ? 'regenerate_fee_drafts' : 'generate_fee_drafts',
      newValue: {
        'year': year,
        'draftsCreated': draftsCreated,
        'bankDraftsCreated': bankDraftsCreated,
        'cashDraftsCreated': cashDraftsCreated,
        'skippedCofrades': skipped,
        'warnings': warnings,
      },
      changedBy: generatedBy,
    );

    return TreasuryGenerationResult(
      year: year,
      version: 1,
      invoicesCreated: draftsCreated,
      linesCreated: draftsCreated,
      bankInvoicesCreated: bankDraftsCreated,
      cashInvoicesCreated: cashDraftsCreated,
      skippedCofrades: skipped,
      warnings: warnings,
    );
  }

  Future<TreasuryGenerationResult> generateAnnualFees({
    required int year,
    required String generatedBy,
    bool forceRegenerate = false,
  }) {
    return generateFeeDrafts(
      year: year,
      generatedBy: generatedBy,
      forceRegenerate: forceRegenerate,
    );
  }

  Future<void> approveInvoice(String invoiceId, String approvedBy) async {
    final invoice = await getInvoice(invoiceId);
    if (invoice == null) throw Exception('Factura no encontrada.');
    if (invoice.status != 'draft') {
      throw Exception('Solo se pueden aprobar facturas en borrador.');
    }
    if (invoice.totalAmount <= 0) {
      throw Exception('No se puede aprobar una factura con importe cero.');
    }
    final linesSnap =
        await _invoiceLines.where('invoiceId', isEqualTo: invoiceId).get();
    if (linesSnap.docs.isEmpty) {
      throw Exception('No se puede aprobar una factura sin líneas.');
    }
    await _invoices.doc(invoiceId).update({
      'status': 'approved',
      'approvedAt': FieldValue.serverTimestamp(),
      'approvedBy': approvedBy,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await createAuditLog(
      entityType: 'treasury_invoice',
      entityId: invoiceId,
      action: 'approve_invoice',
      oldValue: {'status': invoice.status},
      newValue: {'status': 'approved'},
      changedBy: approvedBy,
    );
  }

  Future<void> updateFeeDraft({
    required String feeDraftId,
    required double amount,
    required String concept,
    required String paymentMethod,
    required String changedBy,
  }) async {
    final doc = await _feeDrafts.doc(feeDraftId).get();
    if (!doc.exists) throw Exception('Precuota no encontrada.');
    final draft = TreasuryFeeDraft.fromFirestore(doc);
    if (draft.status != 'draft') {
      throw Exception('Solo se pueden editar precuotas en borrador.');
    }
    final data = <String, dynamic>{
      'amount': amount,
      'concept': concept.trim().isEmpty ? draft.concept : concept.trim(),
      'paymentMethod': paymentMethod,
      'initialPaymentMethod': paymentMethod,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (_isBankPaymentMethod(paymentMethod) &&
        (draft.initialIbanHash.isEmpty || draft.initialIbanMasked.isEmpty)) {
      final cofradeDoc = await _cofrades.doc(draft.cofradeId).get();
      if (cofradeDoc.exists) {
        final cofrade = Cofrade.fromFirestore(cofradeDoc);
        final iban = (cofrade.iban ?? '').trim();
        if (iban.isNotEmpty) {
          data.addAll({
            'ibanMasked': _maskIban(iban),
            'ibanHash': _ibanHash(iban),
            'initialIbanMasked': _maskIban(iban),
            'initialIbanHash': _ibanHash(iban),
            'validationStatus': 'pending',
          });
        }
      }
    }
    if (!_isBankPaymentMethod(paymentMethod)) {
      data.addAll({
        'validationStatus': 'cash',
        'validatedIbanMasked': '',
        'validatedIbanHash': '',
      });
    }
    await _feeDrafts.doc(feeDraftId).update(data);
    await createAuditLog(
      entityType: 'treasury_fee_draft',
      entityId: feeDraftId,
      action: 'fee_draft_updated',
      oldValue: {
        'amount': draft.amount,
        'concept': draft.concept,
        'paymentMethod': draft.initialPaymentMethod,
      },
      newValue: {
        'amount': amount,
        'concept': concept.trim().isEmpty ? draft.concept : concept.trim(),
        'paymentMethod': paymentMethod,
      },
      changedBy: changedBy,
    );
  }

  Future<void> approveFeeDraft({
    required String feeDraftId,
    required String changedBy,
  }) async {
    final doc = await _feeDrafts.doc(feeDraftId).get();
    if (!doc.exists) throw Exception('Precuota no encontrada.');
    final draft = TreasuryFeeDraft.fromFirestore(doc);
    if (draft.status != 'draft') {
      throw Exception('Solo se pueden aprobar precuotas en borrador.');
    }
    if (draft.amount <= 0) {
      throw Exception('No se puede aprobar una precuota con importe cero.');
    }
    await _feeDrafts.doc(feeDraftId).update({
      'status': 'approved',
      'approvedAt': FieldValue.serverTimestamp(),
      'approvedBy': changedBy,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await createAuditLog(
      entityType: 'treasury_fee_draft',
      entityId: feeDraftId,
      action: 'fee_draft_approved',
      oldValue: {'status': draft.status},
      newValue: {'status': 'approved'},
      changedBy: changedBy,
    );
  }

  Future<void> reviewFeeDraft({
    required String feeDraftId,
    required String changedBy,
  }) {
    return approveFeeDraft(feeDraftId: feeDraftId, changedBy: changedBy);
  }

  Future<int> approveAllFeeDrafts({
    required int year,
    required String changedBy,
  }) async {
    final snap = await _feeDrafts
        .where('year', isEqualTo: year)
        .where('status', isEqualTo: 'draft')
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': changedBy,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    if (snap.docs.isNotEmpty) await batch.commit();
    await createAuditLog(
      entityType: 'treasury_fee_drafts',
      entityId: '$year',
      action: 'fee_drafts_approved',
      oldValue: {'status': 'draft'},
      newValue: {'status': 'approved', 'approvedCount': snap.docs.length},
      changedBy: changedBy,
    );
    return snap.docs.length;
  }

  Future<int> reviewAllFeeDrafts({
    required int year,
    required String changedBy,
  }) {
    return approveAllFeeDrafts(year: year, changedBy: changedBy);
  }

  bool isValidationCampaignOpen(TreasurySettings? settings) {
    if (settings == null || !settings.isActive) return false;
    final now = DateTime.now();
    final start = settings.validationStartDate;
    final end = settings.validationEndDate;
    if (start == null || end == null) return false;
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day, 23, 59, 59);
    return !now.isBefore(startDay) && !now.isAfter(endDay);
  }

  Stream<List<TreasuryBankValidation>> getBankValidationsByYear(int year) {
    return _bankValidations.where('year', isEqualTo: year).snapshots().map(
        (s) =>
            s.docs.map((d) => TreasuryBankValidation.fromFirestore(d)).toList()
              ..sort((a, b) => a.invoiceNumber.compareTo(b.invoiceNumber)));
  }

  Stream<List<TreasuryBankValidation>> watchMyBankValidations(
    String authUid, {
    String? cofradeId,
  }) {
    final id = (cofradeId ?? '').trim();
    final query = id.isNotEmpty
        ? _bankValidations.where('cofradeIds', arrayContains: id)
        : _bankValidations.where('cofradeAuthUids', arrayContains: authUid);
    return query.snapshots().map((s) =>
        s.docs.map((d) => TreasuryBankValidation.fromFirestore(d)).toList()
          ..sort((a, b) => b.year.compareTo(a.year)));
  }

  Future<TreasuryBankValidation?> getBankValidation(String validationId) async {
    final doc = await _bankValidations.doc(validationId).get();
    if (!doc.exists) return null;
    return TreasuryBankValidation.fromFirestore(doc);
  }

  Future<TreasuryBankValidationInitializationResult> initializeBankValidations({
    required int year,
    required String changedBy,
  }) async {
    final feeDraftsSnap = await _feeDrafts
        .where('year', isEqualTo: year)
        .where('status', isEqualTo: 'approved')
        .get();
    final existingSnap =
        await _bankValidations.where('year', isEqualTo: year).get();
    final existingFeeDraftIds = existingSnap.docs
        .map((d) => d.data()['feeDraftId'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    var created = 0;
    var existing = 0;
    var skipped = 0;
    final batch = _db.batch();

    for (final doc in feeDraftsSnap.docs) {
      final draft = TreasuryFeeDraft.fromFirestore(doc);
      if (!_isBankPaymentMethod(draft.paymentMethod)) {
        skipped++;
        continue;
      }
      if (existingFeeDraftIds.contains(draft.id)) {
        existing++;
        continue;
      }
      if (draft.status == 'cancelled' ||
          draft.initialIbanHash.isEmpty ||
          draft.initialIbanMasked.isEmpty) {
        skipped++;
        continue;
      }
      var holderName = draft.cofradeName;
      final cofradeDoc = await _cofrades.doc(draft.cofradeId).get();
      if (cofradeDoc.exists) {
        final cofrade = Cofrade.fromFirestore(cofradeDoc);
        holderName = (cofrade.titularIban ?? '').trim().isNotEmpty
            ? cofrade.titularIban!.trim()
            : cofrade.nombreCompleto;
      }
      final ref = _bankValidations.doc();
      batch.set(ref, {
        'feeDraftId': draft.id,
        'invoiceId': '',
        'invoiceNumber':
            'Precuota ${draft.year}-${draft.cofradeNumber ?? draft.cofradeId}',
        'year': year,
        'status': 'pending',
        'holderName': holderName,
        'ibanMasked': draft.initialIbanMasked,
        'ibanHash': draft.initialIbanHash,
        'newIbanMasked': '',
        'newIbanHash': '',
        'cofradeId': draft.cofradeId,
        'cofradeIds': [draft.cofradeId],
        'cofradeNames': [draft.cofradeName],
        'cofradeAuthUids': [
          if ((draft.authUid ?? '').isNotEmpty) draft.authUid!,
        ],
        'totalAmount': draft.amount,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': changedBy,
      });
      created++;
    }

    if (created > 0) await batch.commit();
    await createAuditLog(
      entityType: 'treasury_bank_validations',
      entityId: '$year',
      action: 'initialize_bank_validations',
      newValue: {
        'year': year,
        'createdCount': created,
        'existingCount': existing,
        'skippedCount': skipped,
      },
      changedBy: changedBy,
    );

    return TreasuryBankValidationInitializationResult(
      year: year,
      createdCount: created,
      existingCount: existing,
      skippedCount: skipped,
    );
  }

  Future<TreasuryBankValidationInitializationResult>
      publishBankValidationCampaign({
    required int year,
    required String changedBy,
  }) async {
    final result = await initializeBankValidations(
      year: year,
      changedBy: changedBy,
    );
    final validationsSnap = await _bankValidations
        .where('year', isEqualTo: year)
        .where('status', isEqualTo: 'pending')
        .get();
    final settings = await getSettingsByYear(year);
    final campaignMessage = settings?.validationMessage.trim().isNotEmpty ==
            true
        ? settings!.validationMessage.trim()
        : 'Tienes pendiente la validación de tus datos de cobro para la cuota anual.';
    var novedades = 0;
    for (final doc in validationsSnap.docs) {
      final validation = TreasuryBankValidation.fromFirestore(doc);
      for (final cofradeId in validation.cofradeIds) {
        if (cofradeId.isEmpty) continue;
        await _createNovedad(
          tipo: 'tesoreria',
          titulo: 'Validación bancaria pendiente',
          descripcion: campaignMessage,
          referenciaId:
              'tesoreria_validacion_${year}_${validation.id}_$cofradeId',
          ruta: '/bank-validation',
          visiblePara: 'cofrade',
          cofradeId: cofradeId,
        );
        novedades++;
      }
    }
    await createAuditLog(
      entityType: 'treasury_bank_validations',
      entityId: '$year',
      action: 'publish_bank_validation_campaign',
      newValue: {
        'year': year,
        'notificationsCreated': novedades,
        'validationsCreated': result.createdCount,
      },
      changedBy: changedBy,
    );
    return result;
  }

  Future<void> confirmBankValidation({
    required String validationId,
    required String updatedBy,
  }) async {
    final validation = await getBankValidation(validationId);
    if (validation == null) throw Exception('Validación no encontrada.');
    if (validation.status == 'locked') {
      throw Exception('La validación bancaria está bloqueada.');
    }
    final settings = await getSettingsByYear(validation.year);
    if (!isValidationCampaignOpen(settings)) {
      throw Exception('La campaña de validación bancaria está cerrada.');
    }
    final cofradeId =
        validation.cofradeIds.isNotEmpty ? validation.cofradeIds.first : '';
    if (cofradeId.isEmpty) {
      throw Exception('No se ha encontrado el cofrade asociado.');
    }
    final cofradeDoc = await _cofrades.doc(cofradeId).get();
    if (!cofradeDoc.exists) {
      throw Exception('No se ha encontrado la ficha del cofrade.');
    }
    final cofrade = Cofrade.fromFirestore(cofradeDoc);
    final iban = (cofrade.iban ?? '').trim();
    if (iban.isEmpty) {
      throw Exception(
          'No hay IBAN en tu perfil. Modifica tus datos bancarios antes de confirmar.');
    }
    final normalizedIban = _normalizeIban(iban);
    final masked = _maskIban(normalizedIban);
    final hash = _ibanHash(normalizedIban);
    final status = hash == validation.ibanHash ? 'validated' : 'modified';
    final batch = _db.batch();
    batch.update(_bankValidations.doc(validationId), {
      'status': status,
      'ibanMasked': masked,
      'ibanHash': hash,
      if (status == 'modified') 'newIbanMasked': masked,
      if (status == 'modified') 'newIbanHash': hash,
      if (status == 'modified') 'changedAt': FieldValue.serverTimestamp(),
      'validatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    });
    if (validation.feeDraftId.isNotEmpty) {
      batch.update(_feeDrafts.doc(validation.feeDraftId), {
        'validationStatus': status,
        'validatedIbanMasked': masked,
        'validatedIbanHash': hash,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    await _deleteValidationNovedades(validation);
    await createAuditLog(
      entityType: 'treasury_bank_validation',
      entityId: validationId,
      action: status == 'modified'
          ? 'bank_iban_modified'
          : 'bank_validation_confirmed',
      oldValue: {
        'status': validation.status,
        'ibanMasked': validation.ibanMasked
      },
      newValue: {'status': status, 'ibanMasked': masked},
      changedBy: updatedBy,
    );
  }

  Future<void> modifyBankValidationIban({
    required String validationId,
    required String newIban,
    required String updatedBy,
  }) async {
    final validation = await getBankValidation(validationId);
    if (validation == null) throw Exception('Validación no encontrada.');
    if (validation.status == 'locked') {
      throw Exception('La validación bancaria está bloqueada.');
    }
    final settings = await getSettingsByYear(validation.year);
    if (!isValidationCampaignOpen(settings)) {
      throw Exception('La campaña de validación bancaria está cerrada.');
    }
    if (settings?.allowIbanEdition != true) {
      throw Exception('La edición de IBAN no está habilitada.');
    }
    final normalized = _normalizeIban(newIban);
    if (!_isValidIbanBasic(normalized)) {
      throw Exception('El IBAN introducido no tiene un formato válido.');
    }
    final masked = _maskIban(normalized);
    final hash = _ibanHash(normalized);
    final batch = _db.batch();
    batch.update(_bankValidations.doc(validationId), {
      'status': 'modified',
      'newIbanMasked': masked,
      'newIbanHash': hash,
      'changedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    });
    if (validation.feeDraftId.isNotEmpty) {
      batch.update(_feeDrafts.doc(validation.feeDraftId), {
        'validationStatus': 'modified',
        'validatedIbanMasked': masked,
        'validatedIbanHash': hash,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    await createAuditLog(
      entityType: 'treasury_bank_validation',
      entityId: validationId,
      action: 'bank_iban_modified',
      oldValue: {'ibanMasked': validation.ibanMasked},
      newValue: {'newIbanMasked': masked},
      changedBy: updatedBy,
    );
  }

  Future<int> lockClosedBankValidations({
    required int year,
    required String lockedBy,
  }) async {
    final settings = await getSettingsByYear(year);
    if (isValidationCampaignOpen(settings)) {
      throw Exception('La campaña sigue abierta; no se pueden bloquear.');
    }
    final snap = await _bankValidations
        .where('year', isEqualTo: year)
        .where('status', whereIn: ['pending', 'validated', 'modified']).get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {
        'status': 'locked',
        'lockedAt': FieldValue.serverTimestamp(),
        'lockedBy': lockedBy,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': lockedBy,
      });
    }
    if (snap.docs.isNotEmpty) await batch.commit();
    await createAuditLog(
      entityType: 'treasury_bank_validations',
      entityId: '$year',
      action: 'lock_bank_validations',
      newValue: {'year': year, 'lockedCount': snap.docs.length},
      changedBy: lockedBy,
    );
    return snap.docs.length;
  }

  Future<int> closeBankValidationCampaign({
    required int year,
    required String closedBy,
  }) async {
    final settings = await getSettingsByYear(year);
    if (settings == null) {
      throw Exception('No existe configuración de tesorería para $year.');
    }
    await _settings.doc(settings.id).update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await createAuditLog(
      entityType: 'treasury_settings',
      entityId: settings.id,
      action: 'close_bank_validation_campaign',
      oldValue: {'isActive': settings.isActive},
      newValue: {'isActive': false},
      changedBy: closedBy,
    );
    return lockClosedBankValidations(year: year, lockedBy: closedBy);
  }

  Future<TreasuryFinalInvoiceGenerationResult> generateFinalInvoices({
    required int year,
    required String generatedBy,
  }) async {
    final readySnap = await _feeDrafts
        .where('year', isEqualTo: year)
        .where('status', isEqualTo: 'approved')
        .get();
    final drafts = readySnap.docs
        .map((d) => TreasuryFeeDraft.fromFirestore(d))
        .where((d) => d.finalInvoiceId == null || d.finalInvoiceId!.isEmpty)
        .toList()
      ..sort((a, b) => a.cofradeName.compareTo(b.cofradeName));
    if (drafts.isEmpty) {
      throw Exception(
          'No hay precuotas aprobadas pendientes de facturar en $year.');
    }

    final existingInvoicesSnap = await _invoices
        .where('year', isEqualTo: year)
        .where('status', whereIn: ['approved', 'paid', 'partially_paid']).get();
    if (existingInvoicesSnap.docs.any((doc) {
      final data = doc.data();
      return (data['sourceFeeDraftIds'] as List<dynamic>? ?? []).isNotEmpty;
    })) {
      throw Exception(
          'Ya existen facturas definitivas generadas para $year. Cancela/versiona antes de regenerar.');
    }
    var sequence = existingInvoicesSnap.docs.length + 1;
    final groups = <String, List<TreasuryFeeDraft>>{};
    final cofradesById = <String, Cofrade>{};
    var skipped = 0;
    var unvalidatedCount = 0;
    var unvalidatedAmount = 0.0;
    final warnings = <String>[];

    for (final draft in drafts) {
      if (draft.initialPaymentMethod == 'cash' ||
          draft.validationStatus == 'cash') {
        groups['cash:${draft.id}'] = [draft];
        continue;
      }
      final cofradeDoc = await _cofrades.doc(draft.cofradeId).get();
      if (cofradeDoc.exists) {
        cofradesById[draft.cofradeId] = Cofrade.fromFirestore(cofradeDoc);
      }
      var hash = draft.validatedIbanHash.isNotEmpty
          ? draft.validatedIbanHash
          : draft.initialIbanHash;
      final cofrade = cofradesById[draft.cofradeId];
      final currentIban = (cofrade?.iban ?? '').trim();
      if (currentIban.isNotEmpty &&
          !['validated', 'modified', 'locked']
              .contains(draft.validationStatus)) {
        hash = _ibanHash(currentIban);
      }
      if (hash.isEmpty) {
        skipped++;
        warnings.add('${draft.cofradeName}: sin IBAN validado para facturar.');
        continue;
      }
      if (!['validated', 'modified', 'locked']
          .contains(draft.validationStatus)) {
        unvalidatedCount++;
        unvalidatedAmount += draft.amount;
      }
      groups.putIfAbsent('bank:$hash', () => []).add(draft);
    }

    final batch = _db.batch();
    var invoicesCreated = 0;
    var linesCreated = 0;
    var feeDraftsInvoiced = 0;

    for (final entry in groups.entries) {
      final group = entry.value;
      final isCash = entry.key.startsWith('cash:');
      final invoiceRef = _invoices.doc();
      final invoiceNumber = _invoiceNumber(year, sequence++);
      final totalAmount =
          group.fold<double>(0, (total, draft) => total + draft.amount);
      final groupHasUnvalidated = group.any((draft) => ![
            'cash',
            'validated',
            'modified',
            'locked'
          ].contains(draft.validationStatus));
      final groupUnvalidatedCount = group
          .where((draft) => !['cash', 'validated', 'modified', 'locked']
              .contains(draft.validationStatus))
          .length;
      final ibanMasked = isCash
          ? ''
          : _finalIbanMasked(group.first, cofradesById[group.first.cofradeId]);
      final ibanHash = isCash
          ? ''
          : _finalIbanHash(group.first, cofradesById[group.first.cofradeId]);
      final holderName = isCash
          ? group.first.cofradeName
          : _finalHolderName(group.first, cofradesById[group.first.cofradeId]);
      final invoice = TreasuryInvoice(
        id: '',
        year: year,
        invoiceNumber: invoiceNumber,
        status: 'approved',
        holderName: holderName,
        ibanMasked: ibanMasked,
        ibanHash: ibanHash,
        cofradeIds: group.map((d) => d.cofradeId).toList(),
        cofradeAuthUids: group
            .map((d) => d.authUid)
            .whereType<String>()
            .where((uid) => uid.isNotEmpty)
            .toSet()
            .toList(),
        sourceFeeDraftIds: group.map((d) => d.id).toList(),
        concept: _invoiceConceptFromDrafts(year, group),
        paymentMethod: isCash ? 'cash' : 'bank_remittance',
        totalAmount: totalAmount,
        version: 1,
        hasUnvalidatedRecords: groupHasUnvalidated,
        unvalidatedCount: groupUnvalidatedCount,
      );
      batch.set(invoiceRef, {
        ...invoice.toFirestore(),
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': generatedBy,
      });
      for (final draft in group) {
        final lineRef = _invoiceLines.doc();
        batch.set(
          lineRef,
          TreasuryInvoiceLine(
            id: '',
            invoiceId: invoiceRef.id,
            cofradeId: draft.cofradeId,
            cofradeName: draft.cofradeName,
            cofradeNumber: draft.cofradeNumber,
            authUid: draft.authUid,
            sourceFeeDraftId: draft.id,
            concept: draft.concept,
            amount: draft.amount,
            year: year,
            status: 'pending',
          ).toFirestore(),
        );
        batch.update(_feeDrafts.doc(draft.id), {
          'finalInvoiceId': invoiceRef.id,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        linesCreated++;
        feeDraftsInvoiced++;
      }
      invoicesCreated++;
    }

    await batch.commit();
    await _syncGeneratedInvoicesAccountingAndNotifications(
      year: year,
      changedBy: generatedBy,
    );
    await createAuditLog(
      entityType: 'treasury_invoices',
      entityId: '$year',
      action: 'generate_final_invoices',
      newValue: {
        'year': year,
        'invoicesCreated': invoicesCreated,
        'linesCreated': linesCreated,
        'feeDraftsInvoiced': feeDraftsInvoiced,
        'skippedFeeDrafts': skipped,
        'warnings': warnings,
        'unvalidatedCount': unvalidatedCount,
        'unvalidatedAmount': unvalidatedAmount,
      },
      changedBy: generatedBy,
    );
    if (unvalidatedCount > 0) {
      await createAuditLog(
        entityType: 'treasury_invoices',
        entityId: '$year',
        action: 'generate_final_invoices_with_unvalidated_records',
        newValue: {
          'year': year,
          'countPending': unvalidatedCount,
          'amountPending': unvalidatedAmount,
        },
        changedBy: generatedBy,
      );
    }

    return TreasuryFinalInvoiceGenerationResult(
      year: year,
      invoicesCreated: invoicesCreated,
      linesCreated: linesCreated,
      feeDraftsInvoiced: feeDraftsInvoiced,
      skippedFeeDrafts: skipped,
      unvalidatedCount: unvalidatedCount,
      unvalidatedAmount: unvalidatedAmount,
      warnings: warnings,
    );
  }

  Future<void> markInvoicePdfGenerated({
    required String invoiceId,
    required String pdfUrl,
    required String generatedBy,
  }) async {
    final invoice = await getInvoice(invoiceId);
    if (invoice == null) throw Exception('Factura no encontrada.');
    await _invoices.doc(invoiceId).update({
      'pdfUrl': pdfUrl,
      'generatedAt': FieldValue.serverTimestamp(),
      'generatedBy': generatedBy,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await createAuditLog(
      entityType: 'treasury_invoice',
      entityId: invoiceId,
      action: 'invoice_pdf_generated',
      oldValue: {'pdfUrl': invoice.pdfUrl},
      newValue: {'pdfUrl': pdfUrl},
      changedBy: generatedBy,
    );
  }

  Future<void> cancelInvoice(String invoiceId, String cancelledBy) async {
    final invoice = await getInvoice(invoiceId);
    if (invoice == null) throw Exception('Factura no encontrada.');
    if (invoice.status == 'cancelled') return;
    final batch = _db.batch();
    batch.update(_invoices.doc(invoiceId), {
      'status': 'cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
      'cancelledAt': FieldValue.serverTimestamp(),
      'cancelledBy': cancelledBy,
    });
    final linesSnap =
        await _invoiceLines.where('invoiceId', isEqualTo: invoiceId).get();
    for (final line in linesSnap.docs) {
      batch.update(line.reference, {
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    await createAuditLog(
      entityType: 'treasury_invoice',
      entityId: invoiceId,
      action: 'cancel',
      oldValue: {'status': invoice.status},
      newValue: {'status': 'cancelled'},
      changedBy: cancelledBy,
    );
  }

  String _finalIbanMasked(TreasuryFeeDraft draft, Cofrade? cofrade) {
    if (draft.validatedIbanMasked.isNotEmpty) return draft.validatedIbanMasked;
    final iban = (cofrade?.iban ?? '').trim();
    if (iban.isNotEmpty) return _maskIban(iban);
    return draft.initialIbanMasked;
  }

  String _finalIbanHash(TreasuryFeeDraft draft, Cofrade? cofrade) {
    if (draft.validatedIbanHash.isNotEmpty) return draft.validatedIbanHash;
    final iban = (cofrade?.iban ?? '').trim();
    if (iban.isNotEmpty) return _ibanHash(iban);
    return draft.initialIbanHash;
  }

  String _finalHolderName(TreasuryFeeDraft draft, Cofrade? cofrade) {
    final holder = (cofrade?.titularIban ?? '').trim();
    return holder.isNotEmpty ? holder : draft.cofradeName;
  }

  bool _isBankPaymentMethod(String method) {
    final normalized = method.trim().toLowerCase();
    return normalized == 'bank_remittance' ||
        normalized == 'direct_debit' ||
        normalized == 'domiciliacion' ||
        normalized == 'domiciliación' ||
        normalized == 'bank';
  }

  Future<void> _syncGeneratedInvoicesAccountingAndNotifications({
    required int year,
    required String changedBy,
  }) async {
    final invoicesSnap = await _invoices
        .where('year', isEqualTo: year)
        .where('status', isEqualTo: 'approved')
        .get();
    final defaultCenterId = await _ensureOrdinaryIncomeCostCenter(
      subcenterName: 'Cuotas de hermanos',
      changedBy: changedBy,
    );
    for (final doc in invoicesSnap.docs) {
      final invoice = TreasuryInvoice.fromFirestore(doc);
      final existing = await _movements
          .where('linkedInvoiceId', isEqualTo: invoice.id)
          .where('origin', isEqualTo: 'facturacion')
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
      if (existing.docs.isEmpty) {
        await _movements.add(TreasuryAccountingMovement(
          id: '',
          year: invoice.year,
          type: 'income',
          amount: invoice.totalAmount,
          date: DateTime.now(),
          costCenterId: defaultCenterId,
          concept: invoice.concept.isEmpty
              ? 'Factura ${invoice.invoiceNumber}'
              : invoice.concept,
          description: 'Derecho de cobro generado por factura definitiva',
          paymentMethod: invoice.paymentMethod,
          status: 'pending',
          personType: 'cofrade',
          personId:
              invoice.cofradeIds.length == 1 ? invoice.cofradeIds.first : '',
          personName: invoice.holderName,
          origin: 'facturacion',
          reference: invoice.invoiceNumber,
          linkedInvoiceId: invoice.id,
          createdBy: changedBy,
        ).toFirestore());
      }
      for (final cofradeId in invoice.cofradeIds) {
        await _createNovedad(
          tipo: 'tesoreria',
          titulo: 'Nueva cuota disponible',
          descripcion:
              'Ya tienes disponible la factura ${invoice.invoiceNumber} en Mis cuotas.',
          referenciaId: 'tesoreria_factura_${invoice.id}_$cofradeId',
          ruta: '/cuotas',
          visiblePara: 'cofrade',
          cofradeId: cofradeId,
        );
      }
    }
  }

  Future<void> _syncPaymentAccountingMovement({
    required String paymentId,
    required TreasuryPayment payment,
    required String status,
    required String method,
    required String reference,
    String rejectionReason = '',
    required String changedBy,
  }) async {
    final invoice = await getInvoice(payment.invoiceId);
    if (invoice == null) return;
    final existing = await _movements
        .where('linkedPaymentId', isEqualTo: paymentId)
        .limit(1)
        .get();
    final ref = existing.docs.isEmpty
        ? _movements.doc()
        : existing.docs.first.reference;
    final isRejected = status == 'rejected';
    final isManual = method != 'bank_remittance';
    final subcenterName = isRejected
        ? 'Ajustes de facturación'
        : isManual
            ? 'Cobros manuales'
            : 'Cobros domiciliados';
    final defaultCenterId = await _ensureOrdinaryIncomeCostCenter(
      subcenterName: subcenterName,
      changedBy: changedBy,
    );
    final movement = TreasuryAccountingMovement(
      id: existing.docs.isEmpty ? '' : ref.id,
      year: invoice.year,
      type: 'income',
      amount: payment.amount,
      date: DateTime.now(),
      costCenterId: defaultCenterId,
      concept: isRejected
          ? 'Rechazo bancario ${invoice.invoiceNumber}'
          : status == 'pending'
              ? 'Remesa generada ${invoice.invoiceNumber}'
              : isManual
                  ? 'Cobro manual ${_paymentMethodLabel(method)} ${invoice.invoiceNumber}'
                  : 'Cobro por remesa ${invoice.invoiceNumber}',
      description: isRejected
          ? (rejectionReason.isEmpty ? 'Recibo rechazado' : rejectionReason)
          : status == 'pending'
              ? 'Intento de cobro incluido en remesa; pendiente de resultado bancario'
              : 'Cobro aplicado sobre factura existente',
      paymentMethod: method,
      status: isRejected
          ? 'returned'
          : (status == 'paid' ? 'confirmed' : 'pending'),
      personType: 'cofrade',
      personId: payment.cofradeId ?? '',
      personName: payment.cofradeName,
      origin: method == 'bank_remittance' ? 'remesa' : 'manual',
      reference: reference,
      linkedInvoiceId: invoice.id,
      linkedPaymentId: paymentId,
      createdBy: changedBy,
    );
    await ref.set(movement.toFirestore(), SetOptions(merge: true));
  }

  Future<String> _ensureOrdinaryIncomeCostCenter({
    required String subcenterName,
    required String changedBy,
  }) async {
    final rootSnap = await _costCenters
        .where('parentId', isEqualTo: '')
        .where('name', isEqualTo: 'Ingresos ordinarios')
        .limit(1)
        .get();
    final rootRef = rootSnap.docs.isEmpty
        ? _costCenters.doc()
        : rootSnap.docs.first.reference;
    if (rootSnap.docs.isEmpty) {
      await rootRef.set({
        'name': 'Ingresos ordinarios',
        'description': 'Centro base para cuotas y cobros ordinarios',
        'parentId': '',
        'budgetAmount': 0,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    final childSnap = await _costCenters
        .where('parentId', isEqualTo: rootRef.id)
        .where('name', isEqualTo: subcenterName)
        .limit(1)
        .get();
    if (childSnap.docs.isNotEmpty) return childSnap.docs.first.id;
    final childRef = _costCenters.doc();
    await childRef.set({
      'name': subcenterName,
      'description': 'Subcentro automático de ingresos ordinarios',
      'parentId': rootRef.id,
      'budgetAmount': 0,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await createAuditLog(
      entityType: 'treasury_cost_center',
      entityId: childRef.id,
      action: 'ensure_income_cost_center',
      newValue: {'root': 'Ingresos ordinarios', 'subcenter': subcenterName},
      changedBy: changedBy,
    );
    return childRef.id;
  }

  String _paymentMethodLabel(String method) {
    switch (method) {
      case 'bizum':
        return 'por Bizum';
      case 'transfer':
        return 'por transferencia';
      case 'cash':
        return 'en efectivo';
      case 'card':
        return 'con tarjeta';
      default:
        return 'manual';
    }
  }

  DateTime? _asDate(dynamic value) {
    return value is Timestamp ? value.toDate() : null;
  }

  Future<String> _fullIbanForInvoice(TreasuryInvoice invoice) async {
    for (final cofradeId in invoice.cofradeIds) {
      final doc = await _cofrades.doc(cofradeId).get();
      if (!doc.exists) continue;
      final cofrade = Cofrade.fromFirestore(doc);
      final iban = (cofrade.iban ?? '').trim();
      if (iban.isEmpty) continue;
      final normalized = _normalizeIban(iban);
      if (invoice.ibanHash.isEmpty ||
          _ibanHash(normalized) == invoice.ibanHash) {
        return normalized;
      }
    }
    return '';
  }

  String _invoiceNumber(int year, int sequence) =>
      'TES-$year-${sequence.toString().padLeft(4, '0')}';

  String _invoiceConceptFromDrafts(int year, List<TreasuryFeeDraft> group) {
    final cofrades = group.map((draft) {
      final number =
          draft.cofradeNumber != null ? ' (${draft.cofradeNumber})' : '';
      return '${draft.cofradeName}$number';
    }).join(', ');
    return 'Cuotas $year - $cofrades';
  }

  String _normalizeIban(String iban) =>
      iban.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  String _maskIban(String iban) {
    final normalized = _normalizeIban(iban);
    if (normalized.isEmpty) return '';
    if (normalized.length <= 4) return '****';
    final tail = normalized.substring(normalized.length - 4);
    return '**** **** **** $tail';
  }

  String _ibanHash(String iban) {
    final normalized = _normalizeIban(iban);
    final bytes = utf8.encode(normalized);
    return sha256.convert(bytes).toString();
  }

  bool _isValidIbanBasic(String iban) {
    return RegExp(r'^[A-Z]{2}[0-9A-Z]{13,32}$').hasMatch(iban);
  }

  Future<void> createAuditLog({
    required String entityType,
    required String entityId,
    required String action,
    Map<String, dynamic>? oldValue,
    Map<String, dynamic>? newValue,
    String? changedBy,
  }) async {
    await _auditLogs.add(TreasuryAuditLog(
      id: '',
      entityType: entityType,
      entityId: entityId,
      action: action,
      oldValue: oldValue,
      newValue: newValue,
      changedBy: changedBy,
    ).toFirestore());
  }

  Future<void> _createNovedad({
    required String tipo,
    required String titulo,
    required String descripcion,
    required String referenciaId,
    required String ruta,
    required String visiblePara,
    String? cofradeId,
  }) async {
    final existing = await _db
        .collection('novedades')
        .where('tipo', isEqualTo: tipo)
        .where('referencia_id', isEqualTo: referenciaId)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return;
    final doc = await _db.collection('novedades').add({
      'tipo': tipo,
      'titulo': titulo,
      'descripcion': descripcion,
      'referencia_id': referenciaId,
      'ruta': ruta,
      'fecha_creacion': FieldValue.serverTimestamp(),
      'visible_para': visiblePara,
      'cofrade_id': cofradeId,
    });
    if (tipo == 'tesoreria') {
      await createAuditLog(
        entityType: 'novedades',
        entityId: doc.id,
        action: 'generate_treasury_notification',
        newValue: {
          'titulo': titulo,
          'referenciaId': referenciaId,
          'cofradeId': cofradeId,
        },
        changedBy: 'system',
      );
    }
  }

  Future<void> _deleteValidationNovedades(
      TreasuryBankValidation validation) async {
    final batch = _db.batch();
    var count = 0;
    for (final cofradeId in validation.cofradeIds) {
      final referenciaId =
          'tesoreria_validacion_${validation.year}_${validation.id}_$cofradeId';
      final snap = await _db
          .collection('novedades')
          .where('tipo', isEqualTo: 'tesoreria')
          .where('referencia_id', isEqualTo: referenciaId)
          .get();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
        count++;
      }
    }
    if (count > 0) await batch.commit();
  }
}
