import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/models/noticia.dart';

class ManageNewsScreen extends StatelessWidget {
  const ManageNewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Gestionar Noticias',
                    style: Theme.of(context).textTheme.headlineMedium),
                ElevatedButton.icon(
                  onPressed: () => _showNewsDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Nueva Noticia'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            StreamBuilder<List<Noticia>>(
              stream: firestoreService.getNoticias(soloPublicadas: false),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final noticias = snapshot.data ?? [];
                if (noticias.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('No hay noticias.')),
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
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          noticia.publicado
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color:
                              noticia.publicado ? Colors.green : Colors.grey,
                        ),
                        title: Text(noticia.titulo),
                        subtitle: Text(
                          '${noticia.fecha.day}/${noticia.fecha.month}/${noticia.fecha.year}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showNewsDialog(context,
                                  noticia: noticia),
                            ),
                            IconButton(
                              icon:
                                  const Icon(Icons.delete, color: Colors.red),
                              onPressed: () =>
                                  _confirmDelete(context, noticia),
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

  void _showNewsDialog(BuildContext context, {Noticia? noticia}) {
    final tituloController =
        TextEditingController(text: noticia?.titulo ?? '');
    final contenidoController =
        TextEditingController(text: noticia?.contenido ?? '');
    bool publicado = noticia?.publicado ?? true;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title:
              Text(noticia == null ? 'Nueva Noticia' : 'Editar Noticia'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: tituloController,
                    decoration:
                        const InputDecoration(labelText: 'Título *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contenidoController,
                    decoration:
                        const InputDecoration(labelText: 'Contenido *'),
                    maxLines: 6,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Publicada'),
                    value: publicado,
                    onChanged: (v) =>
                        setDialogState(() => publicado = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (tituloController.text.isEmpty ||
                    contenidoController.text.isEmpty) return;
                final firestoreService =
                    dialogContext.read<FirestoreService>();
                final newNoticia = Noticia(
                  id: noticia?.id ?? '',
                  titulo: tituloController.text,
                  contenido: contenidoController.text,
                  fecha: noticia?.fecha ?? DateTime.now(),
                  publicado: publicado,
                );
                if (noticia == null) {
                  await firestoreService.createNoticia(newNoticia);
                } else {
                  await firestoreService.updateNoticia(
                      noticia.id, newNoticia.toFirestore());
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(noticia == null ? 'Crear' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Noticia noticia) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar noticia'),
        content:
            Text('¿Estás seguro de eliminar "${noticia.titulo}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await context
                  .read<FirestoreService>()
                  .deleteNoticia(noticia.id);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
