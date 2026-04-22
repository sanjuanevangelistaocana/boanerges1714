import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseConfig {
  static FirebaseOptions get currentPlatformOptions {
    if (kIsWeb) {
      return webOptions;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return androidOptions;
      default:
        return webOptions;
    }
  }

  static const FirebaseOptions webOptions = FirebaseOptions(
    apiKey: 'AIzaSyAD5m7hGD_xQ3r4D4NqOmI5QIyJmA-GBFI',
    authDomain: 'boanerges1714.firebaseapp.com',
    projectId: 'boanerges1714',
    storageBucket: 'boanerges1714.firebasestorage.app',
    messagingSenderId: '409974473203',
    appId: '1:409974473203:web:41ae3c83dbf0cdfb931286',
    measurementId: 'G-BWE0S0D8EC',
  );

  static const FirebaseOptions androidOptions = FirebaseOptions(
    apiKey: 'AIzaSyAD5m7hGD_xQ3r4D4NqOmI5QIyJmA-GBFI',
    appId: '1:409974473203:web:41ae3c83dbf0cdfb931286',
    messagingSenderId: '409974473203',
    projectId: 'boanerges1714',
    storageBucket: 'boanerges1714.firebasestorage.app',
  );
}
