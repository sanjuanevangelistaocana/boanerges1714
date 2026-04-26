import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/firestore_service.dart';

class ManageFestividadScreen extends StatelessWidget {
  const ManageFestividadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.primaryDark, AppTheme.primaryColor],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 28, 32, 24),
              child: Row(
                children: [
                  const Icon(Icons.celebration, color: Colors.white70, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Festividad San Juan Evangelista',
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showCrearEdicionDialog(context, fs),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nueva edición'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: fs.getFestividadEdiciones(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final ediciones = snap.data ?? [];
                  if (ediciones.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            Icon(Icons.celebration, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            const Text('No hay ediciones creadas.',
                                style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
                            const SizedBox(height: 8),
                            const Text('Crea la primera edición anual del evento.',
                                style: TextStyle(color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: ediciones.map((ed) => _EdicionCard(edicion: ed, fs: fs)).toList(),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCrearEdicionDialog(BuildContext context, FirestoreService fs) {
    final anio = DateTime.now().year;
    final nombreCtrl = TextEditingController(text: 'Festividad San Juan Evangelista $anio');
    final precioHermanoCtrl = TextEditingController(text: '5');
    final precioInvitadoCtrl = TextEditingController(text: '27');
    final horaCtrl = TextEditingController(text: '14:00');
    final lugarCtrl = TextEditingController();
    final direccionCtrl = TextEditingController();
    final descripcionCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva edición'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nombreCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre del evento', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextField(controller: precioHermanoCtrl,
                        decoration: const InputDecoration(labelText: 'Precio hermano (€)', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: precioInvitadoCtrl,
                        decoration: const InputDecoration(labelText: 'Precio invitado (€)', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextField(controller: horaCtrl,
                        decoration: const InputDecoration(labelText: 'Hora', border: OutlineInputBorder()))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: lugarCtrl,
                        decoration: const InputDecoration(labelText: 'Lugar', border: OutlineInputBorder()))),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(controller: direccionCtrl,
                    decoration: const InputDecoration(labelText: 'Dirección', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: descripcionCtrl,
                    decoration: const InputDecoration(labelText: 'Descripción', border: OutlineInputBorder()),
                    maxLines: 3),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final data = {
                'nombre': nombreCtrl.text.trim(),
                'anio': anio,
                'fecha': Timestamp.fromDate(DateTime(anio, 12, 27)),
                'hora': horaCtrl.text.trim(),
                'lugar': lugarCtrl.text.trim(),
                'direccion': direccionCtrl.text.trim(),
                'descripcion': descripcionCtrl.text.trim(),
                'precio_hermano': double.tryParse(precioHermanoCtrl.text) ?? 5.0,
                'precio_invitado': double.tryParse(precioInvitadoCtrl.text) ?? 27.0,
                'precio_protocolo': 0.0,
                'fecha_limite': Timestamp.fromDate(DateTime(anio, 12, 20)),
                'estado': 'borrador',
              };
              await fs.createFestividadEdicion(data);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }
}

class _EdicionCard extends StatelessWidget {
  final Map<String, dynamic> edicion;
  final FirestoreService fs;
  const _EdicionCard({required this.edicion, required this.fs});

  @override
  Widget build(BuildContext context) {
    final ed = edicion;
    final estado = ed['estado'] ?? 'borrador';
    final fmt = DateFormat('dd/MM/yyyy');
    final fecha = (ed['fecha'] as Timestamp?)?.toDate();
    final fechaLimite = (ed['fecha_limite'] as Timestamp?)?.toDate();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(ed['nombre'] ?? 'Sin nombre',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ),
                _EstadoBadge(estado: estado),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                if (fecha != null) _ChipInfo(icon: Icons.calendar_today, text: fmt.format(fecha)),
                if (fechaLimite != null) _ChipInfo(icon: Icons.timer, text: 'Límite: ${fmt.format(fechaLimite)}'),
                _ChipInfo(icon: Icons.euro, text: 'Hermano: ${ed['precio_hermano']}€ · Invitado: ${ed['precio_invitado']}€'),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ActionBtn(label: 'Editar', icon: Icons.edit, onTap: () => _showEditDialog(context, ed)),
                _ActionBtn(label: 'Menús', icon: Icons.restaurant_menu,
                    onTap: () => context.go('/admin/festividad/menus?edicionId=${ed['id']}')),
                _ActionBtn(label: 'Inscripciones', icon: Icons.people,
                    onTap: () => context.go('/admin/festividad/inscripciones?edicionId=${ed['id']}')),
                _ActionBtn(label: 'Informe', icon: Icons.analytics,
                    onTap: () => context.go('/admin/festividad/informe?edicionId=${ed['id']}')),
                PopupMenuButton<String>(
                  onSelected: (v) => _cambiarEstado(context, ed['id'], v),
                  itemBuilder: (_) => [
                    if (estado == 'borrador')
                      const PopupMenuItem(value: 'abierto', child: Text('Abrir inscripciones')),
                    if (estado == 'abierto')
                      const PopupMenuItem(value: 'cerrado', child: Text('Cerrar inscripciones')),
                    if (estado == 'cerrado')
                      const PopupMenuItem(value: 'finalizado', child: Text('Finalizar evento')),
                    if (estado != 'borrador')
                      const PopupMenuItem(value: 'borrador', child: Text('Volver a borrador')),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.swap_horiz, size: 16),
                        SizedBox(width: 4),
                        Text('Estado', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _cambiarEstado(BuildContext context, String id, String nuevoEstado) async {
    await fs.updateFestividadEdicion(id, {'estado': nuevoEstado});
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Estado cambiado a: $nuevoEstado')));
    }
  }

  void _showEditDialog(BuildContext context, Map<String, dynamic> ed) {
    final nombreCtrl = TextEditingController(text: ed['nombre'] ?? '');
    final precioHermanoCtrl = TextEditingController(text: '${ed['precio_hermano'] ?? 5}');
    final precioInvitadoCtrl = TextEditingController(text: '${ed['precio_invitado'] ?? 27}');
    final horaCtrl = TextEditingController(text: ed['hora'] ?? '');
    final lugarCtrl = TextEditingController(text: ed['lugar'] ?? '');
    final direccionCtrl = TextEditingController(text: ed['direccion'] ?? '');
    final descripcionCtrl = TextEditingController(text: ed['descripcion'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar edición'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nombreCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextField(controller: precioHermanoCtrl,
                        decoration: const InputDecoration(labelText: 'Precio hermano (€)', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: precioInvitadoCtrl,
                        decoration: const InputDecoration(labelText: 'Precio invitado (€)', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextField(controller: horaCtrl,
                        decoration: const InputDecoration(labelText: 'Hora', border: OutlineInputBorder()))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: lugarCtrl,
                        decoration: const InputDecoration(labelText: 'Lugar', border: OutlineInputBorder()))),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(controller: direccionCtrl,
                    decoration: const InputDecoration(labelText: 'Dirección', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: descripcionCtrl,
                    decoration: const InputDecoration(labelText: 'Descripción', border: OutlineInputBorder()),
                    maxLines: 3),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              await fs.updateFestividadEdicion(ed['id'], {
                'nombre': nombreCtrl.text.trim(),
                'precio_hermano': double.tryParse(precioHermanoCtrl.text) ?? 5.0,
                'precio_invitado': double.tryParse(precioInvitadoCtrl.text) ?? 27.0,
                'hora': horaCtrl.text.trim(),
                'lugar': lugarCtrl.text.trim(),
                'direccion': direccionCtrl.text.trim(),
                'descripcion': descripcionCtrl.text.trim(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

class _EstadoBadge extends StatelessWidget {
  final String estado;
  const _EstadoBadge({required this.estado});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (estado) {
      case 'abierto': color = AppTheme.accentColor; label = 'Abierto'; break;
      case 'cerrado': color = Colors.orange; label = 'Cerrado'; break;
      case 'finalizado': color = Colors.grey; label = 'Finalizado'; break;
      default: color = Colors.blue; label = 'Borrador';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _ChipInfo extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ChipInfo({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}
