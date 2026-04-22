import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/models/noticia.dart';
import 'package:boanerges1714/models/evento.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeroBanner(context),
          const SizedBox(height: 32),
          _buildWelcomeSection(context),
          const SizedBox(height: 32),
          _buildProximosEventos(context, firestoreService),
          const SizedBox(height: 32),
          _buildUltimasNoticias(context, firestoreService),
          const SizedBox(height: 32),
          _buildQuickLinks(context),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildHeroBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.primaryDark, AppTheme.primaryColor],
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.church, size: 80, color: AppTheme.accentColor),
          const SizedBox(height: 16),
          Text(
            'Cofradía de San Juan Evangelista',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: Colors.white,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Ocaña · Desde 1714',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.accentColor,
                  fontSize: 18,
                ),
          ),
          const SizedBox(height: 24),
          Text(
            '"Hijos del Trueno"',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white70,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          children: [
            Text(
              'Bienvenidos',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'La Cofradía de San Juan Evangelista de Ocaña, fundada en 1714, '
              'es una hermandad dedicada a la devoción y culto de San Juan Evangelista. '
              'Participamos activamente en la Semana Santa de Ocaña y en diversas '
              'actividades religiosas y culturales a lo largo del año.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => context.go('/history'),
                  icon: const Icon(Icons.history_edu),
                  label: const Text('Nuestra Historia'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.go('/contact'),
                  icon: const Icon(Icons.people),
                  label: const Text('Únete a nosotros'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(color: AppTheme.primaryColor),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProximosEventos(BuildContext context, FirestoreService service) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Próximos Eventos',
                    style: Theme.of(context).textTheme.headlineMedium),
                TextButton(
                  onPressed: () => context.go('/events'),
                  child: const Text('Ver todos →'),
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
                final eventos = snapshot.data ?? [];
                if (eventos.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No hay eventos próximos programados.',
                          textAlign: TextAlign.center),
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: eventos.length,
                  itemBuilder: (context, index) {
                    final evento = eventos[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryColor,
                          child: Text(
                            '${evento.fecha.day}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(evento.titulo),
                        subtitle: Text(
                          '${evento.fecha.day}/${evento.fecha.month}/${evento.fecha.year}'
                          '${evento.hora != null ? ' · ${evento.hora}' : ''}'
                          '${evento.lugar != null ? ' · ${evento.lugar}' : ''}',
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUltimasNoticias(BuildContext context, FirestoreService service) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      color: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Últimas Noticias',
                    style: Theme.of(context).textTheme.headlineMedium),
                TextButton(
                  onPressed: () => context.go('/news'),
                  child: const Text('Ver todas →'),
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
                final noticias = snapshot.data ?? [];
                if (noticias.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No hay noticias publicadas.',
                          textAlign: TextAlign.center),
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: noticias.length,
                  itemBuilder: (context, index) {
                    final noticia = noticias[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(noticia.titulo,
                                style: Theme.of(context).textTheme.headlineSmall),
                            const SizedBox(height: 8),
                            Text(
                              noticia.contenido.length > 150
                                  ? '${noticia.contenido.substring(0, 150)}...'
                                  : noticia.contenido,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${noticia.fecha.day}/${noticia.fecha.month}/${noticia.fecha.year}',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 12),
                            ),
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
    );
  }

  Widget _buildQuickLinks(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: [
            _QuickLinkCard(
              icon: Icons.history_edu,
              title: 'Historia',
              subtitle: 'Más de 300 años de tradición',
              onTap: () => context.go('/history'),
            ),
            _QuickLinkCard(
              icon: Icons.photo_library,
              title: 'Galería',
              subtitle: 'Fotos y recuerdos',
              onTap: () => context.go('/gallery'),
            ),
            _QuickLinkCard(
              icon: Icons.person_add,
              title: 'Hazte Cofrade',
              subtitle: 'Únete a nuestra hermandad',
              onTap: () => context.go('/contact'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickLinkCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickLinkCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(icon, size: 48, color: AppTheme.primaryColor),
                const SizedBox(height: 12),
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
