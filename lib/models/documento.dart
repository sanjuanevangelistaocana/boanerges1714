import 'package:cloud_firestore/cloud_firestore.dart';

class Documento {
  final String id;
  final String titulo;
  final String tipo;
  final String archivoUrl;
  final DateTime fecha;
  final String? descripcion;

  Documento({
    required this.id,
    required this.titulo,
    required this.tipo,
    required this.archivoUrl,
    required this.fecha,
    this.descripcion,
  });

  factory Documento.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Documento(
      id: doc.id,
      titulo: data['titulo'] ?? '',
      tipo: data['tipo'] ?? 'otro',
      archivoUrl: data['archivo_url'] ?? '',
      fecha: (data['fecha'] as Timestamp).toDate(),
      descripcion: data['descripcion'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'titulo': titulo,
      'tipo': tipo,
      'archivo_url': archivoUrl,
      'fecha': Timestamp.fromDate(fecha),
      'descripcion': descripcion,
    };
  }
}
