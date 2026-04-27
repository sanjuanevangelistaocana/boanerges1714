import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/models/loteria.dart';

class AsignacionExternaScreen extends StatefulWidget {
  final String token;
  const AsignacionExternaScreen({super.key, required this.token});

  @override
  State<AsignacionExternaScreen> createState() => _AsignacionExternaScreenState();
}

class _AsignacionExternaScreenState extends State<AsignacionExternaScreen> {
  AsignacionLoteria? _asignacion;
  VendedorLoteria? _vendedor;
  CampanaLoteria? _campana;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _loadError;

  late TextEditingController _vendidosCtrl;
  late TextEditingController _devueltosCtrl;

  @override
  void initState() {
    super.initState();
    _vendidosCtrl = TextEditingController();
    _devueltosCtrl = TextEditingController();
    _cargarDatos();
  }

  @override
  void dispose() {
    _vendidosCtrl.dispose();
    _devueltosCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    final fs = context.read<FirestoreService>();
    try {
      final asignacion = await fs.getAsignacionByToken(widget.token);
      if (asignacion == null) {
        setState(() {
          _loading = false;
          _loadError = 'Enlace no válido o expirado.';
        });
        return;
      }

      final vendedor = await fs.getVendedorById(asignacion.vendedorId);
      final campana = await fs.getCampanaById(asignacion.campanaId);

      setState(() {
        _asignacion = asignacion;
        _vendedor = vendedor;
        _campana = campana;
        _vendidosCtrl.text = '${asignacion.decimosVendidos}';
        _devueltosCtrl.text = '${asignacion.decimosDevueltos}';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _loadError = 'Error al cargar: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
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
                  constraints: BoxConstraints(maxWidth: 800),
                  child: Row(
                    children: [
                      Icon(Icons.confirmation_number, color: Colors.white, size: 28),
                      SizedBox(width: 12),
                      Text('Lotería de Navidad',
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(40),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppTheme.textSecondary),
                      const SizedBox(height: 12),
                      Text(_loadError!, style: const TextStyle(fontSize: 16), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final a = _asignacion!;
    final vendidos = int.tryParse(_vendidosCtrl.text) ?? 0;
    final devueltos = int.tryParse(_devueltosCtrl.text) ?? 0;
    final disponibles = a.decimosAsignados - vendidos - devueltos;
    final pctVenta = a.decimosAsignados > 0 ? (vendidos / a.decimosAsignados * 100) : 0.0;

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
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.confirmation_number, color: Colors.white, size: 28),
                        SizedBox(width: 12),
                        Text('Lotería de Navidad',
                            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    if (_vendedor != null || _campana != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${_vendedor?.nombre ?? ""} · ${_campana?.nombre ?? ""}',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_campana != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withAlpha(10),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, size: 18, color: AppTheme.primaryColor),
                                const SizedBox(width: 8),
                                Text('Nº ${_campana!.numeroLoteria} · ${_campana!.precioVenta.toStringAsFixed(2)}€/décimo',
                                    style: const TextStyle(color: AppTheme.primaryColor)),
                              ],
                            ),
                          ),
                        const SizedBox(height: 20),

                        // Progress
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('$vendidos/${a.decimosAsignados} vendidos', style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text('${pctVenta.toStringAsFixed(0)}%',
                                style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentColor, fontSize: 20)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: a.decimosAsignados > 0 ? vendidos / a.decimosAsignados : 0,
                            backgroundColor: Colors.grey.shade200,
                            color: AppTheme.accentColor,
                            minHeight: 10,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Stats
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _StatChip(label: 'Asignados', value: '${a.decimosAsignados}', color: AppTheme.primaryColor),
                            _StatChip(label: 'Vendidos', value: '$vendidos', color: AppTheme.accentColor),
                            _StatChip(label: 'Devueltos', value: '$devueltos', color: Colors.red.shade600),
                            _StatChip(label: 'Disponibles', value: '$disponibles',
                                color: disponibles >= 0 ? Colors.orange.shade700 : Colors.red),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),

                        const Text('Actualizar ventas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                          Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : _guardar,
                            icon: _saving
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.save),
                            label: const Text('Guardar'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _guardar() async {
    final vendidos = int.tryParse(_vendidosCtrl.text) ?? 0;
    final devueltos = int.tryParse(_devueltosCtrl.text) ?? 0;
    final asignados = _asignacion!.decimosAsignados;

    if (vendidos < 0 || devueltos < 0) {
      setState(() => _error = 'Los valores no pueden ser negativos.');
      return;
    }
    if (vendidos + devueltos > asignados) {
      setState(() => _error = 'Vendidos + devueltos no puede superar los asignados ($asignados).');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final fs = context.read<FirestoreService>();
      await fs.actualizarVentasAsignacion(_asignacion!.id, vendidos, devueltos);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ventas actualizadas'), backgroundColor: AppTheme.accentColor),
        );
        _cargarDatos();
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
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }
}
