import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:boanerges1714/screens/public/home_screen.dart';
import 'package:boanerges1714/screens/public/history_screen.dart';
import 'package:boanerges1714/screens/public/events_screen.dart';
import 'package:boanerges1714/screens/events/events_home_screen.dart';
import 'package:boanerges1714/screens/events/events_admin_screen.dart';
import 'package:boanerges1714/screens/public/news_screen.dart';
import 'package:boanerges1714/screens/public/contact_screen.dart';
import 'package:boanerges1714/screens/public/gallery_screen.dart';
import 'package:boanerges1714/screens/private/login_screen.dart';
import 'package:boanerges1714/screens/private/register_screen.dart';
import 'package:boanerges1714/screens/private/profile_screen.dart';
import 'package:boanerges1714/screens/private/gdpr_consent_screen.dart';
import 'package:boanerges1714/screens/private/access_disabled_screen.dart';
import 'package:boanerges1714/screens/private/email_verification_screen.dart';
import 'package:boanerges1714/screens/private/profile_selection_screen.dart';
import 'package:boanerges1714/screens/private/dashboard_screen.dart';
import 'package:boanerges1714/screens/private/cuotas_screen.dart';
import 'package:boanerges1714/screens/private/documents_screen.dart';
import 'package:boanerges1714/screens/admin/admin_dashboard_screen.dart';
import 'package:boanerges1714/screens/admin/manage_cofrades_screen.dart';
import 'package:boanerges1714/screens/admin/manage_events_screen.dart';
import 'package:boanerges1714/screens/admin/manage_news_screen.dart';
import 'package:boanerges1714/screens/admin/send_notification_screen.dart';
import 'package:boanerges1714/screens/admin/manage_solicitudes_screen.dart';
import 'package:boanerges1714/screens/admin/manage_convocatorias_screen.dart';
import 'package:boanerges1714/screens/private/convocatorias_screen.dart';
import 'package:boanerges1714/screens/private/sugerencias_screen.dart';
import 'package:boanerges1714/screens/private/tunicas_screen.dart';
import 'package:boanerges1714/screens/public/social_media_screen.dart';
import 'package:boanerges1714/screens/public/la_rosa_screen.dart';
import 'package:boanerges1714/screens/public/boanerges_screen.dart';
import 'package:boanerges1714/screens/public/solicitud_alta_screen.dart';
import 'package:boanerges1714/screens/admin/manage_sugerencias_screen.dart';
import 'package:boanerges1714/screens/admin/manage_tunicas_screen.dart';
import 'package:boanerges1714/screens/admin/manage_documentos_screen.dart';
import 'package:boanerges1714/screens/admin/manage_tablon_screen.dart';
import 'package:boanerges1714/screens/admin/manage_banco_tunicas_screen.dart';
import 'package:boanerges1714/screens/private/tablon_screen.dart';
import 'package:boanerges1714/screens/private/banco_tunicas_screen.dart';
import 'package:boanerges1714/screens/private/publicar_oferta_screen.dart';
import 'package:boanerges1714/screens/private/publicar_demanda_screen.dart';
import 'package:boanerges1714/screens/private/festividad/festividad_screen.dart';
import 'package:boanerges1714/screens/private/festividad/inscripcion_screen.dart';
import 'package:boanerges1714/screens/admin/festividad/manage_festividad_screen.dart';
import 'package:boanerges1714/screens/admin/festividad/manage_menus_screen.dart';
import 'package:boanerges1714/screens/admin/festividad/manage_inscripciones_screen.dart';
import 'package:boanerges1714/screens/admin/festividad/informe_festividad_screen.dart';
import 'package:boanerges1714/screens/admin/loteria/manage_loteria_screen.dart';
import 'package:boanerges1714/screens/admin/loteria/manage_sabanas_screen.dart';
import 'package:boanerges1714/screens/admin/loteria/manage_vendedores_screen.dart';
import 'package:boanerges1714/screens/admin/loteria/manage_asignaciones_screen.dart';
import 'package:boanerges1714/screens/admin/loteria/campana_dashboard_screen.dart';
import 'package:boanerges1714/screens/private/loteria/mi_loteria_screen.dart';
import 'package:boanerges1714/screens/private/loteria/asignacion_externa_screen.dart';
import 'package:boanerges1714/screens/private/loteria/disponibilidad_loteria_screen.dart';
import 'package:boanerges1714/screens/treasury/treasury_home_screen.dart';
import 'package:boanerges1714/screens/treasury/treasury_bank_validation_screen.dart';
import 'package:boanerges1714/screens/treasury/my_bank_validation_screen.dart';
import 'package:boanerges1714/screens/treasury/billing_and_collections_screen.dart';
import 'package:boanerges1714/screens/treasury/treasury_module_screens.dart';
import 'package:boanerges1714/screens/treasury/treasury_invoice_detail_screen.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/widgets/shell_scaffold.dart';
import 'package:boanerges1714/screens/admin/manage_encuestas_screen.dart';
import 'package:boanerges1714/screens/private/encuestas_screen.dart';
import 'package:boanerges1714/screens/public/news_detail_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final shellNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter(AuthService authService) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: authService,
    redirect: (context, state) {
      final isLoggedIn = authService.isLoggedIn;
      final isAdmin = authService.isAdmin;
      final path = state.matchedLocation;

      final privateRoutes = [
        '/dashboard',
        '/profile',
        '/cuotas',
        '/documents',
        '/eventos',
        '/encuestas',
        '/convocatorias',
        '/sugerencias',
        '/tunicas',
        '/tablon',
        '/banco-tunicas',
        '/festividad',
        '/loteria',
        '/loteria-disponibilidad',
        '/bank-validation',
        '/consent',
        '/select-profile',
        '/access-disabled',
        '/verify-email',
      ];
      if (privateRoutes.any((r) => path.startsWith(r)) && !isLoggedIn) {
        return '/login';
      }

      if (isLoggedIn &&
          authService.needsEmailVerification &&
          path != '/verify-email' &&
          path != '/access-disabled' &&
          path != '/consent' &&
          !path.startsWith('/admin')) {
        return '/verify-email';
      }

      if (isLoggedIn &&
          authService.needsProfileSelection &&
          path != '/select-profile' &&
          path != '/access-disabled' &&
          path != '/verify-email' &&
          !path.startsWith('/admin')) {
        return '/select-profile';
      }

      if (isLoggedIn &&
          authService.isAccessDisabled &&
          path != '/access-disabled' &&
          !path.startsWith('/admin')) {
        return '/access-disabled';
      }

      if (isLoggedIn &&
          authService.needsGdprConsent &&
          path != '/consent' &&
          path != '/access-disabled' &&
          !path.startsWith('/admin')) {
        return '/consent';
      }

      if (path.startsWith('/admin') && !isAdmin) {
        return isLoggedIn ? '/dashboard' : '/login';
      }

      if (path.startsWith('/treasury') && !authService.canViewTreasury) {
        return isLoggedIn ? '/dashboard' : '/login';
      }

      if ((path == '/login' || path == '/register') && isLoggedIn) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) => ShellScaffold(child: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          GoRoute(
              path: '/history',
              builder: (context, state) => const HistoryScreen()),
          GoRoute(
              path: '/events',
              builder: (context, state) => const EventsScreen()),
          GoRoute(
              path: '/eventos',
              builder: (context, state) => const EventsHomeScreen()),
          GoRoute(
              path: '/news', builder: (context, state) => const NewsScreen()),
          GoRoute(
              path: '/noticias',
              builder: (context, state) => const NewsScreen()),
          GoRoute(
              path: '/noticias/hemeroteca',
              builder: (context, state) => const HemerotecaScreen()),
          GoRoute(
              path: '/noticias/detalle',
              builder: (context, state) {
                final id = state.uri.queryParameters['id'];
                return NewsDetailScreen(id: id);
              }),
          GoRoute(
              path: '/noticias/:slug',
              builder: (context, state) {
                final slug = state.pathParameters['slug'];
                return NewsDetailScreen(slug: slug);
              }),
          GoRoute(
              path: '/gallery',
              builder: (context, state) => const GalleryScreen()),
          GoRoute(
              path: '/contact',
              builder: (context, state) => const ContactScreen()),
          GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardScreen()),
          GoRoute(
              path: '/consent',
              builder: (context, state) => const GdprConsentScreen()),
          GoRoute(
              path: '/select-profile',
              builder: (context, state) => const ProfileSelectionScreen()),
          GoRoute(
              path: '/access-disabled',
              builder: (context, state) => const AccessDisabledScreen()),
          GoRoute(
              path: '/verify-email',
              builder: (context, state) => const EmailVerificationScreen()),
          GoRoute(
              path: '/profile',
              builder: (context, state) => ProfileScreen(
                    startEditing: state.uri.queryParameters['editBank'] == '1',
                  )),
          GoRoute(
              path: '/cuotas',
              builder: (context, state) => const CuotasScreen()),
          GoRoute(
              path: '/documents',
              builder: (context, state) => const DocumentsScreen()),
          GoRoute(
              path: '/admin',
              builder: (context, state) => const AdminDashboardScreen()),
          GoRoute(
              path: '/admin/cofrades',
              builder: (context, state) => const ManageCofradesScreen()),
          GoRoute(
              path: '/admin/events',
              builder: (context, state) => const ManageEventsScreen()),
          GoRoute(
              path: '/admin/eventos',
              builder: (context, state) => const EventsAdminScreen()),
          GoRoute(
              path: '/admin/news',
              builder: (context, state) => const ManageNewsScreen()),
          GoRoute(
              path: '/admin/noticias',
              builder: (context, state) => const ManageNewsScreen()),
          GoRoute(
              path: '/admin/notifications',
              builder: (context, state) => const SendNotificationScreen()),
          GoRoute(
              path: '/admin/solicitudes',
              builder: (context, state) => const ManageSolicitudesScreen()),
          GoRoute(
              path: '/admin/convocatorias',
              builder: (context, state) => const ManageConvocatoriasScreen()),
          GoRoute(
              path: '/admin/encuestas',
              builder: (context, state) => const ManageEncuestasScreen()),
          GoRoute(
              path: '/encuestas',
              builder: (context, state) {
                final surveyId = state.uri.queryParameters['surveyId'];
                return EncuestasScreen(highlightSurveyId: surveyId);
              }),
          GoRoute(
              path: '/convocatorias',
              builder: (context, state) => const ConvocatoriasScreen()),
          GoRoute(
              path: '/sugerencias',
              builder: (context, state) => const SugerenciasScreen()),
          GoRoute(
              path: '/tunicas',
              builder: (context, state) => const TunicasScreen()),
          GoRoute(
              path: '/social-media',
              builder: (context, state) => const SocialMediaScreen()),
          GoRoute(
              path: '/la-rosa',
              builder: (context, state) => const LaRosaScreen()),
          GoRoute(
              path: '/boanerges',
              builder: (context, state) => const BoanergesScreen()),
          GoRoute(
              path: '/admin/sugerencias',
              builder: (context, state) => const ManageSugerenciasScreen()),
          GoRoute(
              path: '/admin/tunicas',
              builder: (context, state) => const ManageTunicasScreen()),
          GoRoute(
              path: '/admin/documentos',
              builder: (context, state) => const ManageDocumentosScreen()),
          GoRoute(
              path: '/admin/tablon',
              builder: (context, state) => const ManageTablonScreen()),
          GoRoute(
              path: '/tablon',
              builder: (context, state) => const TablonScreen()),
          GoRoute(
              path: '/banco-tunicas',
              builder: (context, state) => const BancoTunicasScreen()),
          GoRoute(
              path: '/banco-tunicas/publicar-oferta',
              builder: (context, state) => const PublicarOfertaScreen()),
          GoRoute(
              path: '/banco-tunicas/publicar-demanda',
              builder: (context, state) => const PublicarDemandaScreen()),
          GoRoute(
              path: '/admin/banco-tunicas',
              builder: (context, state) => const ManageBancoTunicasScreen()),
          GoRoute(
              path: '/festividad',
              builder: (context, state) => const FestividadScreen()),
          GoRoute(
              path: '/festividad/inscripcion',
              builder: (context, state) {
                final edicionId = state.uri.queryParameters['edicionId'] ?? '';
                final inscripcionId =
                    state.uri.queryParameters['inscripcionId'];
                return InscripcionFestividadScreen(
                    edicionId: edicionId, inscripcionId: inscripcionId);
              }),
          GoRoute(
              path: '/admin/festividad',
              builder: (context, state) => const ManageFestividadScreen()),
          GoRoute(
              path: '/admin/festividad/menus',
              builder: (context, state) {
                final edicionId = state.uri.queryParameters['edicionId'] ?? '';
                return ManageMenusFestividadScreen(edicionId: edicionId);
              }),
          GoRoute(
              path: '/admin/festividad/inscripciones',
              builder: (context, state) {
                final edicionId = state.uri.queryParameters['edicionId'] ?? '';
                return ManageInscripcionesFestividadScreen(
                    edicionId: edicionId);
              }),
          GoRoute(
              path: '/admin/festividad/informe',
              builder: (context, state) {
                final edicionId = state.uri.queryParameters['edicionId'] ?? '';
                return InformeFestividadScreen(edicionId: edicionId);
              }),
          GoRoute(
              path: '/admin/loteria',
              builder: (context, state) => const ManageLoteriaScreen()),
          GoRoute(
              path: '/admin/loteria/dashboard',
              builder: (context, state) {
                final campanaId = state.uri.queryParameters['campanaId'] ?? '';
                return CampanaDashboardScreen(campanaId: campanaId);
              }),
          GoRoute(
              path: '/admin/loteria/sabanas',
              builder: (context, state) {
                final campanaId = state.uri.queryParameters['campanaId'] ?? '';
                return ManageSabanasScreen(campanaId: campanaId);
              }),
          GoRoute(
              path: '/admin/loteria/vendedores',
              builder: (context, state) =>
                  const ManageVendedoresLoteriaScreen()),
          GoRoute(
              path: '/admin/loteria/asignaciones',
              builder: (context, state) {
                final campanaId = state.uri.queryParameters['campanaId'] ?? '';
                return ManageAsignacionesScreen(campanaId: campanaId);
              }),
          GoRoute(
              path: '/loteria',
              builder: (context, state) => const MiLoteriaScreen()),
          GoRoute(
              path: '/loteria-disponibilidad',
              builder: (context, state) => const DisponibilidadLoteriaScreen()),
          GoRoute(
              path: '/bank-validation',
              builder: (context, state) => const MyBankValidationScreen()),
          GoRoute(
              path: '/loteria/asignacion/:token',
              builder: (context, state) {
                final token = state.pathParameters['token'] ?? '';
                return AsignacionExternaScreen(token: token);
              }),
          GoRoute(
              path: '/treasury',
              builder: (context, state) => const TreasuryHomeScreen()),
          GoRoute(
            path: '/treasury/billing',
            builder: (context, state) => const BillingAndCollectionsScreen(),
          ),
          GoRoute(
            path: '/treasury/bank-validation',
            builder: (context, state) => const TreasuryBankValidationScreen(),
          ),
          GoRoute(
            path: '/treasury/tracking',
            builder: (context, state) => const IndividualTrackingScreen(),
          ),
          GoRoute(
            path: '/treasury/accounting',
            builder: (context, state) => const AccountingScreen(),
          ),
          GoRoute(
            path: '/treasury/control',
            builder: (context, state) => const TreasuryControlScreen(),
          ),
          GoRoute(
            path: '/treasury/settings',
            redirect: (context, state) => '/treasury/billing',
          ),
          GoRoute(
            path: '/treasury/invoices/:invoiceId',
            builder: (context, state) => TreasuryInvoiceDetailScreen(
              invoiceId: state.pathParameters['invoiceId'] ?? '',
            ),
          ),
        ],
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen()),
      GoRoute(
          path: '/solicitud-alta',
          builder: (context, state) => const SolicitudAltaScreen()),
    ],
  );
}
