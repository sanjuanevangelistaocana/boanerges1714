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
    } else {
      fs.cambiarEstadoPublicacionBanco(id, action);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Estado cambiado a: ${_estadoLabel(action)}')));
    }
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
