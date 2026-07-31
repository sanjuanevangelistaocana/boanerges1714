import 'package:flutter/material.dart';
import 'package:boanerges1714/widgets/responsive_dialog.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/models/loteria.dart';

class ManageSabanasScreen extends StatelessWidget {
  final String campanaId;
  const ManageSabanasScreen({super.key, required this.campanaId});

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
              gradient: LinearGradient(
                  colors: [AppTheme.primaryDark, AppTheme.primaryColor]),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long,
                        color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Gestión de Sábanas',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showCrearSabanaDialog(context, fs),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Añadir Sábana'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.primaryColor),
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
                child: StreamBuilder<List<Sabana>>(
                  stream: fs.getSabanas(campanaId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final sabanas = snapshot.data ?? [];
                    if (sabanas.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(
                              child: Text(
                                  'No hay sábanas. Añade una sábana para empezar.')),
                        ),
                      );
                    }

                    final disponibles =
                        sabanas.where((s) => s.estado == 'disponible').length;
                    final asignadas =
                        sabanas.where((s) => s.estado == 'asignada').length;
                    final agotadas =
                        sabanas.where((s) => s.estado == 'agotada').length;
                    final totalDecimos =
                        sabanas.fold<int>(0, (sum, s) => sum + s.totalDecimos);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade200)),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _MiniStat(
                                    value: '${sabanas.length}',
                                    label: 'Sábanas',
                                    color: AppTheme.primaryColor),
                                _MiniStat(
                                    value: '$totalDecimos',
                                    label: 'Décimos',
                                    color: AppTheme.primaryColor),
                                _MiniStat(
                                    value: '$disponibles',
                                    label: 'Disponibles',
                                    color: AppTheme.accentColor),
                                _MiniStat(
                                    value: '$asignadas',
                                    label: 'Asignadas',
                                    color: Colors.orange.shade700),
                                _MiniStat(
                                    value: '$agotadas',
                                    label: 'Agotadas',
                                    color: Colors.red.shade600),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...sabanas.map((s) => _SabanaCard(
                            sabana: s, fs: fs, campanaId: campanaId)),
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

  void _showCrearSabanaDialog(BuildContext context, FirestoreService fs) async {
    final campana = await fs.getCampanaById(campanaId);
    if (campana == null || !context.mounted) return;

    final referenciaCtrl = TextEditingController();
    final serieCtrl = TextEditingController();
    final precioCompraCtrl = TextEditingController(
        text: (campana.precioDecimoBase * 10).toStringAsFixed(2));
    String? error;

    showAppDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Añadir Sábana'),
          content: ResponsiveDialogBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: serieCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Serie *', hintText: 'Ej: 001'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: referenciaCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Referencia (opcional)',
                      hintText: 'Ej: Administración / talonario'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: precioCompraCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Precio compra (€)', hintText: '200.00'),
                  keyboardType: TextInputType.number,
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: TextStyle(color: Colors.red.shade700)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (serieCtrl.text.trim().isEmpty) {
                  setState(() => error = 'La serie es obligatoria.');
                  return;
                }
                try {
                  await fs.createSabana(Sabana(
                    id: '',
                    campanaId: campanaId,
                    numeroLoteria: campana.numeroLoteria,
                    precioCompra: double.tryParse(precioCompraCtrl.text) ??
                        (campana.precioDecimoBase * 10),
                    precioVentaUnidad: campana.precioVenta,
                    administracionNombre: campana.administracionNombre,
                    referencia: referenciaCtrl.text.trim().isNotEmpty
                        ? referenciaCtrl.text.trim()
                        : null,
                    serie: serieCtrl.text.trim(),
                  ));
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  setState(() => error = e.toString());
                }
              },
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SabanaCard extends StatelessWidget {
  final Sabana sabana;
  final FirestoreService fs;
  final String campanaId;
  const _SabanaCard(
      {required this.sabana, required this.fs, required this.campanaId});

  @override
  Widget build(BuildContext context) {
    Color estadoColor;
    switch (sabana.estado) {
      case 'disponible':
        estadoColor = AppTheme.accentColor;
        break;
      case 'asignada':
        estadoColor = Colors.orange.shade700;
        break;
      case 'agotada':
        estadoColor = Colors.red.shade600;
        break;
      default:
        estadoColor = Colors.grey.shade600;
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: estadoColor.withAlpha(20),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.receipt_long, color: estadoColor),
        ),
        title: Text(
          'Sábana Nº ${sabana.numeroLoteria}${sabana.referencia != null ? ' · ${sabana.referencia}' : ''}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Serie ${sabana.serie} · ${sabana.totalDecimos} décimos · ${sabana.precioCompra.toStringAsFixed(2)}€ compra · ${sabana.precioVentaUnidad.toStringAsFixed(2)}€/ud · ${sabana.estado.toUpperCase()}'
          '${sabana.pagadaAdministracion ? ' · Pagada' : ''}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) async {
            if (action == 'pagar') {
              await fs.updateSabana(sabana.id, {
                'pagada_administracion': !sabana.pagadaAdministracion,
                'fecha_pago_administracion':
                    sabana.pagadaAdministracion ? null : DateTime.now(),
              });
            } else if (action == 'delete') {
              await fs.deleteSabana(sabana.id);
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'pagar',
              child: Text(sabana.pagadaAdministracion
                  ? 'Desmarcar pago'
                  : 'Marcar como pagada'),
            ),
            const PopupMenuItem(
                value: 'delete',
                child: Text('Eliminar', style: TextStyle(color: Colors.red))),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _MiniStat(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style:
                const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }
}
