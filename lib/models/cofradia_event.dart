import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _date(dynamic value) => value is Timestamp ? value.toDate() : null;

class EventCampaign {
  final String id;
  final String type;
  final int year;
  final String name;
  final String description;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? processionDate;
  final String contactPhone;
  final String rules;
  final double cost;
  final bool active;
  final bool published;
  final List<Map<String, dynamic>> turns;
  final String status;
  final String location;
  final DateTime? eventDate;
  final bool requiresRegistration;
  final bool allowCompanions;
  final bool allowExternalGuests;
  final bool allowOtherCofrades;
  final int? maxCompanions;
  final int? capacity;
  final bool waitlistEnabled;
  final bool requiresPayment;
  final bool freeEvent;
  final double memberPrice;
  final double guestPrice;
  final double childPrice;
  final double protocolPrice;
  final List<String> paymentMethods;
  final bool allergiesEnabled;
  final bool observationsEnabled;
  final bool showBanner;
  final String bannerText;
  final List<Map<String, dynamic>> customFields;
  final Map<String, dynamic> registrationConfig;
  final Map<String, dynamic> pricingConfig;
  final Map<String, dynamic> companionConfig;
  final Map<String, dynamic> paymentConfig;
  final Map<String, dynamic> notificationConfig;
  final DateTime? createdAt;

  const EventCampaign({
    required this.id,
    required this.type,
    required this.year,
    required this.name,
    this.description = '',
    this.startDate,
    this.endDate,
    this.processionDate,
    this.contactPhone = '',
    this.rules = '',
    this.cost = 0,
    this.active = false,
    this.published = false,
    this.turns = const [],
    this.status = 'draft',
    this.location = '',
    this.eventDate,
    this.requiresRegistration = true,
    this.allowCompanions = false,
    this.allowExternalGuests = false,
    this.allowOtherCofrades = false,
    this.maxCompanions,
    this.capacity,
    this.waitlistEnabled = false,
    this.requiresPayment = false,
    this.freeEvent = true,
    this.memberPrice = 0,
    this.guestPrice = 0,
    this.childPrice = 0,
    this.protocolPrice = 0,
    this.paymentMethods = const [],
    this.allergiesEnabled = false,
    this.observationsEnabled = true,
    this.showBanner = true,
    this.bannerText = '',
    this.customFields = const [],
    this.registrationConfig = const {},
    this.pricingConfig = const {},
    this.companionConfig = const {},
    this.paymentConfig = const {},
    this.notificationConfig = const {},
    this.createdAt,
  });

  bool get isOpen {
    final now = DateTime.now();
    final afterStart = startDate == null || !now.isBefore(startDate!);
    final beforeEnd = endDate == null || !now.isAfter(endDate!);
    return active && afterStart && beforeEnd;
  }

  factory EventCampaign.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EventCampaign(
      id: doc.id,
      type: data['type'] ?? '',
      year: (data['year'] as num?)?.toInt() ?? DateTime.now().year,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      startDate: _date(data['startDate']),
      endDate: _date(data['endDate']),
      processionDate: _date(data['processionDate']),
      contactPhone: data['contactPhone'] ?? '',
      rules: data['rules'] ?? '',
      cost: (data['cost'] as num?)?.toDouble() ?? 0,
      active: data['active'] ?? false,
      published: data['published'] ?? false,
      turns: (data['turns'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      status: data['status'] ?? (data['active'] == true ? 'active' : 'draft'),
      location: data['location'] ?? data['lugar'] ?? '',
      eventDate: _date(data['eventDate']) ?? _date(data['processionDate']),
      requiresRegistration:
          data['requiresRegistration'] ?? data['requires_registration'] ?? true,
      allowCompanions:
          data['allowCompanions'] ?? data['allow_companions'] ?? false,
      allowExternalGuests:
          data['allowExternalGuests'] ?? data['allow_external_guests'] ?? false,
      allowOtherCofrades:
          data['allowOtherCofrades'] ?? data['allow_other_cofrades'] ?? false,
      maxCompanions: (data['maxCompanions'] as num?)?.toInt(),
      capacity: (data['capacity'] as num?)?.toInt(),
      waitlistEnabled: data['waitlistEnabled'] ?? false,
      requiresPayment:
          data['requiresPayment'] ?? data['requires_payment'] ?? false,
      freeEvent: data['freeEvent'] ?? !(data['requiresPayment'] == true),
      memberPrice: (data['memberPrice'] as num?)?.toDouble() ??
          (data['cost'] as num?)?.toDouble() ??
          0,
      guestPrice: (data['guestPrice'] as num?)?.toDouble() ?? 0,
      childPrice: (data['childPrice'] as num?)?.toDouble() ?? 0,
      protocolPrice: (data['protocolPrice'] as num?)?.toDouble() ?? 0,
      paymentMethods: (data['paymentMethods'] as List<dynamic>? ?? [])
          .map((item) => '$item')
          .toList(),
      allergiesEnabled: data['allergiesEnabled'] ?? false,
      observationsEnabled: data['observationsEnabled'] ?? true,
      showBanner: data['showBanner'] ?? true,
      bannerText: data['bannerText'] ?? '',
      customFields: (data['customFields'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      registrationConfig:
          Map<String, dynamic>.from(data['registrationConfig'] ?? const {}),
      pricingConfig:
          Map<String, dynamic>.from(data['pricingConfig'] ?? const {}),
      companionConfig:
          Map<String, dynamic>.from(data['companionConfig'] ?? const {}),
      paymentConfig:
          Map<String, dynamic>.from(data['paymentConfig'] ?? const {}),
      notificationConfig:
          Map<String, dynamic>.from(data['notificationConfig'] ?? const {}),
      createdAt: _date(data['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': type,
      'year': year,
      'name': name,
      'description': description,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'processionDate':
          processionDate != null ? Timestamp.fromDate(processionDate!) : null,
      'contactPhone': contactPhone,
      'rules': rules,
      'cost': cost,
      'active': active,
      'published': published,
      'turns': turns,
      'status': status,
      'location': location,
      'eventDate': eventDate != null ? Timestamp.fromDate(eventDate!) : null,
      'requiresRegistration': requiresRegistration,
      'allowCompanions': allowCompanions,
      'allowExternalGuests': allowExternalGuests,
      'allowOtherCofrades': allowOtherCofrades,
      'maxCompanions': maxCompanions,
      'capacity': capacity,
      'waitlistEnabled': waitlistEnabled,
      'requiresPayment': requiresPayment,
      'freeEvent': freeEvent,
      'memberPrice': memberPrice,
      'guestPrice': guestPrice,
      'childPrice': childPrice,
      'protocolPrice': protocolPrice,
      'paymentMethods': paymentMethods,
      'allergiesEnabled': allergiesEnabled,
      'observationsEnabled': observationsEnabled,
      'showBanner': showBanner,
      'bannerText': bannerText,
      'customFields': customFields,
      'registrationConfig': registrationConfig,
      'pricingConfig': pricingConfig,
      'companionConfig': companionConfig,
      'paymentConfig': paymentConfig,
      'notificationConfig': notificationConfig,
      'updatedAt': FieldValue.serverTimestamp(),
      if (id.isEmpty) 'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

class EventRegistration {
  final String id;
  final String campaignId;
  final String type;
  final int year;
  final String cofradeId;
  final String cofradeName;
  final String addedById;
  final String addedByName;
  final String status;
  final int? heightCm;
  final String turnId;
  final String turnName;
  final String role;
  final int? position;
  final List<Map<String, dynamic>> participants;
  final String paymentStatus;
  final double totalAmount;
  final Map<String, dynamic> answers;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const EventRegistration({
    required this.id,
    required this.campaignId,
    required this.type,
    required this.year,
    required this.cofradeId,
    required this.cofradeName,
    this.addedById = '',
    this.addedByName = '',
    this.status = 'solicitada',
    this.heightCm,
    this.turnId = '',
    this.turnName = '',
    this.role = 'titular',
    this.position,
    this.participants = const [],
    this.paymentStatus = 'not_required',
    this.totalAmount = 0,
    this.answers = const {},
    this.createdAt,
    this.updatedAt,
  });

  factory EventRegistration.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EventRegistration(
      id: doc.id,
      campaignId: data['campaignId'] ?? '',
      type: data['type'] ?? '',
      year: (data['year'] as num?)?.toInt() ?? DateTime.now().year,
      cofradeId: data['cofradeId'] ?? '',
      cofradeName: data['cofradeName'] ?? '',
      addedById: data['addedById'] ?? '',
      addedByName: data['addedByName'] ?? '',
      status: data['status'] ?? 'solicitada',
      heightCm: (data['heightCm'] as num?)?.toInt(),
      turnId: data['turnId'] ?? '',
      turnName: data['turnName'] ?? '',
      role: data['role'] ?? 'titular',
      position: (data['position'] as num?)?.toInt(),
      participants: (data['participants'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      paymentStatus:
          data['paymentStatus'] ?? data['payment_status'] ?? 'not_required',
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0,
      answers: Map<String, dynamic>.from(data['answers'] ?? const {}),
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
    );
  }
}
