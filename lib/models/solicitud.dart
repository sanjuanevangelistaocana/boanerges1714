import 'package:cloud_firestore/cloud_firestore.dart';

class Solicitud {
  final String id;
  final String nombre;
  final String apellidos;
  final String email;
  final String? telefono;
  final String? domicilio;
  final String? localidad;
  final String? codigoPostal;
  final DateTime? fechaNacimiento;
  final String? genero;
  final String? dni;
  final String? motivacion;
  final bool requiresDigitalTutor;
  final String? digitalTutorName;
  final String? digitalTutorDni;
  final String? digitalTutorPhone;
  final String? digitalTutorEmail;
  final String? digitalTutorRelationship;
  final String estado; // pendiente, aprobada, rechazada
  final DateTime fechaSolicitud;
  final String? motivoRechazo;
  final String? aprobadaPor;
  final DateTime? fechaResolucion;

  Solicitud({
    required this.id,
    required this.nombre,
    required this.apellidos,
    required this.email,
    this.telefono,
    this.domicilio,
    this.localidad,
    this.codigoPostal,
    this.fechaNacimiento,
    this.genero,
    this.dni,
    this.motivacion,
    this.requiresDigitalTutor = false,
    this.digitalTutorName,
    this.digitalTutorDni,
    this.digitalTutorPhone,
    this.digitalTutorEmail,
    this.digitalTutorRelationship,
    this.estado = 'pendiente',
    required this.fechaSolicitud,
    this.motivoRechazo,
    this.aprobadaPor,
    this.fechaResolucion,
  });

  String get nombreCompleto => '$nombre $apellidos';

  bool get isPendiente => estado == 'pendiente';
  bool get isAprobada => estado == 'aprobada';
  bool get isRechazada => estado == 'rechazada';

  factory Solicitud.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Solicitud(
      id: doc.id,
      nombre: data['nombre'] ?? '',
      apellidos: data['apellidos'] ?? '',
      email: data['email'] ?? '',
      telefono: data['telefono'] as String?,
      domicilio: data['domicilio'] as String?,
      localidad: data['localidad'] as String?,
      codigoPostal: data['codigo_postal'] as String?,
      fechaNacimiento: (data['fecha_nacimiento'] as Timestamp?)?.toDate(),
      genero: data['genero'] as String?,
      dni: data['dni'] as String?,
      motivacion: data['motivacion'] as String?,
      requiresDigitalTutor: data['requiresDigitalTutor'] == true ||
          data['tutelado_digital'] == true,
      digitalTutorName: data['digitalTutorName'] as String?,
      digitalTutorDni: data['digitalTutorDni'] as String?,
      digitalTutorPhone: data['digitalTutorPhone'] as String?,
      digitalTutorEmail: data['digitalTutorEmail'] as String?,
      digitalTutorRelationship: data['digitalTutorRelationship'] as String?,
      estado: data['estado'] ?? 'pendiente',
      fechaSolicitud:
          (data['fecha_solicitud'] as Timestamp?)?.toDate() ?? DateTime.now(),
      motivoRechazo: data['motivo_rechazo'] as String?,
      aprobadaPor: data['aprobada_por'] as String?,
      fechaResolucion: (data['fecha_resolucion'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'nombre': nombre,
      'apellidos': apellidos,
      'email': email,
      'telefono': telefono,
      'domicilio': domicilio,
      'localidad': localidad,
      'codigo_postal': codigoPostal,
      'fecha_nacimiento':
          fechaNacimiento != null ? Timestamp.fromDate(fechaNacimiento!) : null,
      'genero': genero,
      'dni': dni,
      'motivacion': motivacion,
      'requiresDigitalTutor': requiresDigitalTutor,
      'tutelado_digital': requiresDigitalTutor,
      'digitalTutorName': digitalTutorName,
      'digitalTutorDni': digitalTutorDni,
      'digitalTutorPhone': digitalTutorPhone,
      'digitalTutorEmail': digitalTutorEmail,
      'digitalTutorRelationship': digitalTutorRelationship,
      'estado': estado,
      'fecha_solicitud': Timestamp.fromDate(fechaSolicitud),
      'motivo_rechazo': motivoRechazo,
      'aprobada_por': aprobadaPor,
      'fecha_resolucion':
          fechaResolucion != null ? Timestamp.fromDate(fechaResolucion!) : null,
    };
  }
}
