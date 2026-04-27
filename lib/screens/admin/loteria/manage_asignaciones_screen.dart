import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/models/loteria.dart';

class ManageAsignacionesScreen extends StatelessWidget {
  final String campanaId;
  const ManageAsignacionesScreen({super.key, required this.campanaId});

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
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Row(
                  children: [
                    const Icon(Icons.assignment, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Asignaciones',
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showAsignarDialog(context, fs),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Nueva Asignación'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppTheme.primaryColor),
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
                constraints: const BoxConstraints(maxWidth: 1000),
                child: StreamBuilder<List<AsignacionLoteria>>(
                  stream: fs.getAsignaciones(campanaId),
                  builder: (context, asigSnap) {
                    return StreamBuilder<List<VendedorLoteria>>(
                      stream: fs.getVendedoresLoteria(),
                      builder: (context, vendSnap) {
                        return StreamBuilder<List<Sabana>>(
                          stream: fs.getSabanas(campanaId),
                          builder: (context, sabSnap) {
                            if (asigSnap.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            final asignaciones = asigSnap.data ?? [];
                            final vendedores = vendSnap.data ?? [];
                            final sabanas = sabSnap.data ?? [];

                            final vendMap = {for (final v in vendedores) v.id: v};
                            final sabMap = {for (final s in sabanas) s.id: s};

                            if (asignaciones.isEmpty) {
                              return const Card(
                                child: Padding(
                                  padding: EdgeInsets.all(40),
                                  child: Center(child: Text('No hay asignaciones. Crea una para asignar sábanas a vendedores.')),
                                ),
                              );
                            }

                            final totalAsignados = asignaciones.fold<int>(0, (s, a) => s + a.decimosAsignados);
                            final totalVendidos = asignaciones.fold<int>(0, (s, a) => s + a.decimosVendidos);
                            final totalDevueltos = asignaciones.fold<int>(0, (s, a) => s + a.decimosDevueltos);

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Card(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        _MiniStat(value: '${asignaciones.length}', label: 'Asignaciones', color: AppTheme.primaryColor),
                                        _MiniStat(value: '$totalAsignados', label: 'Asignados', color: Colors.orange.shade700),
                                        _MiniStat(value: '$totalVendidos', label: 'Vendidos', color: AppTheme.accentColor),
                                        _MiniStat(value: '$totalDevueltos', label: 'Devueltos', color: Colors.red.shade600),
                                        _MiniStat(value: '${totalAsignados - totalVendidos - totalDevueltos}', label: 'Pendientes', color: AppTheme.primaryColor),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ...asignaciones.map((a) {
                                  final vendedor = vendMap[a.vendedorId];
                                  final sabana = sabMap[a.sabanaId];
                                  final disponibles = a.decimosDisponibles;
                                  final pctVenta = a.decimosAsignados > 0
                                      ? (a.decimosVendidos / a.decimosAsignados * 100)
                                      : 0.0;

                                  return Card(
                                    elevation: 0,
                                    margin: const EdgeInsets.only(bottom: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: BorderSide(color: Colors.grey.shade200),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.primaryColor.withAlpha(15),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Icon(Icons.assignment, color: AppTheme.primaryColor),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      vendedor?.nombre ?? 'Vendedor desconocido',
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                    ),
                                                    Text(
                                                      'Sábana: ${sabana?.referencia ?? sabana?.id.substring(0, 6) ?? "?"} · ${vendedor?.isCofrade == true ? "Cofrade" : "Externo"}',
                                                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              PopupMenuButton<String>(
                                                onSelected: (action) async {
                                                  if (action == 'delete') {
                                                    final confirm = await showDialog<bool>(
                                                      context: context,
                                                      builder: (ctx) => AlertDialog(
                                                        title: const Text('Eliminar asignación'),
                                                        content: const Text('¿Seguro? La sábana volverá a estar disponible.'),
                                                        actions: [
                                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                                                          TextButton(
                                                            onPressed: () => Navigator.pop(ctx, true),
                                                            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                    if (confirm == true) await fs.deleteAsignacion(a.id);
                                                  } else if (action == 'copy_token' && a.tokenAcceso != null) {
                                                    Clipboard.setData(ClipboardData(text: a.tokenAcceso!));
                                                    if (context.mounted) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(content: Text('Token copiado al portapapeles')),
                                                      );
                                                    }
                                                  }
                                                },
                                                itemBuilder: (_) => [
                                                  if (a.tokenAcceso != null)
                                                    const PopupMenuItem(value: 'copy_token', child: Text('Copiar enlace externo')),
                                                  const PopupMenuItem(value: 'delete', child: Text('Eliminar', style: TextStyle(color: Colors.red))),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              _AsigChip(label: 'Asignados', value: '${a.decimosAsignados}', color: AppTheme.primaryColor),
                                              const SizedBox(width: 8),
                                              _AsigChip(label: 'Vendidos', value: '${a.decimosVendidos}', color: AppTheme.accentColor),
                                              const SizedBox(width: 8),
                                              _AsigChip(label: 'Devueltos', value: '${a.decimosDevueltos}', color: Colors.red.shade600),
                                              const SizedBox(width: 8),
                                              _AsigChip(label: 'Disponibles', value: '$disponibles', color: Colors.orange.shade700),
                                              const Spacer(),
                                              Text('${pctVenta.toStringAsFixed(0)}%', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentColor)),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(4),
                                            child: LinearProgressIndicator(
                                              value: a.decimosAsignados > 0 ? a.decimosVendidos / a.decimosAsignados : 0,
                                              backgroundColor: Colors.grey.shade200,
                                              color: AppTheme.accentColor,
                                              minHeight: 6,
                                            ),
                                          ),
                                          if (a.tokenAcceso != null) ...[
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                const Icon(Icons.link, size: 14, color: AppTheme.textSecondary),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: SelectableText(
                                                    'Token: ${a.tokenAcceso}',
                                                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            );
                          },
                        );
                      },
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

  void _showAsignarDialog(BuildContext context, FirestoreService fs) {
    String? selectedVendedorId;
    String? selectedSabanaId;
    final decimosCtrl = TextEditingController(text: '10');
    bool generarToken = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Nueva Asignación'),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StreamBuilder<List<VendedorLoteria>>(
                  stream: fs.getVendedoresLoteria(),
                  builder: (context, snap) {
                    final vendedores = snap.data ?? [];
                    return DropdownButtonFormField<String>(
                      value: selectedVendedorId,
                      decoration: const InputDecoration(labelText: 'Vendedor'),
                      items: vendedores.map((v) => DropdownMenuItem(
                        value: v.id,
                        child: Text('${v.nombre} (${v.isCofrade ? "Cofrade" : "Externo"})'),
                      )).toList(),
                      onChanged: (v) => setState(() => selectedVendedorId = v),
                    );
                  },
                ),
                const SizedBox(height: 12),
                StreamBuilder<List<Sabana>>(
                  stream: fs.getSabanas(campanaId),
                  builder: (context, snap) {
                    final sabanas = (snap.data ?? []).where((s) => s.estado == 'disponible').toList();
                    return DropdownButtonFormField<String>(
                      value: selectedSabanaId,
                      decoration: const InputDecoration(labelText: 'Sábana disponible'),
                      items: sabanas.map((s) => DropdownMenuItem(
                        value: s.id,
                        child: Text('Nº ${s.numeroLoteria}${s.referencia != null ? " · ${s.referencia}" : ""} (${s.totalDecimos} décimos)'),
                      )).toList(),
                      onChanged: (v) => setState(() => selectedSabanaId = v),
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: decimosCtrl,
                  decoration: const InputDecoration(labelText: 'Décimos a asignar'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: generarToken,
                  onChanged: (v) => setState(() => generarToken = v ?? false),
                  title: const Text('Generar enlace externo (token)'),
                  subtitle: const Text('Para vendedores externos sin cuenta'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (selectedVendedorId == null || selectedSabanaId == null) return;
                final decimos = int.tryParse(decimosCtrl.text) ?? 10;
                if (decimos <= 0) return;

                String? token;
                if (generarToken) {
                  final rng = Random.secure();
                  token = List.generate(24, (_) => 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'[rng.nextInt(62)]).join();
                }

                await fs.createAsignacion(AsignacionLoteria(
                  id: '',
                  campanaId: campanaId,
                  sabanaId: selectedSabanaId!,
                  vendedorId: selectedVendedorId!,
                  decimosAsignados: decimos,
                  tokenAcceso: token,
                ));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Asignar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AsigChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _AsigChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _MiniStat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }
}
