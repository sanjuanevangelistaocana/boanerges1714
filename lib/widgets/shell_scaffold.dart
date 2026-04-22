import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/services/auth_service.dart';
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
      body: child,
    );
  }

  List<Widget> _buildDesktopNav(BuildContext context, bool isLoggedIn, bool isAdmin) {
    return [
      _NavButton(label: 'Inicio', route: '/'),
      _NavButton(label: 'Historia', route: '/history'),
      _NavButton(label: 'Eventos', route: '/events'),
      _NavButton(label: 'Noticias', route: '/news'),
      _NavButton(label: 'Galería', route: '/gallery'),
      _NavButton(label: 'Contacto', route: '/contact'),
      if (isLoggedIn) ...[
        _NavButton(label: 'Mi Zona', route: '/dashboard'),
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
          _DrawerItem(icon: Icons.history_edu, label: 'Historia', route: '/history'),
          _DrawerItem(icon: Icons.event, label: 'Eventos', route: '/events'),
          _DrawerItem(icon: Icons.newspaper, label: 'Noticias', route: '/news'),
          _DrawerItem(icon: Icons.photo_library, label: 'Galería', route: '/gallery'),
          _DrawerItem(icon: Icons.contact_mail, label: 'Contacto', route: '/contact'),
          const Divider(),
          if (isLoggedIn) ...[
            _DrawerItem(icon: Icons.dashboard, label: 'Mi Zona', route: '/dashboard'),
            _DrawerItem(icon: Icons.person, label: 'Mi Perfil', route: '/profile'),
            _DrawerItem(icon: Icons.payment, label: 'Mis Cuotas', route: '/cuotas'),
            _DrawerItem(icon: Icons.folder, label: 'Documentos', route: '/documents'),
            if (isAdmin) ...[
              const Divider(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text('ADMINISTRACIÓN',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
              _DrawerItem(icon: Icons.admin_panel_settings, label: 'Panel Admin', route: '/admin'),
              _DrawerItem(icon: Icons.people, label: 'Cofrades', route: '/admin/cofrades'),
              _DrawerItem(icon: Icons.event_note, label: 'Gestionar Eventos', route: '/admin/events'),
              _DrawerItem(icon: Icons.article, label: 'Gestionar Noticias', route: '/admin/news'),
              _DrawerItem(icon: Icons.notifications_active, label: 'Notificaciones', route: '/admin/notifications'),
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

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;

  const _DrawerItem({required this.icon, required this.label, required this.route});

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
