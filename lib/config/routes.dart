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
import 'package:boanerges1714/screens/public/solicitud_alta_screen.dart';
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

      final privateRoutes = ['/dashboard', '/profile', '/cuotas', '/documents', '/convocatorias'];
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
        ],
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/solicitud-alta', builder: (context, state) => const SolicitudAltaScreen()),
    ],
  );
}
