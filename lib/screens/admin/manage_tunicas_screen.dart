import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/models/proveedor.dart';

void _showProveedorDialog(BuildContext context, FirestoreService fs, {Proveedor? proveedor}) {
  final nombreC = TextEditingController(text: proveedor?.nombre ?? '');
  final telefonoC = TextEditingController(text: proveedor?.telefono ?? '');
  final emailC = TextEditingController(text: proveedor?.email ?? '');
  final direccionC = TextEditingController(text: proveedor?.direccion ?? '');
  final descripcionC = TextEditingController(text: proveedor?.descripcion ?? '');
  final webC = TextEditingController(text: proveedor?.web ?? '');
  final preciosC = TextEditingController(text: proveedor?.precios ?? '');
  bool activo = proveedor?.activo ?? true;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(proveedor == null ? 'Nuevo Proveedor' : 'Editar Proveedor'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nombreC, decoration: const InputDecoration(labelText: 'Nombre *')),
              const SizedBox(height: 8),
              TextField(controller: telefonoC, decoration: const InputDecoration(labelText: 'Tel\u00e9fono')),
              const SizedBox(height: 8),
              TextField(controller: emailC, decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 8),
              TextField(controller: direccionC, decoration: const InputDecoration(labelText: 'Direcci\u00f3n')),
              const SizedBox(height: 8),
              TextField(controller: descripcionC, decoration: const InputDecoration(labelText: 'Descripci\u00f3n'), maxLines: 2),
              const SizedBox(height: 8),
              TextField(controller: webC, decoration: const InputDecoration(labelText: 'Web')),
              const SizedBox(height: 8),
              TextField(controller: preciosC, decoration: const InputDecoration(labelText: 'Precios orientativos')),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Activo'),
                value: activo,
                onChanged: (v) => setDialogState(() => activo = v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (nombreC.text.trim().isEmpty) return;
              if (proveedor == null) {
                fs.createProveedor(Proveedor(
                  id: '',
                  nombre: nombreC.text.trim(),
                  telefono: telefonoC.text.trim(),
                  email: emailC.text.trim(),
                  direccion: direccionC.text.trim(),
                  descripcion: descripcionC.text.trim(),
                  web: webC.text.trim(),
                  precios: preciosC.text.trim(),
                  activo: activo,
                  fechaCreacion: DateTime.now(),
                ));
              } else {
                fs.updateProveedor(proveedor.id, {
                  'nombre': nombreC.text.trim(),
                  'telefono': telefonoC.text.trim(),
                  'email': emailC.text.trim(),
                  'direccion': direccionC.text.trim(),
                  'descripcion': descripcionC.text.trim(),
                  'web': webC.text.trim(),
                  'precios': preciosC.text.trim(),
                  'activo': activo,
                });
              }
              Navigator.pop(ctx);
            },
            child: Text(proveedor == null ? 'Crear' : 'Guardar'),
          ),
        ],
      ),
    ),
  );
}

class ManageTunicasScreen extends StatelessWidget {
  const ManageTunicasScreen({super.key});

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
                constraints: const BoxConstraints(maxWidth: 900),
                child: Row(
                  children: [
                    const Icon(Icons.checkroom, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Gestionar Proveedores de T\u00fanicas',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showProveedorDialog(context, fs),
                      icon: const Icon(Icons.add),
                      label: const Text('A\u00f1adir'),
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
                constraints: const BoxConstraints(maxWidth: 900),
                child: StreamBuilder<List<Proveedor>>(
                  stream: fs.getProveedores(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final proveedores = snapshot.data ?? [];
                    if (proveedores.isEmpty) {
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                        child: const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: Text('No hay proveedores registrados.')),
                        ),
                      );
                    }
                    return Column(
                      children: proveedores.map((p) => _ProveedorAdminCard(proveedor: p, fs: fs)).toList(),
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

class _ProveedorAdminCard extends StatelessWidget {
  final Proveedor proveedor;
  final FirestoreService fs;
  const _ProveedorAdminCard({required this.proveedor, required this.fs});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (proveedor.activo ? AppTheme.accentColor : Colors.grey).withAlpha(15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.store, color: proveedor.activo ? AppTheme.accentColor : Colors.grey),
        ),
        title: Text(proveedor.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          [
            if (proveedor.telefono.isNotEmpty) proveedor.telefono,
            if (proveedor.email.isNotEmpty) proveedor.email,
            if (!proveedor.activo) 'INACTIVO',
          ].join(' · '),
          style: TextStyle(fontSize: 13, color: proveedor.activo ? AppTheme.textSecondary : Colors.red),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => _showProveedorDialog(context, fs, proveedor: proveedor),
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar proveedor'),
        content: Text('¿Seguro que quieres eliminar "${proveedor.nombre}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              fs.deleteProveedor(proveedor.id);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
