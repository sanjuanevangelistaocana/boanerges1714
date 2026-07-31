import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/models/noticia.dart';
import 'package:boanerges1714/models/evento.dart';
import 'package:boanerges1714/widgets/app_logo.dart';
import 'package:boanerges1714/widgets/home_carousel.dart';
import 'package:boanerges1714/utils/madrid_date.dart';
import 'package:boanerges1714/widgets/app_surface_card.dart';
import 'package:boanerges1714/utils/liturgical_calendar.dart';
import 'package:boanerges1714/models/content_models.dart';
import 'package:boanerges1714/services/content_service.dart';
import 'package:boanerges1714/widgets/responsive_layout.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _contentWidth = 1120.0;
  static const _sectionGap = 32.0;
  static const _pagePadding = 24.0;

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeroBanner(context),
          _buildFeatureCards(context),
          const SizedBox(height: _sectionGap),
          _buildEvangelioDelDia(context, firestoreService),
          const SizedBox(height: _sectionGap),
          _buildCalendarioEventos(context, firestoreService),
          const SizedBox(height: _sectionGap),
          _buildCalendarioLiturgico(context),
          const SizedBox(height: _sectionGap),
          _buildInterestLinks(context),
          const SizedBox(height: _sectionGap),
          _buildUltimasNoticias(context, firestoreService),
          const SizedBox(height: _sectionGap),
          _buildAsistenciaSocial(context),
          const SizedBox(height: _sectionGap),
          _buildCtaSection(context),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildHeroBanner(BuildContext context) {
    final content = _buildHeroContent(context);
    return HomeCarousel(
      overlay: content,
      fallback: (context, _) => Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF3A0A14),
              AppTheme.primaryDark,
              AppTheme.primaryColor
            ],
          ),
        ),
        child: content,
      ),
    );
  }

  Widget _buildHeroContent(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(vertical: 64, horizontal: _pagePadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withAlpha(35), Colors.black.withAlpha(175)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(235),
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child:
                const AppLogo(size: 72, fallbackColor: AppTheme.primaryColor),
          ),
          const SizedBox(height: 20),
          Text(
            'Cofradía de San Juan Evangelista',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withAlpha(60),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Ocaña · Desde 1714',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    fontSize: 16,
                    letterSpacing: 1.2,
                  ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '"Hijos del Trueno"',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white70,
                  fontStyle: FontStyle.italic,
                ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildFeatureCards(BuildContext context) {
    final horizontalPadding = context.responsive.isDesktop
        ? 24.0
        : context.responsive.horizontalPadding;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(horizontalPadding, 24, horizontalPadding, 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _contentWidth),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              _FeatureCard(
                icon: Icons.history_edu,
                title: 'Nuestra Historia',
                subtitle: 'Más de 300 años de tradición y devoción',
                onTap: () => context.go('/history'),
              ),
              _FeatureCard(
                icon: Icons.event,
                title: 'Eventos',
                subtitle: 'Calendario de actos y celebraciones',
                onTap: () => context.go('/events'),
              ),
              _FeatureCard(
                icon: Icons.photo_library,
                title: 'Galería',
                subtitle: 'Fotos y recuerdos de nuestra cofradía',
                onTap: () => context.go('/gallery'),
              ),
              _FeatureCard(
                icon: Icons.person_add_alt_1,
                title: 'Hazte Cofrade',
                subtitle: 'Forma parte de nuestra hermandad',
                onTap: () => context.go('/solicitud-alta'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEvangelioDelDia(BuildContext context, FirestoreService service) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryDark, AppTheme.primaryColor],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _contentWidth),
          child: Column(
            children: [
              const Icon(Icons.menu_book_outlined,
                  size: 38, color: Colors.white70),
              const SizedBox(height: 16),
              Text(
                'Evangelio del D\u00eda',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                MadridDate.display(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                      fontStyle: FontStyle.italic,
                    ),
              ),
              const SizedBox(height: 20),
              StreamBuilder<Map<String, dynamic>?>(
                stream: service.getEvangelioDelDia(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    );
                  }
                  final data = snapshot.data;
                  if (data == null) {
                    return AppSurfaceCard(
                      color: Colors.white.withAlpha(235),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(Icons.auto_stories,
                              size: 40, color: AppTheme.textSecondary),
                          const SizedBox(height: 12),
                          Text(
                            'El evangelio de hoy a\u00fan no est\u00e1 disponible.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Se actualiza diariamente.',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                          ),
                        ],
                      ),
                    );
                  }
                  final referencia = data['referencia'] as String? ?? '';
                  final textoRaw = data['texto'] as String? ?? '';
                  final titulo = data['titulo'] as String? ?? '';
                  final texto = textoRaw
                      .replaceAll(RegExp(r'<[^>]*>'), ' ')
                      .replaceAll(RegExp(r'\s+'), ' ')
                      .trim();
                  if (texto.isEmpty && titulo.isEmpty) {
                    return AppSurfaceCard(
                      color: Colors.white.withAlpha(235),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(Icons.auto_stories,
                              size: 40, color: AppTheme.textSecondary),
                          const SizedBox(height: 12),
                          Text(
                            'El evangelio de hoy a\u00fan no tiene contenido.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppTheme.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }
                  return AppSurfaceCard(
                    color: Colors.white.withAlpha(245),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (titulo.isNotEmpty) ...[
                          Text(
                            titulo.replaceAll(RegExp(r'<[^>]*>'), '').trim(),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryDark,
                                ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (referencia.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.accentColor.withAlpha(20),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              referencia,
                              style: const TextStyle(
                                color: AppTheme.primaryDark,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (referencia.isNotEmpty) const SizedBox(height: 16),
                        Text(
                          texto,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    height: 1.7,
                                    color: AppTheme.textPrimary,
                                    fontStyle: FontStyle.italic,
                                  ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarioLiturgico(BuildContext context) {
    return StreamBuilder<List<ManagedCelebration>>(
      stream: context.read<ContentService>().watchCelebrations(),
      builder: (context, snapshot) {
        final celebrations = _mergedCelebrations(snapshot.data ?? const []);
        return _buildLiturgicalCard(context, celebrations);
      },
    );
  }

  Widget _buildLiturgicalCard(
      BuildContext context, List<LiturgicalCelebration> celebrations) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _contentWidth),
          child: AppSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined,
                        color: AppTheme.primaryColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Calendario litúrgico',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    Text(
                      'Iglesia universal',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                for (var index = 0; index < celebrations.length; index++) ...[
                  _LiturgicalRow(
                    celebration: celebrations[index],
                    accent: _liturgicalColor(celebrations[index].color),
                  ),
                  if (index < celebrations.length - 1)
                    const Divider(height: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<LiturgicalCelebration> _mergedCelebrations(
      List<ManagedCelebration> managed) {
    final start = MadridDate.now();
    final values = <LiturgicalCelebration>[
      ...LiturgicalCalendar.next(from: start, limit: 8),
    ];
    for (final item in managed) {
      DateTime? date;
      if (item.annual && item.month != null && item.day != null) {
        final candidate = DateTime(start.year, item.month!, item.day!);
        date = candidate.isBefore(DateTime(start.year, start.month, start.day))
            ? DateTime(start.year + 1, item.month!, item.day!)
            : candidate;
      } else if (!item.annual && item.date != null) {
        date = DateTime(item.date!.year, item.date!.month, item.date!.day);
      }
      if (date == null ||
          date.isBefore(DateTime(start.year, start.month, start.day))) {
        continue;
      }
      values.add(LiturgicalCelebration(
        date: date,
        name: item.title,
        season: item.type,
        color: item.type,
        sourceType: item.type,
        description: item.description,
      ));
    }
    values.sort((a, b) => a.date.compareTo(b.date));
    return values.take(4).toList();
  }

  Widget _buildInterestLinks(BuildContext context) {
    return StreamBuilder<List<InterestLink>>(
      stream: context.read<ContentService>().watchInterestLinks(),
      builder: (context, snapshot) {
        final links = snapshot.data ?? const <InterestLink>[];
        if (links.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _contentWidth),
              child: AppSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Enlaces de interés',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return ResponsiveGrid(
                          smallColumns: 1,
                          mediumColumns: 2,
                          largeColumns: 3,
                          wideColumns: 3,
                          children: [
                            for (final link in links)
                              _InterestLinkCard(link: link),
                          ],
                        );
                      },
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

  Color _liturgicalColor(String? color) {
    switch (color) {
      case 'Morado':
        return const Color(0xFF6A4C93);
      case 'Rojo':
        return const Color(0xFFB3261E);
      case 'Blanco':
        return AppTheme.accentColor;
      case 'Iglesia Católica':
        return const Color(0xFF6A4C93);
      case 'Hermandades invitadas':
        return const Color(0xFF496A72);
      case 'Festividades especiales':
        return AppTheme.accentColor;
      default:
        return AppTheme.primaryColor;
    }
  }

  Widget _buildCalendarioEventos(
      BuildContext context, FirestoreService service) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _contentWidth),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('Calendario de Eventos',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              )),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => context.go('/events'),
                    icon: const Text('Ver todos'),
                    label: const Icon(Icons.arrow_forward, size: 16),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<Evento>>(
                stream: service.getProximosEventos(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _buildEmptyState(
                      context,
                      icon: Icons.event,
                      message: 'No hay eventos próximos programados.',
                      buttonText: 'Ver calendario completo',
                      onTap: () => context.go('/events'),
                    );
                  }
                  final eventos = snapshot.data ?? [];
                  if (eventos.isEmpty) {
                    return _buildEmptyState(
                      context,
                      icon: Icons.event,
                      message: 'No hay eventos pr\u00f3ximos programados.',
                      buttonText: 'Ver calendario completo',
                      onTap: () => context.go('/events'),
                    );
                  }
                  return Column(
                    children: [
                      _buildMiniCalendar(context, eventos),
                      const SizedBox(height: 20),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: eventos.length,
                        itemBuilder: (context, index) {
                          final evento = eventos[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${evento.fecha.day}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    Text(
                                      _getMonthName(evento.fecha.month),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              title: Text(evento.titulo,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                [
                                  if (evento.hora != null) evento.hora!,
                                  if (evento.lugar != null) evento.lugar!,
                                ].join(' \u00b7 '),
                                style: const TextStyle(
                                    color: AppTheme.textSecondary),
                              ),
                              trailing:
                                  const Icon(Icons.arrow_forward_ios, size: 14),
                              onTap: () => context.go('/events'),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUltimasNoticias(BuildContext context, FirestoreService service) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      color: Colors.white,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _contentWidth),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('Últimas Noticias',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              )),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => context.go('/news'),
                    icon: const Text('Ver todas'),
                    label: const Icon(Icons.arrow_forward, size: 16),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<Noticia>>(
                stream: service.getUltimasNoticias(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _buildEmptyState(
                      context,
                      icon: Icons.newspaper,
                      message: 'No hay noticias publicadas.',
                      buttonText: 'Ver todas las noticias',
                      onTap: () => context.go('/news'),
                    );
                  }
                  final noticias = snapshot.data ?? [];
                  if (noticias.isEmpty) {
                    return _buildEmptyState(
                      context,
                      icon: Icons.newspaper,
                      message: 'No hay noticias publicadas.',
                      buttonText: 'Ver todas las noticias',
                      onTap: () => context.go('/news'),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: noticias.length,
                    itemBuilder: (context, index) {
                      final noticia = noticias[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${noticia.fecha.day}/${noticia.fecha.month}/${noticia.fecha.year}',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(noticia.titulo,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text(
                                noticia.contenido.length > 200
                                    ? '${noticia.contenido.substring(0, 200)}...'
                                    : noticia.contenido,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: AppTheme.textSecondary,
                                      height: 1.5,
                                    ),
                              ),
                              if (noticia.adjuntos.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: noticia.adjuntos.map((adj) {
                                    final esImagen = (adj['tipo'] ?? '')
                                        .startsWith('image/');
                                    return ActionChip(
                                      avatar: Icon(
                                        esImagen
                                            ? Icons.image
                                            : Icons.attach_file,
                                        size: 16,
                                        color: AppTheme.primaryColor,
                                      ),
                                      label: Text(adj['nombre'] ?? 'Archivo',
                                          style: const TextStyle(fontSize: 12)),
                                      onPressed: () {
                                        final url = adj['url'];
                                        if (url != null) {
                                          launchUrl(Uri.parse(url),
                                              mode: LaunchMode
                                                  .externalApplication);
                                        }
                                      },
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCtaSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _contentWidth),
          child: Card(
            color: AppTheme.primaryColor,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Icon(Icons.people, size: 48, color: Colors.white),
                  const SizedBox(height: 16),
                  Text('Hazte Cofrade',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              )),
                  const SizedBox(height: 12),
                  Text(
                    'Forma parte de nuestra hermandad. '
                    'Envía tu solicitud de alta y nos pondremos en contacto contigo.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white70,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => context.go('/solicitud-alta'),
                        icon: const Icon(Icons.person_add),
                        label: const Text('Solicitar alta'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 14),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => context.go('/contact'),
                        icon:
                            const Icon(Icons.mail_outline, color: Colors.white),
                        label: const Text('Enviar mensaje'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withAlpha(30),
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white70),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required IconData icon,
    required String message,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(icon, size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            Text(message,
                style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onTap, child: Text(buttonText)),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniCalendar(BuildContext context, List<Evento> eventos) {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    final startWeekday = firstDayOfMonth.weekday;

    final eventDays = <int>{};
    for (final e in eventos) {
      if (e.fecha.year == now.year && e.fecha.month == now.month) {
        eventDays.add(e.fecha.day);
      }
    }

    const dayNames = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    final monthName = DateFormat('MMMM yyyy', 'es_ES').format(now);

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              monthName[0].toUpperCase() + monthName.substring(1),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: dayNames
                  .map((d) => SizedBox(
                        width: 36,
                        child: Center(
                          child: Text(d,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: d == 'D'
                                    ? AppTheme.primaryColor
                                    : AppTheme.textSecondary,
                                fontSize: 12,
                              )),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            ...List.generate(
              ((lastDayOfMonth.day + startWeekday - 1) / 7).ceil(),
              (weekIndex) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(7, (dayIndex) {
                    final dayNum =
                        weekIndex * 7 + dayIndex + 1 - (startWeekday - 1);
                    if (dayNum < 1 || dayNum > lastDayOfMonth.day) {
                      return const SizedBox(width: 36, height: 36);
                    }
                    final isToday = dayNum == now.day;
                    final hasEvent = eventDays.contains(dayNum);
                    return SizedBox(
                      width: 36,
                      height: 36,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isToday
                              ? AppTheme.primaryColor
                              : hasEvent
                                  ? AppTheme.accentColor.withAlpha(30)
                                  : null,
                          shape: BoxShape.circle,
                          border: hasEvent && !isToday
                              ? Border.all(
                                  color: AppTheme.accentColor, width: 1.5)
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            '$dayNum',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isToday || hasEvent
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isToday
                                  ? Colors.white
                                  : hasEvent
                                      ? AppTheme.accentColor
                                      : AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
            if (eventDays.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: AppTheme.accentColor, width: 1.5),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('Evento programado',
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary)),
                  const SizedBox(width: 16),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('Hoy',
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAsistenciaSocial(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _contentWidth),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Asistencia Social',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              )),
                ],
              ),
              const SizedBox(height: 16),
              AppSurfaceCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor.withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.volunteer_activism,
                              size: 32, color: AppTheme.accentColor),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Compromiso con nuestra comunidad',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'La Cofrad\u00eda de San Juan Evangelista mantiene un firme compromiso '
                                'con la asistencia social y la solidaridad. Colaboramos activamente '
                                'con las necesidades de nuestra comunidad en Oca\u00f1a.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: AppTheme.textSecondary,
                                      height: 1.6,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    ResponsiveGrid(
                      smallColumns: 1,
                      mediumColumns: 2,
                      largeColumns: 3,
                      wideColumns: 3,
                      children: const [
                        _AsistenciaItem(
                          icon: Icons.food_bank,
                          title: 'Banco de Alimentos',
                          subtitle: 'Recogida y reparto de alimentos',
                        ),
                        _AsistenciaItem(
                          icon: Icons.shopping_basket_outlined,
                          title: 'Bolsa solidaria',
                          subtitle: 'Apoyo a necesidades b\u00e1sicas',
                        ),
                        _AsistenciaItem(
                          icon: Icons.volunteer_activism_outlined,
                          title: 'Donaciones',
                          subtitle: 'Aportaciones para ayuda social',
                        ),
                        _AsistenciaItem(
                          icon: Icons.church_outlined,
                          title: 'Ayuda parroquial',
                          subtitle: 'Colaboraci\u00f3n con la parroquia',
                        ),
                        _AsistenciaItem(
                          icon: Icons.favorite_outline,
                          title: 'Colaboraci\u00f3n con C\u00e1ritas',
                          subtitle: 'Apoyo a iniciativas solidarias',
                        ),
                        _AsistenciaItem(
                          icon: Icons.groups_outlined,
                          title: 'Voluntariado',
                          subtitle: 'Participaci\u00f3n y acompa\u00f1amiento',
                        ),
                        _AsistenciaItem(
                          icon: Icons.card_giftcard_outlined,
                          title: 'Campa\u00f1as de Navidad',
                          subtitle: 'Acciones solidarias de temporada',
                        ),
                        _AsistenciaItem(
                          icon: Icons.inventory_2_outlined,
                          title: 'Recogidas extraordinarias',
                          subtitle: 'Campañas puntuales de apoyo',
                        ),
                        _AsistenciaItem(
                          icon: Icons.accessibility_new,
                          title:
                              'Colaboración con el Centro Ocupacional de Ocaña',
                          subtitle: 'Centro Ocupacional de Ocaña',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: () => context.go('/contact'),
                        icon: const Icon(Icons.mail_outline),
                        label: const Text(
                            '\u00bfQuieres colaborar? Cont\u00e1ctanos'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'ENE',
      'FEB',
      'MAR',
      'ABR',
      'MAY',
      'JUN',
      'JUL',
      'AGO',
      'SEP',
      'OCT',
      'NOV',
      'DIC'
    ];
    return months[month - 1];
  }
}

class _InterestLinkCard extends StatefulWidget {
  final InterestLink link;

  const _InterestLinkCard({required this.link});

  @override
  State<_InterestLinkCard> createState() => _InterestLinkCardState();
}

class _InterestLinkCardState extends State<_InterestLinkCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final link = widget.link;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
        child: AppSurfaceCard(
          padding: const EdgeInsets.all(16),
          onTap: () => launchUrl(
            Uri.parse(link.url),
            mode: LaunchMode.externalApplication,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (link.imageUrl?.isNotEmpty == true)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    link.imageUrl!,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withAlpha(24),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.link,
                      color: AppTheme.accentColor, size: 26),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            link.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const Icon(Icons.open_in_new,
                            size: 16, color: AppTheme.primaryColor),
                      ],
                    ),
                    if (link.description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        link.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                              height: 1.35,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context).width;
    final columns = Responsive.gridColumns(
      viewport,
      small: 1,
      medium: 2,
      large: 4,
      wide: 4,
    );
    final horizontalPadding = (context.responsive.isDesktop
            ? 24.0
            : context.responsive.horizontalPadding) *
        2;
    final width = (viewport - horizontalPadding - (columns - 1) * 16) / columns;
    return SizedBox(
      width: width.clamp(220, 280).toDouble(),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedSlide(
          offset:
              _hovered && MediaQuery.maybeDisableAnimationsOf(context) != true
                  ? const Offset(0, -0.025)
                  : Offset.zero,
          duration: MediaQuery.maybeDisableAnimationsOf(context) == true
              ? Duration.zero
              : const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: MediaQuery.maybeDisableAnimationsOf(context) == true
                ? Duration.zero
                : const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(_hovered ? 26 : 12),
                  blurRadius: _hovered ? 18 : 10,
                  offset: Offset(0, _hovered ? 8 : 4),
                ),
              ],
            ),
            child: AppSurfaceCard(
              onTap: widget.onTap,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withAlpha(18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.icon,
                        size: 38, color: AppTheme.primaryColor),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryDark,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiturgicalRow extends StatelessWidget {
  final LiturgicalCelebration celebration;
  final Color accent;

  const _LiturgicalRow({
    required this.celebration,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final date = celebration.date;
    final description = celebration.description;
    final month = DateFormat('MMM', 'es_ES')
        .format(date)
        .replaceAll('.', '')
        .toUpperCase();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 58,
          height: 52,
          decoration: BoxDecoration(
            color: accent.withAlpha(18),
            borderRadius: BorderRadius.circular(10),
            border: Border(left: BorderSide(color: accent, width: 3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${date.day}',
                style: TextStyle(
                  color: accent,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                month,
                style: TextStyle(
                  color: accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                celebration.name,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Icon(Icons.circle, size: 8, color: accent),
                  const SizedBox(width: 6),
                  Text(
                    celebration.season,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ],
              ),
              if ((description ?? '').isNotEmpty)
                Text(
                  description!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AsistenciaItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _AsistenciaItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Row(
        children: [
          Icon(icon, size: 28, color: AppTheme.accentColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    )),
                Text(subtitle,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
