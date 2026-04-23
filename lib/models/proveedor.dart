import 'package:cloud_firestore/cloud_firestore.dart';

class Proveedor {
  final String id;
  final String nombre;
  final String telefono;
  final String email;
  final String direccion;
  final String descripcion;
  final String web;
  final String precios;
  final bool activo;
  final DateTime fechaCreacion;

  Proveedor({
    required this.id,
    required this.nombre,
    this.telefono = '',
    this.email = '',
    this.direccion = '',
    this.descripcion = '',
    this.web = '',
    this.precios = '',
    this.activo = true,
    required this.fechaCreacion,
  });

  factory Proveedor.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Proveedor(
      id: doc.id,
      nombre: data['nombre'] ?? '',
      telefono: data['telefono'] ?? '',
      email: data['email'] ?? '',
      direccion: data['direccion'] ?? '',
      descripcion: data['descripcion'] ?? '',
      web: data['web'] ?? '',
      precios: data['precios'] ?? '',
      activo: data['activo'] ?? true,
      fechaCreacion: (data['fecha_creacion'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'nombre': nombre,
      'telefono': telefono,
      'email': email,
      'direccion': direccion,
      'descripcion': descripcion,
      'web': web,
      'precios': precios,
      'activo': activo,
      'fecha_creacion': Timestamp.fromDate(fechaCreacion),
    };
  }
}
