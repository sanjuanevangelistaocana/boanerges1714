import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/models/loteria.dart';

class MiLoteriaScreen extends StatelessWidget {
  const MiLoteriaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    final authService = context.read<AuthService>();
    final uid = authService.userId;
    final cofradeId = authService.cofrade?.id;

    if (uid == null) {
      return const Center(child: Text('Inicia sesión para ver tu lotería.'));
    }

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
                constraints: BoxConstraints(maxWidth: 1000),
                child: Row(
                  children: [
                    Icon(Icons.confirmation_number,
                        color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Text('Mi Lotería de Navidad',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: FutureBuilder<VendedorLoteria?>(
                  future: _findVendedor(fs, uid, cofradeId),
                  builder: (context, vendSnap) {
                    if (vendSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final vendedor = vendSnap.data;
                    if (vendedor == null) {
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(40),
                          child: Column(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 48, color: AppTheme.textSecondary),
                              SizedBox(height: 12),
                              Text('No tienes asignaciones de lotería',
                                  style: TextStyle(
                                      fontSize: 16,
                                      color: AppTheme.textSecondary)),
                              SizedBox(height: 4),
                              Text(
                                  'Si vendes lotería para la cofradía, pide al administrador que te asigne sábanas.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                      );
                    }

                    return StreamBuilder<List<AsignacionLoteria>>(
                      stream: fs.getAsignacionesVendedor(vendedor.id),
                      builder: (context, asigSnap) {
                        final asignaciones = asigSnap.data ?? [];
                        if (asignaciones.isEmpty) {
                          return const Card(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: Center(
                                  child: Text(
                                      'No tienes sábanas asignadas actualmente.')),
                            ),
                          );
                        }

                        return StreamBuilder<List<DecimoLoteria>>(
                          stream: fs.getDecimosVendedor(vendedor.id),
                          builder: (context, decSnap) {
                            final decimos = decSnap.data ?? [];
                            if (decimos.isNotEmpty) {
                              return _DecimosAsignadosPanel(
                                  decimos: decimos, fs: fs);
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: asignaciones
                                  .map((a) =>
                                      _AsignacionCard(asignacion: a, fs: fs))
                                  .toList(),
                            );
                          },
                        );
                      },
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

  Future<VendedorLoteria?> _findVendedor(
      FirestoreService fs, String uid, String? cofradeId) async {
    final byUid = await fs.getVendedorByAuthUid(uid);
    if (byUid != null) return byUid;
    if (cofradeId == null) return null;
    return fs.getVendedorByCofradeId(cofradeId);
  }
}

class _DecimosAsignadosPanel extends StatelessWidget {
  final List<DecimoLoteria> decimos;
  final FirestoreService fs;
  const _DecimosAsignadosPanel({required this.decimos, required this.fs});

  @override
  Widget build(BuildContext context) {
    final vendidos = decimos
        .where((d) => d.estado == 'vendido' || d.estado == 'cobrado')
        .length;
    final pendientes = decimos.where((d) => d.estado == 'asignado').length;
    final devueltosPendientes =
        decimos.where((d) => d.estado == 'devuelto_pendiente_revision').length;
    final totalImporte =
        decimos.fold<double>(0, (sum, d) => sum + d.precioVenta);
    final vendidoImporte = decimos
        .where((d) => d.estado == 'vendido' || d.estado == 'cobrado')
        .fold<double>(0, (sum, d) => sum + d.precioVenta);
    final pendienteImporte = decimos
        .where((d) => d.estado == 'asignado')
        .fold<double>(0, (sum, d) => sum + d.precioVenta);
    final bySabana = <String, List<DecimoLoteria>>{};
    for (final d in decimos) {
      bySabana.putIfAbsent(d.sabanaId, () => []).add(d);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 0,
          color: AppTheme.primaryColor.withAlpha(8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppTheme.primaryColor.withAlpha(35)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Wrap(
              spacing: 18,
              runSpacing: 12,
              children: [
                _StatChip(
                    label: 'Asignados',
                    value: '${decimos.length}',
                    color: AppTheme.primaryColor),
                _StatChip(
                    label: 'Vendidos',
                    value: '$vendidos',
                    color: AppTheme.accentColor),
                _StatChip(
                    label: 'Pendientes',
                    value: '$pendientes',
                    color: Colors.orange.shade700),
                _StatChip(
                    label: 'Devueltos revisión',
                    value: '$devueltosPendientes',
                    color: Colors.red.shade600),
                _StatChip(
                    label: 'Importe vendido',
                    value: '${vendidoImporte.toStringAsFixed(2)}€',
                    color: AppTheme.accentColor),
                _StatChip(
                    label: 'Importe pendiente',
                    value: '${pendienteImporte.toStringAsFixed(2)}€',
                    color: Colors.orange.shade700),
                _StatChip(
                    label: 'Total asignado',
                    value: '${totalImporte.toStringAsFixed(2)}€',
                    color: AppTheme.primaryColor),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...bySabana.entries.map((entry) {
          final items = entry.value;
          final first = items.first;
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nº ${first.numeroLoteria} · Serie ${first.serie}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: items
                        .map((d) => _DecimoChip(decimo: d, fs: fs))
                        .toList(),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _DecimoChip extends StatefulWidget {
  final DecimoLoteria decimo;
  final FirestoreService fs;
  const _DecimoChip({required this.decimo, required this.fs});

  @override
  State<_DecimoChip> createState() => _DecimoChipState();
}

class _DecimoChipState extends State<_DecimoChip> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final estado = widget.decimo.estado;
    final vendido = estado == 'vendido' || estado == 'cobrado';
    final devuelto = estado == 'devuelto_pendiente_revision' ||
        estado == 'devuelto_confirmado';
    final color = vendido
        ? AppTheme.accentColor
        : devuelto
            ? Colors.red.shade600
            : Colors.orange.shade700;
    return PopupMenuButton<String>(
      enabled: !_saving && estado != 'devuelto_confirmado',
      tooltip: 'Actualizar décimo ${widget.decimo.numeroDecimo}',
      onSelected: (value) async {
        setState(() => _saving = true);
        try {
          await widget.fs.updateDecimoEstado(widget.decimo.id, value);
        } finally {
          if (mounted) setState(() => _saving = false);
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'vendido', child: Text('Marcar vendido')),
        PopupMenuItem(value: 'asignado', child: Text('Marcar pendiente')),
        PopupMenuItem(
            value: 'devuelto_pendiente_revision',
            child: Text('Marcar devuelto')),
      ],
      child: Chip(
        avatar: Icon(
          vendido
              ? Icons.check
              : devuelto
                  ? Icons.assignment_return
                  : Icons.radio_button_unchecked,
          size: 16,
          color: color,
        ),
        label: Text('${widget.decimo.numeroDecimo}'),
        backgroundColor: color.withAlpha(20),
        side: BorderSide(color: color.withAlpha(80)),
      ),
    );
  }
}

class _AsignacionCard extends StatefulWidget {
  final AsignacionLoteria asignacion;
  final FirestoreService fs;
  const _AsignacionCard({required this.asignacion, required this.fs});

  @override
  State<_AsignacionCard> createState() => _AsignacionCardState();
}

class _AsignacionCardState extends State<_AsignacionCard> {
  late TextEditingController _vendidosCtrl;
  late TextEditingController _devueltosCtrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _vendidosCtrl =
        TextEditingController(text: '${widget.asignacion.decimosVendidos}');
    _devueltosCtrl =
        TextEditingController(text: '${widget.asignacion.decimosDevueltos}');
  }

  @override
  void didUpdateWidget(covariant _AsignacionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asignacion.decimosVendidos !=
        widget.asignacion.decimosVendidos) {
      _vendidosCtrl.text = '${widget.asignacion.decimosVendidos}';
    }
    if (oldWidget.asignacion.decimosDevueltos !=
        widget.asignacion.decimosDevueltos) {
      _devueltosCtrl.text = '${widget.asignacion.decimosDevueltos}';
    }
  }

  @override
  void dispose() {
    _vendidosCtrl.dispose();
    _devueltosCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.asignacion;
    final vendidos = int.tryParse(_vendidosCtrl.text) ?? 0;
    final devueltos = int.tryParse(_devueltosCtrl.text) ?? 0;
    final disponibles = a.decimosAsignados - vendidos - devueltos;
    final pctVenta =
        a.decimosAsignados > 0 ? (vendidos / a.decimosAsignados * 100) : 0.0;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withAlpha(15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.confirmation_number,
                      color: AppTheme.primaryColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${a.decimosAsignados} décimos asignados',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                      FutureBuilder<CampanaLoteria?>(
                        future: widget.fs.getCampanaById(a.campanaId),
                        builder: (context, snap) {
                          final campana = snap.data;
                          if (campana == null) return const SizedBox.shrink();
                          return Text(
                              'Nº ${campana.numeroLoteria} · ${campana.nombre}',
                              style: const TextStyle(
                                  fontSize: 13, color: AppTheme.textSecondary));
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Progress
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$vendidos/${a.decimosAsignados} vendidos'),
                Text('${pctVenta.toStringAsFixed(0)}%',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentColor,
                        fontSize: 18)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value:
                    a.decimosAsignados > 0 ? vendidos / a.decimosAsignados : 0,
                backgroundColor: Colors.grey.shade200,
                color: AppTheme.accentColor,
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 16),

            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatChip(
                    label: 'Asignados',
                    value: '${a.decimosAsignados}',
                    color: AppTheme.primaryColor),
                _StatChip(
                    label: 'Vendidos',
                    value: '$vendidos',
                    color: AppTheme.accentColor),
                _StatChip(
                    label: 'Devueltos',
                    value: '$devueltos',
                    color: Colors.red.shade600),
                _StatChip(
                    label: 'Disponibles',
                    value: '$disponibles',
                    color:
                        disponibles >= 0 ? Colors.orange.shade700 : Colors.red),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),

            // Input fields
            const Text('Actualizar ventas',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _vendidosCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Décimos vendidos',
                      prefixIcon: Icon(Icons.sell, size: 20),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() => _error = null),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _devueltosCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Décimos devueltos',
                      prefixIcon: Icon(Icons.undo, size: 20),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() => _error = null),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _guardar,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save),
                label: const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _guardar() async {
    final vendidos = int.tryParse(_vendidosCtrl.text) ?? 0;
    final devueltos = int.tryParse(_devueltosCtrl.text) ?? 0;
    final asignados = widget.asignacion.decimosAsignados;

    if (vendidos < 0 || devueltos < 0) {
      setState(() => _error = 'Los valores no pueden ser negativos.');
      return;
    }
    if (vendidos + devueltos > asignados) {
      setState(() => _error =
          'Vendidos + devueltos ($vendidos + $devueltos = ${vendidos + devueltos}) no puede superar los asignados ($asignados).');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.fs.actualizarVentasAsignacion(
          widget.asignacion.id, vendidos, devueltos);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Ventas actualizadas correctamente'),
              backgroundColor: AppTheme.accentColor),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Error al guardar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 20, color: color)),
        Text(label,
            style:
                const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }
}
