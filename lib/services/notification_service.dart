import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('Notificaciones autorizadas');
      await _getToken();
      _setupForegroundHandler();
    } else {
      print('Notificaciones no autorizadas');
    }
  }

  Future<String?> _getToken() async {
    String? token;
    if (kIsWeb) {
      // For web, you need a VAPID key from Firebase Console
      // token = await _messaging.getToken(vapidKey: 'YOUR_VAPID_KEY');
      token = await _messaging.getToken();
    } else {
      token = await _messaging.getToken();
    }
    if (token != null) {
      print('FCM Token: $token');
    }
    return token;
  }

  void _setupForegroundHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Mensaje recibido en primer plano: ${message.notification?.title}');
    });
  }

  Future<void> subscribeToTopic(String topic) async {
    if (!kIsWeb) {
      await _messaging.subscribeToTopic(topic);
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    if (!kIsWeb) {
      await _messaging.unsubscribeFromTopic(topic);
    }
  }
}
