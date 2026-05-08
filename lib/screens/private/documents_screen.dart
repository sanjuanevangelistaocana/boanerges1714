import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/models/documento.dart';

class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();
    final cofrade = context.watch<AuthService>().cofrade;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Documentos',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Actas, estatutos y documentación de la Cofradía',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            if (cofrade != null) ...[
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: firestoreService.watchPrivateDocuments(
                  cofrade.id,
                  onlyVisibleToCofrade: true,
                ),
                builder: (context, snapshot) {
                  final docs = snapshot.data ?? const <Map<String, dynamic>>[];
                  if (docs.isEmpty) return const SizedBox.shrink();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ExpansionTile(
                      initiallyExpanded: true,
                      leading: const Icon(Icons.lock_person_outlined,
                          color: AppTheme.primaryColor),
                      title: const Text('Documentos particulares'),
                      subtitle: Text('${docs.length} documento(s) privados'),
                      children: docs
                          .map((doc) => ListTile(
                                title: Text(
                                    '${doc['title'] ?? doc['fileName'] ?? ''}'),
                                subtitle: Text('${doc['type'] ?? 'Documento'}'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.open_in_new),
                                  onPressed: () =>
                                      _openDocument('${doc['downloadUrl']}'),
                                ),
                              ))
                          .toList(),
                    ),
                  );
                },
              ),
            ],
            StreamBuilder<List<Documento>>(
              stream: firestoreService.getDocumentos(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final documentos = snapshot.data ?? [];
                if (documentos.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(48),
                      child: Column(
                        children: [
                          Icon(Icons.folder_open,
                              size: 64, color: AppTheme.textSecondary),
                          SizedBox(height: 16),
                          Text('No hay documentos disponibles.',
                              style: TextStyle(color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  );
                }
                final grouped = <String, List<Documento>>{};
                for (final doc in documentos) {
                  grouped.putIfAbsent(doc.tipo, () => []).add(doc);
                }
                final order = [
                  'estatutos',
                  'reglamento_interno',
                  'actas_junta_general',
                  ...grouped.keys.where((key) => ![
                        'estatutos',
                        'reglamento_interno',
                        'actas_junta_general'
                      ].contains(key)),
                ];
                return Column(
                  children: order.where(grouped.containsKey).map((tipo) {
                    final docs = grouped[tipo]!;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        leading: Icon(_getIconForType(tipo),
                            color: AppTheme.primaryColor),
                        title: Text(_folderName(tipo)),
                        subtitle: Text('${docs.length} documento(s)'),
                        children: docs
                            .map((doc) => ListTile(
                                  title: Text(doc.titulo),
                                  subtitle: Text(
                                    '${doc.fecha.day}/${doc.fecha.month}/${doc.fecha.year}',
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.download),
                                    onPressed: () =>
                                        _openDocument(doc.archivoUrl),
                                  ),
                                ))
                            .toList(),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForType(String tipo) {
    switch (tipo) {
      case 'acta':
      case 'actas_junta_general':
        return Icons.description;
      case 'estatuto':
      case 'estatutos':
        return Icons.gavel;
      case 'reglamento_interno':
        return Icons.rule_folder;
      case 'circular':
        return Icons.mail;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _folderName(String tipo) {
    switch (tipo) {
      case 'estatutos':
      case 'estatuto':
        return 'Estatutos';
      case 'reglamento_interno':
        return 'Reglamento Interno';
      case 'actas_junta_general':
      case 'acta':
        return 'Actas Junta General';
      default:
        return tipo.toUpperCase();
    }
  }

  Future<void> _openDocument(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
