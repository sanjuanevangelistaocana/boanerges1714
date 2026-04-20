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
                          '${cofrade.email} · ${cofrade.cargo}',
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (action) =>
                              _handleAction(action, cofrade),
                          itemBuilder: (context) => [
                            if (cofrade.estado == 'pendiente')
                              const PopupMenuItem(
                                value: 'aprobar',
                                child: ListTile(
                                  leading: Icon(Icons.check, color: Colors.green),
                                  title: Text('Aprobar'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            if (cofrade.estado != 'baja')
                              const PopupMenuItem(
                                value: 'baja',
                                child: ListTile(
                                  leading: Icon(Icons.block, color: Colors.red),
                                  title: Text('Dar de baja'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            if (cofrade.estado == 'baja')
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
    switch (estado) {
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

  Future<void> _handleAction(String action, Cofrade cofrade) async {
    final firestoreService = context.read<FirestoreService>();

    switch (action) {
      case 'aprobar':
        await firestoreService
            .updateCofrade(cofrade.id, {'estado': 'activo'});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('${cofrade.nombreCompleto} aprobado.')),
          );
        }
        break;
      case 'baja':
        await firestoreService
            .updateCofrade(cofrade.id, {'estado': 'baja'});
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
            .updateCofrade(cofrade.id, {'estado': 'activo'});
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
