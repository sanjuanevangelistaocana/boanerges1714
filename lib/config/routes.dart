import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:boanerges1714/screens/public/home_screen.dart';
import 'package:boanerges1714/screens/public/history_screen.dart';
import 'package:boanerges1714/screens/public/events_screen.dart';
import 'package:boanerges1714/screens/public/news_screen.dart';
import 'package:boanerges1714/screens/public/contact_screen.dart';
import 'package:boanerges1714/screens/public/gallery_screen.dart';
import 'package:boanerges1714/screens/private/login_screen.dart';
import 'package:boanerges1714/screens/private/register_screen.dart';
import 'package:boanerges1714/screens/private/profile_screen.dart';
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
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/widgets/shell_scaffold.dart';

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

      final privateRoutes = ['/dashboard', '/profile', '/cuotas', '/documents', '/convocatorias', '/sugerencias', '/tunicas', '/tablon', '/banco-tunicas', '/festividad'];
      if (privateRoutes.any((r) => path.startsWith(r)) && !isLoggedIn) {
        return '/login';
      }

      if (path.startsWith('/admin') && !isAdmin) {
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
          GoRoute(path: '/history', builder: (context, state) => const HistoryScreen()),
          GoRoute(path: '/events', builder: (context, state) => const EventsScreen()),
          GoRoute(path: '/news', builder: (context, state) => const NewsScreen()),
          GoRoute(path: '/gallery', builder: (context, state) => const GalleryScreen()),
          GoRoute(path: '/contact', builder: (context, state) => const ContactScreen()),
          GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
          GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
          GoRoute(path: '/cuotas', builder: (context, state) => const CuotasScreen()),
          GoRoute(path: '/documents', builder: (context, state) => const DocumentsScreen()),
          GoRoute(path: '/admin', builder: (context, state) => const AdminDashboardScreen()),
          GoRoute(path: '/admin/cofrades', builder: (context, state) => const ManageCofradesScreen()),
          GoRoute(path: '/admin/events', builder: (context, state) => const ManageEventsScreen()),
          GoRoute(path: '/admin/news', builder: (context, state) => const ManageNewsScreen()),
          GoRoute(path: '/admin/notifications', builder: (context, state) => const SendNotificationScreen()),
          GoRoute(path: '/admin/solicitudes', builder: (context, state) => const ManageSolicitudesScreen()),
          GoRoute(path: '/admin/convocatorias', builder: (context, state) => const ManageConvocatoriasScreen()),
          GoRoute(path: '/convocatorias', builder: (context, state) => const ConvocatoriasScreen()),
          GoRoute(path: '/sugerencias', builder: (context, state) => const SugerenciasScreen()),
          GoRoute(path: '/tunicas', builder: (context, state) => const TunicasScreen()),
          GoRoute(path: '/social-media', builder: (context, state) => const SocialMediaScreen()),
          GoRoute(path: '/la-rosa', builder: (context, state) => const LaRosaScreen()),
          GoRoute(path: '/boanerges', builder: (context, state) => const BoanergesScreen()),
          GoRoute(path: '/admin/sugerencias', builder: (context, state) => const ManageSugerenciasScreen()),
          GoRoute(path: '/admin/tunicas', builder: (context, state) => const ManageTunicasScreen()),
          GoRoute(path: '/admin/documentos', builder: (context, state) => const ManageDocumentosScreen()),
          GoRoute(path: '/admin/tablon', builder: (context, state) => const ManageTablonScreen()),
          GoRoute(path: '/tablon', builder: (context, state) => const TablonScreen()),
          GoRoute(path: '/banco-tunicas', builder: (context, state) => const BancoTunicasScreen()),
          GoRoute(path: '/banco-tunicas/publicar-oferta', builder: (context, state) => const PublicarOfertaScreen()),
          GoRoute(path: '/banco-tunicas/publicar-demanda', builder: (context, state) => const PublicarDemandaScreen()),
          GoRoute(path: '/admin/banco-tunicas', builder: (context, state) => const ManageBancoTunicasScreen()),
          GoRoute(path: '/festividad', builder: (context, state) => const FestividadScreen()),
          GoRoute(path: '/festividad/inscripcion', builder: (context, state) {
            final edicionId = state.uri.queryParameters['edicionId'] ?? '';
            final inscripcionId = state.uri.queryParameters['inscripcionId'];
            return InscripcionFestividadScreen(edicionId: edicionId, inscripcionId: inscripcionId);
          }),
          GoRoute(path: '/admin/festividad', builder: (context, state) => const ManageFestividadScreen()),
          GoRoute(path: '/admin/festividad/menus', builder: (context, state) {
            final edicionId = state.uri.queryParameters['edicionId'] ?? '';
            return ManageMenusFestividadScreen(edicionId: edicionId);
          }),
          GoRoute(path: '/admin/festividad/inscripciones', builder: (context, state) {
            final edicionId = state.uri.queryParameters['edicionId'] ?? '';
            return ManageInscripcionesFestividadScreen(edicionId: edicionId);
          }),
          GoRoute(path: '/admin/festividad/informe', builder: (context, state) {
            final edicionId = state.uri.queryParameters['edicionId'] ?? '';
            return InformeFestividadScreen(edicionId: edicionId);
          }),
        ],
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/solicitud-alta', builder: (context, state) => const SolicitudAltaScreen()),
    ],
  );
}
