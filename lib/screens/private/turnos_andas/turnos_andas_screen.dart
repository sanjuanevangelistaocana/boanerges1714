import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/models/turno_andas.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/services/turnos_andas_service.dart';

class TurnosAndasScreen extends StatelessWidget {
  const TurnosAndasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Header(),
        Expanded(child: _Body()),
      ],
    );
  }
}

class _Header extends StatelessWidget {
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
          constraints: const BoxConstraints(maxWidth: 1050),
          child: const Row(
            children: [
              Icon(Icons.fitness_center, color: Colors.white, size: 30),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Turnos de Andas',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
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

class _Body extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final cofrade = auth.cofrade;
    final service = context.read<TurnosAndasService>();
    if (cofrade == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return StreamBuilder<TurnoAndasEvento?>(
      stream: service.watchEventoActivo(),
      builder: (context, eventoSnap) {
        if (eventoSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final evento = eventoSnap.data;
        if (evento == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.fitness_center, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text(
                  'No hay campañas de turnos de andas activas.',
                  style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                ),
              ],
            ),
          );
        }
        return StreamBuilder<InscripcionTurno?>(
          stream: service.watchMiInscripcion(evento.id, cofrade.id),
          builder: (context, inscSnap) {
            final inscripcion = inscSnap.data;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _EventoCard(evento: evento),
                      const SizedBox(height: 20),
                      if (inscripcion == null && evento.acceptsInscriptions)
                        _InscripcionFlow(
                          evento: evento,
                          cofradeId: cofrade.id,
                          cofradeNombre: cofrade.nombre,
                          cofradeApellidos: cofrade.apellidos,
                          service: service,
                        )
                      else if (inscripcion == null && !evento.acceptsInscriptions)
                        _InfoCard(
                          icon: Icons.lock_clock,
                          color: Colors.orange.shade700,
                          title: 'Inscripción cerrada',
                          body: 'El plazo para solicitar portar ha finalizado.',
                        )
                      else if (inscripcion != null) ...[
                        _MiInscripcionCard(
                          inscripcion: inscripcion,
                          eventoAbierto: evento.acceptsInscriptions,
                        ),
                        if ((evento.isPublished || evento.mostrarAndaVisualACofrades) &&
                            inscripcion.asignacion != null)
                          _MiAsignacionCard(
                            inscripcion: inscripcion,
                            evento: evento,
                            service: service,
                          ),
                        if (!evento.isPublished &&
                            evento.mostrarAndaVisualACofrades &&
                            inscripcion.asignacion == null)
                          _InfoCard(
                            icon: Icons.visibility,
                            color: AppTheme.primaryColor,
                            title: 'Distribución provisional',
                            body: 'La distribución de turnos está visible como borrador organizativo. Aún no ha sido publicada oficialmente.',
                          ),
                      ],
                      // Show anda visual for cofrades when admin enabled it or when published
                      if (inscripcion != null &&
                          (evento.isPublished || evento.mostrarAndaVisualACofrades))
                        _CofradeAndaVisual(evento: evento, service: service),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
//  Evento card
// ---------------------------------------------------------------------------

class _EventoCard extends StatelessWidget {
  final TurnoAndasEvento evento;
  const _EventoCard({required this.evento});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.fitness_center, color: AppTheme.primaryColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    evento.titulo,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                _StatusBadge(estado: evento.estado),
              ],
            ),
            if (evento.descripcion.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(evento.descripcion,
                  style: const TextStyle(color: AppTheme.textSecondary)),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                if (evento.fechaProcesion != null)
                  _IconInfo(Icons.calendar_today, _fmtDate(evento.fechaProcesion!)),
                if (evento.deadlineInscripcion != null && evento.isOpen)
                  _IconInfo(
                    Icons.timer_outlined,
                    'Límite: ${_fmtDate(evento.deadlineInscripcion!)}',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Inscripción flow (3 steps)
// ---------------------------------------------------------------------------

class _InscripcionFlow extends StatefulWidget {
  final TurnoAndasEvento evento;
  final String cofradeId;
  final String cofradeNombre;
  final String cofradeApellidos;
  final TurnosAndasService service;

  const _InscripcionFlow({
    required this.evento,
    required this.cofradeId,
    required this.cofradeNombre,
    required this.cofradeApellidos,
    required this.service,
  });

  @override
  State<_InscripcionFlow> createState() => _InscripcionFlowState();
}

class _InscripcionFlowState extends State<_InscripcionFlow> {
  int _step = 0;
  bool _loading = true;
  bool _saving = false;

  // Step 1 — estatura
  int? _estaturaPerfilCm;
  int? _estaturaConfirmadaCm;
  bool _estaturaCorrecta = true;
  final _estaturaCtrl = TextEditingController();

  // Step 2 — portador
  bool _esPortador = false;
  bool _quierePortar = true;

  // Step 3 — disponibilidad
  bool _primerTurno = true;
  bool _segundoTurno = true;
  bool _sustituciones = false;
  bool _reserva = false;
  String _preferenciaLateral = '';
  final _restriccionesCtrl = TextEditingController();
  final _observacionesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final estatura = await widget.service.getEstaturaCofrade(widget.cofradeId);
    final portador = await widget.service.esPortador(widget.cofradeId);
    if (mounted) {
      setState(() {
        _estaturaPerfilCm = estatura;
        _estaturaConfirmadaCm = estatura;
        _esPortador = portador;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _estaturaCtrl.dispose();
    _restriccionesCtrl.dispose();
    _observacionesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      // Update estatura if changed
      if (!_estaturaCorrecta && _estaturaConfirmadaCm != null) {
        await widget.service.actualizarEstaturaCofrade(
            widget.cofradeId, _estaturaConfirmadaCm!);
      }

      final inscripcion = InscripcionTurno(
        id: widget.cofradeId,
        cofradeId: widget.cofradeId,
        nombre: widget.cofradeNombre,
        apellidos: widget.cofradeApellidos,
        estaturaPerfilCm: _estaturaPerfilCm,
        estaturaConfirmadaCm: _estaturaConfirmadaCm,
        estaturaActualizada: !_estaturaCorrecta,
        portadorPerfil: _esPortador,
        quierePortarEsteAnio: _quierePortar,
        requiereRevisionPortador: !_esPortador && _quierePortar,
        disponibilidad: DisponibilidadTurno(
          primerTurno: _primerTurno,
          segundoTurno: _segundoTurno,
          sustituciones: _sustituciones,
          reserva: _reserva,
        ),
        restricciones: _restriccionesCtrl.text.trim(),
        observaciones: _observacionesCtrl.text.trim(),
        preferenciaLateral: _preferenciaLateral,
      );

      await widget.service.inscribirse(widget.evento.id, inscripcion);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud enviada correctamente')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $error'.replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppTheme.accentColor.withAlpha(80)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.edit_note, color: AppTheme.accentColor),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Solicitar portar',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  'Paso ${_step + 1} de 3',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: (_step + 1) / 3,
              backgroundColor: Colors.grey.shade200,
              color: AppTheme.accentColor,
            ),
            const SizedBox(height: 20),
            if (_step == 0) _buildStep1(),
            if (_step == 1) _buildStep2(),
            if (_step == 2) _buildStep3(),
          ],
        ),
      ),
    );
  }

  // Step 1 — Estatura
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Validación de estatura',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        if (_estaturaPerfilCm != null)
          Text(
            'Tenemos registrado que mides $_estaturaPerfilCm cm. ¿Es correcto?',
            style: const TextStyle(fontSize: 15),
          )
        else
          const Text(
            'No tenemos registrada tu estatura. Por favor, indícala:',
            style: TextStyle(fontSize: 15),
          ),
        const SizedBox(height: 16),
        if (_estaturaPerfilCm != null && _estaturaCorrecta) ...[
          Wrap(
            spacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: () => setState(() {
                  _estaturaCorrecta = true;
                  _step = 1;
                }),
                icon: const Icon(Icons.check),
                label: const Text('Sí, es correcto'),
              ),
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  _estaturaCorrecta = false;
                  _estaturaCtrl.text = '$_estaturaPerfilCm';
                }),
                icon: const Icon(Icons.edit),
                label: const Text('Actualizar estatura'),
              ),
            ],
          ),
        ],
        if (!_estaturaCorrecta || _estaturaPerfilCm == null) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: 200,
            child: TextField(
              controller: _estaturaCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Estatura (cm)',
                hintText: 'Ej: 178',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                final parsed = int.tryParse(value);
                if (parsed != null && parsed > 100 && parsed < 250) {
                  _estaturaConfirmadaCm = parsed;
                }
              },
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              if (_estaturaConfirmadaCm == null || _estaturaConfirmadaCm! < 100) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Indica una estatura válida (100-250 cm)')),
                );
                return;
              }
              setState(() => _step = 1);
            },
            child: const Text('Continuar'),
          ),
        ],
      ],
    );
  }

  // Step 2 — Portador
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Validación de portador',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Text(
          _esPortador
              ? 'Tenemos registrado que puedes portar. ¿Quieres solicitar portar este año?'
              : 'No figuras actualmente como portador. ¿Quieres solicitar portar este año?',
          style: const TextStyle(fontSize: 15),
        ),
        if (!_esPortador)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tu solicitud requerirá revisión administrativa.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          children: [
            ElevatedButton.icon(
              onPressed: () => setState(() {
                _quierePortar = true;
                _step = 2;
              }),
              icon: const Icon(Icons.check),
              label: const Text('Sí, quiero portar'),
            ),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).maybePop();
              },
              child: const Text('No, este año no'),
            ),
            TextButton(
              onPressed: () => setState(() => _step = 0),
              child: const Text('Volver'),
            ),
          ],
        ),
      ],
    );
  }

  // Step 3 — Disponibilidad
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Disponibilidad y preferencias',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        const Text('¿En qué turnos puedes portar?',
            style: TextStyle(fontSize: 15)),
        const SizedBox(height: 8),
        CheckboxListTile(
          title: const Text('Primer turno'),
          value: _primerTurno,
          onChanged: (value) => setState(() => _primerTurno = value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        CheckboxListTile(
          title: const Text('Segundo turno'),
          value: _segundoTurno,
          onChanged: (value) => setState(() => _segundoTurno = value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        CheckboxListTile(
          title: const Text('Disponible para sustituciones'),
          value: _sustituciones,
          onChanged: (value) => setState(() => _sustituciones = value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        CheckboxListTile(
          title: const Text('Disponible como reserva'),
          value: _reserva,
          onChanged: (value) => setState(() => _reserva = value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 12),
        const Text('Preferencia lateral', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _preferenciaLateral.isEmpty ? null : _preferenciaLateral,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Sin preferencia',
          ),
          items: const [
            DropdownMenuItem(value: '', child: Text('Sin preferencia')),
            DropdownMenuItem(value: 'izquierda', child: Text('Izquierda')),
            DropdownMenuItem(value: 'derecha', child: Text('Derecha')),
            DropdownMenuItem(value: 'indiferente', child: Text('Indiferente')),
          ],
          onChanged: (value) => setState(() => _preferenciaLateral = value ?? ''),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _restriccionesCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Restricciones físicas',
            hintText: 'Lesiones, limitaciones...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _observacionesCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Observaciones',
            hintText: 'Comentarios adicionales...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            TextButton(
              onPressed: () => setState(() => _step = 1),
              child: const Text('Volver'),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send),
              label: const Text('Enviar solicitud'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
//  Mi inscripción card
// ---------------------------------------------------------------------------

class _MiInscripcionCard extends StatelessWidget {
  final InscripcionTurno inscripcion;
  final bool eventoAbierto;
  const _MiInscripcionCard({required this.inscripcion, this.eventoAbierto = false});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: _estadoColor(inscripcion.estado).withAlpha(80)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment_turned_in, color: _estadoColor(inscripcion.estado)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Tu solicitud',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                _StatusBadge(estado: inscripcion.estado),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 20,
              runSpacing: 10,
              children: [
                _IconInfo(Icons.height, '${inscripcion.estaturaCm} cm'),
                if (inscripcion.disponibilidad.primerTurno)
                  const _IconInfo(Icons.looks_one, 'Turno 1'),
                if (inscripcion.disponibilidad.segundoTurno)
                  const _IconInfo(Icons.looks_two, 'Turno 2'),
                if (inscripcion.disponibilidad.sustituciones)
                  const _IconInfo(Icons.swap_horiz, 'Sustitución'),
                if (inscripcion.disponibilidad.reserva)
                  const _IconInfo(Icons.schedule, 'Reserva'),
                if (inscripcion.preferenciaLateral.isNotEmpty)
                  _IconInfo(Icons.compare_arrows, 'Lateral: ${inscripcion.preferenciaLateral}'),
              ],
            ),
            if (inscripcion.requiereRevisionPortador)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.pending_actions, color: Colors.amber, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text('Pendiente de revisión administrativa (no figurabas como portador)',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ),
            if (inscripcion.restricciones.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Restricciones: ${inscripcion.restricciones}',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            ],
            if (inscripcion.observaciones.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Observaciones: ${inscripcion.observaciones}',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            ],
            if (eventoAbierto && inscripcion.estado == 'solicitado') ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final service = context.read<TurnosAndasService>();
                    final auth = context.read<AuthService>();
                    final cofrade = auth.cofrade;
                    if (cofrade == null) return;
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Actualizar solicitud'),
                        content: const Text(
                            '¿Quieres eliminar tu solicitud actual y volver a inscribirte? Podrás modificar tus datos.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancelar')),
                          ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Sí, actualizar')),
                        ],
                      ),
                    );
                    if (confirm == true && context.mounted) {
                      // Delete current inscription so the flow re-shows
                      try {
                        final eventoSnap = await FirebaseFirestore.instance
                            .collection('turnos_andas')
                            .where('estado', whereIn: ['abierto'])
                            .limit(1)
                            .get();
                        if (eventoSnap.docs.isNotEmpty) {
                          await FirebaseFirestore.instance
                              .collection('turnos_andas')
                              .doc(eventoSnap.docs.first.id)
                              .collection('inscripciones')
                              .doc(cofrade.id)
                              .delete();
                        }
                      } catch (e) {
                        debugPrint('Error deleting inscription for update: $e');
                      }
                    }
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Actualizar solicitud'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Mi asignación card (visible when published)
// ---------------------------------------------------------------------------

class _MiAsignacionCard extends StatelessWidget {
  final InscripcionTurno inscripcion;
  final TurnoAndasEvento evento;
  final TurnosAndasService service;

  const _MiAsignacionCard({
    required this.inscripcion,
    required this.evento,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    final asig = inscripcion.asignacion!;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        elevation: 0,
        color: AppTheme.accentColor.withAlpha(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppTheme.accentColor.withAlpha(60)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.emoji_events, color: AppTheme.accentColor),
                  SizedBox(width: 8),
                  Text(
                    'Tu asignación',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentColor),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _BigKpi(
                    label: 'Turno',
                    value: '${asig.turno}',
                    icon: asig.turno == 1 ? Icons.looks_one : Icons.looks_two,
                  ),
                  const SizedBox(width: 16),
                  _BigKpi(
                    label: 'Posición',
                    value: '${asig.posicion}',
                    icon: Icons.pin_drop,
                  ),
                  const SizedBox(width: 16),
                  _BigKpi(
                    label: 'Tipo',
                    value: _tipoLabel(asig.tipo),
                    icon: Icons.badge,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<Sustitucion>>(
                stream: service.watchSustituciones(evento.id),
                builder: (context, sustSnap) {
                  final sustituciones = (sustSnap.data ?? [])
                      .where((s) =>
                          s.saleCofradeId == inscripcion.cofradeId ||
                          s.entraCofradeId == inscripcion.cofradeId)
                      .toList();
                  if (sustituciones.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Sustituciones',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 6),
                      ...sustituciones.map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                const Icon(Icons.swap_horiz,
                                    color: AppTheme.primaryColor, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    s.saleCofradeId == inscripcion.cofradeId
                                        ? 'Sales → entra ${s.entraNombre}'
                                        : 'Entras por ${s.saleNombre}',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                if (s.momento.isNotEmpty || s.ubicacion.isNotEmpty)
                                  Text(
                                    [s.momento, s.ubicacion]
                                        .where((t) => t.isNotEmpty)
                                        .join(' · '),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary),
                                  ),
                              ],
                            ),
                          )),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _tipoLabel(String tipo) {
    switch (tipo) {
      case 'titular':
        return 'Titular';
      case 'sustituto':
        return 'Sustituto';
      case 'reserva':
        return 'Reserva';
      default:
        return tipo;
    }
  }
}

// ---------------------------------------------------------------------------
//  Shared widgets
// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  final String estado;
  const _StatusBadge({required this.estado});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _estadoColor(estado).withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _estadoColor(estado).withAlpha(80)),
      ),
      child: Text(
        _estadoLabel(estado),
        style: TextStyle(
            color: _estadoColor(estado),
            fontWeight: FontWeight.w700,
            fontSize: 11),
      ),
    );
  }
}

class _IconInfo extends StatelessWidget {
  final IconData icon;
  final String text;
  const _IconInfo(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _InfoCard({required this.icon, required this.color, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withAlpha(60)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                  const SizedBox(height: 4),
                  Text(body, style: const TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BigKpi extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _BigKpi({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primaryColor, size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor)),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Helpers
// ---------------------------------------------------------------------------

String _estadoLabel(String estado) {
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
      return 'Solicitud enviada';
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

Color _estadoColor(String estado) {
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
    case 'en_revision':
    case 'propuesta_generada':
      return AppTheme.primaryColor;
    default:
      return AppTheme.textSecondary;
  }
}

String _fmtDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

// ---------------------------------------------------------------------------
//  Cofrade read-only anda visual (two-column layout)
// ---------------------------------------------------------------------------

class _CofradeAndaVisual extends StatelessWidget {
  final TurnoAndasEvento evento;
  final TurnosAndasService service;
  const _CofradeAndaVisual({required this.evento, required this.service});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.grid_view, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                evento.isPublished ? 'Distribución oficial' : 'Distribución provisional',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (!evento.isPublished)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                'Borrador organizativo — sujeto a cambios',
                style: TextStyle(fontSize: 12, color: Colors.orange.shade700, fontStyle: FontStyle.italic),
              ),
            ),
          const SizedBox(height: 12),
          StreamBuilder<List<Puesto>>(
            stream: service.watchPuestos(evento.id),
            builder: (context, pSnap) {
              final puestos = pSnap.data ?? [];
              if (puestos.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Aún no se ha generado la distribución.',
                        style: TextStyle(color: AppTheme.textSecondary)),
                  ),
                );
              }
              final turno1 = puestos.where((p) => p.turno == 1).toList()
                ..sort((a, b) => a.numero.compareTo(b.numero));
              final turno2 = puestos.where((p) => p.turno == 2).toList()
                ..sort((a, b) => a.numero.compareTo(b.numero));

              return LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth > 600) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _CofradesTurnoColumn(turno: 1, puestos: turno1, config: evento.turno1)),
                        const SizedBox(width: 16),
                        Expanded(child: _CofradesTurnoColumn(turno: 2, puestos: turno2, config: evento.turno2)),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      _CofradesTurnoColumn(turno: 1, puestos: turno1, config: evento.turno1),
                      const SizedBox(height: 16),
                      _CofradesTurnoColumn(turno: 2, puestos: turno2, config: evento.turno2),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CofradesTurnoColumn extends StatelessWidget {
  final int turno;
  final List<Puesto> puestos;
  final ConfiguracionTurno config;
  const _CofradesTurnoColumn({required this.turno, required this.puestos, required this.config});

  @override
  Widget build(BuildContext context) {
    final filled = puestos.where((p) => !p.isEmpty).toList();
    final mediaReal = filled.isEmpty
        ? 0.0
        : filled.fold<int>(0, (s, p) => s + p.estaturaCm) / filled.length;
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Turno $turno',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                const SizedBox(width: 10),
                Text('${filled.length}/${puestos.length} puestos',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const Spacer(),
                Text('Media: ${mediaReal.toStringAsFixed(1)} cm',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            ...puestos.map((p) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: p.isEmpty ? Colors.grey.shade50 : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: p.lateral
                          ? Colors.blue.shade200
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('${p.numero}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          p.isEmpty ? '—' : p.nombreCompleto,
                          style: TextStyle(
                            fontSize: 13,
                            color: p.isEmpty ? AppTheme.textSecondary : Colors.black87,
                          ),
                        ),
                      ),
                      if (!p.isEmpty)
                        Text('${p.estaturaCm} cm',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      if (p.lateral)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Icon(Icons.compare_arrows, size: 14, color: Colors.blue.shade400),
                        ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
