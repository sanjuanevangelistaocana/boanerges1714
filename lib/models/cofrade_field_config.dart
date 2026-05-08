import 'package:cloud_firestore/cloud_firestore.dart';

class CofradeFieldConfig {
  final String id;
  final String fieldKey;
  final String label;
  final String type;
  final bool required;
  final bool editableByAdmin;
  final bool editableByCofrade;
  final bool visibleInPrivateProfile;
  final bool visibleInAdmin;
  final List<String> options;
  final bool active;
  final int order;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CofradeFieldConfig({
    required this.id,
    required this.fieldKey,
    required this.label,
    this.type = 'string',
    this.required = false,
    this.editableByAdmin = true,
    this.editableByCofrade = true,
    this.visibleInPrivateProfile = true,
    this.visibleInAdmin = true,
    this.options = const [],
    this.active = true,
    this.order = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory CofradeFieldConfig.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CofradeFieldConfig(
      id: doc.id,
      fieldKey: data['field_key'] ?? doc.id,
      label: data['label'] ?? data['field_key'] ?? doc.id,
      type: data['type'] ?? 'string',
      required: data['required'] == true,
      editableByAdmin: data['editable_by_admin'] != false,
      editableByCofrade: data['editable_by_cofrade'] != false,
      visibleInPrivateProfile: data['visible_in_private_profile'] != false,
      visibleInAdmin: data['visible_in_admin'] != false,
      options:
          (data['options'] as List<dynamic>? ?? []).map((e) => '$e').toList(),
      active: data['active'] != false,
      order: (data['order'] as num?)?.toInt() ?? 0,
      createdAt: (data['created_at'] as Timestamp?)?.toDate(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'field_key': fieldKey,
      'label': label,
      'type': type,
      'required': required,
      'editable_by_admin': editableByAdmin,
      'editable_by_cofrade': editableByCofrade,
      'visible_in_private_profile': visibleInPrivateProfile,
      'visible_in_admin': visibleInAdmin,
      'options': options,
      'active': active,
      'order': order,
      if (id.isEmpty) 'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }
}
