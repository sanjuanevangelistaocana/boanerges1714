import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boanerges1714/utils/madrid_date.dart';

class Cofrade {
  final String id;
  final int? numero;
  final int? numeroAnterior;
  final String nombre;
  final String apellidos;
  final String? tuteladoDigital;
  final DateTime? fechaNacimiento;
  final String fechaNacimientoStr;
  final int? edad;
  final String? genero;
  final int? anioAlta;
  final int? aniosHermandad;
  final int? anioMayordomia;
  final String estado;
  final DateTime? fechaBaja;
  final String fechaBajaStr;
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
  final bool cuotaMetalico;
  final bool cuotaDomiciliada;
  final String? iban;
  final String? titularIban;
  final bool gdprFirmado;
  final bool gdprPapel;
  final String? comentarios;
  final String? fotoUrl;
  final String rol;
  final DateTime? fechaCreacion;
  final DateTime? fechaActualizacion;
  // New fields: account management
  final String? authUid;
  final DateTime? fechaRegistroApp;
  final DateTime? ultimoAcceso;
  // GDPR dual: paper + digital
  final bool gdprFirmadoDigital;
  final DateTime? fechaGdprDigital;
  final bool gdprDigitalAccepted;
  final DateTime? gdprDigitalAcceptedAt;
  final String? gdprDigitalConsentVersion;
  final String? gdprDigitalConsentHash;
  final bool gdprDigitalRevoked;
  final DateTime? gdprDigitalRevokedAt;
  final String gdprDigitalStatus;
  final bool gdprDigitalReacceptanceRequired;
  final DateTime? reactivatedAt;
  final String? reactivatedBy;
  // Communication
  final String? fcmToken;
  final bool notificacionesActivas;
  final bool cumpleanosVisible;
  final String? emailSecundario;
  final String? telefonoSecundario;
  // Profile extras
  final String? dni;
  final DateTime? fechaNacimientoTutor;
  final String? dniTutor;
  final String? parentescoTutor;
  final bool requiresDigitalTutor;
  final String digitalTutorEmail;
  final String digitalTutorDni;
  final String digitalTutorName;
  final String digitalTutorRelationship;
  final String digitalTutorPhone;
  final bool digitalTutorConsentAccepted;
  final DateTime? digitalTutorConsentAcceptedAt;
  // Cofradía
  final String? cargo;
  final bool tieneTunicaPropia;
  final List<String> tagsManual;
  final List<String> tagsAuto;
  final List<String> roles;
  final bool esCuentaServicio;
  final Map<String, dynamic> adminPermissions;
  final String status;
  final bool isActive;
  final DateTime? bajaAt;
  final String? bajaReason;
  final String? bajaBy;
  final bool cuotaActiva;
  final bool hasPendingProfileReview;
  final DateTime? lastProfileChangeAt;
  final String? lastProfileChangeBy;
  final DateTime? profileReviewedAt;
  final String? profileReviewedBy;
  final Map<String, dynamic> rawData;

  Cofrade({
    required this.id,
    this.numero,
    this.numeroAnterior,
    required this.nombre,
    required this.apellidos,
    this.tuteladoDigital,
    this.fechaNacimiento,
    this.fechaNacimientoStr = '',
    this.edad,
    this.genero,
    this.anioAlta,
    this.aniosHermandad,
    this.anioMayordomia,
    this.estado = 'Activo',
    this.fechaBaja,
    this.fechaBajaStr = '',
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
    this.cuotaMetalico = false,
    this.cuotaDomiciliada = false,
    this.iban,
    this.titularIban,
    this.gdprFirmado = false,
    this.gdprPapel = false,
    this.comentarios,
    this.fotoUrl,
    this.rol = 'cofrade',
    this.fechaCreacion,
    this.fechaActualizacion,
    this.authUid,
    this.fechaRegistroApp,
    this.ultimoAcceso,
    this.gdprFirmadoDigital = false,
    this.fechaGdprDigital,
    this.gdprDigitalAccepted = false,
    this.gdprDigitalAcceptedAt,
    this.gdprDigitalConsentVersion,
    this.gdprDigitalConsentHash,
    this.gdprDigitalRevoked = false,
    this.gdprDigitalRevokedAt,
    this.gdprDigitalStatus = 'accepted',
    this.gdprDigitalReacceptanceRequired = false,
    this.reactivatedAt,
    this.reactivatedBy,
    this.fcmToken,
    this.notificacionesActivas = true,
    this.cumpleanosVisible = true,
    this.emailSecundario,
    this.telefonoSecundario,
    this.dni,
    this.fechaNacimientoTutor,
    this.dniTutor,
    this.parentescoTutor,
    this.requiresDigitalTutor = false,
    this.digitalTutorEmail = '',
    this.digitalTutorDni = '',
    this.digitalTutorName = '',
    this.digitalTutorRelationship = '',
    this.digitalTutorPhone = '',
    this.digitalTutorConsentAccepted = false,
    this.digitalTutorConsentAcceptedAt,
    this.cargo,
    this.tieneTunicaPropia = false,
    this.tagsManual = const [],
    this.tagsAuto = const [],
    this.roles = const [],
    this.esCuentaServicio = false,
    this.adminPermissions = const {},
    this.status = 'active',
    this.isActive = true,
    this.bajaAt,
    this.bajaReason,
    this.bajaBy,
    this.cuotaActiva = true,
    this.hasPendingProfileReview = false,
    this.lastProfileChangeAt,
    this.lastProfileChangeBy,
    this.profileReviewedAt,
    this.profileReviewedBy,
    this.rawData = const {},
  });

  factory Cofrade.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final birthDate = parseBirthDate(data['fecha_nacimiento']) ??
        parseBirthDate(data['fecha_nacimiento_str']);
    return Cofrade(
      id: doc.id,
      numero: (data['numero'] as num?)?.toInt(),
      numeroAnterior: (data['numero_anterior'] as num?)?.toInt(),
      nombre: data['nombre'] ?? '',
      apellidos: data['apellidos'] ?? '',
      tuteladoDigital: _parseLegacyTutorValue(data['tutelado_digital'])
          ? '${data['digitalTutorEmail'] ?? data['tutelado_digital'] ?? ''}'
          : '',
      fechaNacimiento: birthDate,
      fechaNacimientoStr:
          birthDateString(birthDate) ?? '${data['fecha_nacimiento_str'] ?? ''}',
      edad: (data['edad'] as num?)?.toInt(),
      genero: data['genero'] as String?,
      anioAlta: (data['anio_alta'] as num?)?.toInt(),
      aniosHermandad: (data['anios_hermandad'] as num?)?.toInt(),
      anioMayordomia: (data['anio_mayordomia'] as num?)?.toInt(),
      estado: data['estado'] ?? 'Activo',
      fechaBaja: (data['fecha_baja'] as Timestamp?)?.toDate(),
      fechaBajaStr: data['fecha_baja_str'] ?? '',
      causaBaja: data['causa_baja'] as String?,
      domicilio: data['domicilio'] ?? '',
      localidad: data['localidad'] ?? 'Ocaña',
      codigoPostal: data['codigo_postal'] ?? '',
      telefonoFijo: data['telefono_fijo'] ?? '',
      telefonoMovil: data['telefono_movil'] ?? '',
      email: data['email'] ?? '',
      estatura: (data['estatura'] as num?)?.toInt(),
      talla: data['talla'] as String?,
      tieneCuota: data['tiene_cuota'] ?? false,
      cuotaMetalico: data['cuota_metalico'] == true,
      cuotaDomiciliada: data['cuota_domiciliada'] == true,
      iban: data['iban'] as String?,
      titularIban: data['titular_iban'] as String?,
      gdprFirmado: data['gdpr_firmado'] ?? false,
      gdprPapel: data['gdpr_papel'] == true ||
          data['gdprPapel'] == true ||
          data['gdprFirmadoPapel'] == true,
      comentarios: data['comentarios'] as String?,
      fotoUrl: data['foto_url'] as String?,
      rol: data['rol'] ?? data['role'] ?? 'cofrade',
      fechaCreacion: (data['fecha_creacion'] as Timestamp?)?.toDate(),
      fechaActualizacion: (data['fecha_actualizacion'] as Timestamp?)?.toDate(),
      authUid: (data['auth_uid'] ?? data['authUid']) as String?,
      fechaRegistroApp: (data['fecha_registro_app'] as Timestamp?)?.toDate(),
      ultimoAcceso: (data['ultimo_acceso'] as Timestamp?)?.toDate(),
      gdprFirmadoDigital: data['gdpr_firmado_digital'] ?? false,
      fechaGdprDigital: (data['fecha_gdpr_digital'] as Timestamp?)?.toDate(),
      gdprDigitalAccepted: data['gdprDigitalAccepted'] == true ||
          data['gdpr_digital_accepted'] == true ||
          data['gdpr_firmado_digital'] == true,
      gdprDigitalAcceptedAt:
          (data['gdprDigitalAcceptedAt'] as Timestamp?)?.toDate() ??
              (data['gdpr_digital_accepted_at'] as Timestamp?)?.toDate(),
      gdprDigitalConsentVersion: data['gdprDigitalConsentVersion'] ??
          data['gdpr_digital_consent_version'],
      gdprDigitalConsentHash:
          data['gdprDigitalConsentHash'] ?? data['gdpr_digital_consent_hash'],
      gdprDigitalRevoked: data['gdprDigitalRevoked'] == true ||
          data['gdpr_digital_revoked'] == true ||
          data['gdprDigitalStatus'] == 'revoked',
      gdprDigitalRevokedAt:
          (data['gdprDigitalRevokedAt'] as Timestamp?)?.toDate() ??
              (data['gdpr_digital_revoked_at'] as Timestamp?)?.toDate(),
      gdprDigitalStatus:
          '${data['gdprDigitalStatus'] ?? data['gdpr_digital_status'] ?? 'accepted'}',
      gdprDigitalReacceptanceRequired:
          data['gdprDigitalReacceptanceRequired'] == true,
      reactivatedAt: (data['reactivatedAt'] as Timestamp?)?.toDate(),
      reactivatedBy: data['reactivatedBy'] as String?,
      fcmToken: data['fcm_token'] as String?,
      notificacionesActivas: data['notificaciones_activas'] ?? true,
      cumpleanosVisible: data['cumpleanos_visible'] != false,
      emailSecundario: data['email_secundario'] as String?,
      telefonoSecundario: data['telefono_secundario'] as String?,
      dni: data['dni'] as String?,
      fechaNacimientoTutor:
          (data['fecha_nacimiento_tutor'] as Timestamp?)?.toDate(),
      dniTutor: data['dni_tutor'] as String?,
      parentescoTutor: data['parentesco_tutor'] as String?,
      requiresDigitalTutor: _parseLegacyTutorValue(
              data['requiresDigitalTutor'] ?? data['tutelado_digital']) ||
          _isMinor(data['fecha_nacimiento_str'] ?? ''),
      digitalTutorEmail:
          '${data['digitalTutorEmail'] ?? data['tutelado_digital_email'] ?? ''}',
      digitalTutorDni: '${data['digitalTutorDni'] ?? data['dni_tutor'] ?? ''}',
      digitalTutorName: '${data['digitalTutorName'] ?? ''}',
      digitalTutorRelationship:
          '${data['digitalTutorRelationship'] ?? data['parentesco_tutor'] ?? ''}',
      digitalTutorPhone: '${data['digitalTutorPhone'] ?? ''}',
      digitalTutorConsentAccepted: data['digitalTutorConsentAccepted'] == true,
      digitalTutorConsentAcceptedAt:
          (data['digitalTutorConsentAcceptedAt'] as Timestamp?)?.toDate(),
      cargo: data['cargo'] as String?,
      tieneTunicaPropia: data['tiene_tunica_propia'] ?? false,
      tagsManual: (data['tags_manual'] as List<dynamic>? ?? [])
          .map((e) => '$e')
          .toList(),
      tagsAuto:
          (data['tags_auto'] as List<dynamic>? ?? []).map((e) => '$e').toList(),
      roles: (data['roles'] as List<dynamic>? ?? []).map((e) => '$e').toList(),
      esCuentaServicio: data['es_cuenta_servicio'] == true,
      adminPermissions:
          (data['admin_permissions'] as Map?)?.cast<String, dynamic>() ?? {},
      status:
          '${data['status'] ?? (data['estado'] == 'Baja' ? 'baja' : 'active')}',
      isActive:
          data['isActive'] == false || data['estado'] == 'Baja' ? false : true,
      bajaAt: (data['bajaAt'] as Timestamp?)?.toDate(),
      bajaReason: data['bajaReason'] as String?,
      bajaBy: data['bajaBy'] as String?,
      cuotaActiva: data['cuotaActiva'] != false,
      hasPendingProfileReview: data['hasPendingProfileReview'] == true,
      lastProfileChangeAt:
          (data['lastProfileChangeAt'] as Timestamp?)?.toDate(),
      lastProfileChangeBy: data['lastProfileChangeBy'] as String?,
      profileReviewedAt: (data['profileReviewedAt'] as Timestamp?)?.toDate(),
      profileReviewedBy: data['profileReviewedBy'] as String?,
      rawData: data,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'numero': numero,
      'numero_anterior': numeroAnterior,
      'nombre': nombre,
      'apellidos': apellidos,
      'tutelado_digital': tuteladoDigital,
      ...birthDateFields(fechaNacimiento),
      'edad': edad,
      'genero': genero,
      'anio_alta': anioAlta,
      'anios_hermandad': aniosHermandad,
      'anio_mayordomia': anioMayordomia,
      'estado': estado,
      'fecha_baja': fechaBaja != null ? Timestamp.fromDate(fechaBaja!) : null,
      'fecha_baja_str': fechaBajaStr,
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
      'gdpr_papel': gdprPapel,
      'comentarios': comentarios,
      'foto_url': fotoUrl,
      'rol': rol,
      'role': rol,
      'fecha_creacion': fechaCreacion != null
          ? Timestamp.fromDate(fechaCreacion!)
          : FieldValue.serverTimestamp(),
      'fecha_actualizacion': FieldValue.serverTimestamp(),
      'auth_uid': authUid,
      'fecha_registro_app': fechaRegistroApp != null
          ? Timestamp.fromDate(fechaRegistroApp!)
          : null,
      'ultimo_acceso':
          ultimoAcceso != null ? Timestamp.fromDate(ultimoAcceso!) : null,
      'gdpr_firmado_digital': gdprFirmadoDigital,
      'gdprDigitalAccepted': gdprDigitalAccepted,
      'gdprDigitalAcceptedAt': gdprDigitalAcceptedAt != null
          ? Timestamp.fromDate(gdprDigitalAcceptedAt!)
          : null,
      'gdprDigitalConsentVersion': gdprDigitalConsentVersion,
      'gdprDigitalConsentHash': gdprDigitalConsentHash,
      'gdprDigitalRevoked': gdprDigitalRevoked,
      'gdprDigitalRevokedAt': gdprDigitalRevokedAt != null
          ? Timestamp.fromDate(gdprDigitalRevokedAt!)
          : null,
      'gdprDigitalStatus': gdprDigitalStatus,
      'gdprDigitalReacceptanceRequired': gdprDigitalReacceptanceRequired,
      'reactivatedAt':
          reactivatedAt != null ? Timestamp.fromDate(reactivatedAt!) : null,
      'reactivatedBy': reactivatedBy,
      'fecha_gdpr_digital': fechaGdprDigital != null
          ? Timestamp.fromDate(fechaGdprDigital!)
          : null,
      'fcm_token': fcmToken,
      'notificaciones_activas': notificacionesActivas,
      'cumpleanos_visible': cumpleanosVisible,
      'email_secundario': emailSecundario,
      'telefono_secundario': telefonoSecundario,
      'dni': dni,
      'fecha_nacimiento_tutor': fechaNacimientoTutor != null
          ? Timestamp.fromDate(fechaNacimientoTutor!)
          : null,
      'dni_tutor': dniTutor,
      'parentesco_tutor': parentescoTutor,
      'requiresDigitalTutor': requiresDigitalTutor,
      'digitalTutorEmail': digitalTutorEmail,
      'digitalTutorDni': digitalTutorDni,
      'digitalTutorName': digitalTutorName,
      'digitalTutorRelationship': digitalTutorRelationship,
      'digitalTutorPhone': digitalTutorPhone,
      'digitalTutorConsentAccepted': digitalTutorConsentAccepted,
      'digitalTutorConsentAcceptedAt': digitalTutorConsentAcceptedAt != null
          ? Timestamp.fromDate(digitalTutorConsentAcceptedAt!)
          : null,
      'cargo': cargo,
      'tiene_tunica_propia': tieneTunicaPropia,
      'tags_manual': tagsManual,
      'tags_auto': tagsAuto,
      'roles': roles,
      'es_cuenta_servicio': esCuentaServicio,
      'admin_permissions': adminPermissions,
      'status': status,
      'isActive': isActive,
      'bajaAt': bajaAt != null ? Timestamp.fromDate(bajaAt!) : null,
      'bajaReason': bajaReason,
      'bajaBy': bajaBy,
      'cuotaActiva': cuotaActiva,
      'hasPendingProfileReview': hasPendingProfileReview,
      'lastProfileChangeAt': lastProfileChangeAt != null
          ? Timestamp.fromDate(lastProfileChangeAt!)
          : null,
      'lastProfileChangeBy': lastProfileChangeBy,
      'profileReviewedAt': profileReviewedAt != null
          ? Timestamp.fromDate(profileReviewedAt!)
          : null,
      'profileReviewedBy': profileReviewedBy,
    };
  }

  static DateTime? parseBirthDate(Object? value) {
    DateTime? parsed;
    if (value is Timestamp) {
      parsed = value.toDate();
    } else if (value is DateTime) {
      parsed = value;
    } else if (value is int) {
      parsed = DateTime.fromMillisecondsSinceEpoch(value);
    } else if (value is num && value == value.roundToDouble()) {
      parsed = DateTime.fromMillisecondsSinceEpoch(value.toInt());
    } else if (value is String) {
      final text = value.trim();
      if (text.isEmpty) return null;
      final parts = text.split(RegExp(r'[/\-]'));
      if (parts.length == 3 &&
          RegExp(r'^\d{1,4}[/\-]\d{1,2}[/\-]\d{1,4}$').hasMatch(text)) {
        final first = int.tryParse(parts[0]);
        final second = int.tryParse(parts[1]);
        final third = int.tryParse(parts[2]);
        if (first != null && second != null && third != null) {
          final year = first > 31 ? first : third;
          final month = second;
          final day = first > 31 ? third : first;
          parsed = DateTime(year, month, day);
          if (parsed.year != year ||
              parsed.month != month ||
              parsed.day != day) {
            return null;
          }
        }
      }
    }
    if (parsed == null) return null;
    final date = DateTime(parsed.year, parsed.month, parsed.day);
    final today = MadridDate.now();
    if (date.year < 1900 ||
        date.isAfter(DateTime(today.year, today.month, today.day))) {
      return null;
    }
    return date;
  }

  static String? birthDateString(DateTime? value) {
    final date = parseBirthDate(value);
    if (date == null) return null;
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  static Map<String, dynamic> birthDateFields(DateTime? value) {
    final date = parseBirthDate(value);
    return {
      'fecha_nacimiento': date == null ? null : Timestamp.fromDate(date),
      'fecha_nacimiento_str': birthDateString(date) ?? '',
    };
  }

  Cofrade copyWith({
    int? numero,
    int? numeroAnterior,
    String? nombre,
    String? apellidos,
    String? tuteladoDigital,
    DateTime? fechaNacimiento,
    String? fechaNacimientoStr,
    int? edad,
    String? genero,
    int? anioAlta,
    int? aniosHermandad,
    int? anioMayordomia,
    String? estado,
    DateTime? fechaBaja,
    String? fechaBajaStr,
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
    bool? cuotaMetalico,
    bool? cuotaDomiciliada,
    String? iban,
    String? titularIban,
    bool? gdprFirmado,
    bool? gdprPapel,
    String? comentarios,
    String? fotoUrl,
    String? rol,
    String? authUid,
    DateTime? fechaRegistroApp,
    DateTime? ultimoAcceso,
    bool? gdprFirmadoDigital,
    DateTime? fechaGdprDigital,
    bool? gdprDigitalAccepted,
    DateTime? gdprDigitalAcceptedAt,
    String? gdprDigitalConsentVersion,
    String? gdprDigitalConsentHash,
    bool? gdprDigitalRevoked,
    DateTime? gdprDigitalRevokedAt,
    String? gdprDigitalStatus,
    bool? gdprDigitalReacceptanceRequired,
    DateTime? reactivatedAt,
    String? reactivatedBy,
    String? fcmToken,
    bool? notificacionesActivas,
    bool? cumpleanosVisible,
    String? emailSecundario,
    String? telefonoSecundario,
    String? dni,
    DateTime? fechaNacimientoTutor,
    String? dniTutor,
    String? parentescoTutor,
    bool? requiresDigitalTutor,
    String? digitalTutorEmail,
    String? digitalTutorDni,
    String? digitalTutorName,
    String? digitalTutorRelationship,
    String? digitalTutorPhone,
    bool? digitalTutorConsentAccepted,
    DateTime? digitalTutorConsentAcceptedAt,
    String? cargo,
    bool? tieneTunicaPropia,
    List<String>? tagsManual,
    List<String>? tagsAuto,
    List<String>? roles,
    bool? esCuentaServicio,
    Map<String, dynamic>? adminPermissions,
    String? status,
    bool? isActive,
    DateTime? bajaAt,
    String? bajaReason,
    String? bajaBy,
    bool? cuotaActiva,
    bool? hasPendingProfileReview,
    DateTime? lastProfileChangeAt,
    String? lastProfileChangeBy,
    DateTime? profileReviewedAt,
    String? profileReviewedBy,
    Map<String, dynamic>? rawData,
  }) {
    return Cofrade(
      id: id,
      numero: numero ?? this.numero,
      numeroAnterior: numeroAnterior ?? this.numeroAnterior,
      nombre: nombre ?? this.nombre,
      apellidos: apellidos ?? this.apellidos,
      tuteladoDigital: tuteladoDigital ?? this.tuteladoDigital,
      fechaNacimiento: fechaNacimiento ?? this.fechaNacimiento,
      fechaNacimientoStr: fechaNacimientoStr ?? this.fechaNacimientoStr,
      edad: edad ?? this.edad,
      genero: genero ?? this.genero,
      anioAlta: anioAlta ?? this.anioAlta,
      aniosHermandad: aniosHermandad ?? this.aniosHermandad,
      anioMayordomia: anioMayordomia ?? this.anioMayordomia,
      estado: estado ?? this.estado,
      fechaBaja: fechaBaja ?? this.fechaBaja,
      fechaBajaStr: fechaBajaStr ?? this.fechaBajaStr,
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
      gdprPapel: gdprPapel ?? this.gdprPapel,
      comentarios: comentarios ?? this.comentarios,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      rol: rol ?? this.rol,
      fechaCreacion: fechaCreacion,
      fechaActualizacion: fechaActualizacion,
      authUid: authUid ?? this.authUid,
      fechaRegistroApp: fechaRegistroApp ?? this.fechaRegistroApp,
      ultimoAcceso: ultimoAcceso ?? this.ultimoAcceso,
      gdprFirmadoDigital: gdprFirmadoDigital ?? this.gdprFirmadoDigital,
      fechaGdprDigital: fechaGdprDigital ?? this.fechaGdprDigital,
      gdprDigitalAccepted: gdprDigitalAccepted ?? this.gdprDigitalAccepted,
      gdprDigitalAcceptedAt:
          gdprDigitalAcceptedAt ?? this.gdprDigitalAcceptedAt,
      gdprDigitalConsentVersion:
          gdprDigitalConsentVersion ?? this.gdprDigitalConsentVersion,
      gdprDigitalConsentHash:
          gdprDigitalConsentHash ?? this.gdprDigitalConsentHash,
      gdprDigitalRevoked: gdprDigitalRevoked ?? this.gdprDigitalRevoked,
      gdprDigitalRevokedAt: gdprDigitalRevokedAt ?? this.gdprDigitalRevokedAt,
      gdprDigitalStatus: gdprDigitalStatus ?? this.gdprDigitalStatus,
      gdprDigitalReacceptanceRequired: gdprDigitalReacceptanceRequired ??
          this.gdprDigitalReacceptanceRequired,
      reactivatedAt: reactivatedAt ?? this.reactivatedAt,
      reactivatedBy: reactivatedBy ?? this.reactivatedBy,
      fcmToken: fcmToken ?? this.fcmToken,
      notificacionesActivas:
          notificacionesActivas ?? this.notificacionesActivas,
      cumpleanosVisible: cumpleanosVisible ?? this.cumpleanosVisible,
      emailSecundario: emailSecundario ?? this.emailSecundario,
      telefonoSecundario: telefonoSecundario ?? this.telefonoSecundario,
      dni: dni ?? this.dni,
      fechaNacimientoTutor: fechaNacimientoTutor ?? this.fechaNacimientoTutor,
      dniTutor: dniTutor ?? this.dniTutor,
      parentescoTutor: parentescoTutor ?? this.parentescoTutor,
      requiresDigitalTutor: requiresDigitalTutor ?? this.requiresDigitalTutor,
      digitalTutorEmail: digitalTutorEmail ?? this.digitalTutorEmail,
      digitalTutorDni: digitalTutorDni ?? this.digitalTutorDni,
      digitalTutorName: digitalTutorName ?? this.digitalTutorName,
      digitalTutorRelationship:
          digitalTutorRelationship ?? this.digitalTutorRelationship,
      digitalTutorPhone: digitalTutorPhone ?? this.digitalTutorPhone,
      digitalTutorConsentAccepted:
          digitalTutorConsentAccepted ?? this.digitalTutorConsentAccepted,
      digitalTutorConsentAcceptedAt:
          digitalTutorConsentAcceptedAt ?? this.digitalTutorConsentAcceptedAt,
      cargo: cargo ?? this.cargo,
      tieneTunicaPropia: tieneTunicaPropia ?? this.tieneTunicaPropia,
      tagsManual: tagsManual ?? this.tagsManual,
      tagsAuto: tagsAuto ?? this.tagsAuto,
      roles: roles ?? this.roles,
      esCuentaServicio: esCuentaServicio ?? this.esCuentaServicio,
      adminPermissions: adminPermissions ?? this.adminPermissions,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
      bajaAt: bajaAt ?? this.bajaAt,
      bajaReason: bajaReason ?? this.bajaReason,
      bajaBy: bajaBy ?? this.bajaBy,
      cuotaActiva: cuotaActiva ?? this.cuotaActiva,
      hasPendingProfileReview:
          hasPendingProfileReview ?? this.hasPendingProfileReview,
      lastProfileChangeAt: lastProfileChangeAt ?? this.lastProfileChangeAt,
      lastProfileChangeBy: lastProfileChangeBy ?? this.lastProfileChangeBy,
      profileReviewedAt: profileReviewedAt ?? this.profileReviewedAt,
      profileReviewedBy: profileReviewedBy ?? this.profileReviewedBy,
      rawData: rawData ?? this.rawData,
    );
  }

  String get nombreCompleto => '$nombre $apellidos';
  bool get isAdmin =>
      rol.toLowerCase() == 'admin' ||
      roles.map((r) => r.toLowerCase()).contains('admin');
  bool get isSuperAdmin =>
      roles.map((r) => r.toLowerCase()).contains('superadmin');
  bool get isActivo =>
      estado.toLowerCase() == 'activo' &&
      status.toLowerCase() != 'baja' &&
      isActive;
  bool get isBaja =>
      estado.toLowerCase() == 'baja' ||
      status.toLowerCase() == 'baja' ||
      !isActive;
  bool get hasDigitalAccessDisabled =>
      isBaja ||
      gdprDigitalRevoked ||
      gdprDigitalStatus == 'revoked' ||
      gdprDigitalStatus == 'revocation_requested';
  bool get hasConsentAccessBlocked =>
      gdprDigitalRevoked ||
      gdprDigitalStatus == 'revoked' ||
      gdprDigitalStatus == 'revocation_requested';
  bool get tuteladoDigitalBool {
    return requiresDigitalTutor;
  }

  Object? valueForFieldKey(String key) {
    switch (key) {
      case 'nombre':
        return nombre;
      case 'apellidos':
        return apellidos;
      case 'fecha_nacimiento_str':
        return fechaNacimientoStr;
      case 'genero':
        return genero;
      case 'domicilio':
        return domicilio;
      case 'localidad':
        return localidad;
      case 'codigo_postal':
        return codigoPostal;
      case 'telefono_movil':
        return telefonoMovil;
      case 'telefono_fijo':
        return telefonoFijo;
      case 'email':
        return email;
      case 'estatura':
        return estatura;
      case 'talla':
        return talla;
      case 'tiene_cuota':
        return tieneCuota;
      case 'cuota_metalico':
        return cuotaMetalico;
      case 'cuota_domiciliada':
        return cuotaDomiciliada;
      case 'iban':
        return iban;
      case 'titular_iban':
        return titularIban;
      case 'gdpr_firmado':
        return gdprFirmado;
      case 'tutelado_digital':
        return tuteladoDigitalBool;
      case 'tiene_tunica_propia':
        return tieneTunicaPropia;
      case 'dni':
        return dni;
      default:
        return rawData[key];
    }
  }

  bool get tieneDatosIncompletos {
    final estadoValido =
        isActivo || isBaja || estado.toLowerCase() == 'pendiente';
    return email.trim().isEmpty ||
        telefonoMovil.trim().isEmpty ||
        (fechaNacimiento == null && fechaNacimientoStr.trim().isEmpty) ||
        !gdprFirmado ||
        (cuotaDomiciliada && (iban ?? '').trim().isEmpty) ||
        !estadoValido;
  }

  bool get isTesorero => rol.toLowerCase() == 'tesorero';
  bool get isJunta =>
      rol.toLowerCase() == 'junta' ||
      rol.toLowerCase() == 'admin' ||
      rol.toLowerCase() == 'tesorero';

  static bool _parseLegacyTutorValue(Object? value) {
    if (value is bool) return value;
    final normalized = '${value ?? ''}'.trim().toLowerCase();
    if (normalized.isEmpty ||
        normalized == 'false' ||
        normalized == '0' ||
        normalized == 'no') {
      return false;
    }
    if (normalized == 'true' ||
        normalized == '1' ||
        normalized == 'si' ||
        normalized == 'sí') {
      return true;
    }
    return normalized.contains('@');
  }

  static bool _isMinor(String fechaNacimientoStr) {
    final parts = fechaNacimientoStr.split('/');
    if (parts.length != 3) return false;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return false;
    final birth = DateTime(year, month, day);
    final now = DateTime.now();
    var age = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      age--;
    }
    return age < 18;
  }
}
