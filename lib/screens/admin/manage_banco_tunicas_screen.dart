import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/screens/private/banco_tunicas_screen.dart';

class ManageBancoTunicasScreen extends StatefulWidget {
  const ManageBancoTunicasScreen({super.key});

  @override
  State<ManageBancoTunicasScreen> createState() =>
      _ManageBancoTunicasScreenState();
}

class _ManageBancoTunicasScreenState extends State<ManageBancoTunicasScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [AppTheme.primaryDark, AppTheme.primaryColor]),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: const Row(
                  children: [
                    Icon(Icons.admin_panel_settings,
                        color: Colors.white, size: 26),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text('Admin: Banco de T\u00fanicas',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
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
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        labelColor: AppTheme.primaryColor,
                        unselectedLabelColor: AppTheme.textSecondary,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withAlpha(10),
                                blurRadius: 4)
                          ],
                        ),
                        tabs: const [
                          Tab(text: 'Todas las Ofertas'),
                          Tab(text: 'Todas las Demandas'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 600,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _AdminPublicacionesList(tipo: 'oferta', fs: fs),
                          _AdminPublicacionesList(tipo: 'demanda', fs: fs),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminPublicacionesList extends StatelessWidget {
  final String tipo;
  final FirestoreService fs;

  const _AdminPublicacionesList({required this.tipo, required this.fs});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: fs.getBancoTunicas(tipo: tipo),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return Center(
            child: Text(
                'No hay ${tipo == "oferta" ? "ofertas" : "demandas"}',
                style: TextStyle(color: Colors.grey.shade500)),
          );
        }
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) =>
              _AdminCard(data: items[index], tipo: tipo, fs: fs),
        );
      },
    );
  }
}

class _AdminCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String tipo;
  final FirestoreService fs;

  const _AdminCard(
      {required this.data, required this.tipo, required this.fs});

  @override
  Widget build(BuildContext context) {
    final elementos = List<String>.from(data['elementos'] ?? []);
    final nombre = tipo == 'oferta'
        ? (data['nombre_publicador'] ?? '')
        : (data['nombre_demandante'] ?? '');
    final estado = data['estado'] ?? '';
    final id = data['id'] ?? '';
    final fecha = data['fecha'] is Timestamp
        ? (data['fecha'] as Timestamp).toDate()
        : DateTime.now();

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _estadoColor(estado).withAlpha(15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
              tipo == 'oferta'
                  ? Icons.volunteer_activism
                  : Icons.search,
              color: _estadoColor(estado),
              size: 20),
        ),
        title: Text(nombre,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: elementos
                  .map((e) => Chip(
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        label: Text(e, style: const TextStyle(fontSize: 11)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 4),
            Text(
                '${_formatDate(fecha)} \u00b7 ${_estadoLabel(estado)}',
                style: TextStyle(
                    fontSize: 12, color: _estadoColor(estado))),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (action) => _handleAction(context, action, id),
          itemBuilder: (_) => [
            const PopupMenuItem(
                value: 'editar',
                child: Text('Editar')),
            if (tipo == 'oferta') ...[
              const PopupMenuItem(
                  value: 'disponible', child: Text('Disponible')),
              const PopupMenuItem(
                  value: 'reservada', child: Text('Reservada')),
            ] else ...[
              const PopupMenuItem(
                  value: 'activa', child: Text('Activa')),
              const PopupMenuItem(
                  value: 'cubierta', child: Text('Cubierta')),
            ],
            const PopupMenuItem(
                value: 'eliminar',
                child:
                    Text('Eliminar', style: TextStyle(color: Colors.red))),
          ],
        ),
      ),
    );
  }

  void _handleAction(BuildContext context, String action, String id) {
    if (action == 'eliminar') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Eliminar publicaci\u00f3n'),
          content: const Text(
              '\u00bfSeguro que quieres eliminar esta publicaci\u00f3n?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                fs.eliminarPublicacionBanco(id);
                Navigator.pop(ctx);
              },
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      );
    } else if (action == 'editar') {
      _showEditDialog(context, id);
    } else {
      fs.cambiarEstadoPublicacionBanco(id, action);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Estado cambiado a: ${_estadoLabel(action)}')));
    }
  }

  void _showEditDialog(BuildContext context, String id) {
    final elementos = List<String>.from(data['elementos'] ?? []);
    final talla = data['talla'] ?? '';
    final observaciones = data['observaciones'] ?? '';
    final nombre = tipo == 'oferta'
        ? (data['nombre_publicador'] ?? '')
        : (data['nombre_demandante'] ?? '');
    final telefono = tipo == 'oferta'
        ? (data['telefono_publicador'] ?? '')
        : (data['telefono_demandante'] ?? '');
    final conservacion = data['estado_conservacion'] ?? '';

    final tallaCtrl = TextEditingController(text: talla);
    final obsCtrl = TextEditingController(text: observaciones);
    final nombreCtrl = TextEditingController(text: nombre);
    final telCtrl = TextEditingController(text: telefono);
    final conservCtrl = TextEditingController(text: conservacion);
    final selectedElements = Set<String>.from(elementos);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Editar ${tipo == "oferta" ? "oferta" : "demanda"}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nombreCtrl,
                  decoration: InputDecoration(
                    labelText: tipo == 'oferta' ? 'Publicador' : 'Demandante',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: telCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tel\u00e9fono',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Elementos:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: kElementosHabito.map((e) {
                    final sel = selectedElements.contains(e);
                    return FilterChip(
                      label: Text(e, style: const TextStyle(fontSize: 12)),
                      selected: sel,
                      onSelected: (val) {
                        setDialogState(() {
                          if (val) { selectedElements.add(e); } else { selectedElements.remove(e); }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tallaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Talla / Medidas',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (tipo == 'oferta') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: conservCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Estado conservaci\u00f3n',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: obsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Observaciones',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final updateData = <String, dynamic>{
                  'elementos': selectedElements.toList(),
                  'talla': tallaCtrl.text.trim(),
                  'observaciones': obsCtrl.text.trim(),
                };
                if (tipo == 'oferta') {
                  updateData['nombre_publicador'] = nombreCtrl.text.trim();
                  updateData['telefono_publicador'] = telCtrl.text.trim();
                  updateData['estado_conservacion'] = conservCtrl.text.trim();
                } else {
                  updateData['nombre_demandante'] = nombreCtrl.text.trim();
                  updateData['telefono_demandante'] = telCtrl.text.trim();
                }
                fs.editarPublicacionBanco(id, updateData);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Publicaci\u00f3n actualizada')),
                );
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';

  static Color _estadoColor(String estado) {
    switch (estado) {
      case 'disponible':
        return AppTheme.accentColor;
      case 'reservada':
        return Colors.orange;
      case 'activa':
        return Colors.blue;
      case 'cubierta':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  static String _estadoLabel(String estado) {
    switch (estado) {
      case 'disponible':
        return 'Disponible';
      case 'reservada':
        return 'Reservada';
      case 'activa':
        return 'Activa';
      case 'cubierta':
        return 'Cubierta';
      default:
        return estado;
    }
  }
}
