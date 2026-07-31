import 'package:flutter/material.dart';
import 'package:boanerges1714/widgets/responsive_dialog.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/firestore_service.dart';

class ManageMenusFestividadScreen extends StatelessWidget {
  final String edicionId;
  const ManageMenusFestividadScreen({super.key, required this.edicionId});

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
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.restaurant_menu,
                      color: Colors.white70, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Gestión de Menús',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showCrearMenuDialog(context, fs),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nuevo menú'),
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
              constraints: const BoxConstraints(maxWidth: 800),
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: fs.getFestividadMenus(edicionId),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final menus = snap.data ?? [];
                  if (menus.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            Icon(Icons.restaurant_menu,
                                size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            const Text('No hay menús configurados.',
                                style: TextStyle(
                                    fontSize: 16,
                                    color: AppTheme.textSecondary)),
                            const SizedBox(height: 8),
                            const Text(
                                'Crea los menús disponibles para esta edición.',
                                style:
                                    TextStyle(color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                    );
                  }
                  return ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: menus.length,
                    onReorder: (oldIdx, newIdx) {
                      if (newIdx > oldIdx) newIdx--;
                      final reordered = List<Map<String, dynamic>>.from(menus);
                      final item = reordered.removeAt(oldIdx);
                      reordered.insert(newIdx, item);
                      for (int i = 0; i < reordered.length; i++) {
                        fs.updateFestividadMenu(
                            edicionId, reordered[i]['id'], {'orden': i});
                      }
                    },
                    itemBuilder: (context, idx) {
                      final m = menus[idx];
                      final activo = m['activo'] == true;
                      final extra =
                          (m['precio_extra'] as num?)?.toDouble() ?? 0;
                      return Card(
                        key: ValueKey(m['id']),
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                              color: activo
                                  ? AppTheme.accentColor.withAlpha(60)
                                  : Colors.grey.shade200),
                        ),
                        child: ListTile(
                          leading: Icon(Icons.restaurant,
                              color:
                                  activo ? AppTheme.accentColor : Colors.grey),
                          title: Text(m['nombre'] ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: activo
                                    ? AppTheme.textPrimary
                                    : AppTheme.textSecondary,
                                decoration:
                                    activo ? null : TextDecoration.lineThrough,
                              )),
                          subtitle: Text(
                            '${m['descripcion'] ?? ''}${extra > 0 ? ' · +${extra.toStringAsFixed(2)} €' : ''}',
                            style: const TextStyle(fontSize: 13),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: activo,
                                activeColor: AppTheme.accentColor,
                                onChanged: (v) => fs.updateFestividadMenu(
                                    edicionId, m['id'], {'activo': v}),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () =>
                                    _showEditMenuDialog(context, fs, m),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete,
                                    size: 20, color: Colors.red.shade400),
                                onPressed: () =>
                                    _deleteMenu(context, fs, m['id']),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCrearMenuDialog(BuildContext context, FirestoreService fs) {
    final nombreCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final precioExtraCtrl = TextEditingController(text: '0');

    showAppDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo menú'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Nombre *',
                      border: OutlineInputBorder(),
                      hintText: 'Ej: Adulto, Niño, Vegetariano...')),
              const SizedBox(height: 12),
              TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Descripción (opcional)',
                      border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(
                  controller: precioExtraCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Precio extra (€)',
                      border: OutlineInputBorder()),
                  keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (nombreCtrl.text.trim().isEmpty) return;
              final menus = await fs.getFestividadMenus(edicionId).first;
              await fs.createFestividadMenu(edicionId, {
                'nombre': nombreCtrl.text.trim(),
                'descripcion': descCtrl.text.trim(),
                'precio_extra': double.tryParse(precioExtraCtrl.text) ?? 0,
                'activo': true,
                'orden': menus.length,
              });
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  void _showEditMenuDialog(
      BuildContext context, FirestoreService fs, Map<String, dynamic> m) {
    final nombreCtrl = TextEditingController(text: m['nombre'] ?? '');
    final descCtrl = TextEditingController(text: m['descripcion'] ?? '');
    final precioExtraCtrl =
        TextEditingController(text: '${m['precio_extra'] ?? 0}');

    showAppDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar menú'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Nombre *', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Descripción', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(
                  controller: precioExtraCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Precio extra (€)',
                      border: OutlineInputBorder()),
                  keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              await fs.updateFestividadMenu(edicionId, m['id'], {
                'nombre': nombreCtrl.text.trim(),
                'descripcion': descCtrl.text.trim(),
                'precio_extra': double.tryParse(precioExtraCtrl.text) ?? 0,
              });
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _deleteMenu(
      BuildContext context, FirestoreService fs, String menuId) async {
    final inUse = await fs.isMenuUsedInInscripciones(edicionId, menuId);
    if (inUse && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'No se puede eliminar: este menú está siendo usado en inscripciones.')),
      );
      return;
    }
    if (!context.mounted) return;
    showAppDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar menú'),
        content: const Text('¿Seguro que quieres eliminar este menú?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              await fs.deleteFestividadMenu(edicionId, menuId);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
