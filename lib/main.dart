import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:boanerges1714/config/firebase_config.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/config/routes.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/services/events_service.dart';
import 'package:boanerges1714/services/notification_service.dart';
import 'package:boanerges1714/services/storage_service.dart';
import 'package:boanerges1714/services/treasury/treasury_accounting_service.dart';
import 'package:boanerges1714/services/treasury/treasury_audit_service.dart';
import 'package:boanerges1714/services/treasury/treasury_bank_validation_service.dart';
import 'package:boanerges1714/services/treasury/treasury_invoice_service.dart';
import 'package:boanerges1714/services/treasury/treasury_payment_service.dart';
import 'package:boanerges1714/services/treasury/treasury_pdf_service.dart';
import 'package:boanerges1714/services/treasury/treasury_repository.dart';
import 'package:boanerges1714/services/treasury/treasury_remittance_service.dart';
import 'package:boanerges1714/services/treasury/treasury_settings_service.dart';
import 'package:boanerges1714/services/encuesta_service.dart';
import 'package:boanerges1714/services/noticias_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: FirebaseConfig.currentPlatformOptions,
  );

  await initializeDateFormatting('es_ES', null);

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
  late final EventsService _eventsService;
  late final StorageService _storageService;
  late final NotificationService _notificationService;
  late final TreasuryRepository _treasuryRepository;
  late final TreasurySettingsService _treasurySettingsService;
  late final TreasuryInvoiceService _treasuryInvoiceService;
  late final TreasuryBankValidationService _treasuryBankValidationService;
  late final TreasuryPaymentService _treasuryPaymentService;
  late final TreasuryPdfService _treasuryPdfService;
  late final TreasuryRemittanceService _treasuryRemittanceService;
  late final TreasuryAccountingService _treasuryAccountingService;
  late final TreasuryAuditService _treasuryAuditService;
  late final EncuestaService _encuestaService;
  late final NoticiasService _noticiasService;
  late final GoRouter goRouter;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _firestoreService = FirestoreService();
    _eventsService = EventsService();
    _storageService = StorageService();
    _notificationService = NotificationService();
    _treasuryRepository = TreasuryRepository();
    _treasurySettingsService =
        TreasurySettingsService(repository: _treasuryRepository);
    _treasuryInvoiceService =
        TreasuryInvoiceService(repository: _treasuryRepository);
    _treasuryBankValidationService =
        TreasuryBankValidationService(repository: _treasuryRepository);
    _treasuryPaymentService =
        TreasuryPaymentService(repository: _treasuryRepository);
    _treasuryPdfService = TreasuryPdfService(
      repository: _treasuryRepository,
      storageService: _storageService,
    );
    _treasuryRemittanceService = TreasuryRemittanceService(
      repository: _treasuryRepository,
      storageService: _storageService,
    );
    _treasuryAccountingService =
        TreasuryAccountingService(repository: _treasuryRepository);
    _treasuryAuditService =
        TreasuryAuditService(repository: _treasuryRepository);
    _encuestaService = EncuestaService();
    _noticiasService = NoticiasService();
    _notificationService.initialize();
    goRouter = createRouter(_authService);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authService),
        Provider.value(value: _firestoreService),
        Provider.value(value: _eventsService),
        Provider.value(value: _storageService),
        Provider.value(value: _notificationService),
        Provider.value(value: _treasuryRepository),
        Provider.value(value: _treasurySettingsService),
        Provider.value(value: _treasuryInvoiceService),
        Provider.value(value: _treasuryBankValidationService),
        Provider.value(value: _treasuryPaymentService),
        Provider.value(value: _treasuryPdfService),
        Provider.value(value: _treasuryRemittanceService),
        Provider.value(value: _treasuryAccountingService),
        Provider.value(value: _treasuryAuditService),
        Provider.value(value: _encuestaService),
        Provider.value(value: _noticiasService),
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
