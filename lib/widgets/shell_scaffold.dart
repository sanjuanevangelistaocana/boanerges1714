import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/config/theme.dart';

class ShellScaffold extends StatelessWidget {
  final Widget child;

  const ShellScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final isLoggedIn = authService.isLoggedIn;
    final isAdmin = authService.isAdmin;
    final isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => context.go('/'),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.church, color: AppTheme.accentColor, size: 28),
              const SizedBox(width: 8),
              const Text('Cofradía San Juan Evangelista'),
            ],
          ),
        ),
        actions: isWide ? _buildDesktopNav(context, isLoggedIn, isAdmin) : null,
      ),
      drawer: isWide ? null : _buildDrawer(context, isLoggedIn, isAdmin),
      body: Column(
        children: [
          if (_shouldShowBreadcrumbs(context)) const _Breadcrumbs(),
          Expanded(child: child),
        ],
      ),
    );
  }

  List<Widget> _buildDesktopNav(
      BuildContext context, bool isLoggedIn, bool isAdmin) {
    return [
      _NavButton(label: 'Inicio', route: '/'),
      _NavButton(label: 'Historia', route: '/history'),
      _NavButton(label: 'Eventos', route: isLoggedIn ? '/eventos' : '/events'),
      _NavButton(label: 'Noticias', route: '/news'),
      _NavButton(label: 'Galería', route: '/gallery'),
      _NavButton(label: 'Contacto', route: '/contact'),
      PopupMenuButton<String>(
        tooltip: 'Más secciones',
        icon: const Icon(Icons.more_horiz, color: Colors.white),
        onSelected: (route) => context.go(route),
        itemBuilder: (_) => [
          const PopupMenuItem(
              value: '/social-media', child: Text('Redes Sociales')),
          const PopupMenuItem(value: '/la-rosa', child: Text('La Rosa')),
          const PopupMenuItem(
              value: '/boanerges', child: Text('Revista Boanerges')),
        ],
      ),
      if (isLoggedIn) ...[
        _NavButton(label: 'Mi Zona', route: '/dashboard'),
        if (context.watch<AuthService>().canViewTreasury)
          _NavButton(label: 'Tesorería', route: '/treasury'),
        _PrivateZoneMenu(),
        if (isAdmin) _NavButton(label: 'Admin', route: '/admin'),
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white70),
          onPressed: () => context.read<AuthService>().signOut(),
          tooltip: 'Cerrar sesión',
        ),
      ] else
        _NavButton(label: 'Acceder', route: '/login'),
      const SizedBox(width: 8),
    ];
  }

  Widget _buildDrawer(BuildContext context, bool isLoggedIn, bool isAdmin) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppTheme.primaryColor),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.church, color: AppTheme.accentColor, size: 40),
                const SizedBox(height: 8),
                const Text(
                  'Cofradía de\nSan Juan Evangelista',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                const Text(
                  'Ocaña · Fundada en 1714',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          _DrawerItem(icon: Icons.home, label: 'Inicio', route: '/'),
          _DrawerItem(
              icon: Icons.history_edu, label: 'Historia', route: '/history'),
          _DrawerItem(
              icon: Icons.event,
              label: 'Eventos',
              route: isLoggedIn ? '/eventos' : '/events'),
          _DrawerItem(icon: Icons.newspaper, label: 'Noticias', route: '/news'),
          _DrawerItem(
              icon: Icons.photo_library, label: 'Galería', route: '/gallery'),
          _DrawerItem(
              icon: Icons.contact_mail, label: 'Contacto', route: '/contact'),
          _DrawerItem(
              icon: Icons.camera_alt,
              label: 'Redes Sociales',
              route: '/social-media'),
          _DrawerItem(
              icon: Icons.local_florist, label: 'La Rosa', route: '/la-rosa'),
          _DrawerItem(
              icon: Icons.menu_book,
              label: 'Revista Boanerges',
              route: '/boanerges'),
          const Divider(),
          if (isLoggedIn) ...[
            _DrawerItem(
                icon: Icons.dashboard, label: 'Mi Zona', route: '/dashboard'),
            _DrawerItem(
                icon: Icons.person, label: 'Mi Perfil', route: '/profile'),
            _DrawerItem(
                icon: Icons.payment, label: 'Mis Cuotas', route: '/cuotas'),
            _DrawerItem(
                icon: Icons.folder, label: 'Documentos', route: '/documents'),
            _DrawerItem(
                icon: Icons.event_available,
                label: 'Eventos',
                route: '/eventos'),
            _DrawerItem(
                icon: Icons.how_to_vote,
                label: 'Encuestas',
                route: '/encuestas'),
            _DrawerItem(
                icon: Icons.lightbulb_outline,
                label: 'Mensajería',
                route: '/sugerencias'),
            _DrawerItem(
                icon: Icons.campaign, label: 'Tablón', route: '/tablon'),
            _DrawerItem(
                icon: Icons.checkroom, label: 'Túnicas', route: '/tunicas'),
            _DrawerItem(
                icon: Icons.confirmation_number,
                label: 'Lotería Navidad',
                route: '/loteria-disponibilidad'),
            _MiLoteriaDrawerItem(),
            if (context.watch<AuthService>().canViewTreasury)
              _DrawerItem(
                  icon: Icons.account_balance_wallet,
                  label: 'Tesorería',
                  route: '/treasury'),
            if (isAdmin) ...[
              const Divider(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text('ADMINISTRACIÓN',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
              _DrawerItem(
                  icon: Icons.admin_panel_settings,
                  label: 'Panel Admin',
                  route: '/admin'),
              _DrawerItem(
                  icon: Icons.people,
                  label: 'Cofrades',
                  route: '/admin/cofrades'),
              _DrawerItem(
                  icon: Icons.event_note,
                  label: 'Eventos',
                  route: '/admin/eventos'),
              _DrawerItem(
                  icon: Icons.article,
                  label: 'Gestionar Noticias',
                  route: '/admin/news'),
              _DrawerItem(
                  icon: Icons.notifications_active,
                  label: 'Notificaciones',
                  route: '/admin/notifications'),
              _DrawerItem(
                  icon: Icons.forum_outlined,
                  label: 'Mensajería',
                  route: '/admin/sugerencias'),
              _DrawerItem(
                  icon: Icons.confirmation_number,
                  label: 'Lotería Navidad',
                  route: '/admin/loteria'),
            ],
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Cerrar Sesión'),
              onTap: () {
                Navigator.pop(context);
                context.read<AuthService>().signOut();
                context.go('/');
              },
            ),
          ] else
            _DrawerItem(icon: Icons.login, label: 'Acceder', route: '/login'),
        ],
      ),
    );
  }
}

bool _shouldShowBreadcrumbs(BuildContext context) {
  final path = GoRouterState.of(context).uri.path;
  if (path == '/' ||
      path == '/login' ||
      path == '/register' ||
      path == '/verify-email' ||
      path == '/gdpr-consent') {
    return false;
  }
  return path.startsWith('/admin') ||
      path.startsWith('/dashboard') ||
      path.startsWith('/profile') ||
      path.startsWith('/documents') ||
      path.startsWith('/sugerencias') ||
      path.startsWith('/eventos') ||
      path.startsWith('/cuotas') ||
      path.startsWith('/treasury');
}

class _Breadcrumbs extends StatelessWidget {
  const _Breadcrumbs();

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final auth = context.watch<AuthService>();
    final items = _itemsForPath(path, auth);
    if (items.length <= 1) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade500),
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor:
                    i == items.length - 1 ? AppTheme.textSecondary : null,
              ),
              onPressed: i == items.length - 1
                  ? null
                  : () => context.go(items[i].path),
              child: Text(items[i].label, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  List<_BreadcrumbItem> _itemsForPath(String path, AuthService auth) {
    final homePath = !auth.isLoggedIn
        ? '/'
        : path.startsWith('/admin') && auth.isAdmin
            ? '/admin'
            : '/dashboard';
    final items = <_BreadcrumbItem>[_BreadcrumbItem('Inicio', homePath)];
    if (path.startsWith('/admin')) {
      items.add(_BreadcrumbItem('Administración', '/admin'));
      final adminLabels = {
        '/admin/cofrades': 'Gestión de Cofrades',
        '/admin/sugerencias': 'Mensajería',
        '/admin/solicitudes': 'Solicitudes',
        '/admin/documentos': 'Documentos',
        '/admin/eventos': 'Eventos',
        '/admin/events': 'Otros eventos',
        '/admin/festividad': 'Eventos · Festividad 27 de diciembre',
        '/admin/festividad/inscripciones': 'Inscripciones',
        '/admin/festividad/informe': 'Informe',
        '/admin/festividad/menus': 'Menús',
        '/admin/seguridad': 'Seguridad y permisos',
        '/admin/treasury': 'Tesorería',
      };
      final match = adminLabels.entries
          .where((entry) => path.startsWith(entry.key))
          .toList()
        ..sort((a, b) => a.key.length.compareTo(b.key.length));
      if (match.isNotEmpty) {
        final base = adminLabels['/admin/festividad'];
        if (path.startsWith('/admin/festividad/') && base != null) {
          items.add(_BreadcrumbItem(base, '/admin/festividad'));
        }
        final selected = match.last;
        if (items.every((item) => item.path != selected.key)) {
          items.add(_BreadcrumbItem(selected.value, selected.key));
        }
      }
      return items;
    }
    final privateLabels = {
      '/dashboard': 'Mi Zona',
      '/profile': 'Perfil',
      '/documents': 'Documentos',
      '/eventos': 'Eventos',
      '/festividad': 'Eventos · Festividad 27 de diciembre',
      '/festividad/inscripcion': 'Mi inscripción',
      '/sugerencias': 'Mensajería',
      '/cuotas': 'Mis cuotas',
      '/treasury': 'Tesorería',
    };
    final match = privateLabels.entries
        .where((entry) => path.startsWith(entry.key))
        .toList()
      ..sort((a, b) => a.key.length.compareTo(b.key.length));
    if (match.isNotEmpty) {
      if (path.startsWith('/festividad/') &&
          privateLabels['/festividad'] != null) {
        items
            .add(_BreadcrumbItem(privateLabels['/festividad']!, '/festividad'));
      }
      final selected = match.last;
      if (items.every((item) => item.path != selected.key)) {
        items.add(_BreadcrumbItem(selected.value, selected.key));
      }
    }
    return items;
  }
}

class _BreadcrumbItem {
  final String label;
  final String path;

  const _BreadcrumbItem(this.label, this.path);
}

class _NavButton extends StatelessWidget {
  final String label;
  final String route;

  const _NavButton({required this.label, required this.route});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => context.go(route),
      child: Text(label, style: const TextStyle(color: Colors.white)),
    );
  }
}

class _PrivateZoneMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final cofradeId = auth.cofrade?.id;
    final fs = context.read<FirestoreService>();
    return StreamBuilder<bool>(
      stream: cofradeId == null
          ? Stream.value(false)
          : fs.hasLoteriaAsignadaForCofrade(cofradeId),
      builder: (context, snap) {
        return PopupMenuButton<String>(
          tooltip: 'Zona privada',
          icon: const Icon(Icons.account_circle, color: Colors.white),
          onSelected: (route) => context.go(route),
          itemBuilder: (_) => [
            const PopupMenuItem(value: '/profile', child: Text('Mi Perfil')),
            const PopupMenuItem(value: '/documents', child: Text('Documentos')),
            const PopupMenuItem(
                value: '/sugerencias', child: Text('Mensajería')),
            const PopupMenuItem(value: '/eventos', child: Text('Eventos')),
            const PopupMenuItem(
                value: '/loteria-disponibilidad',
                child: Text('Lotería Navidad')),
            if (snap.data == true)
              const PopupMenuItem(value: '/loteria', child: Text('Mi Lotería')),
          ],
        );
      },
    );
  }
}

class _MiLoteriaDrawerItem extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final cofradeId = auth.cofrade?.id;
    final fs = context.read<FirestoreService>();
    return StreamBuilder<bool>(
      stream: cofradeId == null
          ? Stream.value(false)
          : fs.hasLoteriaAsignadaForCofrade(cofradeId),
      builder: (context, snap) {
        if (snap.data != true) return const SizedBox.shrink();
        return _DrawerItem(
            icon: Icons.sell, label: 'Mi Lotería', route: '/loteria');
      },
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;

  const _DrawerItem(
      {required this.icon, required this.label, required this.route});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () {
        Navigator.pop(context);
        context.go(route);
      },
    );
  }
}
