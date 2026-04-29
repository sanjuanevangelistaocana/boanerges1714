import 'package:cloud_firestore/cloud_firestore.dart';

// --- Campaña de Lotería ---
class CampanaLoteria {
  final String id;
  final String nombre;
  final int numeroLoteria;
  final double precioDecimoBase;
  final double recargo;
  final double precioVenta;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final String administracionNombre;
  final String estado; // activa / cerrada

  CampanaLoteria({
    required this.id,
    required this.nombre,
    required this.numeroLoteria,
    required this.precioDecimoBase,
    required this.recargo,
    required this.precioVenta,
    this.fechaInicio,
    this.fechaFin,
    this.administracionNombre = '',
    this.estado = 'activa',
  });

  factory CampanaLoteria.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CampanaLoteria(
      id: doc.id,
      nombre: data['nombre'] ?? '',
      numeroLoteria: (data['numero_loteria'] ?? 0) is int
          ? data['numero_loteria'] ?? 0
          : (data['numero_loteria'] as num?)?.toInt() ?? 0,
      precioDecimoBase:
          (data['precio_decimo_base'] as num?)?.toDouble() ?? 20.0,
      recargo: (data['recargo'] as num?)?.toDouble() ?? 0.0,
      precioVenta: (data['precio_venta'] as num?)?.toDouble() ?? 20.0,
      fechaInicio: (data['fecha_inicio'] as Timestamp?)?.toDate(),
      fechaFin: (data['fecha_fin'] as Timestamp?)?.toDate(),
      administracionNombre: data['administracion_nombre'] ?? '',
      estado: data['estado'] ?? 'activa',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'nombre': nombre,
      'numero_loteria': numeroLoteria,
      'precio_decimo_base': precioDecimoBase,
      'recargo': recargo,
      'precio_venta': precioVenta,
      'fecha_inicio':
          fechaInicio != null ? Timestamp.fromDate(fechaInicio!) : null,
      'fecha_fin': fechaFin != null ? Timestamp.fromDate(fechaFin!) : null,
      'administracion_nombre': administracionNombre,
      'estado': estado,
    };
  }

  bool get isActiva => estado == 'activa';
}

// --- Sábana (sheet of 10 décimos) ---
class Sabana {
  final String id;
  final String campanaId;
  final int numeroLoteria;
  final int totalDecimos;
  final double precioCompra;
  final double precioVentaUnidad;
  final DateTime? fechaRetirada;
  final String administracionNombre;
  final bool pagadaAdministracion;
  final DateTime? fechaPagoAdministracion;
  final String estado; // disponible / asignada / agotada / cerrada
  final String? referencia;
  final String serie;

  Sabana({
    required this.id,
    required this.campanaId,
    required this.numeroLoteria,
    this.totalDecimos = 10,
    required this.precioCompra,
    required this.precioVentaUnidad,
    this.fechaRetirada,
    this.administracionNombre = '',
    this.pagadaAdministracion = false,
    this.fechaPagoAdministracion,
    this.estado = 'disponible',
    this.referencia,
    this.serie = '',
  });

  factory Sabana.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Sabana(
      id: doc.id,
      campanaId: data['campana_id'] ?? '',
      numeroLoteria: (data['numero_loteria'] as num?)?.toInt() ?? 0,
      totalDecimos: (data['total_decimos'] as num?)?.toInt() ?? 10,
      precioCompra: (data['precio_compra'] as num?)?.toDouble() ?? 200.0,
      precioVentaUnidad:
          (data['precio_venta_unidad'] as num?)?.toDouble() ?? 23.0,
      fechaRetirada: (data['fecha_retirada'] as Timestamp?)?.toDate(),
      administracionNombre: data['administracion_nombre'] ?? '',
      pagadaAdministracion: data['pagada_administracion'] ?? false,
      fechaPagoAdministracion:
          (data['fecha_pago_administracion'] as Timestamp?)?.toDate(),
      estado: data['estado'] ?? 'disponible',
      referencia: data['referencia'],
      serie: data['serie'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'campana_id': campanaId,
      'numero_loteria': numeroLoteria,
      'total_decimos': totalDecimos,
      'precio_compra': precioCompra,
      'precio_venta_unidad': precioVentaUnidad,
      'fecha_retirada':
          fechaRetirada != null ? Timestamp.fromDate(fechaRetirada!) : null,
      'administracion_nombre': administracionNombre,
      'pagada_administracion': pagadaAdministracion,
      'fecha_pago_administracion': fechaPagoAdministracion != null
          ? Timestamp.fromDate(fechaPagoAdministracion!)
          : null,
      'estado': estado,
      'referencia': referencia,
      'serie': serie,
    };
  }
}

// --- Décimo / fracción identificable ---
class DecimoLoteria {
  final String id;
  final String campanaId;
  final String sabanaId;
  final int numeroLoteria;
  final String serie;
  final int numeroDecimo;
  final double precioVenta;
  final String
      estado; // disponible / asignado / vendido / cobrado / devuelto...
  final String? vendedorId;
  final String? cofradeId;
  final DateTime? fechaAsignacion;
  final DateTime? fechaVenta;
  final bool paidToBrotherhood;
  final DateTime? paidToBrotherhoodAt;
  final String? paidToBrotherhoodMarkedBy;
  final String? brotherhoodHolderId;
  final String? brotherhoodHolderName;
  final DateTime? brotherhoodHolderAssignedAt;
  final String? brotherhoodHolderAssignedBy;
  final bool paidToAdministration;
  final DateTime? paidToAdministrationAt;
  final String? paidToAdministrationMarkedBy;
  final String paymentNotes;
  final String? returnedBySeller;
  final DateTime? returnedAt;
  final bool returnConfirmedByAdmin;
  final DateTime? returnConfirmedAt;
  final String? returnConfirmedBy;
  final String returnNotes;

  DecimoLoteria({
    required this.id,
    required this.campanaId,
    required this.sabanaId,
    required this.numeroLoteria,
    required this.serie,
    required this.numeroDecimo,
    required this.precioVenta,
    this.estado = 'disponible',
    this.vendedorId,
    this.cofradeId,
    this.fechaAsignacion,
    this.fechaVenta,
    this.paidToBrotherhood = false,
    this.paidToBrotherhoodAt,
    this.paidToBrotherhoodMarkedBy,
    this.brotherhoodHolderId,
    this.brotherhoodHolderName,
    this.brotherhoodHolderAssignedAt,
    this.brotherhoodHolderAssignedBy,
    this.paidToAdministration = false,
    this.paidToAdministrationAt,
    this.paidToAdministrationMarkedBy,
    this.paymentNotes = '',
    this.returnedBySeller,
    this.returnedAt,
    this.returnConfirmedByAdmin = false,
    this.returnConfirmedAt,
    this.returnConfirmedBy,
    this.returnNotes = '',
  });

  factory DecimoLoteria.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DecimoLoteria(
      id: doc.id,
      campanaId: data['campana_id'] ?? '',
      sabanaId: data['sabana_id'] ?? '',
      numeroLoteria: (data['numero_loteria'] as num?)?.toInt() ?? 0,
      serie: data['serie'] ?? '',
      numeroDecimo: (data['numero_decimo'] as num?)?.toInt() ?? 0,
      precioVenta: (data['precio_venta'] as num?)?.toDouble() ?? 0,
      estado: data['estado'] ?? 'disponible',
      vendedorId: data['vendedor_id'],
      cofradeId: data['cofrade_id'],
      fechaAsignacion: (data['fecha_asignacion'] as Timestamp?)?.toDate(),
      fechaVenta: (data['fecha_venta'] as Timestamp?)?.toDate(),
      paidToBrotherhood: data['paidToBrotherhood'] == true,
      paidToBrotherhoodAt:
          (data['paidToBrotherhoodAt'] as Timestamp?)?.toDate(),
      paidToBrotherhoodMarkedBy: data['paidToBrotherhoodMarkedBy'],
      brotherhoodHolderId: data['brotherhoodHolderId'],
      brotherhoodHolderName: data['brotherhoodHolderName'],
      brotherhoodHolderAssignedAt:
          (data['brotherhoodHolderAssignedAt'] as Timestamp?)?.toDate(),
      brotherhoodHolderAssignedBy: data['brotherhoodHolderAssignedBy'],
      paidToAdministration: data['paidToAdministration'] == true,
      paidToAdministrationAt:
          (data['paidToAdministrationAt'] as Timestamp?)?.toDate(),
      paidToAdministrationMarkedBy: data['paidToAdministrationMarkedBy'],
      paymentNotes: data['paymentNotes'] ?? '',
      returnedBySeller: data['returnedBySeller'],
      returnedAt: (data['returnedAt'] as Timestamp?)?.toDate(),
      returnConfirmedByAdmin: data['returnConfirmedByAdmin'] == true,
      returnConfirmedAt: (data['returnConfirmedAt'] as Timestamp?)?.toDate(),
      returnConfirmedBy: data['returnConfirmedBy'],
      returnNotes: data['returnNotes'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'campana_id': campanaId,
      'sabana_id': sabanaId,
      'numero_loteria': numeroLoteria,
      'serie': serie,
      'numero_decimo': numeroDecimo,
      'precio_venta': precioVenta,
      'estado': estado,
      'vendedor_id': vendedorId,
      'cofrade_id': cofradeId,
      'fecha_asignacion':
          fechaAsignacion != null ? Timestamp.fromDate(fechaAsignacion!) : null,
      'fecha_venta':
          fechaVenta != null ? Timestamp.fromDate(fechaVenta!) : null,
      'paidToBrotherhood': paidToBrotherhood,
      'paidToBrotherhoodAt': paidToBrotherhoodAt != null
          ? Timestamp.fromDate(paidToBrotherhoodAt!)
          : null,
      'paidToBrotherhoodMarkedBy': paidToBrotherhoodMarkedBy,
      'brotherhoodHolderId': brotherhoodHolderId,
      'brotherhoodHolderName': brotherhoodHolderName,
      'brotherhoodHolderAssignedAt': brotherhoodHolderAssignedAt != null
          ? Timestamp.fromDate(brotherhoodHolderAssignedAt!)
          : null,
      'brotherhoodHolderAssignedBy': brotherhoodHolderAssignedBy,
      'paidToAdministration': paidToAdministration,
      'paidToAdministrationAt': paidToAdministrationAt != null
          ? Timestamp.fromDate(paidToAdministrationAt!)
          : null,
      'paidToAdministrationMarkedBy': paidToAdministrationMarkedBy,
      'paymentNotes': paymentNotes,
      'returnedBySeller': returnedBySeller,
      'returnedAt': returnedAt != null ? Timestamp.fromDate(returnedAt!) : null,
      'returnConfirmedByAdmin': returnConfirmedByAdmin,
      'returnConfirmedAt': returnConfirmedAt != null
          ? Timestamp.fromDate(returnConfirmedAt!)
          : null,
      'returnConfirmedBy': returnConfirmedBy,
      'returnNotes': returnNotes,
    };
  }

  bool get isPendiente => estado == 'asignado';
  bool get isVendido => estado == 'vendido';
  bool get isCobrado => estado == 'cobrado';
  bool get isDevueltoPendiente => estado == 'devuelto_pendiente_revision';
  bool get isDevueltoConfirmado => estado == 'devuelto_confirmado';
}

// --- Vendedor ---
class VendedorLoteria {
  final String id;
  final String tipo; // cofrade / externo
  final String nombre;
  final String telefono;
  final String? cofradeId;
  final String? usuarioAuthId;
  final String contacto;
  final String direccion;
  final String mapsUrl;
  final String logoUrl;
  final String observaciones;

  VendedorLoteria({
    required this.id,
    required this.tipo,
    required this.nombre,
    this.telefono = '',
    this.cofradeId,
    this.usuarioAuthId,
    this.contacto = '',
    this.direccion = '',
    this.mapsUrl = '',
    this.logoUrl = '',
    this.observaciones = '',
  });

  factory VendedorLoteria.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VendedorLoteria(
      id: doc.id,
      tipo: data['tipo'] ?? 'externo',
      nombre: data['nombre'] ?? '',
      telefono: data['telefono'] ?? '',
      cofradeId: data['cofrade_id'],
      usuarioAuthId: data['usuario_auth_id'],
      contacto: data['contacto'] ?? '',
      direccion: data['direccion'] ?? '',
      mapsUrl: data['maps_url'] ?? '',
      logoUrl: data['logo_url'] ?? '',
      observaciones: data['observaciones'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tipo': tipo,
      'nombre': nombre,
      'telefono': telefono,
      'cofrade_id': cofradeId,
      'usuario_auth_id': usuarioAuthId,
      'contacto': contacto,
      'direccion': direccion,
      'maps_url': mapsUrl,
      'logo_url': logoUrl,
      'observaciones': observaciones,
    };
  }

  bool get isCofrade => tipo == 'cofrade';
}

// --- Asignación ---
class AsignacionLoteria {
  final String id;
  final String campanaId;
  final String sabanaId;
  final String vendedorId;
  final int decimosAsignados;
  final int decimosVendidos;
  final int decimosDevueltos;
  final String estado; // activa / parcial / agotada / devuelta / cerrada
  final String? tokenAcceso;
  final DateTime? ultimaActualizacion;

  AsignacionLoteria({
    required this.id,
    required this.campanaId,
    required this.sabanaId,
    required this.vendedorId,
    required this.decimosAsignados,
    this.decimosVendidos = 0,
    this.decimosDevueltos = 0,
    this.estado = 'activa',
    this.tokenAcceso,
    this.ultimaActualizacion,
  });

  int get decimosDisponibles =>
      decimosAsignados - decimosVendidos - decimosDevueltos;

  factory AsignacionLoteria.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AsignacionLoteria(
      id: doc.id,
      campanaId: data['campana_id'] ?? '',
      sabanaId: data['sabana_id'] ?? '',
      vendedorId: data['vendedor_id'] ?? '',
      decimosAsignados: (data['decimos_asignados'] as num?)?.toInt() ?? 0,
      decimosVendidos: (data['decimos_vendidos'] as num?)?.toInt() ?? 0,
      decimosDevueltos: (data['decimos_devueltos'] as num?)?.toInt() ?? 0,
      estado: data['estado'] ?? 'activa',
      tokenAcceso: data['token_acceso'],
      ultimaActualizacion:
          (data['ultima_actualizacion'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'campana_id': campanaId,
      'sabana_id': sabanaId,
      'vendedor_id': vendedorId,
      'decimos_asignados': decimosAsignados,
      'decimos_vendidos': decimosVendidos,
      'decimos_devueltos': decimosDevueltos,
      'estado': estado,
      'token_acceso': tokenAcceso,
      'ultima_actualizacion': FieldValue.serverTimestamp(),
    };
  }
}
