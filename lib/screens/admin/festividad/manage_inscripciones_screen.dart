import 'package:flutter/material.dart';
import 'package:boanerges1714/widgets/responsive_dialog.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/firestore_service.dart';

class ManageInscripcionesFestividadScreen extends StatefulWidget {
  final String edicionId;
  const ManageInscripcionesFestividadScreen(
      {super.key, required this.edicionId});

  @override
  State<ManageInscripcionesFestividadScreen> createState() =>
      _ManageInscripcionesFestividadScreenState();
}

class _ManageInscripcionesFestividadScreenState
    extends State<ManageInscripcionesFestividadScreen> {
  String _filterEstado = 'todos';
  String _filterPago = 'todos';
  String _searchQuery = '';

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
                  const Icon(Icons.people, color: Colors.white70, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Inscripciones',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                  ),
                  ElevatedButton.icon(
                    onPressed: () =>
                        _showCrearInscripcionProtocolo(context, fs),
                    icon: const Icon(Icons.stars, size: 18),
                    label: const Text('Protocolo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.purple,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                children: [
                  // Filters
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: 200,
                            child: TextField(
                              decoration: const InputDecoration(
                                labelText: 'Buscar',
                                prefixIcon: Icon(Icons.search, size: 20),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (v) => setState(
                                  () => _searchQuery = v.toLowerCase()),
                            ),
                          ),
                          DropdownButton<String>(
                            value: _filterEstado,
                            underline: const SizedBox.shrink(),
                            items: const [
                              DropdownMenuItem(
                                  value: 'todos',
                                  child: Text('Todos los estados')),
                              DropdownMenuItem(
                                  value: 'pendiente', child: Text('Pendiente')),
                              DropdownMenuItem(
                                  value: 'confirmada',
                                  child: Text('Confirmada')),
                              DropdownMenuItem(
                                  value: 'cancelada', child: Text('Cancelada')),
                            ],
                            onChanged: (v) =>
                                setState(() => _filterEstado = v ?? 'todos'),
                          ),
                          DropdownButton<String>(
                            value: _filterPago,
                            underline: const SizedBox.shrink(),
                            items: const [
                              DropdownMenuItem(
                                  value: 'todos',
                                  child: Text('Todos los pagos')),
                              DropdownMenuItem(
                                  value: 'pendiente',
                                  child: Text('Pago pendiente')),
                              DropdownMenuItem(
                                  value: 'pagado', child: Text('Pagado')),
                              DropdownMenuItem(
                                  value: 'parcial', child: Text('Parcial')),
                              DropdownMenuItem(
                                  value: 'exento', child: Text('Exento')),
                            ],
                            onChanged: (v) =>
                                setState(() => _filterPago = v ?? 'todos'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Inscripciones list
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: fs.getFestividadInscripciones(widget.edicionId),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final all = snap.data ?? [];
                      final filtered = all.where((i) {
                        if (_filterEstado != 'todos' &&
                            i['estado'] != _filterEstado) return false;
                        if (_filterPago != 'todos' &&
                            i['payment_status'] != _filterPago) return false;
                        if (_searchQuery.isNotEmpty) {
                          final nombre = (i['cofrade_nombre'] ?? '')
                              .toString()
                              .toLowerCase();
                          final asistentes = List<Map<String, dynamic>>.from(
                              (i['asistentes'] as List<dynamic>?) ?? []);
                          final matchAsistente = asistentes.any((a) =>
                              '${a['nombre']} ${a['apellidos']}'
                                  .toLowerCase()
                                  .contains(_searchQuery));
                          if (!nombre.contains(_searchQuery) && !matchAsistente)
                            return false;
                        }
                        return true;
                      }).toList();

                      // Summary stats
                      final activas =
                          all.where((i) => i['estado'] != 'cancelada').toList();
                      final totalAsistentes = activas.fold<int>(0, (s, i) {
                        final asist = List.from(
                            (i['asistentes'] as List<dynamic>?) ?? []);
                        return s + asist.length;
                      });
                      final totalRecaudacion = activas.fold<double>(0, (s, i) {
                        return s + ((i['total'] as num?)?.toDouble() ?? 0);
                      });
                      final pagados = activas
                          .where((i) => i['payment_status'] == 'pagado')
                          .length;

                      return Column(
                        children: [
                          // Stats row
                          Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _MiniStat(
                                      value: '${activas.length}',
                                      label: 'Inscripciones',
                                      color: AppTheme.primaryColor),
                                  _MiniStat(
                                      value: '$totalAsistentes',
                                      label: 'Asistentes',
                                      color: AppTheme.accentColor),
                                  _MiniStat(
                                      value: '$pagados/${activas.length}',
                                      label: 'Pagados',
                                      color: Colors.orange.shade700),
                                  _MiniStat(
                                      value:
                                          '${totalRecaudacion.toStringAsFixed(0)} €',
                                      label: 'Total',
                                      color: AppTheme.primaryColor),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (filtered.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(32),
                              child: Text(
                                  'No hay inscripciones que coincidan con los filtros.',
                                  style:
                                      TextStyle(color: AppTheme.textSecondary)),
                            )
                          else
                            ...filtered.map((i) => _InscripcionCard(
                                inscripcion: i,
                                edicionId: widget.edicionId,
                                fs: fs)),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCrearInscripcionProtocolo(
      BuildContext context, FirestoreService fs) {
    final nombreCtrl = TextEditingController();
    final apellidosCtrl = TextEditingController();
    final cargoCtrl = TextEditingController();
    String? selectedMenuId;

    showAppDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.stars, color: Colors.purple),
            SizedBox(width: 8),
            Text('Asistente de Protocolo'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: fs.getFestividadMenus(widget.edicionId),
            builder: (context, menuSnap) {
              final menus = (menuSnap.data ?? [])
                  .where((m) => m['activo'] == true)
                  .toList();
              return StatefulBuilder(
                builder: (context, setDialogState) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                        controller: nombreCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Nombre *',
                            border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(
                        controller: apellidosCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Apellidos',
                            border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(
                        controller: cargoCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Cargo/Representación',
                            border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedMenuId,
                      decoration: const InputDecoration(
                          labelText: 'Menú *', border: OutlineInputBorder()),
                      items: menus
                          .map((m) => DropdownMenuItem(
                              value: m['id'] as String,
                              child: Text(m['nombre'] ?? '')))
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => selectedMenuId = v),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (nombreCtrl.text.trim().isEmpty || selectedMenuId == null)
                return;
              final menusAll =
                  await fs.getFestividadMenus(widget.edicionId).first;
              final menuNombre =
                  menusAll.where((m) => m['id'] == selectedMenuId).toList();
              final menuExtra = menuNombre.isNotEmpty
                  ? (menuNombre.first['precio_extra'] as num?)?.toDouble() ?? 0
                  : 0.0;

              await fs.createFestividadInscripcion(widget.edicionId, {
                'cofrade_id': '',
                'cofrade_nombre':
                    '${nombreCtrl.text.trim()} ${apellidosCtrl.text.trim()}'
                        .trim(),
                'es_protocolo': true,
                'asistentes': [
                  {
                    'nombre': nombreCtrl.text.trim(),
                    'apellidos': apellidosCtrl.text.trim(),
                    'tipo': 'protocolo',
                    'cofrade_id': '',
                    'menu_id': selectedMenuId,
                    'menu_nombre': menuNombre.isNotEmpty
                        ? menuNombre.first['nombre'] ?? ''
                        : '',
                    'cargo': cargoCtrl.text.trim(),
                    'alergias': '',
                    'observaciones': '',
                    'precio_aplicado': menuExtra,
                  },
                ],
                'total': menuExtra,
                'estado': 'confirmada',
                'payment_status': 'exento',
              });
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }
}

class _InscripcionCard extends StatelessWidget {
  final Map<String, dynamic> inscripcion;
  final String edicionId;
  final FirestoreService fs;
  const _InscripcionCard(
      {required this.inscripcion, required this.edicionId, required this.fs});

  @override
  Widget build(BuildContext context) {
    final i = inscripcion;
    final estado = i['estado'] ?? 'pendiente';
    final pago = i['payment_status'] ?? 'pendiente';
    final asistentes = List<Map<String, dynamic>>.from(
        (i['asistentes'] as List<dynamic>?) ?? []);
    final total = (i['total'] as num?)?.toDouble() ?? 0;
    final paidAmount = (i['paid_amount'] as num?)?.toDouble() ??
        (pago == 'pagado' ? total : 0);
    final pendingAmount = (i['pending_amount'] as num?)?.toDouble() ??
        (total - paidAmount).clamp(0, total).toDouble();
    final createdAt = (i['created_at'] as Timestamp?)?.toDate();
    final esProtocolo = i['es_protocolo'] == true;
    final fmt = DateFormat('dd/MM/yyyy HH:mm');

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: estado == 'cancelada'
              ? Colors.red.shade200
              : esProtocolo
                  ? Colors.purple.withAlpha(60)
                  : Colors.grey.shade200,
        ),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: esProtocolo
              ? Colors.purple.withAlpha(20)
              : AppTheme.primaryColor.withAlpha(15),
          child: Icon(
            esProtocolo ? Icons.stars : Icons.person,
            size: 20,
            color: esProtocolo ? Colors.purple : AppTheme.primaryColor,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                i['cofrade_nombre'] ?? 'Sin nombre',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  decoration:
                      estado == 'cancelada' ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            _EstadoBadge(status: estado),
            const SizedBox(width: 6),
            _PaymentBadge(status: pago),
          ],
        ),
        subtitle: Row(
          children: [
            Text('${asistentes.length} asist.',
                style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 8),
            Text('${total.toStringAsFixed(2)} €',
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            if (pago == 'parcial') ...[
              const SizedBox(width: 8),
              Text('Pagado ${paidAmount.toStringAsFixed(2)} €',
                  style: TextStyle(fontSize: 12, color: AppTheme.accentColor)),
              const SizedBox(width: 8),
              Text('Pendiente ${pendingAmount.toStringAsFixed(2)} €',
                  style:
                      TextStyle(fontSize: 12, color: Colors.orange.shade700)),
            ],
            if (createdAt != null) ...[
              const SizedBox(width: 8),
              Text(fmt.format(createdAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                ...asistentes.map((a) {
                  final tipo = a['tipo'] ?? '';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(
                          tipo == 'hermano'
                              ? Icons.person
                              : tipo == 'protocolo'
                                  ? Icons.stars
                                  : Icons.person_outline,
                          size: 16,
                          color: tipo == 'hermano'
                              ? AppTheme.accentColor
                              : tipo == 'protocolo'
                                  ? Colors.purple
                                  : AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('${a['nombre']} ${a['apellidos']}',
                              style: const TextStyle(fontSize: 13)),
                        ),
                        Text(_tipoLabel(tipo),
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade600)),
                        const SizedBox(width: 8),
                        Text(a['menu_nombre'] ?? '',
                            style: const TextStyle(fontSize: 11)),
                        const SizedBox(width: 8),
                        Text(
                            '${(a['precio_aplicado'] as num? ?? 0).toStringAsFixed(2)} €',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 12)),
                      ],
                    ),
                  );
                }),
                // Alergias
                ...asistentes
                    .where((a) => (a['alergias'] ?? '').toString().isNotEmpty)
                    .map((a) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber,
                                  size: 14, color: Colors.orange.shade700),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${a['nombre']}: ${a['alergias']}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange.shade700),
                                ),
                              ),
                            ],
                          ),
                        )),
                const Divider(height: 20),
                // Actions
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (estado != 'cancelada') ...[
                      PopupMenuButton<String>(
                        onSelected: (v) => _cambiarPago(context, v),
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                              value: 'pendiente', child: Text('Pendiente')),
                          const PopupMenuItem(
                              value: 'pagado', child: Text('Pagado')),
                          const PopupMenuItem(
                              value: 'parcial', child: Text('Parcial')),
                          const PopupMenuItem(
                              value: 'exento', child: Text('Exento')),
                        ],
                        child: _ActionChip(
                            icon: Icons.payment, label: 'Cambiar pago'),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (v) => _cambiarEstado(context, v),
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                              value: 'pendiente', child: Text('Pendiente')),
                          const PopupMenuItem(
                              value: 'confirmada', child: Text('Confirmada')),
                          const PopupMenuItem(
                              value: 'cancelada', child: Text('Cancelar')),
                        ],
                        child: _ActionChip(
                            icon: Icons.swap_horiz, label: 'Estado'),
                      ),
                    ],
                    if (estado == 'cancelada')
                      InkWell(
                        onTap: () => _cambiarEstado(context, 'pendiente'),
                        child: const _ActionChip(
                            icon: Icons.restore, label: 'Restaurar'),
                      ),
                    InkWell(
                      onTap: () => _confirmarEliminar(context),
                      child: _ActionChip(
                          icon: Icons.delete,
                          label: 'Eliminar',
                          isDestructive: true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _tipoLabel(String tipo) {
    switch (tipo) {
      case 'hermano':
        return 'Hermano/a';
      case 'invitado':
        return 'Invitado/a';
      case 'protocolo':
        return 'Protocolo';
      default:
        return tipo;
    }
  }

  void _cambiarPago(BuildContext context, String status) async {
    if (status == 'parcial') {
      _showPagoParcialDialog(context);
      return;
    }
    final total = (inscripcion['total'] as num?)?.toDouble() ?? 0;
    await fs.updateFestividadInscripcion(edicionId, inscripcion['id'], {
      'payment_status': status,
      'paid_amount': status == 'pagado' ? total : 0,
      'pending_amount': status == 'pagado' || status == 'exento' ? 0 : total,
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Pago actualizado a: $status')));
    }
  }

  void _showPagoParcialDialog(BuildContext context) {
    final total = (inscripcion['total'] as num?)?.toDouble() ?? 0;
    final paidCtrl = TextEditingController(
      text: ((inscripcion['paid_amount'] as num?)?.toDouble() ?? 0)
          .toStringAsFixed(2),
    );
    final notesCtrl = TextEditingController(
      text: '${inscripcion['payment_notes'] ?? ''}',
    );
    showAppDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pago parcial'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Total inscripción: ${total.toStringAsFixed(2)} €'),
              const SizedBox(height: 12),
              TextField(
                controller: paidCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Importe pagado',
                  suffixText: '€',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Observaciones de pago',
                  border: OutlineInputBorder(),
                ),
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
            onPressed: () async {
              final paid = double.tryParse(
                    paidCtrl.text.replaceAll(',', '.'),
                  ) ??
                  0;
              final normalizedPaid = paid.clamp(0, total).toDouble();
              await fs
                  .updateFestividadInscripcion(edicionId, inscripcion['id'], {
                'payment_status': 'parcial',
                'paid_amount': normalizedPaid,
                'pending_amount': (total - normalizedPaid).clamp(0, total),
                'payment_notes': notesCtrl.text.trim(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Pago parcial actualizado.')),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _cambiarEstado(BuildContext context, String estado) async {
    await fs.updateFestividadInscripcion(
        edicionId, inscripcion['id'], {'estado': estado});
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Estado actualizado a: $estado')));
    }
  }

  void _confirmarEliminar(BuildContext context) {
    showAppDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar inscripción'),
        content: const Text(
            '¿Seguro que quieres eliminar esta inscripción permanentemente?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              await fs.deleteFestividadInscripcion(
                  edicionId, inscripcion['id']);
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

class _PaymentBadge extends StatelessWidget {
  final String status;
  const _PaymentBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'pagado':
        color = AppTheme.accentColor;
        label = 'Pagado';
        break;
      case 'parcial':
        color = Colors.orange.shade800;
        label = 'Parcial';
        break;
      case 'exento':
        color = AppTheme.accentColor;
        label = 'Exento';
        break;
      case 'devuelto':
      case 'rechazado':
      case 'no_pagado':
        color = Colors.red.shade700;
        label = 'No pagado';
        break;
      default:
        color = Colors.orange.shade800;
        label = 'Pendiente';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _EstadoBadge extends StatelessWidget {
  final String status;
  const _EstadoBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'confirmada':
        color = AppTheme.accentColor;
        label = 'Confirmada';
        break;
      case 'cancelada':
      case 'rechazada':
        color = Colors.red.shade700;
        label = status == 'rechazada' ? 'Rechazada' : 'Cancelada';
        break;
      default:
        color = Colors.orange.shade800;
        label = 'Pendiente';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDestructive;
  const _ActionChip(
      {required this.icon, required this.label, this.isDestructive = false});

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.red.shade400 : AppTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(
            color: isDestructive ? Colors.red.shade200 : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _MiniStat(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style:
                const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }
}
