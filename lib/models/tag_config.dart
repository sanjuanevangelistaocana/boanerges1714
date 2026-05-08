import 'package:cloud_firestore/cloud_firestore.dart';

class TagConfig {
  final String id;
  final String nombre;
  final String descripcion;
  final String tipo;
  final String color;
  final bool activo;
  final bool showInPrivateProfile;
  final Map<String, dynamic> criterio;
  final DateTime? fechaCreacion;
  final DateTime? fechaActualizacion;

  const TagConfig({
    required this.id,
    required this.nombre,
    this.descripcion = '',
    this.tipo = 'manual',
    this.color = '#607D8B',
    this.activo = true,
    this.showInPrivateProfile = false,
    this.criterio = const {},
    this.fechaCreacion,
    this.fechaActualizacion,
  });

  factory TagConfig.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TagConfig(
      id: doc.id,
      nombre: data['nombre'] ?? '',
      descripcion: data['descripcion'] ?? '',
      tipo: data['tipo'] ?? 'manual',
      color: data['color'] ?? '#607D8B',
      activo: data['activo'] ?? true,
      showInPrivateProfile: data['showInPrivateProfile'] == true ||
          data['show_in_private_profile'] == true,
      criterio: (data['criterio'] as Map?)?.cast<String, dynamic>() ?? {},
      fechaCreacion: (data['fecha_creacion'] as Timestamp?)?.toDate(),
      fechaActualizacion: (data['fecha_actualizacion'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      if (id.isNotEmpty) 'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'tipo': tipo,
      'color': color,
      'activo': activo,
      'showInPrivateProfile': showInPrivateProfile,
      'criterio': criterio,
      'fecha_actualizacion': FieldValue.serverTimestamp(),
      if (id.isEmpty) 'fecha_creacion': FieldValue.serverTimestamp(),
    };
  }
}
