import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/services/auth_service.dart';

const List<String> kElementosHabito = [
  'Túnica',
  'Cíngulo',
  'Capuz',
  'Capirote',
  'Cetro',
];

const Map<String, IconData> kElementoIcons = {
  'Túnica': Icons.checkroom,
  'Cíngulo': Icons.horizontal_rule,
  'Capuz': Icons.masks,
  'Capirote': Icons.arrow_upward,
  'Cetro': Icons.architecture,
};

class BancoTunicasScreen extends StatefulWidget {
  const BancoTunicasScreen({super.key});

  @override
  State<BancoTunicasScreen> createState() => _BancoTunicasScreenState();
}

class _BancoTunicasScreenState extends State<BancoTunicasScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _filtroElemento;

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
    final auth = context.watch<AuthService>();
    final isAdmin = auth.isAdmin;
    final cofradeId = auth.cofrade?.id ?? '';

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
                constraints: const BoxConstraints(maxWidth: 900),
                child: Row(
                  children: [
                    IconButton(
                      icon:
                          const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => context.go('/tunicas'),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.volunteer_activism,
                        color: Colors.white, size: 26),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Banco de Túnicas',
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 0,
                      color: AppTheme.accentColor.withAlpha(10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                            color: AppTheme.accentColor.withAlpha(30)),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: AppTheme.accentColor),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'El Banco de Túnicas es un espacio privado para facilitar el préstamo temporal '
                                'de elementos del hábito procesional durante Semana Santa. Las publicaciones pueden '
                                'incluir el conjunto completo o elementos sueltos: túnica, cíngulo, capuz, capirote '
                                'y cetro. La gestión del préstamo se realizará directamente entre las personas interesadas.',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textPrimary,
                                    height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                context.go('/banco-tunicas/publicar-oferta'),
                            icon: const Icon(Icons.add_circle_outline,
                                size: 20),
                            label: const Text('Publicar Oferta'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentColor,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                context.go('/banco-tunicas/publicar-demanda'),
                            icon: const Icon(Icons.search, size: 20),
                            label: const Text('Publicar Demanda'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.accentColor,
                              side: const BorderSide(
                                  color: AppTheme.accentColor),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          const Text('Filtrar: ',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: const Text('Todos'),
                            selected: _filtroElemento == null,
                            onSelected: (_) =>
                                setState(() => _filtroElemento = null),
                            selectedColor:
                                AppTheme.accentColor.withAlpha(30),
                          ),
                          const SizedBox(width: 6),
                          ...kElementosHabito.map((e) => Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: FilterChip(
                                  label: Text(e),
                                  selected: _filtroElemento == e,
                                  onSelected: (_) => setState(() =>
                                      _filtroElemento =
                                          _filtroElemento == e ? null : e),
                                  selectedColor:
                                      AppTheme.accentColor.withAlpha(30),
                                ),
                              )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
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
                          Tab(text: 'Ofertas disponibles'),
                          Tab(text: 'Demandas activas'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 600,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _PublicacionesList(
                              tipo: 'oferta',
                              fs: fs,
                              cofradeId: cofradeId,
                              isAdmin: isAdmin,
                              filtroElemento: _filtroElemento),
                          _PublicacionesList(
                              tipo: 'demanda',
                              fs: fs,
                              cofradeId: cofradeId,
                              isAdmin: isAdmin,
                              filtroElemento: _filtroElemento),
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

class _PublicacionesList extends StatelessWidget {
  final String tipo;
  final FirestoreService fs;
  final String cofradeId;
  final bool isAdmin;
  final String? filtroElemento;

  const _PublicacionesList({
    required this.tipo,
    required this.fs,
    required this.cofradeId,
    required this.isAdmin,
    this.filtroElemento,
  });

  @override
  Widget build(BuildContext context) {
    final estadoActivo = tipo == 'oferta' ? 'disponible' : 'activa';
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: fs.getBancoTunicas(tipo: tipo),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        var items = snapshot.data ?? [];
        items = items.where((i) => i['estado'] == estadoActivo).toList();
        if (filtroElemento != null) {
          items = items.where((i) {
            final elementos = List<String>.from(i['elementos'] ?? []);
            return elementos.contains(filtroElemento);
          }).toList();
        }
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                    tipo == 'oferta'
                        ? Icons.volunteer_activism
                        : Icons.search_off,
                    size: 48,
                    color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text(
                    tipo == 'oferta'
                        ? 'No hay ofertas disponibles'
                        : 'No hay demandas activas',
                    style: TextStyle(color: Colors.grey.shade500)),
              ],
            ),
          );
        }
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) => _PublicacionCard(
              data: items[index],
              tipo: tipo,
              cofradeId: cofradeId,
              isAdmin: isAdmin,
              fs: fs),
        );
      },
    );
  }
}

class _PublicacionCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String tipo;
  final String cofradeId;
  final bool isAdmin;
  final FirestoreService fs;

  const _PublicacionCard({
    required this.data,
    required this.tipo,
    required this.cofradeId,
    required this.isAdmin,
    required this.fs,
  });

  @override
  Widget build(BuildContext context) {
    final elementos = List<String>.from(data['elementos'] ?? []);
    final nombre = tipo == 'oferta'
        ? (data['nombre_publicador'] ?? '')
        : (data['nombre_demandante'] ?? '');
    final telefono = tipo == 'oferta'
        ? (data['telefono_publicador'] ?? '')
        : (data['telefono_demandante'] ?? '');
    final estado = data['estado'] ?? '';
    final talla = data['talla'] ?? '';
    final observaciones = data['observaciones'] ?? '';
    final conservacion = data['estado_conservacion'] ?? '';
    final propiedad = data['propiedad'] ?? 'particular';
    final id = data['id'] ?? '';
    final esPropio = data['cofrade_id'] == cofradeId;
    final puedeModificar = esPropio || isAdmin;
    final fecha = data['fecha'] is Timestamp
        ? (data['fecha'] as Timestamp).toDate()
        : DateTime.now();

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      color: (tipo == 'oferta'
                              ? AppTheme.accentColor
                              : Colors.blue)
                          .withAlpha(15),
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(
                      tipo == 'oferta'
                          ? Icons.volunteer_activism
                          : Icons.search,
                      color: tipo == 'oferta'
                          ? AppTheme.accentColor
                          : Colors.blue,
                      size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tipo == 'oferta' ? 'Oferta' : 'Demanda',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(
                          '$nombre${propiedad == "cofradia" && tipo == "oferta" ? " (Cofrad\u00eda)" : ""} \u00b7 ${_formatDate(fecha)}',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: _estadoColor(estado).withAlpha(20),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(_estadoLabel(estado),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _estadoColor(estado))),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: elementos
                  .map((e) => Chip(
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        avatar: Icon(kElementoIcons[e] ?? Icons.checkroom,
                            size: 16),
                        label: Text(e, style: const TextStyle(fontSize: 12)),
                      ))
                  .toList(),
            ),
            if (_hasTallas(data)) ...[
              const SizedBox(height: 8),
              ..._buildTallaRows(data),
            ] else if (talla.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.straighten,
                    size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Flexible(child: Text('Talla/Medidas: $talla',
                    style: const TextStyle(fontSize: 13))),
              ]),
            ],
            if (tipo == 'oferta' && conservacion.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.star_outline,
                    size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Text('Conservaci\u00f3n: $conservacion',
                    style: const TextStyle(fontSize: 13)),
              ]),
            ],
            if (observaciones.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(observaciones,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      height: 1.4)),
            ],
            const Divider(height: 20),
            Row(children: [
              const Icon(Icons.person_outline,
                  size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                  child: Text('$nombre \u00b7 $telefono',
                      style: const TextStyle(fontSize: 13))),
            ]),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _contactarWhatsApp(telefono, tipo),
                    icon: const Icon(Icons.chat, size: 18),
                    label: const Text('Contactar por WhatsApp'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 10)),
                  ),
                ),
                if (puedeModificar) ...[
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (action) =>
                        _handleAction(context, action, id),
                    itemBuilder: (_) => [
                      if (tipo == 'oferta') ...[
                        if (estado == 'disponible')
                          const PopupMenuItem(
                              value: 'reservada',
                              child: Text('Marcar como Reservada')),
                        if (estado == 'reservada')
                          const PopupMenuItem(
                              value: 'disponible',
                              child: Text('Marcar como Disponible')),
                      ] else ...[
                        if (estado == 'activa')
                          const PopupMenuItem(
                              value: 'cubierta',
                              child: Text('Marcar como Cubierta')),
                        if (estado == 'cubierta')
                          const PopupMenuItem(
                              value: 'activa',
                              child: Text('Marcar como Activa')),
                      ],
                      const PopupMenuItem(
                          value: 'eliminar',
                          child: Text('Eliminar',
                              style: TextStyle(color: Colors.red))),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  static bool _hasTallas(Map<String, dynamic> data) {
    final tpe = data['tallas_por_elemento'];
    return tpe is Map && tpe.isNotEmpty;
  }

  static List<Widget> _buildTallaRows(Map<String, dynamic> data) {
    final tpe = Map<String, dynamic>.from(data['tallas_por_elemento'] as Map);
    return tpe.entries.map((e) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Icon(kElementoIcons[e.key] ?? Icons.straighten,
            size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 6),
        Text('${e.key}: ${e.value}',
            style: const TextStyle(fontSize: 13)),
      ]),
    )).toList();
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      );
    } else {
      fs.cambiarEstadoPublicacionBanco(id, action);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Estado cambiado a: ${_estadoLabel(action)}')));
    }
  }

  static void _contactarWhatsApp(String telefono, String tipo) {
    final cleanPhone = telefono.replaceAll(RegExp(r'[^0-9+]'), '');
    final phone =
        cleanPhone.startsWith('+') ? cleanPhone : '+34$cleanPhone';
    final mensaje = tipo == 'oferta'
        ? 'Hola, he visto tu oferta en el Banco de T\u00fanicas de San Juan y estoy interesado/a en los elementos que ofreces para Semana Santa.'
        : 'Hola, he visto tu demanda en el Banco de T\u00fanicas de San Juan y creo que puedo ayudarte con alguno de los elementos que necesitas para Semana Santa.';
    final url =
        'https://wa.me/${phone.replaceAll('+', '')}?text=${Uri.encodeComponent(mensaje)}';
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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
