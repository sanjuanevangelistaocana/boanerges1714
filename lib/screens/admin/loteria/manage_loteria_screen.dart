import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/models/loteria.dart';

class ManageLoteriaScreen extends StatelessWidget {
  const ManageLoteriaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    final fmt = DateFormat('dd/MM/yyyy');

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
                    const Icon(Icons.confirmation_number, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Lotería de Navidad',
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showCampanaDialog(context, fs),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Nueva Campaña'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryColor,
                      ),
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
                child: StreamBuilder<List<CampanaLoteria>>(
                  stream: fs.getCampanasLoteria(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final campanas = snapshot.data ?? [];
                    if (campanas.isEmpty) {
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(40),
                          child: Column(
                            children: [
                              Icon(Icons.confirmation_number_outlined, size: 48, color: AppTheme.textSecondary),
                              SizedBox(height: 12),
                              Text('No hay campañas creadas', style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
                              SizedBox(height: 4),
                              Text('Crea una nueva campaña para empezar a gestionar la lotería.',
                                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: campanas.map((c) {
                        final isActiva = c.isActiva;
                        return Card(
                          elevation: isActiva ? 2 : 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isActiva ? AppTheme.accentColor.withAlpha(100) : Colors.grey.shade200,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isActiva ? AppTheme.accentColor.withAlpha(20) : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isActiva ? 'ACTIVA' : 'CERRADA',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isActiva ? AppTheme.accentColor : Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    PopupMenuButton<String>(
                                      onSelected: (action) async {
                                        if (action == 'edit') {
                                          _showCampanaDialog(context, fs, campana: c);
                                        } else if (action == 'toggle') {
                                          await fs.updateCampanaLoteria(c.id, {
                                            'estado': isActiva ? 'cerrada' : 'activa',
                                          });
                                        } else if (action == 'delete') {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('Eliminar campaña'),
                                              content: const Text('¿Seguro? Se perderán todos los datos de esta campaña.'),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                                                TextButton(
                                                  onPressed: () => Navigator.pop(ctx, true),
                                                  child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) await fs.deleteCampanaLoteria(c.id);
                                        }
                                      },
                                      itemBuilder: (_) => [
                                        const PopupMenuItem(value: 'edit', child: Text('Editar')),
                                        PopupMenuItem(
                                          value: 'toggle',
                                          child: Text(isActiva ? 'Cerrar campaña' : 'Reactivar'),
                                        ),
                                        const PopupMenuItem(value: 'delete', child: Text('Eliminar', style: TextStyle(color: Colors.red))),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(c.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 8,
                                  children: [
                                    _InfoChip(icon: Icons.tag, label: 'Nº ${c.numeroLoteria}'),
                                    _InfoChip(icon: Icons.euro, label: '${c.precioVenta.toStringAsFixed(2)}€/décimo'),
                                    _InfoChip(icon: Icons.store, label: c.administracionNombre.isNotEmpty ? c.administracionNombre : 'Sin administración'),
                                    if (c.fechaInicio != null) _InfoChip(icon: Icons.calendar_today, label: fmt.format(c.fechaInicio!)),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () => context.go('/admin/loteria/dashboard?campanaId=${c.id}'),
                                      icon: const Icon(Icons.dashboard, size: 16),
                                      label: const Text('Dashboard'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => context.go('/admin/loteria/sabanas?campanaId=${c.id}'),
                                      icon: const Icon(Icons.receipt_long, size: 16),
                                      label: const Text('Sábanas'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => context.go('/admin/loteria/vendedores'),
                                      icon: const Icon(Icons.people, size: 16),
                                      label: const Text('Vendedores'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => context.go('/admin/loteria/asignaciones?campanaId=${c.id}'),
                                      icon: const Icon(Icons.assignment, size: 16),
                                      label: const Text('Asignaciones'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
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

  void _showCampanaDialog(BuildContext context, FirestoreService fs, {CampanaLoteria? campana}) {
    final isEdit = campana != null;
    final nombreCtrl = TextEditingController(text: campana?.nombre ?? '');
    final numeroCtrl = TextEditingController(text: campana?.numeroLoteria.toString() ?? '');
    final precioBaseCtrl = TextEditingController(text: campana?.precioDecimoBase.toStringAsFixed(2) ?? '20.00');
    final recargoCtrl = TextEditingController(text: campana?.recargo.toStringAsFixed(2) ?? '3.00');
    final adminCtrl = TextEditingController(text: campana?.administracionNombre ?? '');
    DateTime? fechaInicio = campana?.fechaInicio;
    DateTime? fechaFin = campana?.fechaFin;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final precioBase = double.tryParse(precioBaseCtrl.text) ?? 0;
          final recargo = double.tryParse(recargoCtrl.text) ?? 0;
          final precioVenta = precioBase + recargo;
          final fmt = DateFormat('dd/MM/yyyy');

          return AlertDialog(
            title: Text(isEdit ? 'Editar Campaña' : 'Nueva Campaña'),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nombreCtrl,
                      decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej: Navidad 2026'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: numeroCtrl,
                      decoration: const InputDecoration(labelText: 'Número de lotería', hintText: 'Ej: 12345'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: precioBaseCtrl,
                            decoration: const InputDecoration(labelText: 'Precio base (€)', hintText: '20.00'),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: recargoCtrl,
                            decoration: const InputDecoration(labelText: 'Recargo (€)', hintText: '3.00'),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor.withAlpha(15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.euro, size: 16, color: AppTheme.accentColor),
                          const SizedBox(width: 6),
                          Text(
                            'Precio de venta: ${precioVenta.toStringAsFixed(2)}€',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentColor),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: adminCtrl,
                      decoration: const InputDecoration(labelText: 'Nombre administración', hintText: 'Ej: Adm. Lotería nº 3'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: fechaInicio ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2050),
                              );
                              if (picked != null) setState(() => fechaInicio = picked);
                            },
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(fechaInicio != null ? fmt.format(fechaInicio!) : 'Fecha inicio'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: fechaFin ?? DateTime(DateTime.now().year, 12, 22),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2050),
                              );
                              if (picked != null) setState(() => fechaFin = picked);
                            },
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(fechaFin != null ? fmt.format(fechaFin!) : 'Fecha fin'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () async {
                  final nombre = nombreCtrl.text.trim();
                  final numero = int.tryParse(numeroCtrl.text.trim()) ?? 0;
                  if (nombre.isEmpty || numero == 0) return;

                  final pBase = double.tryParse(precioBaseCtrl.text) ?? 20.0;
                  final rec = double.tryParse(recargoCtrl.text) ?? 0.0;

                  if (isEdit) {
                    await fs.updateCampanaLoteria(campana.id, {
                      'nombre': nombre,
                      'numero_loteria': numero,
                      'precio_decimo_base': pBase,
                      'recargo': rec,
                      'precio_venta': pBase + rec,
                      'administracion_nombre': adminCtrl.text.trim(),
                      'fecha_inicio': fechaInicio != null ? fechaInicio : null,
                      'fecha_fin': fechaFin != null ? fechaFin : null,
                    });
                  } else {
                    await fs.createCampanaLoteria(CampanaLoteria(
                      id: '',
                      nombre: nombre,
                      numeroLoteria: numero,
                      precioDecimoBase: pBase,
                      recargo: rec,
                      precioVenta: pBase + rec,
                      fechaInicio: fechaInicio,
                      fechaFin: fechaFin,
                      administracionNombre: adminCtrl.text.trim(),
                    ));
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(isEdit ? 'Guardar' : 'Crear'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
      ],
    );
  }
}
