import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/models/revista.dart';
import 'package:boanerges1714/widgets/responsive_layout.dart';

class BoanergesScreen extends StatelessWidget {
  const BoanergesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

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
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(20),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.menu_book,
                          size: 48, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Boanerges',
                      style:
                          Theme.of(context).textTheme.headlineLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Revista de la Cofradía de San Juan Evangelista',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white70,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Boanerges no es solo una revista. Es el latido escrito de la Cofradía de San Juan Evangelista.\n\n'
                          'En cada página hay más que palabras: hay recuerdos, hay rostros, hay momentos que han marcado a quienes forman parte de esta hermandad. Es el lugar donde queda guardado todo aquello que no debería olvidarse: una procesión, una mirada, un esfuerzo compartido, una emoción vivida en silencio.\n\n'
                          'Boanerges recoge lo que somos. Lo que hemos sido. Y, sobre todo, lo que seguimos construyendo juntos. Es memoria, pero también es identidad. Es una forma de detener el tiempo para poder volver a él cuando haga falta.\n\n'
                          'Porque hay cosas que no se explican… se sienten. Y esta revista es precisamente eso: una forma de sentir, de recordar y de seguir caminando unidos, generación tras generación, bajo la mirada de San Juan Evangelista.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(height: 1.65),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    StreamBuilder<List<Revista>>(
                      stream: firestoreService.getRevistas(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final revistas = snapshot.data ?? [];
                        if (revistas.isEmpty) {
                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(40),
                              child: Column(
                                children: [
                                  const Icon(Icons.menu_book,
                                      size: 48, color: AppTheme.textSecondary),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Próximamente se publicarán los números de la revista Boanerges.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
                                          color: AppTheme.textSecondary,
                                        ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        final isWide = MediaQuery.of(context).size.width >= 768;
                        return ResponsiveGrid(
                          smallColumns: 1,
                          mediumColumns: 1,
                          largeColumns: 3,
                          wideColumns: 3,
                          children: [
                            for (final revista in revistas)
                              _RevistaCard(
                                revista: revista,
                                isWide: isWide,
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RevistaCard extends StatelessWidget {
  final Revista revista;
  final bool isWide;
  const _RevistaCard({required this.revista, required this.isWide});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMMM yyyy', 'es_ES');
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: revista.pdfUrl.isNotEmpty
            ? () => launchUrl(Uri.parse(revista.pdfUrl),
                mode: LaunchMode.externalApplication)
            : null,
        borderRadius: BorderRadius.circular(12),
        child: isWide
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 140,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withAlpha(15),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: revista.portadaUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12)),
                            child: Image.network(revista.portadaUrl,
                                fit: BoxFit.cover),
                          )
                        : const Center(
                            child: Icon(Icons.menu_book,
                                size: 48, color: AppTheme.primaryColor)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (revista.numero > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('N.º ${revista.numero}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                        const SizedBox(height: 6),
                        Text(revista.titulo,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(fmt.format(revista.fecha),
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ],
              )
            : ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withAlpha(15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: revista.portadaUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(revista.portadaUrl,
                              fit: BoxFit.cover),
                        )
                      : const Icon(Icons.menu_book,
                          color: AppTheme.primaryColor),
                ),
                title: Text(revista.titulo,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  '${revista.numero > 0 ? "N.º ${revista.numero} · " : ""}${fmt.format(revista.fecha)}',
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary),
                ),
                trailing: const Icon(Icons.picture_as_pdf,
                    color: AppTheme.primaryColor),
              ),
      ),
    );
  }
}
