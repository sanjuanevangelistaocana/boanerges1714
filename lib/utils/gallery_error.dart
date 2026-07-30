import 'package:firebase_core/firebase_core.dart';

String galleryErrorMessage(Object error) {
  if (error is FirebaseException) {
    final detail = error.message?.trim();
    final description = switch (error.code) {
      'failed-precondition' =>
        'Falta un índice de Firestore. Despliega firestore.indexes.json.',
      'permission-denied' =>
        'Firestore ha denegado el acceso para este usuario.',
      'unavailable' => 'Firestore no está disponible en este momento.',
      _ => detail?.isNotEmpty == true ? detail : 'Error de Firebase.',
    };
    return '${error.code}: $description';
  }
  final text = error.toString();
  return text.startsWith('Bad state: ')
      ? text.substring('Bad state: '.length)
      : text;
}
