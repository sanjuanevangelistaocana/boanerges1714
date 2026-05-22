import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/models/turno_andas.dart';
import 'package:boanerges1714/services/turnos_andas_service.dart';

class TurnosAndasAdminScreen extends StatelessWidget {
  const TurnosAndasAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AdminHeader(),
        Expanded(child: _AdminBody()),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
//  Header
// ---------------------------------------------------------------------------

class _AdminHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryDark, AppTheme.primaryColor],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Row(
            children: [
              const Icon(Icons.fitness_center, color: Colors.white, size: 30),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Administración — Turnos de Andas',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                tooltip: 'Crear nuevo evento',
                onPressed: () => _showCrearEvento(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Body — lists events, or shows detail for selected event
// ---------------------------------------------------------------------------

class _AdminBody extends StatefulWidget {
  @override
  State<_AdminBody> createState() => _AdminBodyState();
}

class _AdminBodyState extends State<_AdminBody> {
  String? _selectedEventoId;

  @override
  Widget build(BuildContext context) {
    final service = context.read<TurnosAndasService>();
    return StreamBuilder<List<TurnoAndasEvento>>(
      stream: service.watchEventos(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final eventos = snap.data ?? [];
        if (eventos.isEmpty && _selectedEventoId == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.fitness_center, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text('No hay eventos de turnos de andas.',
                    style: TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _showCrearEvento(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Crear evento'),
                ),
              ],
            ),
          );
        }

        // If an event is selected, show the detail
        if (_selectedEventoId != null) {
          final evento = eventos.where((e) => e.id == _selectedEventoId).toList();
          if (evento.isEmpty) {
            _selectedEventoId = null;
            return const SizedBox.shrink();
          }
          return _EventoDetail(
            evento: evento.first,
            onBack: () => setState(() => _selectedEventoId = null),
          );
        }

        // List of events
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Eventos',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: eventos
                        .map((e) => _EventoListCard(
                              evento: e,
                              onTap: () => setState(() => _selectedEventoId = e.id),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
//  Event list card
// ---------------------------------------------------------------------------

class _EventoListCard extends StatelessWidget {
  final TurnoAndasEvento evento;
  final VoidCallback onTap;
  const _EventoListCard({required this.evento, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 340,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.fitness_center, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(evento.titulo,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _SmallBadge(estado: evento.estado),
                const SizedBox(height: 8),
                if (evento.fechaProcesion != null)
                  _SmallInfo(Icons.calendar_today,
                      'Procesión: ${_fmtDate(evento.fechaProcesion!)}'),
                _SmallInfo(Icons.person, 'Año: ${evento.anio}'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Event detail — dashboard, inscriptions, anda visual, config
// ---------------------------------------------------------------------------

class _EventoDetail extends StatefulWidget {
  final TurnoAndasEvento evento;
  final VoidCallback onBack;
  const _EventoDetail({required this.evento, required this.onBack});

  @override
  State<_EventoDetail> createState() => _EventoDetailState();
}

class _EventoDetailState extends State<_EventoDetail> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Back bar + tabs
        Container(
          color: Colors.white,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: widget.onBack,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(widget.evento.titulo,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    ),
                    _SmallBadge(estado: widget.evento.estado),
                    const SizedBox(width: 12),
                    _EstadoActions(evento: widget.evento),
                  ],
                ),
              ),
              TabBar(
                controller: _tabCtrl,
                labelColor: AppTheme.primaryColor,
                unselectedLabelColor: AppTheme.textSecondary,
                indicatorColor: AppTheme.primaryColor,
                tabs: const [
                  Tab(text: 'Dashboard', icon: Icon(Icons.dashboard, size: 18)),
                  Tab(text: 'Inscripciones', icon: Icon(Icons.people, size: 18)),
                  Tab(text: 'Anda Visual', icon: Icon(Icons.view_column, size: 18)),
                  Tab(text: 'Configuración', icon: Icon(Icons.settings, size: 18)),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _DashboardTab(evento: widget.evento),
              _InscripcionesTab(eventoId: widget.evento.id),
              _AndaVisualTab(evento: widget.evento),
              _ConfigTab(evento: widget.evento),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
//  Estado actions (change state buttons)
// ---------------------------------------------------------------------------

class _EstadoActions extends StatelessWidget {
  final TurnoAndasEvento evento;
  const _EstadoActions({required this.evento});

  @override
  Widget build(BuildContext context) {
    final service = context.read<TurnosAndasService>();
    return Wrap(
      spacing: 8,
      children: [
        if (evento.estado == 'borrador')
          _ActionButton(
            label: 'Abrir inscripciones',
            icon: Icons.play_arrow,
            color: AppTheme.accentColor,
            onPressed: () => service.cambiarEstado(evento.id, 'abierto'),
          ),
        if (evento.estado == 'abierto')
          _ActionButton(
            label: 'Cerrar inscripciones',
            icon: Icons.stop,
            color: Colors.orange,
            onPressed: () => service.cambiarEstado(evento.id, 'cerrado'),
          ),
        if (evento.estado == 'propuesta_generada' || evento.estado == 'en_revision')
          _ActionButton(
            label: 'Publicar',
            icon: Icons.publish,
            color: AppTheme.accentColor,
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Publicar turnos'),
                  content: const Text(
                      'Los cofrades podrán ver su asignación. ¿Continuar?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                    ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Publicar')),
                  ],
                ),
              );
              if (confirm == true) {
                service.cambiarEstado(evento.id, 'publicado');
              }
            },
          ),
        if (evento.estado != 'archivado')
          _ActionButton(
            label: 'Archivar',
            icon: Icons.archive,
            color: AppTheme.textSecondary,
            onPressed: () => service.cambiarEstado(evento.id, 'archivado'),
          ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(color: color, fontSize: 12)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: color.withAlpha(60)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Dashboard tab
// ---------------------------------------------------------------------------

class _DashboardTab extends StatelessWidget {
  final TurnoAndasEvento evento;
  const _DashboardTab({required this.evento});

  @override
  Widget build(BuildContext context) {
    final service = context.read<TurnosAndasService>();
    return StreamBuilder<List<InscripcionTurno>>(
      stream: service.watchInscripciones(evento.id),
      builder: (context, snap) {
        final inscripciones = snap.data ?? [];
        final total = inscripciones.length;
        final portadores = inscripciones.where((i) => i.quierePortarEsteAnio).length;
        final revisionRequerida = inscripciones.where((i) => i.requiereRevisionPortador).length;
        final asignados = inscripciones.where((i) => i.estado == 'asignado').length;
        final reservas = inscripciones.where((i) => i.estado == 'reserva').length;
        final alturas = inscripciones
            .where((i) => i.estaturaCm > 0)
            .map((i) => i.estaturaCm)
            .toList();
        final mediaAltura = alturas.isEmpty
            ? 0.0
            : alturas.fold<int>(0, (s, h) => s + h) / alturas.length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KPI cards
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _KpiCard(
                        label: 'Total inscritos',
                        value: '$total',
                        icon: Icons.people,
                        color: AppTheme.primaryColor,
                      ),
                      _KpiCard(
                        label: 'Quieren portar',
                        value: '$portadores',
                        icon: Icons.fitness_center,
                        color: AppTheme.accentColor,
                      ),
                      _KpiCard(
                        label: 'Revisión portador',
                        value: '$revisionRequerida',
                        icon: Icons.pending_actions,
                        color: Colors.amber.shade700,
                      ),
                      _KpiCard(
                        label: 'Asignados',
                        value: '$asignados',
                        icon: Icons.check_circle,
                        color: Colors.green,
                      ),
                      _KpiCard(
                        label: 'Reservas',
                        value: '$reservas',
                        icon: Icons.schedule,
                        color: Colors.blue,
                      ),
                      _KpiCard(
                        label: 'Media altura',
                        value: '${mediaAltura.toStringAsFixed(1)} cm',
                        icon: Icons.height,
                        color: AppTheme.primaryColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Generar distribución
                  if (evento.estado == 'cerrado' ||
                      evento.estado == 'propuesta_generada' ||
                      evento.estado == 'en_revision')
                    _GenerarDistribucionButton(eventoId: evento.id),

                  const SizedBox(height: 28),

                  // Alerts
                  StreamBuilder<List<Puesto>>(
                    stream: service.watchPuestos(evento.id),
                    builder: (context, pSnap) {
                      final puestos = pSnap.data ?? [];
                      final alertas = _computeAlerts(puestos, inscripciones, evento);
                      if (alertas.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Alertas',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          ...alertas.map((a) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _AlertChip(text: a),
                              )),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  // Height distribution chart (text-based)
                  if (alturas.isNotEmpty) ...[
                    const Text('Distribución de alturas',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _HeightDistribution(inscripciones: inscripciones.where((i) => i.estaturaCm > 0).toList()),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<String> _computeAlerts(
      List<Puesto> puestos, List<InscripcionTurno> inscripciones, TurnoAndasEvento evento) {
    final alertas = <String>[];
    final t1 = puestos.where((p) => p.turno == 1).toList();
    final t2 = puestos.where((p) => p.turno == 2).toList();
    final empty1 = t1.where((p) => p.isEmpty).length;
    final empty2 = t2.where((p) => p.isEmpty).length;
    if (empty1 > 0) alertas.add('Turno 1: $empty1 puestos vacíos');
    if (empty2 > 0) alertas.add('Turno 2: $empty2 puestos vacíos');

    final reservas = inscripciones.where((i) => i.estado == 'reserva').length;
    if (reservas == 0 && puestos.isNotEmpty) alertas.add('No hay reservas disponibles');

    // Height variance within each turn
    for (final turn in [t1, t2]) {
      final filled = turn.where((p) => !p.isEmpty && p.estaturaCm > 0).toList();
      if (filled.length >= 2) {
        filled.sort((a, b) => a.estaturaCm.compareTo(b.estaturaCm));
        final diff = filled.last.estaturaCm - filled.first.estaturaCm;
        final turnoLabel = turn == t1 ? 'Turno 1' : 'Turno 2';
        if (diff > 15) alertas.add('$turnoLabel: diferencia de altura excesiva (${diff}cm)');
      }
    }
    return alertas;
  }
}

// ---------------------------------------------------------------------------
//  Generar distribución button
// ---------------------------------------------------------------------------

class _GenerarDistribucionButton extends StatefulWidget {
  final String eventoId;
  const _GenerarDistribucionButton({required this.eventoId});

  @override
  State<_GenerarDistribucionButton> createState() => _GenerarDistribucionButtonState();
}

class _GenerarDistribucionButtonState extends State<_GenerarDistribucionButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final service = context.read<TurnosAndasService>();
    return Card(
      elevation: 0,
      color: AppTheme.accentColor.withAlpha(10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppTheme.accentColor.withAlpha(40)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_awesome, color: AppTheme.accentColor),
                SizedBox(width: 8),
                Text('Motor de asignación automática',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Genera una propuesta automática de distribución. Respeta posiciones bloqueadas.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loading
                  ? null
                  : () async {
                      setState(() => _loading = true);
                      try {
                        final result = await service.generarDistribucion(widget.eventoId);
                        if (mounted) {
                          _showResultDialog(context, result);
                        }
                      } catch (error) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $error')),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _loading = false);
                      }
                    },
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome),
              label: const Text('Generar distribución automática'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _loading ? null : () async {
                setState(() => _loading = true);
                try {
                  final result = await service.generarDistribucion(widget.eventoId);
                  if (mounted) _showResultDialog(context, result);
                } catch (error) {
                  if (mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('Error: $error')));
                  }
                } finally {
                  if (mounted) setState(() => _loading = false);
                }
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Recalcular huecos libres'),
            ),
          ],
        ),
      ),
    );
  }

  void _showResultDialog(BuildContext context, AsignacionResult result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Distribución generada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Turno 1: ${result.turno1Count} asignados (media: ${result.mediaTurno1.toStringAsFixed(1)} cm)'),
            Text('Turno 2: ${result.turno2Count} asignados (media: ${result.mediaTurno2.toStringAsFixed(1)} cm)'),
            Text('Reservas: ${result.reservaCount}'),
            if (result.alertas.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Alertas:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...result.alertas.map((a) => Text('⚠ $a', style: TextStyle(color: Colors.orange.shade700))),
            ],
          ],
        ),
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Aceptar')),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Inscripciones tab
// ---------------------------------------------------------------------------

class _InscripcionesTab extends StatelessWidget {
  final String eventoId;
  const _InscripcionesTab({required this.eventoId});

  @override
  Widget build(BuildContext context) {
    final service = context.read<TurnosAndasService>();
    return StreamBuilder<List<InscripcionTurno>>(
      stream: service.watchInscripciones(eventoId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final inscripciones = snap.data ?? [];
        if (inscripciones.isEmpty) {
          return const Center(
            child: Text('No hay inscripciones todavía.',
                style: TextStyle(color: AppTheme.textSecondary)),
          );
        }
        inscripciones.sort((a, b) => a.estaturaCm.compareTo(b.estaturaCm));
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${inscripciones.length} inscripciones',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 16),
                  ...inscripciones.map((insc) => _InscripcionTile(
                        inscripcion: insc,
                        eventoId: eventoId,
                      )),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _InscripcionTile extends StatelessWidget {
  final InscripcionTurno inscripcion;
  final String eventoId;
  const _InscripcionTile({required this.inscripcion, required this.eventoId});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primaryColor.withAlpha(20),
              child: Text(
                '${inscripcion.estaturaCm}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(inscripcion.nombreCompleto,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    '${inscripcion.estaturaCm} cm · ${_dispLabel(inscripcion.disponibilidad)}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            if (inscripcion.requiereRevisionPortador)
              Tooltip(
                message: 'Requiere revisión de portador',
                child: Icon(Icons.pending_actions, color: Colors.amber.shade700, size: 20),
              ),
            const SizedBox(width: 8),
            _SmallBadge(estado: inscripcion.estado),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'asignado', child: Text('Marcar asignado')),
                const PopupMenuItem(value: 'reserva', child: Text('Marcar reserva')),
                const PopupMenuItem(value: 'descartado', child: Text('Descartar')),
              ],
              onSelected: (value) {
                context.read<TurnosAndasService>().actualizarInscripcion(
                  eventoId,
                  inscripcion.cofradeId,
                  {'estado': value},
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _dispLabel(DisponibilidadTurno d) {
    final parts = <String>[];
    if (d.primerTurno) parts.add('T1');
    if (d.segundoTurno) parts.add('T2');
    if (d.sustituciones) parts.add('Sust.');
    if (d.reserva) parts.add('Res.');
    return parts.isEmpty ? 'Sin preferencia' : parts.join(', ');
  }
}

// ---------------------------------------------------------------------------
//  Anda Visual tab — two-column layout with drag & drop
// ---------------------------------------------------------------------------

class _AndaVisualTab extends StatelessWidget {
  final TurnoAndasEvento evento;
  const _AndaVisualTab({required this.evento});

  @override
  Widget build(BuildContext context) {
    final service = context.read<TurnosAndasService>();
    return StreamBuilder<List<Puesto>>(
      stream: service.watchPuestos(evento.id),
      builder: (context, pSnap) {
        if (pSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final puestos = pSnap.data ?? [];
        if (puestos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.view_column, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text(
                  'No hay distribución generada.\nGenera una propuesta automática desde el Dashboard.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          );
        }

        final turno1 = puestos.where((p) => p.turno == 1).toList()
          ..sort((a, b) => a.numero.compareTo(b.numero));
        final turno2 = puestos.where((p) => p.turno == 2).toList()
          ..sort((a, b) => a.numero.compareTo(b.numero));

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                children: [
                  // Sustituciones section
                  StreamBuilder<List<Sustitucion>>(
                    stream: service.watchSustituciones(evento.id),
                    builder: (context, sustSnap) {
                      final sustituciones = sustSnap.data ?? [];
                      return _SustitucionesPanel(
                        sustituciones: sustituciones,
                        eventoId: evento.id,
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  // Two-column anda
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 800;
                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _TurnoColumn(
                              turnoLabel: 'Turno 1',
                              puestos: turno1,
                              eventoId: evento.id,
                              config: evento.turno1,
                            )),
                            const SizedBox(width: 24),
                            Expanded(child: _TurnoColumn(
                              turnoLabel: 'Turno 2',
                              puestos: turno2,
                              eventoId: evento.id,
                              config: evento.turno2,
                            )),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          _TurnoColumn(
                            turnoLabel: 'Turno 1',
                            puestos: turno1,
                            eventoId: evento.id,
                            config: evento.turno1,
                          ),
                          const SizedBox(height: 24),
                          _TurnoColumn(
                            turnoLabel: 'Turno 2',
                            puestos: turno2,
                            eventoId: evento.id,
                            config: evento.turno2,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
//  Turno column
// ---------------------------------------------------------------------------

class _TurnoColumn extends StatelessWidget {
  final String turnoLabel;
  final List<Puesto> puestos;
  final String eventoId;
  final ConfiguracionTurno config;

  const _TurnoColumn({
    required this.turnoLabel,
    required this.puestos,
    required this.eventoId,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final filled = puestos.where((p) => !p.isEmpty && p.estaturaCm > 0).toList();
    final media = filled.isEmpty
        ? 0.0
        : filled.fold<int>(0, (s, p) => s + p.estaturaCm) / filled.length;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppTheme.primaryColor.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withAlpha(10),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.view_column, color: AppTheme.primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(turnoLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                Text(
                  '${filled.length}/${config.numeroPuestos} · Media: ${media.toStringAsFixed(1)} cm',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          // Puesto cards
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: puestos.map((p) => _PuestoCard(
                    puesto: p,
                    eventoId: eventoId,
                  )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Puesto card with drag & drop
// ---------------------------------------------------------------------------

class _PuestoCard extends StatelessWidget {
  final Puesto puesto;
  final String eventoId;
  const _PuestoCard({required this.puesto, required this.eventoId});

  @override
  Widget build(BuildContext context) {
    final service = context.read<TurnosAndasService>();
    final cardContent = Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: puesto.isEmpty
            ? Colors.grey.shade50
            : puesto.locked
                ? Colors.amber.shade50
                : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: puesto.locked
              ? Colors.amber.shade300
              : puesto.isEmpty
                  ? Colors.grey.shade200
                  : AppTheme.primaryColor.withAlpha(30),
        ),
      ),
      child: Row(
        children: [
          // Position number
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: puesto.lateral
                  ? Colors.blue.shade50
                  : AppTheme.primaryColor.withAlpha(10),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              '${puesto.numero}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: puesto.lateral ? Colors.blue.shade700 : AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Name + height
          Expanded(
            child: puesto.isEmpty
                ? Text('— Vacío —',
                    style: TextStyle(
                        color: Colors.grey.shade400,
                        fontStyle: FontStyle.italic,
                        fontSize: 13))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(puesto.nombreCompleto,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('${puesto.estaturaCm} cm',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ),
          ),
          // Badges
          if (puesto.lateral)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Tooltip(
                message: 'Lateral',
                child: Icon(Icons.compare_arrows,
                    size: 16, color: Colors.blue.shade400),
              ),
            ),
          if (puesto.locked)
            Tooltip(
              message: 'Bloqueado manualmente',
              child: Icon(Icons.lock, size: 16, color: Colors.amber.shade700),
            ),
          // Actions menu
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, size: 18, color: Colors.grey.shade400),
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'lock',
                child: Text(puesto.locked ? 'Desbloquear' : 'Bloquear'),
              ),
              PopupMenuItem(
                value: 'lateral',
                child: Text(puesto.lateral ? 'Quitar lateral' : 'Marcar lateral'),
              ),
              if (!puesto.isEmpty)
                const PopupMenuItem(value: 'vaciar', child: Text('Vaciar puesto')),
            ],
            onSelected: (action) {
              switch (action) {
                case 'lock':
                  service.actualizarPuesto(
                      eventoId, puesto.id, {'locked': !puesto.locked});
                  break;
                case 'lateral':
                  service.actualizarPuesto(
                      eventoId, puesto.id, {'lateral': !puesto.lateral});
                  break;
                case 'vaciar':
                  service.actualizarPuesto(eventoId, puesto.id, {
                    'cofradeId': null,
                    'nombreCompleto': '',
                    'estaturaCm': 0,
                    'tipo': 'titular',
                  });
                  break;
              }
            },
          ),
        ],
      ),
    );

    // Wrap with Draggable + DragTarget for drag & drop
    return DragTarget<Puesto>(
      onWillAcceptWithDetails: (details) => !puesto.locked,
      onAcceptWithDetails: (details) {
        final draggedPuesto = details.data;
        service.intercambiarPuestos(eventoId, puesto, draggedPuesto);
      },
      builder: (context, candidateData, rejectedData) {
        final isOver = candidateData.isNotEmpty;
        return Draggable<Puesto>(
          data: puesto,
          feedback: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 260,
              child: cardContent,
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.3, child: cardContent),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: isOver
                  ? Border.all(color: AppTheme.accentColor, width: 2)
                  : null,
            ),
            child: cardContent,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
//  Sustituciones panel
// ---------------------------------------------------------------------------

class _SustitucionesPanel extends StatelessWidget {
  final List<Sustitucion> sustituciones;
  final String eventoId;
  const _SustitucionesPanel({required this.sustituciones, required this.eventoId});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.swap_horiz, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Sustituciones',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 20),
                  tooltip: 'Añadir sustitución',
                  onPressed: () => _addSustitucion(context),
                ),
              ],
            ),
            if (sustituciones.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No hay sustituciones definidas.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              )
            else
              ...sustituciones.asMap().entries.map((entry) {
                final s = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(Icons.swap_horiz, color: Colors.orange.shade700, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                            children: [
                              TextSpan(text: s.saleNombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                              const TextSpan(text: ' → '),
                              TextSpan(text: s.entraNombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                              if (s.momento.isNotEmpty || s.ubicacion.isNotEmpty)
                                TextSpan(
                                  text: ' (${[s.momento, s.ubicacion].where((t) => t.isNotEmpty).join(' · ')})',
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Chip(
                        label: Text('T${s.turno}', style: const TextStyle(fontSize: 11)),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  void _addSustitucion(BuildContext context) {
    final saleCtrl = TextEditingController();
    final entraCtrl = TextEditingController();
    final momentoCtrl = TextEditingController();
    final ubicacionCtrl = TextEditingController();
    int turno = 1;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: const Text('Añadir sustitución'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: saleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Sale (nombre)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: entraCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Entra (nombre)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: momentoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Momento',
                    hintText: 'Ej: Después de la segunda caída',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ubicacionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ubicación',
                    hintText: 'Ej: Plaza Gutierre de Cárdenas',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: turno,
                  decoration: const InputDecoration(
                    labelText: 'Turno',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Turno 1')),
                    DropdownMenuItem(value: 2, child: Text('Turno 2')),
                  ],
                  onChanged: (value) => setDState(() => turno = value ?? 1),
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
                if (saleCtrl.text.isEmpty || entraCtrl.text.isEmpty) return;
                final newSust = Sustitucion(
                  saleCofradeId: '',
                  saleNombre: saleCtrl.text.trim(),
                  entraCofradeId: '',
                  entraNombre: entraCtrl.text.trim(),
                  momento: momentoCtrl.text.trim(),
                  ubicacion: ubicacionCtrl.text.trim(),
                  turno: turno,
                );
                final service = context.read<TurnosAndasService>();
                final updated = [...sustituciones, newSust];
                service.guardarSustituciones(eventoId, updated);
                Navigator.pop(ctx);
              },
              child: const Text('Añadir'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Config tab
// ---------------------------------------------------------------------------

class _ConfigTab extends StatefulWidget {
  final TurnoAndasEvento evento;
  const _ConfigTab({required this.evento});

  @override
  State<_ConfigTab> createState() => _ConfigTabState();
}

class _ConfigTabState extends State<_ConfigTab> {
  late final TextEditingController _tituloCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _puestos1Ctrl;
  late final TextEditingController _puestos2Ctrl;
  late final TextEditingController _media1Ctrl;
  late final TextEditingController _media2Ctrl;
  late final TextEditingController _min1Ctrl;
  late final TextEditingController _max1Ctrl;
  late final TextEditingController _min2Ctrl;
  late final TextEditingController _max2Ctrl;
  late final TextEditingController _lat1Ctrl;
  late final TextEditingController _lat2Ctrl;
  DateTime? _fechaProcesion;
  DateTime? _deadlineInscripcion;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.evento;
    _tituloCtrl = TextEditingController(text: e.titulo);
    _descCtrl = TextEditingController(text: e.descripcion);
    _puestos1Ctrl = TextEditingController(text: '${e.turno1.numeroPuestos}');
    _puestos2Ctrl = TextEditingController(text: '${e.turno2.numeroPuestos}');
    _media1Ctrl = TextEditingController(text: '${e.turno1.mediaObjetivoCm}');
    _media2Ctrl = TextEditingController(text: '${e.turno2.mediaObjetivoCm}');
    _min1Ctrl = TextEditingController(text: '${e.turno1.alturaMinObjetivoCm}');
    _max1Ctrl = TextEditingController(text: '${e.turno1.alturaMaxObjetivoCm}');
    _min2Ctrl = TextEditingController(text: '${e.turno2.alturaMinObjetivoCm}');
    _max2Ctrl = TextEditingController(text: '${e.turno2.alturaMaxObjetivoCm}');
    _lat1Ctrl = TextEditingController(text: '${e.turno1.posicionesLaterales}');
    _lat2Ctrl = TextEditingController(text: '${e.turno2.posicionesLaterales}');
    _fechaProcesion = e.fechaProcesion;
    _deadlineInscripcion = e.deadlineInscripcion;
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descCtrl.dispose();
    _puestos1Ctrl.dispose();
    _puestos2Ctrl.dispose();
    _media1Ctrl.dispose();
    _media2Ctrl.dispose();
    _min1Ctrl.dispose();
    _max1Ctrl.dispose();
    _min2Ctrl.dispose();
    _max2Ctrl.dispose();
    _lat1Ctrl.dispose();
    _lat2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final service = context.read<TurnosAndasService>();
      await service.actualizarEvento(widget.evento.id, {
        'titulo': _tituloCtrl.text.trim(),
        'descripcion': _descCtrl.text.trim(),
        'fechaProcesion': _fechaProcesion != null
            ? _fechaProcesion
            : null,
        'deadlineInscripcion': _deadlineInscripcion != null
            ? _deadlineInscripcion
            : null,
        'configuracionTurnos': {
          'turno1': {
            'numeroPuestos': int.tryParse(_puestos1Ctrl.text) ?? 24,
            'mediaObjetivoCm': int.tryParse(_media1Ctrl.text) ?? 175,
            'alturaMinObjetivoCm': int.tryParse(_min1Ctrl.text) ?? 165,
            'alturaMaxObjetivoCm': int.tryParse(_max1Ctrl.text) ?? 195,
            'posicionesLaterales': int.tryParse(_lat1Ctrl.text) ?? 4,
          },
          'turno2': {
            'numeroPuestos': int.tryParse(_puestos2Ctrl.text) ?? 24,
            'mediaObjetivoCm': int.tryParse(_media2Ctrl.text) ?? 175,
            'alturaMinObjetivoCm': int.tryParse(_min2Ctrl.text) ?? 165,
            'alturaMaxObjetivoCm': int.tryParse(_max2Ctrl.text) ?? 195,
            'posicionesLaterales': int.tryParse(_lat2Ctrl.text) ?? 4,
          },
        },
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Configuración guardada')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al guardar: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Configuración del evento',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: _tituloCtrl,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                      label: 'Fecha de procesión',
                      date: _fechaProcesion,
                      onChanged: (d) => setState(() => _fechaProcesion = d),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DateField(
                      label: 'Fecha límite inscripción',
                      date: _deadlineInscripcion,
                      onChanged: (d) => setState(() => _deadlineInscripcion = d),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const Text('Configuración Turno 1',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _TurnoConfigFields(
                puestosCtrl: _puestos1Ctrl,
                mediaCtrl: _media1Ctrl,
                minCtrl: _min1Ctrl,
                maxCtrl: _max1Ctrl,
                latCtrl: _lat1Ctrl,
              ),
              const SizedBox(height: 28),
              const Text('Configuración Turno 2',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _TurnoConfigFields(
                puestosCtrl: _puestos2Ctrl,
                mediaCtrl: _media2Ctrl,
                minCtrl: _min2Ctrl,
                maxCtrl: _max2Ctrl,
                latCtrl: _lat2Ctrl,
              ),
              const SizedBox(height: 28),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save),
                  label: const Text('Guardar configuración'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TurnoConfigFields extends StatelessWidget {
  final TextEditingController puestosCtrl;
  final TextEditingController mediaCtrl;
  final TextEditingController minCtrl;
  final TextEditingController maxCtrl;
  final TextEditingController latCtrl;

  const _TurnoConfigFields({
    required this.puestosCtrl,
    required this.mediaCtrl,
    required this.minCtrl,
    required this.maxCtrl,
    required this.latCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: 140,
          child: TextField(
            controller: puestosCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Nº puestos',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        SizedBox(
          width: 140,
          child: TextField(
            controller: mediaCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Media obj. (cm)',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        SizedBox(
          width: 140,
          child: TextField(
            controller: minCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Alt. mín (cm)',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        SizedBox(
          width: 140,
          child: TextField(
            controller: maxCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Alt. máx (cm)',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        SizedBox(
          width: 140,
          child: TextField(
            controller: latCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Laterales',
              border: OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final ValueChanged<DateTime?> onChanged;

  const _DateField({required this.label, required this.date, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2040),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(
          date != null ? _fmtDate(date!) : 'Seleccionar fecha',
          style: TextStyle(
            color: date != null ? AppTheme.textPrimary : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Height distribution mini-chart
// ---------------------------------------------------------------------------

class _HeightDistribution extends StatelessWidget {
  final List<InscripcionTurno> inscripciones;
  const _HeightDistribution({required this.inscripciones});

  @override
  Widget build(BuildContext context) {
    // Group by 5cm ranges
    final Map<String, int> buckets = {};
    for (final insc in inscripciones) {
      final bucket = (insc.estaturaCm ~/ 5) * 5;
      final label = '$bucket-${bucket + 4}';
      buckets[label] = (buckets[label] ?? 0) + 1;
    }
    final maxVal = buckets.values.fold<int>(0, (a, b) => a > b ? a : b);

    final entries = buckets.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: entries.map((e) {
            final pct = maxVal > 0 ? e.value / maxVal : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                      width: 80,
                      child: Text('${e.key} cm',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        backgroundColor: Colors.grey.shade100,
                        color: AppTheme.primaryColor,
                        minHeight: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${e.value}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Shared widgets
// ---------------------------------------------------------------------------

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withAlpha(40)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(value,
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              Text(label,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  final String estado;
  const _SmallBadge({required this.estado});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _getColor(estado).withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getColor(estado).withAlpha(80)),
      ),
      child: Text(
        _getLabel(estado),
        style: TextStyle(
            color: _getColor(estado), fontWeight: FontWeight.w700, fontSize: 10),
      ),
    );
  }

  Color _getColor(String estado) {
    switch (estado) {
      case 'abierto':
      case 'solicitado':
        return Colors.orange.shade700;
      case 'asignado':
      case 'publicado':
        return AppTheme.accentColor;
      case 'reserva':
      case 'sustituto':
        return Colors.blue.shade700;
      case 'descartado':
      case 'archivado':
        return AppTheme.textSecondary;
      case 'cerrado':
      case 'en_revision':
      case 'propuesta_generada':
        return AppTheme.primaryColor;
      case 'borrador':
        return AppTheme.textSecondary;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _getLabel(String estado) {
    switch (estado) {
      case 'borrador':
        return 'Borrador';
      case 'abierto':
        return 'Abierto';
      case 'cerrado':
        return 'Cerrado';
      case 'propuesta_generada':
        return 'Propuesta generada';
      case 'en_revision':
        return 'En revisión';
      case 'publicado':
        return 'Publicado';
      case 'archivado':
        return 'Archivado';
      case 'solicitado':
        return 'Solicitado';
      case 'asignado':
        return 'Asignado';
      case 'reserva':
        return 'Reserva';
      case 'sustituto':
        return 'Sustitución';
      case 'descartado':
        return 'Descartado';
      default:
        return estado;
    }
  }
}

class _SmallInfo extends StatelessWidget {
  final IconData icon;
  final String text;
  const _SmallInfo(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _AlertChip extends StatelessWidget {
  final String text;
  const _AlertChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, size: 18, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: TextStyle(fontSize: 13, color: Colors.orange.shade900))),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Create event dialog
// ---------------------------------------------------------------------------

void _showCrearEvento(BuildContext context) {
  final tituloCtrl = TextEditingController(text: 'Turnos de Andas — Semana Santa ${DateTime.now().year}');
  final descCtrl = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Crear evento de Turnos de Andas'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tituloCtrl,
              decoration: const InputDecoration(
                labelText: 'Título',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descripción',
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
            if (tituloCtrl.text.trim().isEmpty) return;
            final service = context.read<TurnosAndasService>();
            final evento = TurnoAndasEvento(
              id: '',
              titulo: tituloCtrl.text.trim(),
              descripcion: descCtrl.text.trim(),
              anio: DateTime.now().year,
              turno1: const ConfiguracionTurno(),
              turno2: const ConfiguracionTurno(),
            );
            await service.crearEvento(evento);
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('Crear'),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
//  Helpers
// ---------------------------------------------------------------------------

String _fmtDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
