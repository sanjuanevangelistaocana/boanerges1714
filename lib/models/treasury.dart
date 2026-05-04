import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _date(dynamic value) => value is Timestamp ? value.toDate() : null;

class TreasurySettings {
  final String id;
  final int year;
  final double annualFeeAmount;
  final DateTime? validationStartDate;
  final DateTime? validationEndDate;
  final DateTime? remittanceDate;
  final DateTime? fiscalStartDate;
  final DateTime? fiscalEndDate;
  final bool allowIbanEdition;
  final bool isActive;
  final String validationMessage;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TreasurySettings({
    required this.id,
    required this.year,
    required this.annualFeeAmount,
    this.validationStartDate,
    this.validationEndDate,
    this.remittanceDate,
    this.fiscalStartDate,
    this.fiscalEndDate,
    this.allowIbanEdition = true,
    this.isActive = false,
    this.validationMessage = '',
    this.createdAt,
    this.updatedAt,
  });

  factory TreasurySettings.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TreasurySettings(
      id: doc.id,
      year: (data['year'] as num?)?.toInt() ?? DateTime.now().year,
      annualFeeAmount: (data['annualFeeAmount'] as num?)?.toDouble() ?? 0,
      validationStartDate: _date(data['validationStartDate']),
      validationEndDate: _date(data['validationEndDate']),
      remittanceDate: _date(data['remittanceDate']),
      fiscalStartDate: _date(data['fiscalStartDate']),
      fiscalEndDate: _date(data['fiscalEndDate']),
      allowIbanEdition: data['allowIbanEdition'] ?? true,
      isActive: data['isActive'] ?? false,
      validationMessage: data['validationMessage'] ?? '',
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'year': year,
      'annualFeeAmount': annualFeeAmount,
      'validationStartDate': validationStartDate != null
          ? Timestamp.fromDate(validationStartDate!)
          : null,
      'validationEndDate': validationEndDate != null
          ? Timestamp.fromDate(validationEndDate!)
          : null,
      'remittanceDate':
          remittanceDate != null ? Timestamp.fromDate(remittanceDate!) : null,
      'fiscalStartDate':
          fiscalStartDate != null ? Timestamp.fromDate(fiscalStartDate!) : null,
      'fiscalEndDate':
          fiscalEndDate != null ? Timestamp.fromDate(fiscalEndDate!) : null,
      'allowIbanEdition': allowIbanEdition,
      'isActive': isActive,
      'validationMessage': validationMessage,
      'updatedAt': FieldValue.serverTimestamp(),
      if (id.isEmpty) 'createdAt': FieldValue.serverTimestamp(),
    };
  }

  TreasurySettings copyWith({
    String? id,
    int? year,
    double? annualFeeAmount,
    DateTime? validationStartDate,
    DateTime? validationEndDate,
    DateTime? remittanceDate,
    DateTime? fiscalStartDate,
    DateTime? fiscalEndDate,
    bool? allowIbanEdition,
    bool? isActive,
    String? validationMessage,
  }) {
    return TreasurySettings(
      id: id ?? this.id,
      year: year ?? this.year,
      annualFeeAmount: annualFeeAmount ?? this.annualFeeAmount,
      validationStartDate: validationStartDate ?? this.validationStartDate,
      validationEndDate: validationEndDate ?? this.validationEndDate,
      remittanceDate: remittanceDate ?? this.remittanceDate,
      fiscalStartDate: fiscalStartDate ?? this.fiscalStartDate,
      fiscalEndDate: fiscalEndDate ?? this.fiscalEndDate,
      allowIbanEdition: allowIbanEdition ?? this.allowIbanEdition,
      isActive: isActive ?? this.isActive,
      validationMessage: validationMessage ?? this.validationMessage,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class TreasuryInvoice {
  final String id;
  final int year;
  final String invoiceNumber;
  final String status;
  final String holderName;
  final String ibanMasked;
  final String ibanHash;
  final String concept;
  final List<String> cofradeIds;
  final List<String> cofradeAuthUids;
  final List<String> sourceFeeDraftIds;
  final String paymentMethod;
  final double totalAmount;
  final int version;
  final String pdfUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? approvedAt;
  final String? approvedBy;
  final DateTime? generatedAt;
  final String? generatedBy;
  final bool hasUnvalidatedRecords;
  final int unvalidatedCount;

  const TreasuryInvoice({
    required this.id,
    required this.year,
    this.invoiceNumber = '',
    this.status = 'draft',
    this.holderName = '',
    this.ibanMasked = '',
    this.ibanHash = '',
    this.concept = '',
    this.cofradeIds = const [],
    this.cofradeAuthUids = const [],
    this.sourceFeeDraftIds = const [],
    this.paymentMethod = 'bank_remittance',
    this.totalAmount = 0,
    this.version = 1,
    this.pdfUrl = '',
    this.createdAt,
    this.updatedAt,
    this.approvedAt,
    this.approvedBy,
    this.generatedAt,
    this.generatedBy,
    this.hasUnvalidatedRecords = false,
    this.unvalidatedCount = 0,
  });

  factory TreasuryInvoice.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TreasuryInvoice(
      id: doc.id,
      year: (data['year'] as num?)?.toInt() ?? DateTime.now().year,
      invoiceNumber: data['invoiceNumber'] ?? '',
      status: data['status'] ?? 'draft',
      holderName: data['holderName'] ?? '',
      ibanMasked: data['ibanMasked'] ?? '',
      ibanHash: data['ibanHash'] ?? '',
      concept: data['concept'] ?? '',
      cofradeIds: (data['cofradeIds'] as List<dynamic>? ?? [])
          .map((e) => '$e')
          .toList(),
      cofradeAuthUids: (data['cofradeAuthUids'] as List<dynamic>? ?? [])
          .map((e) => '$e')
          .toList(),
      sourceFeeDraftIds: (data['sourceFeeDraftIds'] as List<dynamic>? ?? [])
          .map((e) => '$e')
          .toList(),
      paymentMethod: data['paymentMethod'] ?? 'bank_remittance',
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0,
      version: (data['version'] as num?)?.toInt() ?? 1,
      pdfUrl: data['pdfUrl'] ?? '',
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
      approvedAt: _date(data['approvedAt']),
      approvedBy: data['approvedBy'],
      generatedAt: _date(data['generatedAt']),
      generatedBy: data['generatedBy'],
      hasUnvalidatedRecords: data['hasUnvalidatedRecords'] ?? false,
      unvalidatedCount: (data['unvalidatedCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'year': year,
      'invoiceNumber': invoiceNumber,
      'status': status,
      'holderName': holderName,
      'ibanMasked': ibanMasked,
      'ibanHash': ibanHash,
      'concept': concept,
      'cofradeIds': cofradeIds,
      'cofradeAuthUids': cofradeAuthUids,
      'sourceFeeDraftIds': sourceFeeDraftIds,
      'paymentMethod': paymentMethod,
      'totalAmount': totalAmount,
      'version': version,
      'pdfUrl': pdfUrl,
      'updatedAt': FieldValue.serverTimestamp(),
      if (id.isEmpty) 'createdAt': FieldValue.serverTimestamp(),
      if (approvedAt != null) 'approvedAt': Timestamp.fromDate(approvedAt!),
      'approvedBy': approvedBy,
      if (generatedAt != null) 'generatedAt': Timestamp.fromDate(generatedAt!),
      'generatedBy': generatedBy,
      'hasUnvalidatedRecords': hasUnvalidatedRecords,
      'unvalidatedCount': unvalidatedCount,
    };
  }
}

class TreasuryInvoiceLine {
  final String id;
  final String invoiceId;
  final String cofradeId;
  final String cofradeName;
  final int? cofradeNumber;
  final String? authUid;
  final String sourceFeeDraftId;
  final String concept;
  final double amount;
  final int year;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TreasuryInvoiceLine({
    required this.id,
    required this.invoiceId,
    required this.cofradeId,
    required this.cofradeName,
    this.cofradeNumber,
    this.authUid,
    this.sourceFeeDraftId = '',
    required this.concept,
    required this.amount,
    required this.year,
    this.status = 'pending',
    this.createdAt,
    this.updatedAt,
  });

  factory TreasuryInvoiceLine.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TreasuryInvoiceLine(
      id: doc.id,
      invoiceId: data['invoiceId'] ?? '',
      cofradeId: data['cofradeId'] ?? '',
      cofradeName: data['cofradeName'] ?? '',
      cofradeNumber: (data['cofradeNumber'] as num?)?.toInt(),
      authUid: data['authUid'],
      sourceFeeDraftId: data['sourceFeeDraftId'] ?? '',
      concept: data['concept'] ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      year: (data['year'] as num?)?.toInt() ?? DateTime.now().year,
      status: data['status'] ?? 'pending',
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'invoiceId': invoiceId,
      'cofradeId': cofradeId,
      'cofradeName': cofradeName,
      'cofradeNumber': cofradeNumber,
      'authUid': authUid,
      'sourceFeeDraftId': sourceFeeDraftId,
      'concept': concept,
      'amount': amount,
      'year': year,
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      if (id.isEmpty) 'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

class TreasuryFeeDraft {
  final String id;
  final int year;
  final String cofradeId;
  final String cofradeName;
  final int? cofradeNumber;
  final String? authUid;
  final double amount;
  final String concept;
  final String initialPaymentMethod;
  final String initialIbanMasked;
  final String initialIbanHash;
  final String validatedIbanMasked;
  final String validatedIbanHash;
  final String validationStatus;
  final String status;
  final String? finalInvoiceId;
  final DateTime? approvedAt;
  final String? approvedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TreasuryFeeDraft({
    required this.id,
    required this.year,
    required this.cofradeId,
    required this.cofradeName,
    this.cofradeNumber,
    this.authUid,
    this.amount = 0,
    this.concept = '',
    this.initialPaymentMethod = 'cash',
    this.initialIbanMasked = '',
    this.initialIbanHash = '',
    this.validatedIbanMasked = '',
    this.validatedIbanHash = '',
    this.validationStatus = 'pending',
    this.status = 'draft',
    this.finalInvoiceId,
    this.approvedAt,
    this.approvedBy,
    this.createdAt,
    this.updatedAt,
  });

  factory TreasuryFeeDraft.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TreasuryFeeDraft(
      id: doc.id,
      year: (data['year'] as num?)?.toInt() ?? DateTime.now().year,
      cofradeId: data['cofradeId'] ?? '',
      cofradeName: data['cofradeName'] ?? '',
      cofradeNumber: (data['cofradeNumber'] as num?)?.toInt(),
      authUid: data['authUid'],
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      concept: data['concept'] ?? '',
      initialPaymentMethod:
          data['paymentMethod'] ?? data['initialPaymentMethod'] ?? 'cash',
      initialIbanMasked: data['ibanMasked'] ?? data['initialIbanMasked'] ?? '',
      initialIbanHash: data['ibanHash'] ?? data['initialIbanHash'] ?? '',
      validatedIbanMasked: data['validatedIbanMasked'] ?? '',
      validatedIbanHash: data['validatedIbanHash'] ?? '',
      validationStatus: data['validationStatus'] ?? 'pending',
      status: data['status'] ?? 'draft',
      finalInvoiceId: data['finalInvoiceId'],
      approvedAt: _date(data['approvedAt']),
      approvedBy: data['approvedBy'],
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'year': year,
      'cofradeId': cofradeId,
      'cofradeName': cofradeName,
      'cofradeNumber': cofradeNumber,
      'authUid': authUid,
      'amount': amount,
      'concept': concept,
      'paymentMethod': initialPaymentMethod,
      'ibanMasked': initialIbanMasked,
      'ibanHash': initialIbanHash,
      'initialPaymentMethod': initialPaymentMethod,
      'initialIbanMasked': initialIbanMasked,
      'initialIbanHash': initialIbanHash,
      'validatedIbanMasked': validatedIbanMasked,
      'validatedIbanHash': validatedIbanHash,
      'validationStatus': validationStatus,
      'status': status,
      'finalInvoiceId': finalInvoiceId,
      if (approvedAt != null) 'approvedAt': Timestamp.fromDate(approvedAt!),
      'approvedBy': approvedBy,
      'updatedAt': FieldValue.serverTimestamp(),
      if (id.isEmpty) 'createdAt': FieldValue.serverTimestamp(),
    };
  }

  String get paymentMethod => initialPaymentMethod;
  String get ibanMasked => initialIbanMasked;
  String get ibanHash => initialIbanHash;
}

class TreasuryPayment {
  final String id;
  final int year;
  final String invoiceId;
  final String? cofradeId;
  final String remittanceId;
  final String invoiceNumber;
  final String cofradeName;
  final double amount;
  final String method;
  final String status;
  final DateTime? paymentDate;
  final DateTime? resultDate;
  final String rejectionReason;
  final String reference;
  final String notes;
  final DateTime? createdAt;
  final String? createdBy;

  const TreasuryPayment({
    required this.id,
    this.year = 0,
    required this.invoiceId,
    this.cofradeId,
    this.remittanceId = '',
    this.invoiceNumber = '',
    this.cofradeName = '',
    required this.amount,
    this.method = 'other',
    this.status = 'pending',
    this.paymentDate,
    this.resultDate,
    this.rejectionReason = '',
    this.reference = '',
    this.notes = '',
    this.createdAt,
    this.createdBy,
  });

  factory TreasuryPayment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TreasuryPayment(
      id: doc.id,
      year: (data['year'] as num?)?.toInt() ?? 0,
      invoiceId: data['invoiceId'] ?? '',
      cofradeId: data['cofradeId'],
      remittanceId: data['remittanceId'] ?? '',
      invoiceNumber: data['invoiceNumber'] ?? '',
      cofradeName: data['cofradeName'] ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      method: data['method'] ?? 'other',
      status: data['status'] ?? 'pending',
      paymentDate: _date(data['paymentDate']),
      resultDate: _date(data['resultDate']),
      rejectionReason: data['rejectionReason'] ?? '',
      reference: data['reference'] ?? '',
      notes: data['notes'] ?? '',
      createdAt: _date(data['createdAt']),
      createdBy: data['createdBy'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'invoiceId': invoiceId,
      'year': year,
      'cofradeId': cofradeId,
      'remittanceId': remittanceId,
      'invoiceNumber': invoiceNumber,
      'cofradeName': cofradeName,
      'amount': amount,
      'method': method,
      'status': status,
      'paymentDate':
          paymentDate != null ? Timestamp.fromDate(paymentDate!) : null,
      'resultDate': resultDate != null ? Timestamp.fromDate(resultDate!) : null,
      'rejectionReason': rejectionReason,
      'reference': reference,
      'notes': notes,
      'createdBy': createdBy,
      if (id.isEmpty) 'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

class TreasuryAccountingMovement {
  final String id;
  final int year;
  final String type;
  final double amount;
  final DateTime? date;
  final String categoryId;
  final String costCenterId;
  final String subCostCenterId;
  final String concept;
  final String description;
  final String paymentMethod;
  final String status;
  final String personType;
  final String personId;
  final String personName;
  final String origin;
  final String reference;
  final String? linkedInvoiceId;
  final String? linkedPaymentId;
  final List<String> documentUrls;
  final DateTime? createdAt;
  final String? createdBy;

  const TreasuryAccountingMovement({
    required this.id,
    this.year = 0,
    required this.type,
    required this.amount,
    this.date,
    this.categoryId = '',
    this.costCenterId = '',
    this.subCostCenterId = '',
    this.concept = '',
    this.description = '',
    this.paymentMethod = '',
    this.status = 'pending',
    this.personType = '',
    this.personId = '',
    this.personName = '',
    this.origin = 'manual',
    this.reference = '',
    this.linkedInvoiceId,
    this.linkedPaymentId,
    this.documentUrls = const [],
    this.createdAt,
    this.createdBy,
  });

  factory TreasuryAccountingMovement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TreasuryAccountingMovement(
      id: doc.id,
      year: (data['year'] as num?)?.toInt() ?? 0,
      type: data['type'] ?? 'expense',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      date: _date(data['date']),
      categoryId: data['categoryId'] ?? '',
      costCenterId: data['costCenterId'] ?? '',
      subCostCenterId: data['subCostCenterId'] ?? '',
      concept: data['concept'] ?? '',
      description: data['description'] ?? '',
      paymentMethod: data['paymentMethod'] ?? '',
      status: data['status'] ?? 'pending',
      personType: data['personType'] ?? '',
      personId: data['personId'] ?? '',
      personName: data['personName'] ?? '',
      origin: data['origin'] ?? 'manual',
      reference: data['reference'] ?? '',
      linkedInvoiceId: data['linkedInvoiceId'],
      linkedPaymentId: data['linkedPaymentId'],
      documentUrls: (data['documentUrls'] as List<dynamic>? ?? [])
          .map((e) => '$e')
          .toList(),
      createdAt: _date(data['createdAt']),
      createdBy: data['createdBy'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'year': year,
      'type': type,
      'amount': amount,
      'date': date != null ? Timestamp.fromDate(date!) : null,
      'categoryId': categoryId,
      'costCenterId': costCenterId,
      'subCostCenterId': subCostCenterId,
      'concept': concept,
      'description': description,
      'paymentMethod': paymentMethod,
      'status': status,
      'personType': personType,
      'personId': personId,
      'personName': personName,
      'origin': origin,
      'reference': reference,
      'linkedInvoiceId': linkedInvoiceId,
      'linkedPaymentId': linkedPaymentId,
      'documentUrls': documentUrls,
      'createdBy': createdBy,
      if (id.isEmpty) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class TreasuryBankValidation {
  final String id;
  final String feeDraftId;
  final String invoiceId;
  final String invoiceNumber;
  final int year;
  final String status;
  final String holderName;
  final String ibanMasked;
  final String ibanHash;
  final String newIbanMasked;
  final String newIbanHash;
  final List<String> cofradeIds;
  final List<String> cofradeNames;
  final List<String> cofradeAuthUids;
  final double totalAmount;
  final DateTime? changedAt;
  final DateTime? validatedAt;
  final DateTime? lockedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? updatedBy;
  final String? lockedBy;

  const TreasuryBankValidation({
    required this.id,
    this.feeDraftId = '',
    required this.invoiceId,
    this.invoiceNumber = '',
    required this.year,
    this.status = 'pending',
    this.holderName = '',
    this.ibanMasked = '',
    this.ibanHash = '',
    this.newIbanMasked = '',
    this.newIbanHash = '',
    this.cofradeIds = const [],
    this.cofradeNames = const [],
    this.cofradeAuthUids = const [],
    this.totalAmount = 0,
    this.changedAt,
    this.validatedAt,
    this.lockedAt,
    this.createdAt,
    this.updatedAt,
    this.updatedBy,
    this.lockedBy,
  });

  factory TreasuryBankValidation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TreasuryBankValidation(
      id: doc.id,
      feeDraftId: data['feeDraftId'] ?? '',
      invoiceId: data['invoiceId'] ?? '',
      invoiceNumber: data['invoiceNumber'] ?? '',
      year: (data['year'] as num?)?.toInt() ?? DateTime.now().year,
      status: data['status'] ?? 'pending',
      holderName: data['holderName'] ?? '',
      ibanMasked: data['ibanMasked'] ?? '',
      ibanHash: data['ibanHash'] ?? '',
      newIbanMasked: data['newIbanMasked'] ?? '',
      newIbanHash: data['newIbanHash'] ?? '',
      cofradeIds: (data['cofradeIds'] as List<dynamic>? ?? [])
          .map((e) => '$e')
          .toList(),
      cofradeNames: (data['cofradeNames'] as List<dynamic>? ?? [])
          .map((e) => '$e')
          .toList(),
      cofradeAuthUids: (data['cofradeAuthUids'] as List<dynamic>? ?? [])
          .map((e) => '$e')
          .toList(),
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0,
      changedAt: _date(data['changedAt']),
      validatedAt: _date(data['validatedAt']),
      lockedAt: _date(data['lockedAt']),
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
      updatedBy: data['updatedBy'],
      lockedBy: data['lockedBy'],
    );
  }
}

class TreasuryCategory {
  final String id;
  final String name;
  final String type;
  final bool isActive;
  final DateTime? createdAt;

  const TreasuryCategory({
    required this.id,
    required this.name,
    this.type = 'expense',
    this.isActive = true,
    this.createdAt,
  });

  factory TreasuryCategory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TreasuryCategory(
      id: doc.id,
      name: data['name'] ?? '',
      type: data['type'] ?? 'expense',
      isActive: data['isActive'] ?? true,
      createdAt: _date(data['createdAt']),
    );
  }
}

class TreasuryCostCenter {
  final String id;
  final String name;
  final String description;
  final String parentId;
  final double budgetAmount;
  final bool isActive;
  final DateTime? createdAt;

  const TreasuryCostCenter({
    required this.id,
    required this.name,
    this.description = '',
    this.parentId = '',
    this.budgetAmount = 0,
    this.isActive = true,
    this.createdAt,
  });

  factory TreasuryCostCenter.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TreasuryCostCenter(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      parentId: data['parentId'] ?? '',
      budgetAmount: (data['budgetAmount'] as num?)?.toDouble() ?? 0,
      isActive: data['isActive'] ?? true,
      createdAt: _date(data['createdAt']),
    );
  }
}

class TreasuryAuditLog {
  final String id;
  final String entityType;
  final String entityId;
  final String action;
  final Map<String, dynamic>? oldValue;
  final Map<String, dynamic>? newValue;
  final String? changedBy;
  final DateTime? changedAt;

  const TreasuryAuditLog({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.action,
    this.oldValue,
    this.newValue,
    this.changedBy,
    this.changedAt,
  });

  factory TreasuryAuditLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TreasuryAuditLog(
      id: doc.id,
      entityType: data['entityType'] ?? '',
      entityId: data['entityId'] ?? '',
      action: data['action'] ?? '',
      oldValue: (data['oldValue'] as Map?)?.cast<String, dynamic>(),
      newValue: (data['newValue'] as Map?)?.cast<String, dynamic>(),
      changedBy: data['changedBy'],
      changedAt: _date(data['changedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'entityType': entityType,
      'entityId': entityId,
      'action': action,
      'oldValue': oldValue,
      'newValue': newValue,
      'changedBy': changedBy,
      'changedAt': FieldValue.serverTimestamp(),
    };
  }
}

class TreasuryDashboardSummary {
  final int year;
  final double annualFeeAmount;
  final int draftInvoicesCount;
  final int feeDraftsCount;
  final int feeDraftsDraftCount;
  final int feeDraftsApprovedCount;
  final int feeDraftsCancelledCount;
  final int validatedInvoicesCount;
  final double pendingAmount;
  final double paidAmount;
  final double returnedAmount;
  final int totalInvoicesCount;
  final double totalInvoicesAmount;
  final int approvedInvoicesCount;
  final double approvedAmount;
  final int bankInvoicesCount;
  final int cashInvoicesCount;
  final double bankAmount;
  final double cashAmount;
  final int bankValidationPendingCount;
  final int bankValidationValidatedCount;
  final int bankValidationModifiedCount;
  final int bankValidationLockedCount;
  final int finalInvoicesWithUnvalidatedCount;
  final int remittancesCount;
  final double remittancesAmount;
  final int remittanceUnvalidatedInvoicesCount;
  final int collectionPendingCount;
  final int collectionPaidCount;
  final int collectionRejectedCount;
  final int manualPaymentsCount;
  final double manualPaymentsAmount;
  final double incomeAmount;
  final double expenseAmount;

  const TreasuryDashboardSummary({
    required this.year,
    this.annualFeeAmount = 0,
    this.draftInvoicesCount = 0,
    this.feeDraftsCount = 0,
    this.feeDraftsDraftCount = 0,
    this.feeDraftsApprovedCount = 0,
    this.feeDraftsCancelledCount = 0,
    this.validatedInvoicesCount = 0,
    this.pendingAmount = 0,
    this.paidAmount = 0,
    this.returnedAmount = 0,
    this.totalInvoicesCount = 0,
    this.totalInvoicesAmount = 0,
    this.approvedInvoicesCount = 0,
    this.approvedAmount = 0,
    this.bankInvoicesCount = 0,
    this.cashInvoicesCount = 0,
    this.bankAmount = 0,
    this.cashAmount = 0,
    this.bankValidationPendingCount = 0,
    this.bankValidationValidatedCount = 0,
    this.bankValidationModifiedCount = 0,
    this.bankValidationLockedCount = 0,
    this.finalInvoicesWithUnvalidatedCount = 0,
    this.remittancesCount = 0,
    this.remittancesAmount = 0,
    this.remittanceUnvalidatedInvoicesCount = 0,
    this.collectionPendingCount = 0,
    this.collectionPaidCount = 0,
    this.collectionRejectedCount = 0,
    this.manualPaymentsCount = 0,
    this.manualPaymentsAmount = 0,
    this.incomeAmount = 0,
    this.expenseAmount = 0,
  });

  double get annualResult => incomeAmount - expenseAmount;
}

class TreasuryBankValidationInitializationResult {
  final int year;
  final int createdCount;
  final int existingCount;
  final int skippedCount;

  const TreasuryBankValidationInitializationResult({
    required this.year,
    this.createdCount = 0,
    this.existingCount = 0,
    this.skippedCount = 0,
  });
}

class TreasuryGenerationResult {
  final int year;
  final int version;
  final int invoicesCreated;
  final int linesCreated;
  final int bankInvoicesCreated;
  final int cashInvoicesCreated;
  final int skippedCofrades;
  final List<String> warnings;

  const TreasuryGenerationResult({
    required this.year,
    required this.version,
    required this.invoicesCreated,
    required this.linesCreated,
    required this.bankInvoicesCreated,
    required this.cashInvoicesCreated,
    this.skippedCofrades = 0,
    this.warnings = const [],
  });
}

class TreasuryFinalInvoiceGenerationResult {
  final int year;
  final int invoicesCreated;
  final int linesCreated;
  final int feeDraftsInvoiced;
  final int skippedFeeDrafts;
  final int unvalidatedCount;
  final double unvalidatedAmount;
  final List<String> warnings;

  const TreasuryFinalInvoiceGenerationResult({
    required this.year,
    this.invoicesCreated = 0,
    this.linesCreated = 0,
    this.feeDraftsInvoiced = 0,
    this.skippedFeeDrafts = 0,
    this.unvalidatedCount = 0,
    this.unvalidatedAmount = 0,
    this.warnings = const [],
  });
}

class TreasuryRemittance {
  final String id;
  final int year;
  final String status;
  final List<String> invoiceIds;
  final double totalAmount;
  final String fileUrlCsv;
  final String fileUrlXlsx;
  final DateTime? generatedAt;
  final String? generatedBy;
  final int unvalidatedCount;
  final double unvalidatedAmount;
  final String notes;

  const TreasuryRemittance({
    required this.id,
    required this.year,
    this.status = 'generated',
    this.invoiceIds = const [],
    this.totalAmount = 0,
    this.fileUrlCsv = '',
    this.fileUrlXlsx = '',
    this.generatedAt,
    this.generatedBy,
    this.unvalidatedCount = 0,
    this.unvalidatedAmount = 0,
    this.notes = '',
  });

  factory TreasuryRemittance.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TreasuryRemittance(
      id: doc.id,
      year: (data['year'] as num?)?.toInt() ?? DateTime.now().year,
      status: data['status'] ?? 'generated',
      invoiceIds: (data['invoiceIds'] as List<dynamic>? ?? [])
          .map((e) => '$e')
          .toList(),
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0,
      fileUrlCsv: data['fileUrlCsv'] ?? '',
      fileUrlXlsx: data['fileUrlXlsx'] ?? '',
      generatedAt: _date(data['generatedAt']),
      generatedBy: data['generatedBy'],
      unvalidatedCount: (data['unvalidatedCount'] as num?)?.toInt() ?? 0,
      unvalidatedAmount: (data['unvalidatedAmount'] as num?)?.toDouble() ?? 0,
      notes: data['notes'] ?? '',
    );
  }
}

class TreasuryRemittanceRow {
  final String invoiceId;
  final String invoiceNumber;
  final String holderName;
  final String debtorIban;
  final double amount;
  final String concept;
  final bool hasUnvalidatedRecords;

  const TreasuryRemittanceRow({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.holderName,
    required this.debtorIban,
    required this.amount,
    required this.concept,
    this.hasUnvalidatedRecords = false,
  });

  List<String> toCells({
    required DateTime issueDate,
    required DateTime operationDate,
  }) {
    return [
      'DOMICILIACIONES',
      'CORE',
      'G45483997',
      'CSE',
      'COFRADIA SAN JUAN EVANGELISTA',
      'G45483997',
      'CSE',
      _formatDate(issueDate),
      'COFRADIA SAN JUAN EVANGELISTA',
      'ES0700492524552194017371',
      invoiceNumber,
      amount.toStringAsFixed(2),
      'RCUR',
      amount.toStringAsFixed(2),
      _formatDate(operationDate),
      holderName,
      debtorIban,
      concept,
    ];
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class TreasuryRemittanceGenerationResult {
  final TreasuryRemittance remittance;
  final List<TreasuryRemittanceRow> rows;
  final List<String> warnings;

  const TreasuryRemittanceGenerationResult({
    required this.remittance,
    this.rows = const [],
    this.warnings = const [],
  });
}
