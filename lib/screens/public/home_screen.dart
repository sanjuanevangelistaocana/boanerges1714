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
          _buildFeatureCards(context),
          const SizedBox(height: 40),
          _buildProximosEventos(context, firestoreService),
          const SizedBox(height: 40),
          _buildUltimasNoticias(context, firestoreService),
          const SizedBox(height: 40),
          _buildCtaSection(context),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildHeroBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3A0A14),
            AppTheme.primaryDark,
            AppTheme.primaryColor,
          ],
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.church, size: 64, color: Colors.white),
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
          const SizedBox(height: 28),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => context.go('/solicitud-alta'),
                icon: const Icon(Icons.person_add),
                label: const Text('Únete a nosotros'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => context.go('/contact'),
                icon: const Icon(Icons.mail_outline),
                label: const Text('Contacto'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white.withAlpha(20),
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white, width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCards(BuildContext context) {
    return Container(
      width: double.infinity,
      transform: Matrix4.translationValues(0, -30, 0),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProximosEventos(BuildContext context, FirestoreService service) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
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
                      Text('Próximos Eventos',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
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
                      message: 'No hay eventos próximos programados.',
                      buttonText: 'Ver calendario completo',
                      onTap: () => context.go('/events'),
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
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            [
                              if (evento.hora != null) evento.hora!,
                              if (evento.lugar != null) evento.lugar!,
                            ].join(' · '),
                            style: const TextStyle(color: AppTheme.textSecondary),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                          onTap: () => context.go('/events'),
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

  Widget _buildUltimasNoticias(BuildContext context, FirestoreService service) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      color: Colors.white,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
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
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
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
                              Row(
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
                                  if (noticia.soloCofrades) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accentColor.withAlpha(30),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Solo cofrades',
                                        style: TextStyle(
                                            color: AppTheme.accentColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ],
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
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.textSecondary,
                                      height: 1.5,
                                    ),
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
      ),
    );
  }

  Widget _buildCtaSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Card(
            color: AppTheme.primaryColor,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Icon(Icons.people, size: 48, color: Colors.white),
                  const SizedBox(height: 16),
                  Text('Hazte Cofrade',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/contact'),
                        icon: const Icon(Icons.mail_outline),
                        label: const Text('Enviar mensaje'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white70),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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
            Text(message, style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onTap, child: Text(buttonText)),
          ],
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
      'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'
    ];
    return months[month - 1];
  }
}

class _FeatureCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: Card(
        elevation: 4,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 36, color: AppTheme.primaryColor),
                ),
                const SizedBox(height: 16),
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
