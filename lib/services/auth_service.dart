import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boanerges1714/models/cofrade.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _user;
  List<Cofrade> _cofrades = [];
  Cofrade? _selectedCofrade;
  bool _isLoading = false;

  User? get user => _user;
  Cofrade? get cofrade => _selectedCofrade;
  List<Cofrade> get cofrades => _cofrades;
  bool get hasMultipleCofrades => _cofrades.length > 1;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _selectedCofrade?.isAdmin ?? false;
  bool get isLoading => _isLoading;
  String? get userId => _user?.uid;

  AuthService() {
    _auth.setLanguageCode('es');
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? user) async {
    _user = user;
    if (user != null) {
      await _loadCofradeData();
    } else {
      _cofrades = [];
      _selectedCofrade = null;
    }
    notifyListeners();
  }

  Future<void> _loadCofradeData() async {
    if (_user == null) return;
    try {
      final Map<String, Cofrade> cofradesMap = {};

      final byAuthUid = await _firestore
          .collection('cofrades')
          .where('auth_uid', isEqualTo: _user!.uid)
          .get();
      for (final doc in byAuthUid.docs) {
        cofradesMap[doc.id] = Cofrade.fromFirestore(doc);
      }

      if (_user!.email != null) {
        final byEmail = await _firestore
            .collection('cofrades')
            .where('email', isEqualTo: _user!.email)
            .get();
        for (final doc in byEmail.docs) {
          cofradesMap.putIfAbsent(doc.id, () => Cofrade.fromFirestore(doc));
        }

        final byTutelado = await _firestore
            .collection('cofrades')
            .where('tutelado_digital', isEqualTo: _user!.email)
            .get();
        for (final doc in byTutelado.docs) {
          cofradesMap.putIfAbsent(doc.id, () => Cofrade.fromFirestore(doc));
        }
      }

      _cofrades = cofradesMap.values.toList();

      if (_cofrades.isNotEmpty) {
        _selectedCofrade = _cofrades.firstWhere(
          (c) => c.email == _user!.email,
          orElse: () => _cofrades.first,
        );
      } else {
        _selectedCofrade = null;
      }
    } catch (e) {
      debugPrint('Error loading cofrade data: $e');
    }
  }

  void selectCofrade(String cofradeId) {
    final match = _cofrades.where((c) => c.id == cofradeId);
    if (match.isNotEmpty) {
      _selectedCofrade = match.first;
      notifyListeners();
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
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final trimmedEmail = email.trim();

      // Create auth account FIRST so we are authenticated
      // (Firestore rules require auth to query cofrades collection)
      final credential = await _auth.createUserWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );

      // Now query Firestore for cofrades matching this email
      final byEmail = await _firestore
          .collection('cofrades')
          .where('email', isEqualTo: trimmedEmail)
          .get();

      final byTutelado = await _firestore
          .collection('cofrades')
          .where('tutelado_digital', isEqualTo: trimmedEmail)
          .get();

      if (byEmail.docs.isEmpty && byTutelado.docs.isEmpty) {
        // No cofrade found with this email — delete the auth account
        await credential.user?.delete();
        return 'Tu email no está registrado como cofrade. '
            'Contacta con la Junta Directiva para darte de alta.';
      }

      // Link auth_uid to all matching cofrade documents
      if (credential.user != null) {
        final docIds = <String>{};
        for (final doc in byEmail.docs) {
          docIds.add(doc.id);
        }
        for (final doc in byTutelado.docs) {
          docIds.add(doc.id);
        }

        final batch = _firestore.batch();
        for (final docId in docIds) {
          batch.update(
            _firestore.collection('cofrades').doc(docId),
            {
              'auth_uid': credential.user!.uid,
              'fecha_actualizacion': FieldValue.serverTimestamp(),
            },
          );
        }
        await batch.commit();
      }
      return null;
    } on FirebaseAuthException catch (e) {
      return _getErrorMessage(e.code);
    } catch (e) {
      debugPrint('Registration error: $e');
      return 'Error durante el registro. Inténtalo de nuevo.';
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
