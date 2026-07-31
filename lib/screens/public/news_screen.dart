import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/models/noticia.dart';
import 'package:boanerges1714/services/noticias_service.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/config/responsive.dart';
import 'package:boanerges1714/widgets/responsive_layout.dart';

// =============================================================================
// NEWS SCREEN (Public portal + private feed)
// =============================================================================

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  String _selectedCategory = 'Todas';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<NoticiasService>();
    final auth = context.watch<AuthService>();
    final isLoggedIn = auth.userId != null;

    return SingleChildScrollView(
      child: Column(
        children: [
          // ---- Hero section ----
          _HeroSection(service: service),

          // ---- Search & filters ----
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  children: [
                    // Search bar
                    TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Buscar noticias...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                    const SizedBox(height: 12),

                    // Category chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _CategoryChip(
                            label: 'Todas',
                            selected: _selectedCategory == 'Todas',
                            onTap: () =>
                                setState(() => _selectedCategory = 'Todas'),
                          ),
                          ...Noticia.defaultCategories
                              .map((cat) => _CategoryChip(
                                    label: cat,
                                    selected: _selectedCategory == cat,
                                    onTap: () =>
                                        setState(() => _selectedCategory = cat),
                                  )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ---- News grid ----
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: StreamBuilder<List<Noticia>>(
                  stream: isLoggedIn
                      ? service.getNoticiasActivas()
                      : service.getNoticiasPublicas(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    var noticias = snapshot.data ?? [];

                    // Filter by category
                    if (_selectedCategory != 'Todas') {
                      noticias = noticias
                          .where((n) => n.category == _selectedCategory)
                          .toList();
                    }

                    // Filter by search
                    if (_searchQuery.isNotEmpty) {
                      final q = _searchQuery.toLowerCase();
                      noticias = noticias
                          .where((n) =>
                              n.title.toLowerCase().contains(q) ||
                              n.shortDescription.toLowerCase().contains(q) ||
                              n.content.toLowerCase().contains(q))
                          .toList();
                    }

                    // Sort: pinned first, then featured, then by date
                    noticias.sort((a, b) {
                      if (a.isPinned != b.isPinned) {
                        return a.isPinned ? -1 : 1;
                      }
                      if (a.isFeatured != b.isFeatured) {
                        return a.isFeatured ? -1 : 1;
                      }
                      return b.createdAt.compareTo(a.createdAt);
                    });

                    if (noticias.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(48),
                        child: Column(
                          children: [
                            Icon(Icons.article,
                                size: 64, color: AppTheme.textSecondary),
                            SizedBox(height: 16),
                            Text('No hay noticias publicadas.',
                                style:
                                    TextStyle(color: AppTheme.textSecondary)),
                          ],
                        ),
                      );
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >=
                            ResponsiveBreakpoints.tablet;
                        if (isWide) {
                          return _buildGrid(noticias);
                        }
                        return _buildList(noticias);
                      },
                    );
                  },
                ),
              ),
            ),
          ),

          // ---- Hemeroteca link ----
          Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: Center(
              child: OutlinedButton.icon(
                onPressed: () => context.go('/noticias/hemeroteca'),
                icon: const Icon(Icons.history),
                label: const Text('Hemeroteca - Archivo histórico'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<Noticia> noticias) {
    return ResponsiveGrid(
      smallColumns: 1,
      mediumColumns: 2,
      largeColumns: 3,
      wideColumns: 3,
      children: [
        for (final noticia in noticias) _NoticiaCard(noticia: noticia),
      ],
    );
  }

  Widget _buildList(List<Noticia> noticias) {
    return Column(
      children: noticias.map((n) => _NoticiaCard(noticia: n)).toList(),
    );
  }
}

// =============================================================================
// HERO SECTION
// =============================================================================

class _HeroSection extends StatelessWidget {
  final NoticiasService service;
  const _HeroSection({required this.service});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Noticia>>(
      stream: service.getNoticiasDestacadas(),
      builder: (context, snapshot) {
        final destacadas = snapshot.data ?? [];

        // Static hero header if no featured news
        if (destacadas.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryDark, AppTheme.primaryColor],
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Noticias',
                  style: Theme.of(context)
                      .textTheme
                      .headlineLarge
                      ?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'Últimas novedades de la Cofradía',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: AppTheme.accentColor),
                ),
              ],
            ),
          );
        }

        // Dynamic hero with featured news
        final hero = destacadas.first;
        return GestureDetector(
          onTap: () {
            final route = hero.slug.isNotEmpty
                ? '/noticias/${hero.slug}'
                : '/noticias/detalle?id=${hero.id}';
            context.go(route);
          },
          child: Container(
            width: double.infinity,
            height: 340,
            decoration: BoxDecoration(
              image: (hero.coverImageUrl ?? '').isNotEmpty
                  ? DecorationImage(
                      image: CachedNetworkImageProvider(hero.coverImageUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
              gradient: (hero.coverImageUrl ?? '').isEmpty
                  ? const LinearGradient(
                      colors: [AppTheme.primaryDark, AppTheme.primaryColor],
                    )
                  : null,
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
              padding: const EdgeInsets.all(32),
              alignment: Alignment.bottomLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(hero.category,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                        if (hero.isUrgent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('URGENTE',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      hero.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hero.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        hero.subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      DateFormat('dd MMMM yyyy', 'es').format(hero.createdAt),
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// NOTICIA CARD
// =============================================================================

class _NoticiaCard extends StatelessWidget {
  final Noticia noticia;
  const _NoticiaCard({required this.noticia});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          final route = noticia.slug.isNotEmpty
              ? '/noticias/${noticia.slug}'
              : '/noticias/detalle?id=${noticia.id}';
          context.go(route);

          // Track view
          context.read<NoticiasService>().incrementViews(noticia.id);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            if ((noticia.coverImageUrl ?? '').isNotEmpty)
              CachedNetworkImage(
                imageUrl: noticia.coverImageUrl!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  height: 180,
                  color: Colors.grey.shade100,
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (_, __, ___) => Container(
                  height: 180,
                  color: Colors.grey.shade100,
                  child: const Icon(Icons.broken_image),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category + flags row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          noticia.category,
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (noticia.isPinned) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.push_pin,
                            size: 14, color: Colors.orange.shade700),
                      ],
                      if (noticia.isUrgent) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text('URGENTE',
                              style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                      if (noticia.visibility != NoticiaVisibility.publica) ...[
                        const SizedBox(width: 6),
                        Icon(
                          noticia.visibility == NoticiaVisibility.privada
                              ? Icons.lock
                              : Icons.people,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                      ],
                      const Spacer(),
                      Text(
                        DateFormat('dd/MM/yyyy').format(noticia.createdAt),
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Title
                  Text(
                    noticia.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  if (noticia.shortDescription.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      noticia.shortDescription,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  if (noticia.attachments.isNotEmpty ||
                      noticia.gallery.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (noticia.gallery.isNotEmpty)
                          _MiniStat(
                            icon: Icons.photo_library,
                            label: '${noticia.gallery.length} fotos',
                          ),
                        if (noticia.attachments.isNotEmpty)
                          _MiniStat(
                            icon: Icons.attach_file,
                            label: '${noticia.attachments.length} adjuntos',
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MiniStat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade500),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

// =============================================================================
// CATEGORY CHIP
// =============================================================================

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
        labelStyle: TextStyle(
          color: selected ? AppTheme.primaryColor : AppTheme.textSecondary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}
