import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/models/noticia.dart';

class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();
    final authService = context.watch<AuthService>();
    final isLoggedIn = authService.userId != null;

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
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
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: StreamBuilder<List<Noticia>>(
                stream: firestoreService.getNoticias(
                  incluirSoloCofrades: isLoggedIn,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(48),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  final noticias = snapshot.data ?? [];
                  if (noticias.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(48),
                      child: Column(
                        children: [
                          Icon(Icons.article,
                              size: 64, color: AppTheme.textSecondary),
                          SizedBox(height: 16),
                          Text('No hay noticias publicadas.',
                              style: TextStyle(color: AppTheme.textSecondary)),
                        ],
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
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if ((noticia.imagenUrl ?? '').isNotEmpty) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    noticia.imagenUrl!,
                                    height: 190,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(height: 14),
                              ],
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
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
                                        color: AppTheme.accentColor,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Solo cofrades',
                                        style: TextStyle(
                                            color: Colors.white, fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                noticia.titulo,
                                style:
                                    Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                noticia.contenido,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              if (noticia.adjuntos.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final adj in noticia.adjuntos)
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          final url = adj['url'];
                                          if (url == null || url.isEmpty) {
                                            return;
                                          }
                                          launchUrl(
                                            Uri.parse(url),
                                            mode:
                                                LaunchMode.externalApplication,
                                          );
                                        },
                                        icon: Icon(
                                          (adj['tipo'] ?? '')
                                                  .startsWith('application/pdf')
                                              ? Icons.picture_as_pdf
                                              : Icons.attach_file,
                                        ),
                                        label: Text(
                                          (adj['tipo'] ?? '')
                                                  .startsWith('application/pdf')
                                              ? 'Descargar PDF'
                                              : 'Ver adjunto',
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                              if (authService.cofrade != null) ...[
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () async {
                                      await firestoreService.markNewsRead(
                                        authService.cofrade!.id,
                                        noticia.id,
                                      );
                                      if (context.mounted) {
                                        context.go('/dashboard');
                                      }
                                    },
                                    child: const Text('Marcar como leída'),
                                  ),
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
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}
