import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/models/evento.dart';

class ManageEventsScreen extends StatelessWidget {
  const ManageEventsScreen({super.key});

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
                Text('Gestionar Eventos',
                    style: Theme.of(context).textTheme.headlineMedium),
                ElevatedButton.icon(
                  onPressed: () => _showEventDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo Evento'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            StreamBuilder<List<Evento>>(
              stream: firestoreService.getEventos(soloPublicados: false),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final eventos = snapshot.data ?? [];
                if (eventos.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('No hay eventos.')),
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
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          evento.publicado
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: evento.publicado ? Colors.green : Colors.grey,
                        ),
                        title: Text(evento.titulo),
                        subtitle: Text(
                          '${evento.fecha.day}/${evento.fecha.month}/${evento.fecha.year}'
                          '${evento.hora != null ? ' · ${evento.hora}' : ''}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () =>
                                  _showEventDialog(context, evento: evento),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () =>
                                  _confirmDelete(context, evento),
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

  void _showEventDialog(BuildContext context, {Evento? evento}) {
    final tituloController =
        TextEditingController(text: evento?.titulo ?? '');
    final descripcionController =
        TextEditingController(text: evento?.descripcion ?? '');
    final horaController =
        TextEditingController(text: evento?.hora ?? '');
    final lugarController =
        TextEditingController(text: evento?.lugar ?? '');
    DateTime selectedDate = evento?.fecha ?? DateTime.now();
    bool publicado = evento?.publicado ?? true;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(evento == null ? 'Nuevo Evento' : 'Editar Evento'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: tituloController,
                  decoration: const InputDecoration(labelText: 'Título *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descripcionController,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                      'Fecha: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) {
                      setDialogState(() => selectedDate = date);
                    }
                  },
                ),
                TextField(
                  controller: horaController,
                  decoration:
                      const InputDecoration(labelText: 'Hora (ej: 20:00)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lugarController,
                  decoration: const InputDecoration(labelText: 'Lugar'),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Publicado'),
                  value: publicado,
                  onChanged: (v) => setDialogState(() => publicado = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (tituloController.text.isEmpty) return;
                final firestoreService = dialogContext.read<FirestoreService>();
                final newEvento = Evento(
                  id: evento?.id ?? '',
                  titulo: tituloController.text,
                  descripcion: descripcionController.text,
                  fecha: selectedDate,
                  hora: horaController.text.isNotEmpty
                      ? horaController.text
                      : null,
                  lugar: lugarController.text.isNotEmpty
                      ? lugarController.text
                      : null,
                  publicado: publicado,
                );
                if (evento == null) {
                  await firestoreService.createEvento(newEvento);
                } else {
                  await firestoreService.updateEvento(
                      evento.id, newEvento.toFirestore());
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(evento == null ? 'Crear' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Evento evento) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar evento'),
        content: Text('¿Estás seguro de eliminar "${evento.titulo}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await context.read<FirestoreService>().deleteEvento(evento.id);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
