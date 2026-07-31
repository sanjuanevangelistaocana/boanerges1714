import 'package:flutter/material.dart';
import 'package:boanerges1714/widgets/responsive_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/firestore_service.dart';

class ManageFestividadScreen extends StatefulWidget {
  const ManageFestividadScreen({super.key});

  @override
  State<ManageFestividadScreen> createState() => _ManageFestividadScreenState();
}

class _ManageFestividadScreenState extends State<ManageFestividadScreen> {
  bool _showFinalizadas = false;

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
                  const Icon(Icons.celebration,
                      color: Colors.white70, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Festividad San Juan Evangelista',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
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
                  final allEdiciones = snap.data ?? [];
                  final ediciones = _sortEdiciones(
                    _showFinalizadas
                        ? allEdiciones
                        : allEdiciones
                            .where((ed) => !_isFinalizadaOCaducada(ed))
                            .toList(),
                  );
                  if (allEdiciones.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            Icon(Icons.celebration,
                                size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            const Text('No hay ediciones creadas.',
                                style: TextStyle(
                                    fontSize: 16,
                                    color: AppTheme.textSecondary)),
                            const SizedBox(height: 8),
                            const Text(
                                'Crea la primera edición anual del evento.',
                                style:
                                    TextStyle(color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: ediciones.isEmpty
                        ? [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                FilterChip(
                                  selected: _showFinalizadas,
                                  label:
                                      const Text('Mostrar eventos finalizados'),
                                  onSelected: (value) =>
                                      setState(() => _showFinalizadas = value),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            const Center(
                              child: Text(
                                'No hay ediciones vigentes. Activa "Mostrar eventos finalizados" para ver histórico.',
                                style: TextStyle(color: AppTheme.textSecondary),
                              ),
                            ),
                          ]
                        : [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                FilterChip(
                                  selected: _showFinalizadas,
                                  label:
                                      const Text('Mostrar eventos finalizados'),
                                  onSelected: (value) =>
                                      setState(() => _showFinalizadas = value),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...ediciones
                                .map((ed) => _EdicionCard(edicion: ed, fs: fs)),
                          ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _sortEdiciones(List<Map<String, dynamic>> items) {
    final sorted = [...items];
    int priority(Map<String, dynamic> ed) {
      final estado = '${ed['estado'] ?? ed['status'] ?? ''}'.toLowerCase();
      if (estado.contains('abiert') || estado == 'open') return 0;
      if (estado.contains('public') || estado == 'published') return 1;
      if (estado.contains('cerr') || estado == 'closed') return 2;
      if (estado.contains('final') || estado == 'finished') return 3;
      if (estado.contains('archiv') || estado == 'archived') return 4;
      return 2;
    }

    sorted.sort((a, b) {
      final p = priority(a).compareTo(priority(b));
      if (p != 0) return p;
      final da = _edicionDate(a);
      final db = _edicionDate(b);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });
    return sorted;
  }

  bool _isFinalizadaOCaducada(Map<String, dynamic> ed) {
    final estado = '${ed['estado'] ?? ed['status'] ?? ''}'.toLowerCase();
    if (estado.contains('final') ||
        estado.contains('archiv') ||
        estado == 'finished' ||
        estado == 'archived') {
      return true;
    }
    final date = _edicionDate(ed);
    if (date == null) return false;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final eventDay = DateTime(date.year, date.month, date.day);
    return eventDay.isBefore(todayOnly);
  }

  DateTime? _edicionDate(Map<String, dynamic> ed) {
    final value = ed['fecha'] ?? ed['fecha_evento'] ?? ed['eventDate'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  void _showCrearEdicionDialog(BuildContext context, FirestoreService fs) {
    final anio = DateTime.now().year;
    final nombreCtrl =
        TextEditingController(text: 'Festividad San Juan Evangelista $anio');
    final precioHermanoCtrl = TextEditingController(text: '5');
    final precioHermanoNinoCtrl = TextEditingController(text: '5');
    final precioInvitadoCtrl = TextEditingController(text: '27');
    final precioInvitadoNinoCtrl = TextEditingController(text: '15');
    final precioProtocoloCtrl = TextEditingController(text: '0');
    final precioProtocoloNinoCtrl = TextEditingController(text: '0');
    final costeMenuAdultoCtrl = TextEditingController(text: '27');
    final costeMenuNinoCtrl = TextEditingController(text: '15');
    final horaCtrl = TextEditingController(text: '14:00');
    final lugarCtrl = TextEditingController();
    final direccionCtrl = TextEditingController();
    final descripcionCtrl = TextEditingController();
    DateTime fechaEvento = DateTime(anio, 12, 27);
    DateTime fechaLimite = DateTime(anio, 12, 20);
    TimeOfDay horaEvento = const TimeOfDay(hour: 14, minute: 0);
    TimeOfDay horaLimite = const TimeOfDay(hour: 23, minute: 59);

    showAppDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final fmt = DateFormat('dd/MM/yyyy');
          return AlertDialog(
            title: const Text('Nueva edición'),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                        controller: nombreCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Nombre del evento',
                            border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Precios que paga el asistente',
                            style: TextStyle(fontWeight: FontWeight.w600))),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                          child: TextField(
                              controller: precioHermanoCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Hermano adulto (€)',
                                  helperText:
                                      'Importe que paga el hermano adulto',
                                  border: OutlineInputBorder()),
                              keyboardType: TextInputType.number)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: TextField(
                              controller: precioHermanoNinoCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Hermano niño (€)',
                                  border: OutlineInputBorder()),
                              keyboardType: TextInputType.number)),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                          child: TextField(
                              controller: precioInvitadoCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Invitado adulto (€)',
                                  border: OutlineInputBorder()),
                              keyboardType: TextInputType.number)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: TextField(
                              controller: precioInvitadoNinoCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Invitado niño (€)',
                                  border: OutlineInputBorder()),
                              keyboardType: TextInputType.number)),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                          child: TextField(
                              controller: precioProtocoloCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Protocolo adulto (€)',
                                  border: OutlineInputBorder()),
                              keyboardType: TextInputType.number)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: TextField(
                              controller: precioProtocoloNinoCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Protocolo niño (€)',
                                  border: OutlineInputBorder()),
                              keyboardType: TextInputType.number)),
                    ]),
                    const SizedBox(height: 12),
                    const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                            'Costes reales para la cofradía/restaurante',
                            style: TextStyle(fontWeight: FontWeight.w600))),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                          child: TextField(
                              controller: costeMenuAdultoCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Coste real menú adulto (€)',
                                  helperText:
                                      'Importe que se pagará al restaurante',
                                  border: OutlineInputBorder()),
                              keyboardType: TextInputType.number)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: TextField(
                              controller: costeMenuNinoCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Coste real menú niño (€)',
                                  border: OutlineInputBorder()),
                              keyboardType: TextInputType.number)),
                    ]),
                    const SizedBox(height: 16),
                    const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Fecha y hora del evento',
                            style: TextStyle(fontWeight: FontWeight.w600))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: fechaEvento,
                                  firstDate: DateTime(anio - 1),
                                  lastDate: DateTime(anio + 2));
                              if (picked != null)
                                setDialogState(() => fechaEvento = picked);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                  labelText: 'Fecha evento',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.calendar_today)),
                              child: Text(fmt.format(fechaEvento)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showTimePicker(
                                  context: ctx, initialTime: horaEvento);
                              if (picked != null)
                                setDialogState(() => horaEvento = picked);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                  labelText: 'Hora evento',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.access_time)),
                              child: Text(horaEvento.format(ctx)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Fecha y hora límite inscripción',
                            style: TextStyle(fontWeight: FontWeight.w600))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: fechaLimite,
                                  firstDate: DateTime(anio - 1),
                                  lastDate: DateTime(anio + 2));
                              if (picked != null)
                                setDialogState(() => fechaLimite = picked);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                  labelText: 'Fecha límite',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.calendar_today)),
                              child: Text(fmt.format(fechaLimite)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showTimePicker(
                                  context: ctx, initialTime: horaLimite);
                              if (picked != null)
                                setDialogState(() => horaLimite = picked);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                  labelText: 'Hora límite',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.access_time)),
                              child: Text(horaLimite.format(ctx)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child: TextField(
                                controller: horaCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'Hora (texto)',
                                    border: OutlineInputBorder()))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: TextField(
                                controller: lugarCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'Lugar',
                                    border: OutlineInputBorder()))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                        controller: direccionCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Dirección',
                            border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(
                        controller: descripcionCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Descripción',
                            border: OutlineInputBorder()),
                        maxLines: 3),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () async {
                  final fechaEventoFull = DateTime(
                      fechaEvento.year,
                      fechaEvento.month,
                      fechaEvento.day,
                      horaEvento.hour,
                      horaEvento.minute);
                  final fechaLimiteFull = DateTime(
                      fechaLimite.year,
                      fechaLimite.month,
                      fechaLimite.day,
                      horaLimite.hour,
                      horaLimite.minute);
                  final data = {
                    'nombre': nombreCtrl.text.trim(),
                    'anio': anio,
                    'fecha': Timestamp.fromDate(fechaEventoFull),
                    'hora': horaCtrl.text.trim(),
                    'hora_evento':
                        '${horaEvento.hour.toString().padLeft(2, '0')}:${horaEvento.minute.toString().padLeft(2, '0')}',
                    'lugar': lugarCtrl.text.trim(),
                    'direccion': direccionCtrl.text.trim(),
                    'descripcion': descripcionCtrl.text.trim(),
                    'precio_hermano':
                        double.tryParse(precioHermanoCtrl.text) ?? 5.0,
                    'precio_hermano_adulto':
                        double.tryParse(precioHermanoCtrl.text) ?? 5.0,
                    'precio_hermano_nino':
                        double.tryParse(precioHermanoNinoCtrl.text) ?? 5.0,
                    'precio_invitado':
                        double.tryParse(precioInvitadoCtrl.text) ?? 27.0,
                    'precio_invitado_adulto':
                        double.tryParse(precioInvitadoCtrl.text) ?? 27.0,
                    'precio_invitado_nino':
                        double.tryParse(precioInvitadoNinoCtrl.text) ?? 15.0,
                    'precio_protocolo':
                        double.tryParse(precioProtocoloCtrl.text) ?? 0.0,
                    'precio_protocolo_adulto':
                        double.tryParse(precioProtocoloCtrl.text) ?? 0.0,
                    'precio_protocolo_nino':
                        double.tryParse(precioProtocoloNinoCtrl.text) ?? 0.0,
                    'coste_menu_adulto':
                        double.tryParse(costeMenuAdultoCtrl.text) ?? 27.0,
                    'coste_menu_nino':
                        double.tryParse(costeMenuNinoCtrl.text) ?? 15.0,
                    'fecha_limite': Timestamp.fromDate(fechaLimiteFull),
                    'hora_limite':
                        '${horaLimite.hour.toString().padLeft(2, '0')}:${horaLimite.minute.toString().padLeft(2, '0')}',
                    'estado': 'borrador',
                  };
                  await fs.createFestividadEdicion(data);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Crear'),
              ),
            ],
          );
        },
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
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                ),
                _EstadoBadge(estado: estado),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                if (fecha != null)
                  _ChipInfo(
                      icon: Icons.calendar_today, text: fmt.format(fecha)),
                if (fechaLimite != null)
                  _ChipInfo(
                      icon: Icons.timer,
                      text: 'Límite: ${fmt.format(fechaLimite)}'),
                _ChipInfo(
                    icon: Icons.euro,
                    text:
                        'Hermano: ${ed['precio_hermano']}€ · Invitado: ${ed['precio_invitado']}€'),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ActionBtn(
                    label: 'Editar',
                    icon: Icons.edit,
                    onTap: () => _showEditDialog(context, ed)),
                _ActionBtn(
                    label: 'Menús',
                    icon: Icons.restaurant_menu,
                    onTap: () => context
                        .go('/admin/festividad/menus?edicionId=${ed['id']}')),
                _ActionBtn(
                    label: 'Inscripciones',
                    icon: Icons.people,
                    onTap: () => context.go(
                        '/admin/festividad/inscripciones?edicionId=${ed['id']}')),
                _ActionBtn(
                    label: 'Informe',
                    icon: Icons.analytics,
                    onTap: () => context
                        .go('/admin/festividad/informe?edicionId=${ed['id']}')),
                PopupMenuButton<String>(
                  onSelected: (v) => _cambiarEstado(context, ed['id'], v),
                  itemBuilder: (_) => [
                    if (estado == 'borrador')
                      const PopupMenuItem(
                          value: 'abierto', child: Text('Abrir inscripciones')),
                    if (estado == 'abierto')
                      const PopupMenuItem(
                          value: 'cerrado',
                          child: Text('Cerrar inscripciones')),
                    if (estado == 'cerrado')
                      const PopupMenuItem(
                          value: 'finalizado', child: Text('Finalizar evento')),
                    if (estado != 'borrador')
                      const PopupMenuItem(
                          value: 'borrador', child: Text('Volver a borrador')),
                  ],
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

  void _cambiarEstado(
      BuildContext context, String id, String nuevoEstado) async {
    await fs.updateFestividadEdicion(id, {'estado': nuevoEstado});
    // Fix 7: Create novedad when state changes to 'abierto'
    if (nuevoEstado == 'abierto') {
      await fs.crearNovedad(
        tipo: 'festividad',
        titulo:
            'Inscripciones abiertas: ${edicion['nombre'] ?? 'Festividad SJE'}',
        descripcion:
            'Ya puedes inscribirte en la Festividad de San Juan Evangelista.',
        referenciaId: id,
        ruta: '/festividad',
      );
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Estado cambiado a: $nuevoEstado')));
    }
  }

  void _showEditDialog(BuildContext context, Map<String, dynamic> ed) {
    final nombreCtrl = TextEditingController(text: ed['nombre'] ?? '');
    final precioHermanoCtrl = TextEditingController(
        text: '${ed['precio_hermano_adulto'] ?? ed['precio_hermano'] ?? 5}');
    final precioHermanoNinoCtrl = TextEditingController(
        text: '${ed['precio_hermano_nino'] ?? ed['precio_hermano'] ?? 5}');
    final precioInvitadoCtrl = TextEditingController(
        text: '${ed['precio_invitado_adulto'] ?? ed['precio_invitado'] ?? 27}');
    final precioInvitadoNinoCtrl = TextEditingController(
        text: '${ed['precio_invitado_nino'] ?? ed['precio_invitado'] ?? 15}');
    final precioProtocoloCtrl = TextEditingController(
        text:
            '${ed['precio_protocolo_adulto'] ?? ed['precio_protocolo'] ?? 0}');
    final precioProtocoloNinoCtrl = TextEditingController(
        text: '${ed['precio_protocolo_nino'] ?? ed['precio_protocolo'] ?? 0}');
    final costeMenuAdultoCtrl = TextEditingController(
        text: '${ed['coste_menu_adulto'] ?? ed['precio_invitado'] ?? 27}');
    final costeMenuNinoCtrl = TextEditingController(
        text: '${ed['coste_menu_nino'] ?? ed['precio_invitado_nino'] ?? 15}');
    final horaCtrl = TextEditingController(text: ed['hora'] ?? '');
    final lugarCtrl = TextEditingController(text: ed['lugar'] ?? '');
    final direccionCtrl = TextEditingController(text: ed['direccion'] ?? '');
    final descripcionCtrl =
        TextEditingController(text: ed['descripcion'] ?? '');

    final fechaTs = ed['fecha'] as Timestamp?;
    final fechaLimTs = ed['fecha_limite'] as Timestamp?;
    DateTime fechaEvento =
        fechaTs?.toDate() ?? DateTime(DateTime.now().year, 12, 27);
    DateTime fechaLimite =
        fechaLimTs?.toDate() ?? DateTime(DateTime.now().year, 12, 20);

    final horaEventoStr = ed['hora_evento'] as String?;
    final horaLimiteStr = ed['hora_limite'] as String?;
    TimeOfDay horaEvento = horaEventoStr != null && horaEventoStr.contains(':')
        ? TimeOfDay(
            hour: int.tryParse(horaEventoStr.split(':')[0]) ?? 14,
            minute: int.tryParse(horaEventoStr.split(':')[1]) ?? 0)
        : TimeOfDay(
            hour: fechaEvento.hour != 0 ? fechaEvento.hour : 14,
            minute: fechaEvento.minute);
    TimeOfDay horaLimiteTime =
        horaLimiteStr != null && horaLimiteStr.contains(':')
            ? TimeOfDay(
                hour: int.tryParse(horaLimiteStr.split(':')[0]) ?? 23,
                minute: int.tryParse(horaLimiteStr.split(':')[1]) ?? 59)
            : TimeOfDay(
                hour: fechaLimite.hour != 0 ? fechaLimite.hour : 23,
                minute: fechaLimite.minute);

    showAppDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final fmt = DateFormat('dd/MM/yyyy');
          return AlertDialog(
            title: const Text('Editar edición'),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                        controller: nombreCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Nombre', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Precios que paga el asistente',
                            style: TextStyle(fontWeight: FontWeight.w600))),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                          child: TextField(
                              controller: precioHermanoCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Hermano adulto (€)',
                                  border: OutlineInputBorder()),
                              keyboardType: TextInputType.number)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: TextField(
                              controller: precioHermanoNinoCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Hermano niño (€)',
                                  border: OutlineInputBorder()),
                              keyboardType: TextInputType.number)),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                          child: TextField(
                              controller: precioInvitadoCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Invitado adulto (€)',
                                  border: OutlineInputBorder()),
                              keyboardType: TextInputType.number)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: TextField(
                              controller: precioInvitadoNinoCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Invitado niño (€)',
                                  border: OutlineInputBorder()),
                              keyboardType: TextInputType.number)),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                          child: TextField(
                              controller: precioProtocoloCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Protocolo adulto (€)',
                                  border: OutlineInputBorder()),
                              keyboardType: TextInputType.number)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: TextField(
                              controller: precioProtocoloNinoCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Protocolo niño (€)',
                                  border: OutlineInputBorder()),
                              keyboardType: TextInputType.number)),
                    ]),
                    const SizedBox(height: 12),
                    const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Costes reales restaurante',
                            style: TextStyle(fontWeight: FontWeight.w600))),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                          child: TextField(
                              controller: costeMenuAdultoCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Coste menú adulto (€)',
                                  border: OutlineInputBorder()),
                              keyboardType: TextInputType.number)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: TextField(
                              controller: costeMenuNinoCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Coste menú niño (€)',
                                  border: OutlineInputBorder()),
                              keyboardType: TextInputType.number)),
                    ]),
                    const SizedBox(height: 16),
                    const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Fecha y hora del evento',
                            style: TextStyle(fontWeight: FontWeight.w600))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: fechaEvento,
                                  firstDate: DateTime(DateTime.now().year - 1),
                                  lastDate: DateTime(DateTime.now().year + 2));
                              if (picked != null)
                                setDialogState(() => fechaEvento = picked);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                  labelText: 'Fecha evento',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.calendar_today)),
                              child: Text(fmt.format(fechaEvento)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showTimePicker(
                                  context: ctx, initialTime: horaEvento);
                              if (picked != null)
                                setDialogState(() => horaEvento = picked);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                  labelText: 'Hora evento',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.access_time)),
                              child: Text(horaEvento.format(ctx)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Fecha y hora límite inscripción',
                            style: TextStyle(fontWeight: FontWeight.w600))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: fechaLimite,
                                  firstDate: DateTime(DateTime.now().year - 1),
                                  lastDate: DateTime(DateTime.now().year + 2));
                              if (picked != null)
                                setDialogState(() => fechaLimite = picked);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                  labelText: 'Fecha límite',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.calendar_today)),
                              child: Text(fmt.format(fechaLimite)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showTimePicker(
                                  context: ctx, initialTime: horaLimiteTime);
                              if (picked != null)
                                setDialogState(() => horaLimiteTime = picked);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                  labelText: 'Hora límite',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.access_time)),
                              child: Text(horaLimiteTime.format(ctx)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child: TextField(
                                controller: horaCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'Hora (texto)',
                                    border: OutlineInputBorder()))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: TextField(
                                controller: lugarCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'Lugar',
                                    border: OutlineInputBorder()))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                        controller: direccionCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Dirección',
                            border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(
                        controller: descripcionCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Descripción',
                            border: OutlineInputBorder()),
                        maxLines: 3),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () async {
                  final fechaEventoFull = DateTime(
                      fechaEvento.year,
                      fechaEvento.month,
                      fechaEvento.day,
                      horaEvento.hour,
                      horaEvento.minute);
                  final fechaLimiteFull = DateTime(
                      fechaLimite.year,
                      fechaLimite.month,
                      fechaLimite.day,
                      horaLimiteTime.hour,
                      horaLimiteTime.minute);
                  await fs.updateFestividadEdicion(ed['id'], {
                    'nombre': nombreCtrl.text.trim(),
                    'precio_hermano':
                        double.tryParse(precioHermanoCtrl.text) ?? 5.0,
                    'precio_hermano_adulto':
                        double.tryParse(precioHermanoCtrl.text) ?? 5.0,
                    'precio_hermano_nino':
                        double.tryParse(precioHermanoNinoCtrl.text) ?? 5.0,
                    'precio_invitado':
                        double.tryParse(precioInvitadoCtrl.text) ?? 27.0,
                    'precio_invitado_adulto':
                        double.tryParse(precioInvitadoCtrl.text) ?? 27.0,
                    'precio_invitado_nino':
                        double.tryParse(precioInvitadoNinoCtrl.text) ?? 15.0,
                    'precio_protocolo':
                        double.tryParse(precioProtocoloCtrl.text) ?? 0,
                    'precio_protocolo_adulto':
                        double.tryParse(precioProtocoloCtrl.text) ?? 0,
                    'precio_protocolo_nino':
                        double.tryParse(precioProtocoloNinoCtrl.text) ?? 0,
                    'coste_menu_adulto':
                        double.tryParse(costeMenuAdultoCtrl.text) ?? 27.0,
                    'coste_menu_nino':
                        double.tryParse(costeMenuNinoCtrl.text) ?? 15.0,
                    'fecha': Timestamp.fromDate(fechaEventoFull),
                    'hora_evento':
                        '${horaEvento.hour.toString().padLeft(2, '0')}:${horaEvento.minute.toString().padLeft(2, '0')}',
                    'hora': horaCtrl.text.trim(),
                    'lugar': lugarCtrl.text.trim(),
                    'direccion': direccionCtrl.text.trim(),
                    'descripcion': descripcionCtrl.text.trim(),
                    'fecha_limite': Timestamp.fromDate(fechaLimiteFull),
                    'hora_limite':
                        '${horaLimiteTime.hour.toString().padLeft(2, '0')}:${horaLimiteTime.minute.toString().padLeft(2, '0')}',
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
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
      case 'abierto':
        color = AppTheme.accentColor;
        label = 'Abierto';
        break;
      case 'cerrado':
        color = Colors.orange;
        label = 'Cerrado';
        break;
      case 'finalizado':
        color = Colors.grey;
        label = 'Finalizado';
        break;
      default:
        color = Colors.blue;
        label = 'Borrador';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: color)),
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
        Text(text,
            style:
                const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.label, required this.icon, required this.onTap});

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
