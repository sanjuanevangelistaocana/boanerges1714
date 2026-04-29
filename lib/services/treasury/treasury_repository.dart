import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boanerges1714/models/cofrade.dart';
import 'package:boanerges1714/models/treasury.dart';

class TreasuryRepository {
  final FirebaseFirestore _db;

  TreasuryRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _settings =>
      _db.collection('treasury_settings');
  CollectionReference<Map<String, dynamic>> get _invoices =>
      _db.collection('treasury_invoices');
  CollectionReference<Map<String, dynamic>> get _invoiceLines =>
      _db.collection('treasury_invoice_lines');
  CollectionReference<Map<String, dynamic>> get _payments =>
      _db.collection('treasury_payments');
  CollectionReference<Map<String, dynamic>> get _returns =>
      _db.collection('treasury_returns');
  CollectionReference<Map<String, dynamic>> get _movements =>
      _db.collection('treasury_accounting_movements');
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

    final ref = await _settings.add(settings.toFirestore());
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
    };
  }

  Stream<List<TreasuryInvoice>> getInvoicesByYear(int year) {
    return _invoices.where('year', isEqualTo: year).snapshots().map((s) =>
        s.docs.map((d) => TreasuryInvoice.fromFirestore(d)).toList()
          ..sort((a, b) => a.invoiceNumber.compareTo(b.invoiceNumber)));
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
    return _invoiceLines.where('invoiceId', isEqualTo: invoiceId).snapshots().map(
        (s) => s.docs.map((d) => TreasuryInvoiceLine.fromFirestore(d)).toList()
          ..sort((a, b) => a.cofradeName.compareTo(b.cofradeName)));
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

  Stream<List<Map<String, dynamic>>> getReturnsByYear(int year) {
    return _returns
        .where('year', isEqualTo: year)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Stream<List<TreasuryAccountingMovement>> getAccountingMovementsByYear(
      int year) {
    return _movements.snapshots().map((s) => s.docs
        .map((d) => TreasuryAccountingMovement.fromFirestore(d))
        .where((m) => m.date?.year == year)
        .toList());
  }

  Stream<TreasuryDashboardSummary> watchDashboardSummary(int year) {
    return _settings
        .snapshots()
        .asyncMap((_) async => getDashboardSummary(year));
  }

  Future<TreasuryDashboardSummary> getDashboardSummary(int year) async {
    final settings = await getSettingsByYear(year);
    final invoicesSnap = await _invoices.where('year', isEqualTo: year).get();
    final linesSnap = await _invoiceLines.where('year', isEqualTo: year).get();
    final paymentsSnap = await _payments.get();
    final returnsSnap = await _returns.get();
    final movementsSnap = await _movements.get();

    final invoices =
        invoicesSnap.docs.map((d) => TreasuryInvoice.fromFirestore(d)).toList();
    final lines = linesSnap.docs
        .map((d) => TreasuryInvoiceLine.fromFirestore(d))
        .toList();
    final payments =
        paymentsSnap.docs.map((d) => TreasuryPayment.fromFirestore(d)).where(
              (p) => p.paymentDate?.year == year || p.paymentDate == null,
            );
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
    final paidAmount = payments
        .where((p) => p.status == 'paid')
        .fold<double>(0, (total, p) => total + p.amount);
    final returnedAmount = returnsSnap.docs
        .where((d) =>
            (d.data()['returnedAt'] as Timestamp?)?.toDate().year == year)
        .fold<double>(
            0,
            (total, d) =>
                total + ((d.data()['amount'] as num?)?.toDouble() ?? 0));
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
      incomeAmount: incomeAmount + paidAmount,
      expenseAmount: expenseAmount,
    );
  }

  Future<TreasuryGenerationResult> generateAnnualFees({
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

    final existingSnap = await _invoices
        .where('year', isEqualTo: year)
        .where('status', whereIn: ['draft', 'approved'])
        .get();
    if (existingSnap.docs.isNotEmpty && !forceRegenerate) {
      throw Exception(
          'Ya existen facturas activas para $year. Cancélalas o regenera con control de versión.');
    }

    final allInvoicesSnap =
        await _invoices.where('year', isEqualTo: year).get();
    final currentMaxVersion = allInvoicesSnap.docs
        .map((d) => (d.data()['version'] as num?)?.toInt() ?? 1)
        .fold<int>(0, (max, value) => value > max ? value : max);
    final version = currentMaxVersion + 1;

    final cofradesSnap = await _cofrades.get();
    final cofrades = cofradesSnap.docs
        .map((d) => Cofrade.fromFirestore(d))
        .where((c) => c.isActivo && c.tieneCuota)
        .toList()
      ..sort((a, b) => a.nombreCompleto.compareTo(b.nombreCompleto));

    final warnings = <String>[];
    final bankGroups = <String, List<Cofrade>>{};
    final cashCofrades = <Cofrade>[];
    var skipped = 0;

    for (final cofrade in cofrades) {
      if (cofrade.cuotaMetalico) {
        cashCofrades.add(cofrade);
        continue;
      }
      if (cofrade.cuotaDomiciliada && (cofrade.iban ?? '').trim().isNotEmpty) {
        final normalizedIban = _normalizeIban(cofrade.iban!);
        final key = _ibanHash(normalizedIban);
        bankGroups.putIfAbsent(key, () => []).add(cofrade);
        continue;
      }
      if (cofrade.cuotaDomiciliada) {
        warnings.add('${cofrade.nombreCompleto}: domiciliado sin IBAN; se genera como efectivo.');
        cashCofrades.add(cofrade);
      } else {
        skipped++;
        warnings.add('${cofrade.nombreCompleto}: sin forma de pago marcada.');
      }
    }

    final batch = _db.batch();
    var sequence = 1;
    var invoicesCreated = 0;
    var linesCreated = 0;
    var bankInvoicesCreated = 0;
    var cashInvoicesCreated = 0;

    if (forceRegenerate) {
      for (final doc in existingSnap.docs) {
        batch.update(doc.reference, {
          'status': 'cancelled',
          'updatedAt': FieldValue.serverTimestamp(),
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancelledBy': generatedBy,
          'cancelReason': 'Regeneración versión $version',
        });
      }
    }

    Future<void> createInvoice({
      required List<Cofrade> group,
      required String paymentMethod,
      String ibanHash = '',
      String ibanMasked = '',
    }) async {
      final invoiceRef = _invoices.doc();
      final invoiceNumber = _invoiceNumber(year, sequence++);
      final totalAmount = group.length * settings.annualFeeAmount;
      final holderName = paymentMethod == 'bank_remittance'
          ? _holderNameForGroup(group)
          : group.first.nombreCompleto;
      final invoice = TreasuryInvoice(
        id: '',
        year: year,
        invoiceNumber: invoiceNumber,
        status: 'draft',
        holderName: holderName,
        ibanMasked: ibanMasked,
        ibanHash: ibanHash,
        cofradeIds: group.map((c) => c.id).toList(),
        cofradeAuthUids: group
            .map((c) => c.authUid)
            .whereType<String>()
            .where((uid) => uid.isNotEmpty)
            .toSet()
            .toList(),
        paymentMethod: paymentMethod,
        totalAmount: totalAmount,
        version: version,
      );
      batch.set(invoiceRef, invoice.toFirestore());
      for (final cofrade in group) {
        final lineRef = _invoiceLines.doc();
        batch.set(
          lineRef,
          TreasuryInvoiceLine(
            id: '',
            invoiceId: invoiceRef.id,
            cofradeId: cofrade.id,
            cofradeName: cofrade.nombreCompleto,
            authUid: cofrade.authUid,
            concept: 'Cuota anual $year',
            amount: settings.annualFeeAmount,
            year: year,
            status: 'pending',
          ).toFirestore(),
        );
        linesCreated++;
      }
      invoicesCreated++;
      if (paymentMethod == 'bank_remittance') {
        bankInvoicesCreated++;
      } else {
        cashInvoicesCreated++;
      }
    }

    for (final entry in bankGroups.entries) {
      final firstIban = _normalizeIban(entry.value.first.iban ?? '');
      await createInvoice(
        group: entry.value,
        paymentMethod: 'bank_remittance',
        ibanHash: entry.key,
        ibanMasked: _maskIban(firstIban),
      );
    }
    for (final cofrade in cashCofrades) {
      await createInvoice(group: [cofrade], paymentMethod: 'cash');
    }

    await batch.commit();
    await createAuditLog(
      entityType: 'treasury_invoices',
      entityId: '$year-v$version',
      action: forceRegenerate ? 'regenerate_annual_fees' : 'generate_annual_fees',
      newValue: {
        'year': year,
        'version': version,
        'invoicesCreated': invoicesCreated,
        'linesCreated': linesCreated,
        'bankInvoicesCreated': bankInvoicesCreated,
        'cashInvoicesCreated': cashInvoicesCreated,
        'skippedCofrades': skipped,
        'warnings': warnings,
      },
      changedBy: generatedBy,
    );

    return TreasuryGenerationResult(
      year: year,
      version: version,
      invoicesCreated: invoicesCreated,
      linesCreated: linesCreated,
      bankInvoicesCreated: bankInvoicesCreated,
      cashInvoicesCreated: cashInvoicesCreated,
      skippedCofrades: skipped,
      warnings: warnings,
    );
  }

  Future<void> approveInvoice(String invoiceId, String approvedBy) async {
    final invoice = await getInvoice(invoiceId);
    if (invoice == null) throw Exception('Factura no encontrada.');
    if (invoice.status != 'draft') {
      throw Exception('Solo se pueden aprobar facturas en borrador.');
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
      action: 'approve',
      oldValue: {'status': invoice.status},
      newValue: {'status': 'approved'},
      changedBy: approvedBy,
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

  String _invoiceNumber(int year, int sequence) =>
      'TES-$year-${sequence.toString().padLeft(4, '0')}';

  String _holderNameForGroup(List<Cofrade> group) {
    final titular = group
        .map((c) => c.titularIban?.trim() ?? '')
        .firstWhere((name) => name.isNotEmpty, orElse: () => '');
    return titular.isNotEmpty ? titular : group.first.nombreCompleto;
  }

  String _normalizeIban(String iban) =>
      iban.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  String _maskIban(String iban) {
    if (iban.isEmpty) return '';
    final tail = iban.length <= 4 ? iban : iban.substring(iban.length - 4);
    return '****$tail';
  }

  String _ibanHash(String iban) {
    // Deterministic FNV-1a hash for grouping without storing full IBAN.
    var hash = 0xcbf29ce484222325;
    for (final unit in iban.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x100000001b3) & 0xffffffffffffffff;
    }
    return hash.toRadixString(16).padLeft(16, '0');
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
}
