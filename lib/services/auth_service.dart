import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boanerges1714/models/cofrade.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _user;
  Cofrade? _cofrade;
  bool _isLoading = false;

  User? get user => _user;
  Cofrade? get cofrade => _cofrade;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _cofrade?.isAdmin ?? false;
  bool get isLoading => _isLoading;
  String? get userId => _user?.uid;

  AuthService() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? user) async {
    _user = user;
    if (user != null) {
      await _loadCofradeData();
    } else {
      _cofrade = null;
    }
    notifyListeners();
  }

  Future<void> _loadCofradeData() async {
    if (_user == null) return;
    try {
      final doc = await _firestore.collection('cofrades').doc(_user!.uid).get();
      if (doc.exists) {
        _cofrade = Cofrade.fromFirestore(doc);
      }
    } catch (e) {
      print('Error loading cofrade data: $e');
    }
  }

  Future<String?> signIn(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return _getErrorMessage(e.code);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> register({
    required String email,
    required String password,
    required String nombre,
    required String apellidos,
    String telefono = '',
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (credential.user != null) {
        final cofrade = Cofrade(
          id: credential.user!.uid,
          nombre: nombre,
          apellidos: apellidos,
          email: email.trim(),
          telefono: telefono,
          estado: 'pendiente',
          rol: 'cofrade',
        );

        await _firestore
            .collection('cofrades')
            .doc(credential.user!.uid)
            .set(cofrade.toFirestore());
      }
      return null;
    } on FirebaseAuthException catch (e) {
      return _getErrorMessage(e.code);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return _getErrorMessage(e.code);
    }
  }

  Future<void> refreshCofradeData() async {
    await _loadCofradeData();
    notifyListeners();
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No existe una cuenta con este email.';
      case 'wrong-password':
        return 'Contraseña incorrecta.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con este email.';
      case 'weak-password':
        return 'La contraseña es demasiado débil. Usa al menos 6 caracteres.';
      case 'invalid-email':
        return 'El email no es válido.';
      case 'too-many-requests':
        return 'Demasiados intentos. Inténtalo de nuevo más tarde.';
      default:
        return 'Error de autenticación. Inténtalo de nuevo.';
    }
  }
}
