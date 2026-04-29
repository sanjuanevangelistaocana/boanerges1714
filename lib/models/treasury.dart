import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _date(dynamic value) => value is Timestamp ? value.toDate() : null;

class TreasurySettings {
  final String id;
  final int year;
  final double annualFeeAmount;
  final DateTime? validationStartDate;
  final DateTime? validationEndDate;
  final DateTime? remittanceDate;
  final bool allowIbanEdition;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TreasurySettings({
    required this.id,
    required this.year,
    required this.annualFeeAmount,
    this.validationStartDate,
    this.validationEndDate,
    this.remittanceDate,
    this.allowIbanEdition = true,
    this.isActive = false,
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
      allowIbanEdition: data['allowIbanEdition'] ?? true,
      isActive: data['isActive'] ?? false,
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
      'allowIbanEdition': allowIbanEdition,
      'isActive': isActive,
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
    bool? allowIbanEdition,
    bool? isActive,
  }) {
    return TreasurySettings(
      id: id ?? this.id,
      year: year ?? this.year,
      annualFeeAmount: annualFeeAmount ?? this.annualFeeAmount,
      validationStartDate: validationStartDate ?? this.validationStartDate,
      validationEndDate: validationEndDate ?? this.validationEndDate,
      remittanceDate: remittanceDate ?? this.remittanceDate,
      allowIbanEdition: allowIbanEdition ?? this.allowIbanEdition,
      isActive: isActive ?? this.isActive,
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
  final String paymentMethod;
  final double totalAmount;
  final int version;
  final String pdfUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? approvedAt;
  final String? approvedBy;

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
    this.paymentMethod = 'bank_remittance',
    this.totalAmount = 0,
    this.version = 1,
    this.pdfUrl = '',
    this.createdAt,
    this.updatedAt,
    this.approvedAt,
    this.approvedBy,
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
      paymentMethod: data['paymentMethod'] ?? 'bank_remittance',
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0,
      version: (data['version'] as num?)?.toInt() ?? 1,
      pdfUrl: data['pdfUrl'] ?? '',
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
      approvedAt: _date(data['approvedAt']),
      approvedBy: data['approvedBy'],
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
      'paymentMethod': paymentMethod,
      'totalAmount': totalAmount,
      'version': version,
      'pdfUrl': pdfUrl,
      'updatedAt': FieldValue.serverTimestamp(),
      if (id.isEmpty) 'createdAt': FieldValue.serverTimestamp(),
      if (approvedAt != null) 'approvedAt': Timestamp.fromDate(approvedAt!),
      'approvedBy': approvedBy,
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
      'concept': concept,
      'amount': amount,
      'year': year,
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      if (id.isEmpty) 'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

class TreasuryPayment {
  final String id;
  final String invoiceId;
  final String? cofradeId;
  final double amount;
  final String method;
  final String status;
  final DateTime? paymentDate;
  final String notes;
  final DateTime? createdAt;
  final String? createdBy;

  const TreasuryPayment({
    required this.id,
    required this.invoiceId,
    this.cofradeId,
    required this.amount,
    this.method = 'other',
    this.status = 'pending',
    this.paymentDate,
    this.notes = '',
    this.createdAt,
    this.createdBy,
  });

  factory TreasuryPayment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TreasuryPayment(
      id: doc.id,
      invoiceId: data['invoiceId'] ?? '',
      cofradeId: data['cofradeId'],
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      method: data['method'] ?? 'other',
      status: data['status'] ?? 'pending',
      paymentDate: _date(data['paymentDate']),
      notes: data['notes'] ?? '',
      createdAt: _date(data['createdAt']),
      createdBy: data['createdBy'],
    );
  }
}

class TreasuryAccountingMovement {
  final String id;
  final String type;
  final double amount;
  final DateTime? date;
  final String categoryId;
  final String costCenterId;
  final String description;
  final String? linkedInvoiceId;
  final String? linkedPaymentId;
  final List<String> documentUrls;
  final DateTime? createdAt;
  final String? createdBy;

  const TreasuryAccountingMovement({
    required this.id,
    required this.type,
    required this.amount,
    this.date,
    this.categoryId = '',
    this.costCenterId = '',
    this.description = '',
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
      type: data['type'] ?? 'expense',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      date: _date(data['date']),
      categoryId: data['categoryId'] ?? '',
      costCenterId: data['costCenterId'] ?? '',
      description: data['description'] ?? '',
      linkedInvoiceId: data['linkedInvoiceId'],
      linkedPaymentId: data['linkedPaymentId'],
      documentUrls: (data['documentUrls'] as List<dynamic>? ?? [])
          .map((e) => '$e')
          .toList(),
      createdAt: _date(data['createdAt']),
      createdBy: data['createdBy'],
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
  final bool isActive;
  final DateTime? createdAt;

  const TreasuryCostCenter({
    required this.id,
    required this.name,
    this.description = '',
    this.isActive = true,
    this.createdAt,
  });

  factory TreasuryCostCenter.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TreasuryCostCenter(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
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
  final double incomeAmount;
  final double expenseAmount;

  const TreasuryDashboardSummary({
    required this.year,
    this.annualFeeAmount = 0,
    this.draftInvoicesCount = 0,
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
    this.incomeAmount = 0,
    this.expenseAmount = 0,
  });

  double get annualResult => incomeAmount - expenseAmount;
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
