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
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
    );
  }
}
