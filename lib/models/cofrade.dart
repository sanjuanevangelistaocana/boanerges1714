import 'package:cloud_firestore/cloud_firestore.dart';

class Cofrade {
  final String id;
  final int? numero;
  final String nombre;
  final String apellidos;
  final String? tuteladoDigital;
  final DateTime? fechaNacimiento;
  final int? edad;
  final String? genero;
  final int? anioAlta;
  final int? aniosHermandad;
  final int? anioMayordomia;
  final String estado;
  final DateTime? fechaBaja;
  final String? causaBaja;
  final String domicilio;
  final String localidad;
  final String codigoPostal;
  final String telefonoFijo;
  final String telefonoMovil;
  final String email;
  final int? estatura;
  final String? talla;
  final bool tieneCuota;
  final double? cuotaMetalico;
  final double? cuotaDomiciliada;
  final String? iban;
  final String? titularIban;
  final bool gdprFirmado;
  final String? comentarios;
  final String? fotoUrl;
  final String rol;
  final DateTime? fechaCreacion;
  final DateTime? fechaActualizacion;

  Cofrade({
    required this.id,
    this.numero,
    required this.nombre,
    required this.apellidos,
    this.tuteladoDigital,
    this.fechaNacimiento,
    this.edad,
    this.genero,
    this.anioAlta,
    this.aniosHermandad,
    this.anioMayordomia,
    this.estado = 'Activo',
    this.fechaBaja,
    this.causaBaja,
    this.domicilio = '',
    this.localidad = 'Ocaña',
    this.codigoPostal = '',
    this.telefonoFijo = '',
    this.telefonoMovil = '',
    this.email = '',
    this.estatura,
    this.talla,
    this.tieneCuota = false,
    this.cuotaMetalico,
    this.cuotaDomiciliada,
    this.iban,
    this.titularIban,
    this.gdprFirmado = false,
    this.comentarios,
    this.fotoUrl,
    this.rol = 'cofrade',
    this.fechaCreacion,
    this.fechaActualizacion,
  });

  factory Cofrade.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Cofrade(
      id: doc.id,
      numero: data['numero'] as int?,
      nombre: data['nombre'] ?? '',
      apellidos: data['apellidos'] ?? '',
      tuteladoDigital: data['tutelado_digital'] as String?,
      fechaNacimiento: (data['fecha_nacimiento'] as Timestamp?)?.toDate(),
      edad: data['edad'] as int?,
      genero: data['genero'] as String?,
      anioAlta: data['anio_alta'] as int?,
      aniosHermandad: data['anios_hermandad'] as int?,
      anioMayordomia: data['anio_mayordomia'] as int?,
      estado: data['estado'] ?? 'Activo',
      fechaBaja: (data['fecha_baja'] as Timestamp?)?.toDate(),
      causaBaja: data['causa_baja'] as String?,
      domicilio: data['domicilio'] ?? '',
      localidad: data['localidad'] ?? 'Ocaña',
      codigoPostal: data['codigo_postal'] ?? '',
      telefonoFijo: data['telefono_fijo'] ?? '',
      telefonoMovil: data['telefono_movil'] ?? '',
      email: data['email'] ?? '',
      estatura: data['estatura'] as int?,
      talla: data['talla'] as String?,
      tieneCuota: data['tiene_cuota'] ?? false,
      cuotaMetalico: (data['cuota_metalico'] as num?)?.toDouble(),
      cuotaDomiciliada: (data['cuota_domiciliada'] as num?)?.toDouble(),
      iban: data['iban'] as String?,
      titularIban: data['titular_iban'] as String?,
      gdprFirmado: data['gdpr_firmado'] ?? false,
      comentarios: data['comentarios'] as String?,
      fotoUrl: data['foto_url'] as String?,
      rol: data['rol'] ?? 'cofrade',
      fechaCreacion: (data['fecha_creacion'] as Timestamp?)?.toDate(),
      fechaActualizacion: (data['fecha_actualizacion'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'numero': numero,
      'nombre': nombre,
      'apellidos': apellidos,
      'tutelado_digital': tuteladoDigital,
      'fecha_nacimiento': fechaNacimiento != null
          ? Timestamp.fromDate(fechaNacimiento!)
          : null,
      'edad': edad,
      'genero': genero,
      'anio_alta': anioAlta,
      'anios_hermandad': aniosHermandad,
      'anio_mayordomia': anioMayordomia,
      'estado': estado,
      'fecha_baja': fechaBaja != null ? Timestamp.fromDate(fechaBaja!) : null,
      'causa_baja': causaBaja,
      'domicilio': domicilio,
      'localidad': localidad,
      'codigo_postal': codigoPostal,
      'telefono_fijo': telefonoFijo,
      'telefono_movil': telefonoMovil,
      'email': email,
      'estatura': estatura,
      'talla': talla,
      'tiene_cuota': tieneCuota,
      'cuota_metalico': cuotaMetalico,
      'cuota_domiciliada': cuotaDomiciliada,
      'iban': iban,
      'titular_iban': titularIban,
      'gdpr_firmado': gdprFirmado,
      'comentarios': comentarios,
      'foto_url': fotoUrl,
      'rol': rol,
      'fecha_creacion': fechaCreacion != null
          ? Timestamp.fromDate(fechaCreacion!)
          : FieldValue.serverTimestamp(),
      'fecha_actualizacion': FieldValue.serverTimestamp(),
    };
  }

  Cofrade copyWith({
    int? numero,
    String? nombre,
    String? apellidos,
    String? tuteladoDigital,
    DateTime? fechaNacimiento,
    int? edad,
    String? genero,
    int? anioAlta,
    int? aniosHermandad,
    int? anioMayordomia,
    String? estado,
    DateTime? fechaBaja,
    String? causaBaja,
    String? domicilio,
    String? localidad,
    String? codigoPostal,
    String? telefonoFijo,
    String? telefonoMovil,
    String? email,
    int? estatura,
    String? talla,
    bool? tieneCuota,
    double? cuotaMetalico,
    double? cuotaDomiciliada,
    String? iban,
    String? titularIban,
    bool? gdprFirmado,
    String? comentarios,
    String? fotoUrl,
    String? rol,
  }) {
    return Cofrade(
      id: id,
      numero: numero ?? this.numero,
      nombre: nombre ?? this.nombre,
      apellidos: apellidos ?? this.apellidos,
      tuteladoDigital: tuteladoDigital ?? this.tuteladoDigital,
      fechaNacimiento: fechaNacimiento ?? this.fechaNacimiento,
      edad: edad ?? this.edad,
      genero: genero ?? this.genero,
      anioAlta: anioAlta ?? this.anioAlta,
      aniosHermandad: aniosHermandad ?? this.aniosHermandad,
      anioMayordomia: anioMayordomia ?? this.anioMayordomia,
      estado: estado ?? this.estado,
      fechaBaja: fechaBaja ?? this.fechaBaja,
      causaBaja: causaBaja ?? this.causaBaja,
      domicilio: domicilio ?? this.domicilio,
      localidad: localidad ?? this.localidad,
      codigoPostal: codigoPostal ?? this.codigoPostal,
      telefonoFijo: telefonoFijo ?? this.telefonoFijo,
      telefonoMovil: telefonoMovil ?? this.telefonoMovil,
      email: email ?? this.email,
      estatura: estatura ?? this.estatura,
      talla: talla ?? this.talla,
      tieneCuota: tieneCuota ?? this.tieneCuota,
      cuotaMetalico: cuotaMetalico ?? this.cuotaMetalico,
      cuotaDomiciliada: cuotaDomiciliada ?? this.cuotaDomiciliada,
      iban: iban ?? this.iban,
      titularIban: titularIban ?? this.titularIban,
      gdprFirmado: gdprFirmado ?? this.gdprFirmado,
      comentarios: comentarios ?? this.comentarios,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      rol: rol ?? this.rol,
      fechaCreacion: fechaCreacion,
      fechaActualizacion: fechaActualizacion,
    );
  }

  String get nombreCompleto => '$nombre $apellidos';
  bool get isAdmin => rol == 'admin';
  bool get isActivo => estado == 'Activo' || estado == 'activo';
  bool get isBaja => estado == 'Baja' || estado == 'baja';
}
