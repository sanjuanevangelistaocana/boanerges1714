import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/firestore_service.dart';

class ManageTablonScreen extends StatelessWidget {
  const ManageTablonScreen({super.key});

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
                  Icon(Icons.campaign, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Text('Moderar Tabl\u00f3n de Anuncios',
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
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: fs.getAnuncios(),
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
                          child: Center(child: Text('No hay anuncios en el tabl\u00f3n.')),
                        ),
                      );
                    }

                    final pendientes = items.where((a) => a['aprobado'] != true && a['visible'] != false).toList();
                    final aprobados = items.where((a) => a['aprobado'] == true).toList();
                    final rechazados = items.where((a) => a['visible'] == false).toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (pendientes.isNotEmpty) ...[
                          _SectionTitle(title: 'Pendientes de aprobaci\u00f3n (${pendientes.length})', color: Colors.orange.shade700),
                          const SizedBox(height: 8),
                          ...pendientes.map((a) => _AdminAnuncioCard(anuncio: a, fs: fs)),
                          const SizedBox(height: 24),
                        ],
                        if (aprobados.isNotEmpty) ...[
                          _SectionTitle(title: 'Aprobados (${aprobados.length})', color: AppTheme.accentColor),
                          const SizedBox(height: 8),
                          ...aprobados.map((a) => _AdminAnuncioCard(anuncio: a, fs: fs)),
                          const SizedBox(height: 24),
                        ],
                        if (rechazados.isNotEmpty) ...[
                          _SectionTitle(title: 'Rechazados (${rechazados.length})', color: Colors.red.shade400),
                          const SizedBox(height: 8),
                          ...rechazados.map((a) => _AdminAnuncioCard(anuncio: a, fs: fs)),
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

class _AdminAnuncioCard extends StatelessWidget {
  final Map<String, dynamic> anuncio;
  final FirestoreService fs;
  const _AdminAnuncioCard({required this.anuncio, required this.fs});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    final fecha = (anuncio['fecha'] as Timestamp?)?.toDate() ?? DateTime.now();
    final id = anuncio['id'] as String? ?? '';
    final aprobado = anuncio['aprobado'] == true;
    final visible = anuncio['visible'] != false;
    final categoria = anuncio['categoria'] as String? ?? 'general';

    Color catColor;
    String catLabel;
    switch (categoria) {
      case 'venta':
        catColor = Colors.green.shade700;
        catLabel = 'Venta';
        break;
      case 'busqueda':
        catColor = Colors.blue.shade700;
        catLabel = 'B\u00fasqueda';
        break;
      case 'ofrecimiento':
        catColor = Colors.purple.shade700;
        catLabel = 'Ofrecimiento';
        break;
      case 'otro':
        catColor = Colors.grey.shade700;
        catLabel = 'Otro';
        break;
      default:
        catColor = AppTheme.accentColor;
        catLabel = 'General';
    }

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
                  decoration: BoxDecoration(color: catColor.withAlpha(20), borderRadius: BorderRadius.circular(4)),
                  child: Text(catLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: catColor)),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(anuncio['cofrade_nombre'] ?? '', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary))),
                Text(fmt.format(fecha), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
            const SizedBox(height: 8),
            Text(anuncio['titulo'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text(anuncio['mensaje'] ?? '', style: const TextStyle(color: AppTheme.textSecondary, height: 1.4)),
            const SizedBox(height: 12),
            Row(
              children: [
                if (!aprobado && visible) ...[
                  ElevatedButton.icon(
                    onPressed: () {
                      fs.aprobarAnuncio(id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Anuncio aprobado'), backgroundColor: AppTheme.accentColor),
                      );
                    },
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Aprobar'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentColor),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      fs.rechazarAnuncio(id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Anuncio rechazado')),
                      );
                    },
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Rechazar'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
                if (aprobado)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppTheme.accentColor.withAlpha(20), borderRadius: BorderRadius.circular(6)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 14, color: AppTheme.accentColor),
                        const SizedBox(width: 4),
                        Text('Aprobado', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accentColor)),
                      ],
                    ),
                  ),
                if (!visible)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.red.withAlpha(20), borderRadius: BorderRadius.circular(6)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.block, size: 14, color: Colors.red.shade400),
                        const SizedBox(width: 4),
                        Text('Rechazado', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red.shade400)),
                      ],
                    ),
                  ),
                const Spacer(),
                IconButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Eliminar anuncio'),
                        content: const Text('\u00bfSeguro que quieres eliminar este anuncio permanentemente?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            child: const Text('Eliminar'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      fs.eliminarAnuncio(id);
                    }
                  },
                  icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade300),
                  tooltip: 'Eliminar',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
