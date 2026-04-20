import 'package:cloud_firestore/cloud_firestore.dart';

class Cuota {
  final String id;
  final String cofradeId;
  final int anio;
  final double importe;
  final String estado;
  final DateTime? fechaPago;
  final String? concepto;

  Cuota({
    required this.id,
    required this.cofradeId,
    required this.anio,
    required this.importe,
    this.estado = 'pendiente',
    this.fechaPago,
    this.concepto,
  });

  factory Cuota.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Cuota(
      id: doc.id,
      cofradeId: data['cofrade_id'] ?? '',
      anio: data['anio'] ?? DateTime.now().year,
      importe: (data['importe'] ?? 0).toDouble(),
      estado: data['estado'] ?? 'pendiente',
      fechaPago: (data['fecha_pago'] as Timestamp?)?.toDate(),
      concepto: data['concepto'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'cofrade_id': cofradeId,
      'anio': anio,
      'importe': importe,
      'estado': estado,
      'fecha_pago': fechaPago != null ? Timestamp.fromDate(fechaPago!) : null,
      'concepto': concepto,
    };
  }

  bool get isPagada => estado == 'pagada';
  bool get isPendiente => estado == 'pendiente';
}
