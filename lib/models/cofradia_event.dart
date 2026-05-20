import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _date(dynamic value) => value is Timestamp ? value.toDate() : null;

dynamic _cleanFirestoreValue(dynamic value) {
  if (value == null ||
      value is String ||
      value is num ||
      value is bool ||
      value is Timestamp ||
      value is FieldValue) {
    return value;
  }
  if (value is DateTime) return Timestamp.fromDate(value);
  if (value is Iterable) {
    return value
        .map(_cleanFirestoreValue)
        .where((item) => item != _unsupportedFirestoreValue)
        .toList();
  }
  if (value is Map) {
    final cleaned = <String, dynamic>{};
    value.forEach((key, item) {
      final cleanedValue = _cleanFirestoreValue(item);
      if (cleanedValue != _unsupportedFirestoreValue) {
        cleaned['$key'] = cleanedValue;
      }
    });
    return cleaned;
  }
  return _unsupportedFirestoreValue;
}

const _unsupportedFirestoreValue = Object();

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
  final double memberAdultPrice;
  final double memberChildPrice;
  final double guestAdultPrice;
  final double guestChildPrice;
  final double protocolAdultPrice;
  final double protocolChildPrice;
  final double realAdultMenuCost;
  final double realChildMenuCost;
  final double palmMemberPrice;
  final double palmExternalPrice;
  final double realPalmCost;
  final List<String> paymentMethods;
  final bool allergiesEnabled;
  final bool observationsEnabled;
  final bool showBanner;
  final String bannerText;
  final bool menusEnabled;
  final bool menuRequired;
  final List<Map<String, dynamic>> menus;
  final List<Map<String, dynamic>> customFields;
  final Map<String, dynamic> registrationConfig;
  final Map<String, dynamic> pricingConfig;
  final Map<String, dynamic> companionConfig;
  final Map<String, dynamic> paymentConfig;
  final Map<String, dynamic> notificationConfig;
  final Map<String, dynamic> popupConfig;
  final String coverImagePath;
  final String coverImageUrl;
  final bool deleted;
  final DateTime? deletedAt;
  final String deletedBy;
  final String deleteReason;
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
    this.memberAdultPrice = 0,
    this.memberChildPrice = 0,
    this.guestAdultPrice = 0,
    this.guestChildPrice = 0,
    this.protocolAdultPrice = 0,
    this.protocolChildPrice = 0,
    this.realAdultMenuCost = 0,
    this.realChildMenuCost = 0,
    this.palmMemberPrice = 0,
    this.palmExternalPrice = 0,
    this.realPalmCost = 0,
    this.paymentMethods = const [],
    this.allergiesEnabled = false,
    this.observationsEnabled = true,
    this.showBanner = true,
    this.bannerText = '',
    this.menusEnabled = false,
    this.menuRequired = false,
    this.menus = const [],
    this.customFields = const [],
    this.registrationConfig = const {},
    this.pricingConfig = const {},
    this.companionConfig = const {},
    this.paymentConfig = const {},
    this.notificationConfig = const {},
    this.popupConfig = const {},
    this.coverImagePath = '',
    this.coverImageUrl = '',
    this.deleted = false,
    this.deletedAt,
    this.deletedBy = '',
    this.deleteReason = '',
    this.createdAt,
  });

  bool get isOpen {
    final now = DateTime.now();
    final afterStart = startDate == null || !now.isBefore(startDate!);
    final beforeEnd = endDate == null || !now.isAfter(endDate!);
    return (active || status == 'open') && afterStart && beforeEnd;
  }

  bool get isVisibleToCofrade =>
      active ||
      status == 'published' ||
      status == 'open' ||
      status == 'closed' ||
      published;

  bool get isHistorical => status == 'finished' || status == 'archived';

  bool get isUpcoming =>
      status == 'published' ||
      (eventDate != null && eventDate!.isAfter(DateTime.now()));

  bool get isAfterEventDay {
    if (eventDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay =
        DateTime(eventDate!.year, eventDate!.month, eventDate!.day);
    return today.isAfter(eventDay);
  }

  factory EventCampaign.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EventCampaign(
      id: doc.id,
      type: data['type'] ?? data['eventType'] ?? '',
      year: (data['year'] as num?)?.toInt() ?? DateTime.now().year,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      startDate: _date(data['startDate']) ?? _date(data['registrationOpenAt']),
      endDate: _date(data['endDate']) ?? _date(data['registrationCloseAt']),
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
      eventDate: _date(data['eventDate']) ??
          _date(data['startsAt']) ??
          _date(data['processionDate']),
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
      memberAdultPrice: (data['memberAdultPrice'] as num?)?.toDouble() ??
          (data['memberPrice'] as num?)?.toDouble() ??
          5,
      memberChildPrice: (data['memberChildPrice'] as num?)?.toDouble() ??
          (data['childPrice'] as num?)?.toDouble() ??
          5,
      guestAdultPrice: (data['guestAdultPrice'] as num?)?.toDouble() ??
          (data['guestPrice'] as num?)?.toDouble() ??
          27,
      guestChildPrice: (data['guestChildPrice'] as num?)?.toDouble() ??
          (data['childPrice'] as num?)?.toDouble() ??
          15,
      protocolAdultPrice: (data['protocolAdultPrice'] as num?)?.toDouble() ?? 0,
      protocolChildPrice: (data['protocolChildPrice'] as num?)?.toDouble() ?? 0,
      realAdultMenuCost: (data['realAdultMenuCost'] as num?)?.toDouble() ??
          (data['realMenuAdultCost'] as num?)?.toDouble() ??
          27,
      realChildMenuCost: (data['realChildMenuCost'] as num?)?.toDouble() ??
          (data['realMenuChildCost'] as num?)?.toDouble() ??
          15,
      palmMemberPrice: (data['palmMemberPrice'] as num?)?.toDouble() ??
          ((data['pricingConfig'] is Map)
              ? ((data['pricingConfig']['palmMemberPrice'] as num?)
                      ?.toDouble() ??
                  (data['pricingConfig']['memberPrice'] as num?)?.toDouble())
              : null) ??
          (data['memberPrice'] as num?)?.toDouble() ??
          0,
      palmExternalPrice: (data['palmExternalPrice'] as num?)?.toDouble() ??
          ((data['pricingConfig'] is Map)
              ? ((data['pricingConfig']['palmExternalPrice'] as num?)
                      ?.toDouble() ??
                  (data['pricingConfig']['guestPrice'] as num?)?.toDouble())
              : null) ??
          (data['guestPrice'] as num?)?.toDouble() ??
          0,
      realPalmCost: (data['realPalmCost'] as num?)?.toDouble() ??
          ((data['pricingConfig'] is Map)
              ? ((data['pricingConfig']['realPalmCost'] as num?)?.toDouble() ??
                  (data['pricingConfig']['realAdultMenuCost'] as num?)
                      ?.toDouble())
              : null) ??
          (data['realAdultMenuCost'] as num?)?.toDouble() ??
          (data['cost'] as num?)?.toDouble() ??
          0,
      paymentMethods: (data['paymentMethods'] as List<dynamic>? ?? [])
          .map((item) => '$item')
          .toList(),
      allergiesEnabled: data['allergiesEnabled'] ?? false,
      observationsEnabled: data['observationsEnabled'] ?? true,
      showBanner: data['showBanner'] ?? true,
      bannerText: data['bannerText'] ?? '',
      menusEnabled: data['menusEnabled'] ?? data['menus_enabled'] ?? false,
      menuRequired: data['menuRequired'] ?? data['menu_required'] ?? false,
      menus: (data['menus'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
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
      popupConfig: Map<String, dynamic>.from(data['popupConfig'] ?? const {}),
      coverImagePath: data['coverImagePath'] ?? '',
      coverImageUrl: data['coverImageUrl'] ?? '',
      deleted: data['deleted'] == true,
      deletedAt: _date(data['deletedAt']),
      deletedBy: data['deletedBy'] ?? '',
      deleteReason: data['deleteReason'] ?? '',
      createdAt: _date(data['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    final registrationOpen =
        startDate != null ? Timestamp.fromDate(startDate!) : null;
    final registrationClose =
        endDate != null ? Timestamp.fromDate(endDate!) : null;
    final eventTimestamp =
        eventDate != null ? Timestamp.fromDate(eventDate!) : null;
    final payload = {
      'type': type,
      'year': year,
      'name': name,
      'title': name,
      'description': description,
      'startDate': registrationOpen,
      'startsAt': eventTimestamp ?? registrationOpen,
      'endDate': registrationClose,
      'endsAt': eventTimestamp ?? registrationClose,
      'registrationOpenAt': registrationOpen,
      'registrationCloseAt': registrationClose,
      'processionDate':
          processionDate != null ? Timestamp.fromDate(processionDate!) : null,
      'contactPhone': contactPhone,
      'rules': rules,
      'cost': cost,
      'active': active,
      'published': published,
      'privateAreaVisible': published || active || status != 'draft',
      'visibility':
          published || active || status != 'draft' ? 'private' : 'admin_only',
      'turns': turns,
      'status': status,
      'location': location,
      'eventDate': eventTimestamp,
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
      'memberAdultPrice': memberAdultPrice,
      'memberChildPrice': memberChildPrice,
      'guestAdultPrice': guestAdultPrice,
      'guestChildPrice': guestChildPrice,
      'protocolAdultPrice': protocolAdultPrice,
      'protocolChildPrice': protocolChildPrice,
      'realAdultMenuCost': realAdultMenuCost,
      'realChildMenuCost': realChildMenuCost,
      'palmMemberPrice': palmMemberPrice,
      'palmExternalPrice': palmExternalPrice,
      'realPalmCost': realPalmCost,
      'paymentMethods': paymentMethods,
      'allergiesEnabled': allergiesEnabled,
      'observationsEnabled': observationsEnabled,
      'showBanner': showBanner,
      'bannerText': bannerText,
      'menusEnabled': menusEnabled,
      'menuRequired': menuRequired,
      'menus': menus,
      'customFields': customFields,
      'registrationConfig': registrationConfig,
      'pricingConfig': pricingConfig,
      'companionConfig': companionConfig,
      'paymentConfig': paymentConfig,
      'notificationConfig': notificationConfig,
      'popupConfig': popupConfig,
      'coverImagePath': coverImagePath,
      'coverImageUrl': coverImageUrl,
      'deleted': deleted,
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
      'deletedBy': deletedBy,
      'deleteReason': deleteReason,
      'updatedAt': FieldValue.serverTimestamp(),
      if (id.isEmpty) 'createdAt': FieldValue.serverTimestamp(),
    };
    return Map<String, dynamic>.from(_cleanFirestoreValue(payload) as Map);
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
  final double paidAmount;
  final String paymentNotes;
  final Map<String, dynamic> answers;
  final List<Map<String, dynamic>> delegatedVotes;
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
    this.paidAmount = 0,
    this.paymentNotes = '',
    this.answers = const {},
    this.delegatedVotes = const [],
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
      paidAmount: (data['paidAmount'] as num?)?.toDouble() ??
          (data['paid_amount'] as num?)?.toDouble() ??
          0,
      paymentNotes: data['paymentNotes'] ?? data['payment_notes'] ?? '',
      answers: Map<String, dynamic>.from(data['answers'] ?? const {}),
      delegatedVotes: (data['delegatedVotes'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
    );
  }
}
