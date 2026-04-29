import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/services/firestore_service.dart';

class FestividadScreen extends StatelessWidget {
  const FestividadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    final auth = context.watch<AuthService>();
    final cofrade = auth.cofrade;

    return StreamBuilder<Map<String, dynamic>?>(
      stream: fs.getFestividadEdicionActivaStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final edicion = snap.data;
        if (edicion == null) {
          return _buildNoEdicion(context);
        }
        return _FestividadContent(
          edicion: edicion,
          cofrade: cofrade,
          fs: fs,
        );
      },
    );
  }

  Widget _buildNoEdicion(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeader(),
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.celebration,
                      size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text(
                    'No hay ninguna edición de la Festividad activa en este momento.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Cuando la Junta publique la próxima edición, podrás inscribirte desde aquí.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryDark, AppTheme.primaryColor],
        ),
      ),
      child: const Padding(
        padding: EdgeInsets.fromLTRB(32, 28, 32, 24),
        child: Row(
          children: [
            Icon(Icons.celebration, color: Colors.white70, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text('Festividad San Juan Evangelista',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _FestividadContent extends StatefulWidget {
  final Map<String, dynamic> edicion;
  final dynamic cofrade;
  final FirestoreService fs;
  const _FestividadContent(
      {required this.edicion, this.cofrade, required this.fs});

  @override
  State<_FestividadContent> createState() => _FestividadContentState();
}

class _FestividadContentState extends State<_FestividadContent> {
  Map<String, dynamic>? _miInscripcion;
  bool _loadingInscripcion = true;

  @override
  void initState() {
    super.initState();
    _loadMiInscripcion();
  }

  Future<void> _loadMiInscripcion() async {
    if (widget.cofrade == null) {
      setState(() => _loadingInscripcion = false);
      return;
    }
    try {
      final insc = await widget.fs
          .getMiInscripcionFestividad(widget.edicion['id'], widget.cofrade.id);
      final accessible = insc ??
          await widget.fs.getInscripcionFestividadParaCofrade(
              widget.edicion['id'], widget.cofrade.id);
      if (mounted) {
        setState(() {
          _miInscripcion = accessible;
          _loadingInscripcion = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingInscripcion = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ed = widget.edicion;
    final estado = ed['estado'] ?? 'borrador';
    final isAbierto = estado == 'abierto';
    final fmt = DateFormat('dd/MM/yyyy');
    final fecha = (ed['fecha'] as Timestamp?)?.toDate();
    final fechaLimite = (ed['fecha_limite'] as Timestamp?)?.toDate();
    final precioHermano = (ed['precio_hermano'] as num?)?.toDouble() ?? 5.0;
    final precioInvitado = (ed['precio_invitado'] as num?)?.toDouble() ?? 27.0;

    return SingleChildScrollView(
      child: Column(
        children: [
          // Header
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.celebration,
                          color: Colors.white70, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          ed['nombre'] ?? 'Festividad San Juan Evangelista',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _EstadoChip(estado: estado),
                      const SizedBox(width: 12),
                      if (fecha != null)
                        Text(
                          fmt.format(fecha),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Event info card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Detalles del evento',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          const Divider(height: 24),
                          _InfoRow(
                              icon: Icons.calendar_today,
                              label: 'Fecha',
                              value: fecha != null
                                  ? fmt.format(fecha)
                                  : 'Por confirmar'),
                          _InfoRow(
                              icon: Icons.access_time,
                              label: 'Hora',
                              value: ed['hora'] ?? 'Por confirmar'),
                          _InfoRow(
                              icon: Icons.location_on,
                              label: 'Lugar',
                              value: ed['lugar'] ?? 'Por confirmar'),
                          if (ed['direccion'] != null &&
                              (ed['direccion'] as String).isNotEmpty)
                            _InfoRow(
                                icon: Icons.map,
                                label: 'Dirección',
                                value: ed['direccion']),
                          if (ed['descripcion'] != null &&
                              (ed['descripcion'] as String).isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(ed['descripcion'],
                                style: const TextStyle(
                                    color: AppTheme.textSecondary)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Pricing card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Precios',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          const Divider(height: 24),
                          Row(
                            children: [
                              Expanded(
                                  child: _PriceChip(
                                      label: 'Hermano/a',
                                      price: precioHermano,
                                      color: AppTheme.accentColor)),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: _PriceChip(
                                      label: 'Invitado/a',
                                      price: precioInvitado,
                                      color: AppTheme.primaryColor)),
                            ],
                          ),
                          if (fechaLimite != null) ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Icon(Icons.timer,
                                    size: 18, color: Colors.orange.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  'Fecha límite inscripción: ${fmt.format(fechaLimite)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: fechaLimite.isBefore(DateTime.now())
                                        ? Colors.red
                                        : Colors.orange.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Inscription section
                  if (_loadingInscripcion)
                    const Center(child: CircularProgressIndicator())
                  else if (_miInscripcion != null)
                    _MiInscripcionCard(
                      inscripcion: _miInscripcion!,
                      edicion: ed,
                      fs: widget.fs,
                      onUpdated: _loadMiInscripcion,
                    )
                  else if (isAbierto &&
                      fechaLimite != null &&
                      !fechaLimite.isBefore(DateTime.now()))
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final result = await context.push<bool>(
                              '/festividad/inscripcion?edicionId=${ed['id']}');
                          if (result == true) _loadMiInscripcion();
                        },
                        icon: const Icon(Icons.how_to_reg),
                        label: const Text('Inscribirme'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 16),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
                    )
                  else if (!isAbierto)
                    _buildClosedMessage(estado)
                  else
                    _buildDeadlinePassedMessage(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClosedMessage(String estado) {
    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                estado == 'cerrado'
                    ? 'Las inscripciones están cerradas.'
                    : estado == 'finalizado'
                        ? 'Este evento ya ha finalizado.'
                        : 'Las inscripciones aún no están abiertas.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeadlinePassedMessage() {
    return Card(
      elevation: 0,
      color: Colors.red.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.timer_off, color: Colors.red.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'El plazo de inscripción ha finalizado.',
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiInscripcionCard extends StatelessWidget {
  final Map<String, dynamic> inscripcion;
  final Map<String, dynamic> edicion;
  final FirestoreService fs;
  final VoidCallback onUpdated;
  const _MiInscripcionCard({
    required this.inscripcion,
    required this.edicion,
    required this.fs,
    required this.onUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final asistentes = List<Map<String, dynamic>>.from(
        (inscripcion['asistentes'] as List<dynamic>?) ?? []);
    final estado = inscripcion['estado'] ?? 'pendiente';
    final estadoPago = inscripcion['payment_status'] ?? 'pendiente';
    final totalPagar = _calcTotal(asistentes);
    final isAbierto = edicion['estado'] == 'abierto';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: estado == 'confirmada'
              ? AppTheme.accentColor
              : Colors.orange.shade300,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.confirmation_number,
                    color: AppTheme.primaryColor),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Mi inscripción',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                _EstadoChip(estado: estado),
              ],
            ),
            const Divider(height: 24),
            // Payment status
            Row(
              children: [
                Icon(
                  estadoPago == 'pagado' ? Icons.check_circle : Icons.payment,
                  size: 18,
                  color: estadoPago == 'pagado'
                      ? AppTheme.accentColor
                      : estadoPago == 'exento'
                          ? Colors.blue
                          : Colors.orange.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  'Pago: ${_paymentLabel(estadoPago)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: estadoPago == 'pagado'
                        ? AppTheme.accentColor
                        : estadoPago == 'exento'
                            ? Colors.blue
                            : Colors.orange.shade700,
                  ),
                ),
                const Spacer(),
                Text(
                  '${totalPagar.toStringAsFixed(2)} €',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Asistentes
            const Text('Asistentes:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            ...asistentes.asMap().entries.map((entry) {
              final a = entry.value;
              final tipo = a['tipo'] ?? 'hermano';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      tipo == 'hermano'
                          ? Icons.person
                          : tipo == 'protocolo'
                              ? Icons.stars
                              : Icons.person_outline,
                      size: 18,
                      color: tipo == 'hermano'
                          ? AppTheme.accentColor
                          : tipo == 'protocolo'
                              ? Colors.purple
                              : AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${a['nombre'] ?? ''} ${a['apellidos'] ?? ''}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    Text(
                      _tipoLabel(tipo),
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(a['precio_aplicado'] as num? ?? 0).toStringAsFixed(2)} €',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
              );
            }),
            const Divider(height: 24),
            // Summary
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    '${asistentes.length} asistente${asistentes.length != 1 ? 's' : ''}',
                    style: const TextStyle(color: AppTheme.textSecondary)),
                Text('Total: ${totalPagar.toStringAsFixed(2)} €',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.primaryColor)),
              ],
            ),
            if (isAbierto && estado != 'cancelada') ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final result = await context.push<bool>(
                          '/festividad/inscripcion?edicionId=${edicion['id']}&inscripcionId=${inscripcion['id']}');
                      if (result == true) onUpdated();
                    },
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Editar'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _confirmarCancelacion(context),
                    icon: Icon(Icons.cancel,
                        size: 18, color: Colors.red.shade600),
                    label: Text('Cancelar',
                        style: TextStyle(color: Colors.red.shade600)),
                    style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.red.shade300)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  double _calcTotal(List<Map<String, dynamic>> asistentes) {
    double total = 0;
    for (final a in asistentes) {
      total += (a['precio_aplicado'] as num? ?? 0).toDouble();
    }
    return total;
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

  String _paymentLabel(String status) {
    switch (status) {
      case 'pagado':
        return 'Pagado';
      case 'exento':
        return 'Exento';
      default:
        return 'Pendiente de pago';
    }
  }

  void _confirmarCancelacion(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar inscripción'),
        content: const Text(
            '¿Estás seguro de que quieres cancelar tu inscripción? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('No, mantener')),
          ElevatedButton(
            onPressed: () async {
              await fs.updateFestividadInscripcion(
                  edicion['id'], inscripcion['id'], {'estado': 'cancelada'});
              if (ctx.mounted) Navigator.pop(ctx);
              onUpdated();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
  }
}

class _EstadoChip extends StatelessWidget {
  final String estado;
  const _EstadoChip({required this.estado});

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
      case 'borrador':
        color = Colors.blue;
        label = 'Borrador';
        break;
      case 'pendiente':
        color = Colors.orange;
        label = 'Pendiente';
        break;
      case 'confirmada':
        color = AppTheme.accentColor;
        label = 'Confirmada';
        break;
      case 'cancelada':
        color = Colors.red;
        label = 'Cancelada';
        break;
      default:
        color = Colors.grey;
        label = estado;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          SizedBox(
              width: 80,
              child: Text(label,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class _PriceChip extends StatelessWidget {
  final String label;
  final double price;
  final Color color;
  const _PriceChip(
      {required this.label, required this.price, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13, color: color, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text('${price.toStringAsFixed(2)} €',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
