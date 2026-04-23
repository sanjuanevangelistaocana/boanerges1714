import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/models/sugerencia.dart';

class ManageSugerenciasScreen extends StatelessWidget {
  const ManageSugerenciasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [AppTheme.primaryDark, AppTheme.primaryColor]),
            ),
            child: const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Text('Gestionar Sugerencias y Peticiones',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: StreamBuilder<List<Sugerencia>>(
                  stream: fs.getSugerencias(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final items = snapshot.data ?? [];
                    if (items.isEmpty) {
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                        child: const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: Text('No hay sugerencias ni peticiones.')),
                        ),
                      );
                    }
                    final pendientes = items.where((s) => s.estado == 'pendiente').toList();
                    final respondidas = items.where((s) => s.estado != 'pendiente').toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (pendientes.isNotEmpty) ...[
                          _SectionTitle(title: 'Pendientes (${pendientes.length})', color: Colors.orange.shade700),
                          const SizedBox(height: 8),
                          ...pendientes.map((s) => _AdminSugerenciaCard(sugerencia: s, fs: fs)),
                          const SizedBox(height: 24),
                        ],
                        if (respondidas.isNotEmpty) ...[
                          _SectionTitle(title: 'Gestionadas (${respondidas.length})', color: AppTheme.accentColor),
                          const SizedBox(height: 8),
                          ...respondidas.map((s) => _AdminSugerenciaCard(sugerencia: s, fs: fs)),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionTitle({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 4, height: 24, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
      ],
    );
  }
}

class _AdminSugerenciaCard extends StatelessWidget {
  final Sugerencia sugerencia;
  final FirestoreService fs;
  const _AdminSugerenciaCard({required this.sugerencia, required this.fs});

  void _responder(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Responder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('De: ${sugerencia.cofradeNombre}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(sugerencia.titulo, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 8),
            Text(sugerencia.mensaje, style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Tu respuesta', border: OutlineInputBorder()),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                fs.responderSugerencia(sugerencia.id, controller.text.trim());
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Respuesta enviada'), backgroundColor: AppTheme.accentColor),
                );
              }
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    final esPeticion = sugerencia.tipo == 'peticion';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (esPeticion ? Colors.orange : AppTheme.accentColor).withAlpha(20),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(esPeticion ? 'Petición' : 'Sugerencia',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: esPeticion ? Colors.orange.shade700 : AppTheme.accentColor)),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(sugerencia.cofradeNombre, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary))),
                Text(fmt.format(sugerencia.fecha), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
            const SizedBox(height: 8),
            Text(sugerencia.titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text(sugerencia.mensaje, style: const TextStyle(color: AppTheme.textSecondary, height: 1.4)),
            if (sugerencia.respuestaAdmin != null && sugerencia.respuestaAdmin!.isNotEmpty) ...[
              const Divider(height: 16),
              Row(
                children: [
                  const Icon(Icons.reply, size: 14, color: AppTheme.primaryColor),
                  const SizedBox(width: 4),
                  const Text('Respuesta:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor)),
                ],
              ),
              const SizedBox(height: 4),
              Text(sugerencia.respuestaAdmin!),
            ],
            if (sugerencia.estado == 'pendiente') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => fs.marcarSugerenciaLeida(sugerencia.id),
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('Marcar leída'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _responder(context),
                    icon: const Icon(Icons.reply, size: 16),
                    label: const Text('Responder'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
