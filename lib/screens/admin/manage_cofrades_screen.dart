import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/models/cofrade.dart';

class ManageCofradesScreen extends StatefulWidget {
  const ManageCofradesScreen({super.key});

  @override
  State<ManageCofradesScreen> createState() => _ManageCofradesScreenState();
}

class _ManageCofradesScreenState extends State<ManageCofradesScreen> {
  String _filtroEstado = 'todos';
  String _busqueda = '';

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gestión de Cofrades',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            // Filters
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 300,
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Buscar por nombre...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => _busqueda = v.toLowerCase()),
                  ),
                ),
                ChoiceChip(
                  label: const Text('Todos'),
                  selected: _filtroEstado == 'todos',
                  onSelected: (_) => setState(() => _filtroEstado = 'todos'),
                ),
                ChoiceChip(
                  label: const Text('Activos'),
                  selected: _filtroEstado == 'activo',
                  onSelected: (_) => setState(() => _filtroEstado = 'activo'),
                ),
                ChoiceChip(
                  label: const Text('Pendientes'),
                  selected: _filtroEstado == 'pendiente',
                  onSelected: (_) =>
                      setState(() => _filtroEstado = 'pendiente'),
                ),
                ChoiceChip(
                  label: const Text('Baja'),
                  selected: _filtroEstado == 'baja',
                  onSelected: (_) => setState(() => _filtroEstado = 'baja'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            StreamBuilder<List<Cofrade>>(
              stream: firestoreService.getCofrades(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                var cofrades = snapshot.data ?? [];

                // Apply filters
                if (_filtroEstado != 'todos') {
                  cofrades = cofrades
                      .where((c) => c.estado == _filtroEstado)
                      .toList();
                }
                if (_busqueda.isNotEmpty) {
                  cofrades = cofrades
                      .where((c) =>
                          c.nombreCompleto.toLowerCase().contains(_busqueda))
                      .toList();
                }

                if (cofrades.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('No se encontraron cofrades.')),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: cofrades.length,
                  itemBuilder: (context, index) {
                    final cofrade = cofrades[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(cofrade.estado),
                          child: Text(
                            cofrade.nombre.isNotEmpty
                                ? cofrade.nombre[0].toUpperCase()
                                : '?',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(cofrade.nombreCompleto),
                        subtitle: Text(
                          '${cofrade.email} · Nº ${cofrade.numero ?? "-"}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              tooltip: 'Editar cofrade',
                              onPressed: () => _showEditCofradeDialog(cofrade),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (action) =>
                                  _handleAction(action, cofrade),
                              itemBuilder: (context) => [
                                if (cofrade.estado == 'Pendiente' ||
                                    cofrade.estado == 'pendiente')
                                  const PopupMenuItem(
                                    value: 'aprobar',
                                    child: ListTile(
                                      leading: Icon(Icons.check, color: Colors.green),
                                      title: Text('Aprobar'),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                if (!cofrade.isBaja)
                                  const PopupMenuItem(
                                    value: 'baja',
                                    child: ListTile(
                                      leading: Icon(Icons.block, color: Colors.red),
                                      title: Text('Dar de baja'),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                if (cofrade.isBaja)
                                  const PopupMenuItem(
                                    value: 'reactivar',
                                    child: ListTile(
                                      leading:
                                          Icon(Icons.refresh, color: Colors.blue),
                                      title: Text('Reactivar'),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                if (!cofrade.isAdmin)
                                  const PopupMenuItem(
                                    value: 'hacer_admin',
                                    child: ListTile(
                                      leading: Icon(Icons.admin_panel_settings,
                                          color: AppTheme.primaryColor),
                                      title: Text('Hacer admin'),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                              ],
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

  Color _getStatusColor(String estado) {
    switch (estado.toLowerCase()) {
      case 'activo':
        return Colors.green;
      case 'pendiente':
        return Colors.orange;
      case 'baja':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showEditCofradeDialog(Cofrade cofrade) {
    final nombreC = TextEditingController(text: cofrade.nombre);
    final apellidosC = TextEditingController(text: cofrade.apellidos);
    final emailC = TextEditingController(text: cofrade.email);
    final dniC = TextEditingController(text: cofrade.dni ?? '');
    final telefonoMovilC = TextEditingController(text: cofrade.telefonoMovil);
    final telefonoFijoC = TextEditingController(text: cofrade.telefonoFijo);
    final domicilioC = TextEditingController(text: cofrade.domicilio);
    final localidadC = TextEditingController(text: cofrade.localidad);
    final codigoPostalC = TextEditingController(text: cofrade.codigoPostal);
    final ibanC = TextEditingController(text: cofrade.iban ?? '');
    final titularIbanC = TextEditingController(text: cofrade.titularIban ?? '');
    final comentariosC = TextEditingController(text: cofrade.comentarios ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar: ${cofrade.nombreCompleto}'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nombreC, decoration: const InputDecoration(labelText: 'Nombre')),
                const SizedBox(height: 8),
                TextField(controller: apellidosC, decoration: const InputDecoration(labelText: 'Apellidos')),
                const SizedBox(height: 8),
                TextField(controller: emailC, decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 8),
                TextField(controller: dniC, decoration: const InputDecoration(labelText: 'DNI')),
                const SizedBox(height: 8),
                TextField(controller: telefonoMovilC, decoration: const InputDecoration(labelText: 'Tel\u00e9fono m\u00f3vil')),
                const SizedBox(height: 8),
                TextField(controller: telefonoFijoC, decoration: const InputDecoration(labelText: 'Tel\u00e9fono fijo')),
                const SizedBox(height: 8),
                TextField(controller: domicilioC, decoration: const InputDecoration(labelText: 'Domicilio')),
                const SizedBox(height: 8),
                TextField(controller: localidadC, decoration: const InputDecoration(labelText: 'Localidad')),
                const SizedBox(height: 8),
                TextField(controller: codigoPostalC, decoration: const InputDecoration(labelText: 'C\u00f3digo postal')),
                const SizedBox(height: 8),
                TextField(controller: ibanC, decoration: const InputDecoration(labelText: 'IBAN')),
                const SizedBox(height: 8),
                TextField(controller: titularIbanC, decoration: const InputDecoration(labelText: 'Titular IBAN')),
                const SizedBox(height: 8),
                TextField(controller: comentariosC, decoration: const InputDecoration(labelText: 'Comentarios'), maxLines: 3),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              try {
                await context.read<FirestoreService>().updateCofrade(cofrade.id, {
                  'nombre': nombreC.text.trim(),
                  'apellidos': apellidosC.text.trim(),
                  'email': emailC.text.trim(),
                  'dni': dniC.text.trim().toUpperCase(),
                  'telefono_movil': telefonoMovilC.text.trim(),
                  'telefono_fijo': telefonoFijoC.text.trim(),
                  'domicilio': domicilioC.text.trim(),
                  'localidad': localidadC.text.trim(),
                  'codigo_postal': codigoPostalC.text.trim(),
                  'iban': ibanC.text.trim(),
                  'titular_iban': titularIbanC.text.trim(),
                  'comentarios': comentariosC.text.trim(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${cofrade.nombreCompleto} actualizado.')),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(String action, Cofrade cofrade) async {
    final firestoreService = context.read<FirestoreService>();

    switch (action) {
      case 'aprobar':
        await firestoreService
            .updateCofrade(cofrade.id, {'estado': 'Activo'});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('${cofrade.nombreCompleto} aprobado.')),
          );
        }
        break;
      case 'baja':
        await firestoreService
            .updateCofrade(cofrade.id, {'estado': 'Baja'});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('${cofrade.nombreCompleto} dado de baja.')),
          );
        }
        break;
      case 'reactivar':
        await firestoreService
            .updateCofrade(cofrade.id, {'estado': 'Activo'});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('${cofrade.nombreCompleto} reactivado.')),
          );
        }
        break;
      case 'hacer_admin':
        await firestoreService
            .updateCofrade(cofrade.id, {'rol': 'admin'});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('${cofrade.nombreCompleto} es ahora administrador.')),
          );
        }
        break;
    }
  }
}
