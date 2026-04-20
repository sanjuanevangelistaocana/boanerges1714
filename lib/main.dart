import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/firebase_config.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/config/routes.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: FirebaseConfig.currentPlatformOptions,
  );

  runApp(const BoanergesApp());
}

class BoanergesApp extends StatefulWidget {
  const BoanergesApp({super.key});

  @override
  State<BoanergesApp> createState() => _BoanergesAppState();
}

class _BoanergesAppState extends State<BoanergesApp> {
  late final AuthService _authService;
  late final FirestoreService _firestoreService;
  late final NotificationService _notificationService;
  late final goRouter;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _firestoreService = FirestoreService();
    _notificationService = NotificationService();
    _notificationService.initialize();
    goRouter = createRouter(_authService);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authService),
        Provider.value(value: _firestoreService),
        Provider.value(value: _notificationService),
      ],
      child: MaterialApp.router(
        title: 'Cofradía San Juan Evangelista - Ocaña',
        theme: AppTheme.lightTheme,
        routerConfig: goRouter,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
