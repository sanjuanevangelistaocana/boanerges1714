import 'package:cloud_firestore/cloud_firestore.dart';

class Cofrade {
  final String id;
  final String nombre;
  final String apellidos;
  final String email;
  final String telefono;
  final String direccion;
  final String localidad;
  final String codigoPostal;
  final DateTime? fechaIngreso;
  final String cargo;
  final String estado;
  final String? fotoUrl;
  final String rol;
  final DateTime? fechaCreacion;
  final DateTime? fechaActualizacion;

  Cofrade({
    required this.id,
    required this.nombre,
    required this.apellidos,
    required this.email,
    this.telefono = '',
    this.direccion = '',
    this.localidad = 'Ocaña',
    this.codigoPostal = '',
    this.fechaIngreso,
    this.cargo = 'Cofrade',
    this.estado = 'activo',
    this.fotoUrl,
    this.rol = 'cofrade',
    this.fechaCreacion,
    this.fechaActualizacion,
  });

  factory Cofrade.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Cofrade(
      id: doc.id,
      nombre: data['nombre'] ?? '',
      apellidos: data['apellidos'] ?? '',
      email: data['email'] ?? '',
      telefono: data['telefono'] ?? '',
      direccion: data['direccion'] ?? '',
      localidad: data['localidad'] ?? 'Ocaña',
      codigoPostal: data['codigo_postal'] ?? '',
      fechaIngreso: (data['fecha_ingreso'] as Timestamp?)?.toDate(),
      cargo: data['cargo'] ?? 'Cofrade',
      estado: data['estado'] ?? 'activo',
      fotoUrl: data['foto_url'],
      rol: data['rol'] ?? 'cofrade',
      fechaCreacion: (data['fecha_creacion'] as Timestamp?)?.toDate(),
      fechaActualizacion: (data['fecha_actualizacion'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'nombre': nombre,
      'apellidos': apellidos,
      'email': email,
      'telefono': telefono,
      'direccion': direccion,
      'localidad': localidad,
      'codigo_postal': codigoPostal,
      'fecha_ingreso': fechaIngreso != null ? Timestamp.fromDate(fechaIngreso!) : null,
      'cargo': cargo,
      'estado': estado,
      'foto_url': fotoUrl,
      'rol': rol,
      'fecha_creacion': fechaCreacion != null ? Timestamp.fromDate(fechaCreacion!) : FieldValue.serverTimestamp(),
      'fecha_actualizacion': FieldValue.serverTimestamp(),
    };
  }

  Cofrade copyWith({
    String? nombre,
    String? apellidos,
    String? email,
    String? telefono,
    String? direccion,
    String? localidad,
    String? codigoPostal,
    DateTime? fechaIngreso,
    String? cargo,
    String? estado,
    String? fotoUrl,
    String? rol,
  }) {
    return Cofrade(
      id: id,
      nombre: nombre ?? this.nombre,
      apellidos: apellidos ?? this.apellidos,
      email: email ?? this.email,
      telefono: telefono ?? this.telefono,
      direccion: direccion ?? this.direccion,
      localidad: localidad ?? this.localidad,
      codigoPostal: codigoPostal ?? this.codigoPostal,
      fechaIngreso: fechaIngreso ?? this.fechaIngreso,
      cargo: cargo ?? this.cargo,
      estado: estado ?? this.estado,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      rol: rol ?? this.rol,
      fechaCreacion: fechaCreacion,
      fechaActualizacion: fechaActualizacion,
    );
  }

  String get nombreCompleto => '$nombre $apellidos';

  bool get isAdmin => rol == 'admin';
  bool get isActivo => estado == 'activo';
}
