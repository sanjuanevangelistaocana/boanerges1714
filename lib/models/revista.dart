import 'package:cloud_firestore/cloud_firestore.dart';

class Revista {
  final String id;
  final String titulo;
  final String descripcion;
  final String pdfUrl;
  final String portadaUrl;
  final int numero;
  final DateTime fecha;

  Revista({
    required this.id,
    required this.titulo,
    this.descripcion = '',
    required this.pdfUrl,
    this.portadaUrl = '',
    this.numero = 0,
    required this.fecha,
  });

  factory Revista.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Revista(
      id: doc.id,
      titulo: data['titulo'] ?? '',
      descripcion: data['descripcion'] ?? '',
      pdfUrl: data['pdf_url'] ?? '',
      portadaUrl: data['portada_url'] ?? '',
      numero: data['numero'] ?? 0,
      fecha: (data['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'titulo': titulo,
      'descripcion': descripcion,
      'pdf_url': pdfUrl,
      'portada_url': portadaUrl,
      'numero': numero,
      'fecha': Timestamp.fromDate(fecha),
    };
  }
}
