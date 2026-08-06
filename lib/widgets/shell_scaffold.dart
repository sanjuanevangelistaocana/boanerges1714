import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/widgets/app_logo.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/models/content_models.dart';
import 'package:boanerges1714/services/content_service.dart';
import 'package:boanerges1714/config/responsive.dart';

class ShellScaffold extends StatelessWidget {
  final Widget child;

  const ShellScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final isLoggedIn = authService.isLoggedIn;
    final isAdmin = authService.isAdmin;
    final isDesktop = context.responsive.isWideDesktop;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        centerTitle: false,
        titleSpacing: 16,
        title: GestureDetector(
          onTap: () => context.go('/'),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogo(
                  size: 28, compact: true, fallbackColor: AppTheme.accentColor),
              const SizedBox(width: 8),
              const Text('Cofradía San Juan Evangelista'),
            ],
          ),
        ),
        actions: isDesktop
            ? [
                _DesktopNavigation(isLoggedIn: isLoggedIn, isAdmin: isAdmin),
              ]
            : null,
      ),
      drawer: isDesktop ? null : _buildDrawer(context, isLoggedIn, isAdmin),
      body: Column(
        children: [
          if (_shouldShowBreadcrumbs(context)) const _Breadcrumbs(),
          Expanded(child: child),
          const _InstitutionalFooter(),
        ],
      ),
    );
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
                const AppLogo(size: 40, fallbackColor: AppTheme.accentColor),
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
          const _DrawerSectionGroups(),
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
              icon: Icons.share,
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
                icon: Icons.fitness_center,
                label: 'Turnos de Andas',
                route: '/turnos-andas'),
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
            const _DrawerAccessButton(),
        ],
      ),
    );
  }
}

class _DesktopNavigation extends StatelessWidget {
  final bool isLoggedIn;
  final bool isAdmin;

  const _DesktopNavigation({
    required this.isLoggedIn,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: _desktopNavigationItems(context, isLoggedIn, isAdmin),
        ),
      ),
    );
  }
}

List<Widget> _desktopNavigationItems(
    BuildContext context, bool isLoggedIn, bool isAdmin) {
  return [
    _NavGroup(
      children: [
        _NavButton(label: 'Inicio', route: '/'),
        const _SectionNavMenu(
          slug: 'cofradia',
          label: 'Cofradía',
          fallback: [
            _SectionNavEntry('Historia', 'historia'),
            _SectionNavEntry('Reglas', 'reglas'),
            _SectionNavEntry('La Parroquia', 'la-parroquia'),
            _SectionNavEntry('Junta de Gobierno', 'junta-de-gobierno'),
            _SectionNavEntry('Grupos', 'grupos'),
          ],
        ),
        const _SectionNavMenu(
          slug: 'patrimonio',
          label: 'Patrimonio',
          fallback: [
            _SectionNavEntry('Archivo Histórico', 'archivo-historico'),
            _SectionNavEntry('Patrimonio Artístico', 'patrimonio-artistico'),
          ],
        ),
        _NavButton(
            label: 'Eventos', route: isLoggedIn ? '/eventos' : '/events'),
        _NavButton(label: 'Noticias', route: '/news'),
        _NavButton(label: 'Galería', route: '/gallery'),
        _NavButton(label: 'Contacto', route: '/contact'),
      ],
    ),
    const SizedBox(width: 10),
    _NavGroup(
      secondary: true,
      children: [
        _NavButton(label: 'Redes Sociales', route: '/social-media'),
        _NavButton(label: 'La Rosa', route: '/la-rosa'),
        _NavButton(label: 'Revista Boanerges', route: '/boanerges'),
      ],
    ),
    if (isLoggedIn) ...[
      const SizedBox(width: 10),
      _NavGroup(
        secondary: true,
        children: [
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
        ],
      ),
    ] else ...[
      const SizedBox(width: 10),
      _NavButton(label: 'Acceso Cofrades', route: '/login', prominent: true),
    ],
    const SizedBox(width: 8),
  ];
}

class _SectionNavEntry {
  final String label;
  final String slug;

  const _SectionNavEntry(this.label, this.slug);
}

class _SectionNavMenu extends StatelessWidget {
  final String slug;
  final String label;
  final List<_SectionNavEntry> fallback;

  const _SectionNavMenu({
    required this.slug,
    required this.label,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ContentSection>>(
      stream: context.read<ContentService>().publishedSectionsStream,
      builder: (context, snapshot) {
        final all = snapshot.data ?? const <ContentSection>[];
        final matchingRoots =
            all.where((section) => section.slug == slug).toList();
        final root = matchingRoots.isEmpty ? null : matchingRoots.first;
        final dynamicEntries = root == null
            ? <_SectionNavEntry>[]
            : all
                .where((section) => section.parentId == root.id)
                .map((section) => _SectionNavEntry(section.title, section.slug))
                .toList();
        final entries = dynamicEntries.isEmpty ? fallback : dynamicEntries;
        final path = GoRouterState.of(context).uri.path;
        final selected = path == '/$slug' || path.startsWith('/$slug/');
        return PopupMenuButton<String>(
          tooltip: label,
          onSelected: (sectionSlug) => context.go('/$slug/$sectionSlug'),
          itemBuilder: (_) => entries
              .map((entry) => PopupMenuItem<String>(
                    value: entry.slug,
                    child: Text(entry.label),
                  ))
              .toList(),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: selected ? AppTheme.accentColor : Colors.transparent,
                  width: 2.5,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 12.5)),
                const SizedBox(width: 2),
                const Icon(Icons.expand_more, color: Colors.white, size: 18),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DrawerSectionGroups extends StatelessWidget {
  const _DrawerSectionGroups();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ContentSection>>(
      stream: context.read<ContentService>().publishedSectionsStream,
      builder: (context, snapshot) {
        final all = snapshot.data ?? const <ContentSection>[];
        final roots = all.where((section) => section.parentId == null).toList();
        if (roots.isEmpty) {
          return Column(
            children: const [
              _DrawerStaticSection(
                title: 'Cofradía',
                rootSlug: 'cofradia',
                children: [
                  _SectionNavEntry('Historia', 'historia'),
                  _SectionNavEntry('Reglas', 'reglas'),
                  _SectionNavEntry('La Parroquia', 'la-parroquia'),
                  _SectionNavEntry('Junta de Gobierno', 'junta-de-gobierno'),
                  _SectionNavEntry('Grupos', 'grupos'),
                ],
              ),
              _DrawerStaticSection(
                title: 'Patrimonio',
                rootSlug: 'patrimonio',
                children: [
                  _SectionNavEntry('Archivo Histórico', 'archivo-historico'),
                  _SectionNavEntry(
                      'Patrimonio Artístico', 'patrimonio-artistico'),
                ],
              ),
            ],
          );
        }
        return Column(
          children: roots.map((root) {
            final children =
                all.where((section) => section.parentId == root.id).toList();
            if (children.isEmpty) {
              final fallback = root.slug == 'patrimonio'
                  ? const [
                      _SectionNavEntry(
                          'Archivo Histórico', 'archivo-historico'),
                      _SectionNavEntry(
                          'Patrimonio Artístico', 'patrimonio-artistico'),
                    ]
                  : const [
                      _SectionNavEntry('Historia', 'historia'),
                      _SectionNavEntry('Reglas', 'reglas'),
                      _SectionNavEntry('La Parroquia', 'la-parroquia'),
                      _SectionNavEntry(
                          'Junta de Gobierno', 'junta-de-gobierno'),
                      _SectionNavEntry('Grupos', 'grupos'),
                    ];
              return _DrawerStaticSection(
                title: root.title,
                rootSlug: root.slug,
                children: fallback,
              );
            }
            return ExpansionTile(
              leading: const Icon(Icons.account_tree_outlined),
              title: Text(root.title),
              children: children
                  .map((section) => ListTile(
                        selected: _isCurrentRoute(
                            context, '/${root.slug}/${section.slug}'),
                        selectedColor: AppTheme.primaryColor,
                        title: Text(section.title),
                        minTileHeight: 48,
                        contentPadding:
                            const EdgeInsets.only(left: 56, right: 16),
                        onTap: () {
                          Navigator.pop(context);
                          context.go('/${root.slug}/${section.slug}');
                        },
                      ))
                  .toList(),
            );
          }).toList(),
        );
      },
    );
  }
}

class _DrawerStaticSection extends StatelessWidget {
  final String title;
  final String rootSlug;
  final List<_SectionNavEntry> children;

  const _DrawerStaticSection({
    required this.title,
    required this.rootSlug,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: const Icon(Icons.account_tree_outlined),
      title: Text(title),
      children: children
          .map((child) => ListTile(
                selected: _isCurrentRoute(context, '/$rootSlug/${child.slug}'),
                selectedColor: AppTheme.primaryColor,
                title: Text(child.label),
                minTileHeight: 48,
                contentPadding: const EdgeInsets.only(left: 56, right: 16),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/$rootSlug/${child.slug}');
                },
              ))
          .toList(),
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
  final bool prominent;

  const _NavButton({
    required this.label,
    required this.route,
    this.prominent = false,
  });

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final selected = path == route || path.startsWith('$route/');
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) == true;
    return TextButton(
      onPressed: () => context.go(route),
      style: TextButton.styleFrom(
        foregroundColor: prominent ? AppTheme.primaryColor : Colors.white,
        minimumSize: const Size(48, 48),
        padding: EdgeInsets.symmetric(horizontal: prominent ? 14 : 10),
        backgroundColor: prominent ? AppTheme.surfaceColor : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        overlayColor: prominent
            ? AppTheme.accentColor.withAlpha(25)
            : Colors.white.withAlpha(18),
      ),
      child: AnimatedContainer(
        duration: disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(
          vertical: prominent ? 7 : 0,
          horizontal: prominent ? 2 : 0,
        ),
        decoration: BoxDecoration(
          border: prominent
              ? null
              : Border(
                  bottom: BorderSide(
                    color: selected ? AppTheme.accentColor : Colors.transparent,
                    width: 2.5,
                  ),
                ),
        ),
        child: Text(label,
            style: TextStyle(
              color: prominent ? AppTheme.primaryColor : Colors.white,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              fontSize: 12.5,
            )),
      ),
    );
  }
}

class _NavGroup extends StatelessWidget {
  final List<Widget> children;
  final bool secondary;

  const _NavGroup({
    required this.children,
    this.secondary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      decoration: BoxDecoration(
        color: secondary ? Colors.white.withAlpha(10) : Colors.black12,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(22)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
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
      selected: _isCurrentRoute(context, route),
      selectedColor: AppTheme.primaryColor,
      minTileHeight: 48,
      leading: Icon(icon),
      title: Text(label),
      onTap: () {
        Navigator.pop(context);
        context.go(route);
      },
    );
  }
}

class _DrawerAccessButton extends StatelessWidget {
  const _DrawerAccessButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: ListTile(
        minTileHeight: 48,
        leading: const Icon(Icons.login, color: AppTheme.primaryColor),
        title: const Text(
          'Acceso Cofrades',
          style: TextStyle(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        tileColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        onTap: () {
          Navigator.pop(context);
          context.go('/login');
        },
      ),
    );
  }
}

bool _isCurrentRoute(BuildContext context, String route) {
  final path = GoRouterState.of(context).uri.path;
  return path == route || path.startsWith('$route/');
}

class _InstitutionalFooter extends StatelessWidget {
  const _InstitutionalFooter();

  @override
  Widget build(BuildContext context) {
    final isMobile = context.responsive.isMobile;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 10 : 16,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceContainerLowColor,
        border: Border(top: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: isMobile ? 4 : 16,
        runSpacing: isMobile ? 0 : 8,
        children: [
          Text(
            '© ${DateTime.now().year} Cofradía San Juan Evangelista de Ocaña. '
            'Todos los derechos reservados.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          TextButton(
            onPressed: () => context.go('/aviso-legal'),
            style: isMobile
                ? TextButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )
                : null,
            child: const Text('Aviso Legal'),
          ),
          TextButton(
            onPressed: () => context.go('/politica-privacidad'),
            style: isMobile
                ? TextButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )
                : null,
            child: const Text('Política de Privacidad'),
          ),
          TextButton(
            onPressed: () => context.go('/politica-cookies'),
            style: isMobile
                ? TextButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )
                : null,
            child: const Text('Política de Cookies'),
          ),
        ],
      ),
    );
  }
}
