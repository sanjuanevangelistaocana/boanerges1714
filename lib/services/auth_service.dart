import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boanerges1714/models/cofrade.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  User? _user;
  List<Cofrade> _cofrades = [];
  Cofrade? _selectedCofrade;
  bool _isLoading = false;
  bool _profileSelectedThisSession = false;
  Map<String, dynamic>? _activeLegalConsent;

  User? get user => _user;
  Cofrade? get cofrade => _selectedCofrade;
  List<Cofrade> get cofrades => _cofrades;
  bool get hasMultipleCofrades => _cofrades.length > 1;
  List<Cofrade> get selectableCofrades =>
      _cofrades.where((c) => !c.isBaja && c.isActive != false).toList();
  List<Cofrade> get accessibleCofrades =>
      selectableCofrades.where((c) => !c.hasConsentAccessBlocked).toList();
  bool get needsProfileSelection =>
      _user != null &&
      accessibleCofrades.length > 1 &&
      !_profileSelectedThisSession;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _selectedCofrade?.isAdmin ?? false;
  bool get isTreasurer => _selectedCofrade?.rol == 'tesorero';
  bool get isBoardMember => _selectedCofrade?.isJunta ?? false;
  bool get canViewTreasury => isAdmin || isTreasurer || isBoardMember;
  bool get canManageTreasury => isAdmin || isTreasurer;
  bool get canApproveInvoices => isAdmin || isTreasurer;
  bool get canGenerateRemittance => isAdmin || isTreasurer;
  bool get canEditTreasurySettings => isAdmin || isTreasurer;
  bool get isLoading => _isLoading;
  String? get userId => _user?.uid;
  Map<String, dynamic>? get activeLegalConsent => _activeLegalConsent;
  bool get needsEmailVerification {
    final cofrade = _selectedCofrade;
    if (_user == null || cofrade == null) return false;
    if (cofrade.esCuentaServicio || cofrade.isAdmin || cofrade.isSuperAdmin) {
      return false;
    }
    return _user!.emailVerified != true;
  }

  bool get isAccessDisabled {
    final cofrade = _selectedCofrade;
    if (_user == null || cofrade == null || cofrade.esCuentaServicio) {
      return false;
    }
    if (cofrade.isAdmin || cofrade.isSuperAdmin) return false;
    return cofrade.hasDigitalAccessDisabled;
  }

  String get accessDisabledMessage {
    final cofrade = _selectedCofrade;
    if (cofrade?.isBaja == true) {
      return 'Tu acceso está deshabilitado. Contacta con la Cofradía.';
    }
    if (cofrade?.gdprDigitalRevoked == true ||
        cofrade?.gdprDigitalStatus == 'revoked') {
      return 'Tu acceso digital está deshabilitado por revocación del consentimiento. Contacta con la Cofradía.';
    }
    return 'Tu acceso está deshabilitado. Contacta con la Cofradía.';
  }

  bool get needsGdprConsent {
    final cofrade = _selectedCofrade;
    if (_user == null ||
        cofrade == null ||
        cofrade.esCuentaServicio ||
        cofrade.isAdmin ||
        cofrade.isSuperAdmin ||
        isAccessDisabled) {
      return false;
    }
    final version = _activeLegalConsent?['versionId'] ?? 'gdpr-rgpd-v1';
    return cofrade.gdprDigitalAccepted != true ||
        cofrade.gdprDigitalConsentVersion != version ||
        cofrade.gdprDigitalReacceptanceRequired == true ||
        cofrade.gdprDigitalStatus == 'pending_reacceptance';
  }

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
      _profileSelectedThisSession = false;
      _activeLegalConsent = null;
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
      _cofrades.sort((a, b) {
        final an = a.numero ?? 999999;
        final bn = b.numero ?? 999999;
        final byNumber = an.compareTo(bn);
        if (byNumber != 0) return byNumber;
        return a.nombreCompleto.compareTo(b.nombreCompleto);
      });

      if (_cofrades.isNotEmpty) {
        final validOptions = accessibleCofrades;
        final activeOptions = selectableCofrades;
        final options = validOptions.isNotEmpty
            ? validOptions
            : (activeOptions.isEmpty ? _cofrades : activeOptions);
        final previousSelectedId = _selectedCofrade?.id;
        if (previousSelectedId != null &&
            options.any((c) => c.id == previousSelectedId)) {
          _selectedCofrade =
              options.firstWhere((c) => c.id == previousSelectedId);
        } else {
          _selectedCofrade = options.firstWhere(
            (c) => c.email == _user!.email,
            orElse: () => options.first,
          );
        }
      } else {
        _selectedCofrade = null;
      }

      if (_selectedCofrade?.isAdmin == true) {
        await _ensureAdminRulesRole();
      }
      await _loadActiveLegalConsent();
    } catch (e) {
      debugPrint('Error loading cofrade data: $e');
    }
  }

  Future<void> _loadActiveLegalConsent() async {
    try {
      final snap = await _firestore
          .collection('legal_consents')
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) {
        _activeLegalConsent = {
          'versionId': 'gdpr-rgpd-v1',
          'title': 'Consentimiento de protección de datos',
          'legalText': defaultGdprLegalText,
          'hash': 'gdpr-rgpd-v1',
        };
      } else {
        _activeLegalConsent = snap.docs.first.data();
      }
    } catch (e) {
      debugPrint('Error loading legal consent: $e');
      _activeLegalConsent = {
        'versionId': 'gdpr-rgpd-v1',
        'title': 'Consentimiento de protección de datos',
        'legalText': defaultGdprLegalText,
        'hash': 'gdpr-rgpd-v1',
      };
    }
  }

  Future<void> _ensureAdminRulesRole() async {
    try {
      final callable =
          _functions.httpsCallable('ensureAdminRoleForCurrentUser');
      final result = await callable.call<Map<String, dynamic>>({});
      debugPrint('[Auth] ensureAdminRoleForCurrentUser: ${result.data}');
    } catch (e) {
      debugPrint('[Auth] ensureAdminRoleForCurrentUser error: $e');
    }
  }

  void selectCofrade(String cofradeId) {
    final match = _cofrades.where((c) => c.id == cofradeId);
    if (match.isNotEmpty &&
        !match.first.isBaja &&
        match.first.isActive != false) {
      _selectedCofrade = match.first;
      _profileSelectedThisSession = true;
      _firestore.collection('audit_logs').add({
        'action': 'auth_profile_selected',
        'target_id': cofradeId,
        'target_type': 'cofrade',
        'target_nombre': match.first.nombreCompleto,
        'changed_by': cofradeId,
        'changed_by_role': match.first.rol,
        'changed_at': FieldValue.serverTimestamp(),
        'metadata': {'uid': _user?.uid, 'email': _user?.email},
      });
      notifyListeners();
    }
  }

  Future<String?> signIn(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (credential.user?.emailVerified != true) {
        await credential.user?.sendEmailVerification();
      }
      await _markLoginProvider(
        uid: credential.user?.uid,
        email: email.trim(),
        provider: 'password',
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return _getErrorMessage(e.code);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> signInWithDni(String dni, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      final cleanDni = _normalizeDni(dni);
      debugPrint('[Auth] signInWithDni: lookup DNI=$cleanDni');
      final callable = _functions.httpsCallable('lookupEmailByDni');
      final result = await callable.call<Map<String, dynamic>>({
        'dni': cleanDni,
      });
      final cofradeEmail = result.data['email'] as String?;
      if (cofradeEmail == null || cofradeEmail.trim().isEmpty) {
        debugPrint('[Auth] signInWithDni: DNI found without email');
        return 'El cofrade con ese DNI/NIE no tiene email asociado. Contacta con la Junta.';
      }

      final credential = await _auth.signInWithEmailAndPassword(
        email: cofradeEmail.trim(),
        password: password,
      );
      if (credential.user?.emailVerified != true) {
        await credential.user?.sendEmailVerification();
      }
      await _markLoginProvider(
        uid: credential.user?.uid,
        email: cofradeEmail.trim(),
        provider: 'dni',
      );
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('[Auth] signInWithDni auth error: ${e.code} - ${e.message}');
      return _getErrorMessage(e.code);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[Auth] signInWithDni lookup error: ${e.code} - ${e.message}');
      switch (e.code) {
        case 'not-found':
          return 'No se encontró ningún cofrade con ese DNI/NIE.';
        case 'failed-precondition':
          return e.message ??
              'El cofrade existe, pero no tiene email asociado. Contacta con la Junta.';
        case 'invalid-argument':
          return 'Introduce un DNI/NIE válido.';
        case 'permission-denied':
          return 'No se pudo consultar el DNI/NIE por permisos. Contacta con la Junta.';
        default:
          return 'No se pudo consultar el DNI/NIE. Inténtalo de nuevo.';
      }
    } catch (e) {
      debugPrint('DNI login error: $e');
      return 'Error al iniciar sesi\u00f3n. Int\u00e9ntalo de nuevo.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> signInWithGoogle() async {
    try {
      _isLoading = true;
      notifyListeners();
      final provider = GoogleAuthProvider()
        ..setCustomParameters({'prompt': 'select_account'});
      final credential = kIsWeb
          ? await _auth.signInWithPopup(provider)
          : await _auth.signInWithProvider(provider);
      final user = credential.user;
      final email = user?.email?.trim();
      if (user == null || email == null || email.isEmpty) {
        await _auth.signOut();
        return 'No se pudo obtener el email de la cuenta de Google.';
      }
      final byEmail = await _firestore
          .collection('cofrades')
          .where('email', isEqualTo: email)
          .get();
      if (byEmail.docs.isEmpty) {
        await _auth.signOut();
        return 'No existe ningún cofrade asociado a esta cuenta de Google. Contacta con la Cofradía.';
      }
      final batch = _firestore.batch();
      for (final doc in byEmail.docs) {
        final currentAuthUid = doc.data()['auth_uid'];
        batch.update(doc.reference, {
          if (currentAuthUid == null || '$currentAuthUid'.isEmpty)
            'auth_uid': user.uid,
          'authUid': user.uid,
          'login_method': 'google',
          'lastLoginMethod': 'google',
          'linkedAuthProviders': FieldValue.arrayUnion(['google']),
          'hasLoggedIn': true,
          if (doc.data()['firstLoginAt'] == null)
            'firstLoginAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
          'loginCount': FieldValue.increment(1),
          'fecha_actualizacion': FieldValue.serverTimestamp(),
          'ultimo_acceso': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      final doc = byEmail.docs.first;
      await _firestore.collection('audit_logs').add({
        'action': 'google_login',
        'target_id': doc.id,
        'target_type': 'cofrade',
        'target_nombre':
            '${doc.data()['nombre'] ?? ''} ${doc.data()['apellidos'] ?? ''}'
                .trim(),
        'changed_by': doc.id,
        'changed_by_role': 'cofrade',
        'changed_at': FieldValue.serverTimestamp(),
        'metadata': {'email': email, 'uid': user.uid},
      });
      await _loadCofradeData();
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('Google login FirebaseAuth error: ${e.code} ${e.message}');
      if (e.code == 'account-exists-with-different-credential') {
        return 'Ya existe una cuenta con este email. Accede con email y contraseña para vincular Google.';
      }
      return _getErrorMessage(e.code);
    } catch (e) {
      debugPrint('Google login error: $e');
      return 'No se pudo iniciar sesión con Google. Inténtalo de nuevo.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _normalizeDni(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'[\s\-_.]'), '').trim();
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
      await credential.user?.sendEmailVerification();

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

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && user.emailVerified != true) {
      await user.sendEmailVerification();
      await _createAuthAuditLog(
        action: 'email_verification_sent',
        metadata: {'email': user.email},
      );
    }
  }

  Future<void> _markLoginProvider({
    required String? uid,
    required String email,
    required String provider,
  }) async {
    if (uid == null || email.trim().isEmpty) return;
    try {
      final snap = await _firestore
          .collection('cofrades')
          .where('email', isEqualTo: email.trim())
          .get();
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {
          'auth_uid': uid,
          'authUid': uid,
          'linkedAuthProviders': FieldValue.arrayUnion([provider]),
          'lastLoginMethod': provider,
          'hasLoggedIn': true,
          'firstLoginAt':
              doc.data()['firstLoginAt'] ?? FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
          'loginCount': FieldValue.increment(1),
          'ultimo_acceso': FieldValue.serverTimestamp(),
          'fecha_actualizacion': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[Auth] mark login provider failed: $e');
    }
  }

  Future<bool> reloadAndCheckEmailVerification() async {
    await _auth.currentUser?.reload();
    _user = _auth.currentUser;
    final verified = _user?.emailVerified == true;
    if (verified) {
      await _createAuthAuditLog(
        action: 'email_verified',
        metadata: {'email': _user?.email},
      );
    }
    notifyListeners();
    return verified;
  }

  Future<void> _createAuthAuditLog({
    required String action,
    Map<String, dynamic> metadata = const {},
  }) async {
    final target = _selectedCofrade;
    if (target == null) return;
    try {
      await _firestore.collection('audit_logs').add({
        'action': action,
        'target_id': target.id,
        'target_type': 'cofrade',
        'target_nombre': target.nombreCompleto,
        'changed_by': target.id,
        'changed_by_role': target.rol,
        'changed_at': FieldValue.serverTimestamp(),
        'metadata': metadata,
      });
    } catch (e) {
      debugPrint('[Auth] audit $action failed: $e');
    }
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

const defaultGdprLegalText = '''
CONSENTIMIENTO INFORMADO PARA EL TRATAMIENTO DE DATOS PERSONALES

Responsable del tratamiento:
Cofradía de San Juan Evangelista de Ocaña.

Finalidad del tratamiento:
Los datos personales facilitados por el cofrade serán tratados con la finalidad de gestionar su relación con la Cofradía, incluyendo la administración interna de miembros, comunicaciones institucionales, gestión de cuotas, participación en actividades, organización de actos, gestión documental, control de permisos de acceso a la aplicación y demás actuaciones necesarias para el correcto funcionamiento ordinario de la Cofradía.

Base jurídica:
La base jurídica del tratamiento es el consentimiento prestado por el interesado, así como, cuando proceda, la ejecución de la relación asociativa existente entre el cofrade y la Cofradía y el cumplimiento de obligaciones legales aplicables.

Datos tratados:
Podrán tratarse datos identificativos, datos de contacto, datos bancarios cuando sean necesarios para la gestión de cuotas o pagos, información relativa a la pertenencia y participación en la Cofradía, documentación aportada por el cofrade y datos técnicos derivados del uso de la aplicación.

Destinatarios:
Los datos no serán cedidos a terceros salvo obligación legal, necesidad operativa vinculada a la gestión ordinaria de la Cofradía o prestación de servicios tecnológicos necesarios para el funcionamiento de la aplicación, siempre bajo las garantías exigidas por la normativa vigente.

Conservación:
Los datos serán conservados mientras el interesado mantenga su relación con la Cofradía y, posteriormente, durante los plazos necesarios para atender posibles responsabilidades legales, administrativas o documentales.

Derechos del interesado:
El cofrade podrá ejercer sus derechos de acceso, rectificación, supresión, oposición, limitación del tratamiento y portabilidad, así como retirar el consentimiento prestado, mediante solicitud dirigida a la Cofradía por los canales habilitados al efecto.

Retirada del consentimiento:
La retirada del consentimiento no afectará a la licitud del tratamiento realizado con anterioridad a dicha retirada. La solicitud de retirada será atendida conforme a la normativa aplicable y podrá implicar limitaciones en el acceso o uso de determinados servicios de la aplicación cuando el tratamiento sea necesario para su funcionamiento.

Declaración de consentimiento:
Mediante la marcación de las casillas correspondientes y la pulsación del botón “Firmar y aceptar consentimiento”, declaro haber leído y comprendido la presente información, y presto mi consentimiento expreso, libre, específico, informado e inequívoco para el tratamiento de mis datos personales en los términos indicados.
''';
