import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/models/solicitud.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/services/firestore_service.dart';

class ManageSolicitudesScreen extends StatelessWidget {
  const ManageSolicitudesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Solicitudes de Alta',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text(
              'Gestiona las solicitudes de nuevos cofrades.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            StreamBuilder<List<Solicitud>>(
              stream: firestoreService.getSolicitudes(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final solicitudes = snapshot.data ?? [];
                if (solicitudes.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text('No hay solicitudes.'),
                      ),
                    ),
                  );
                }

                final pendientes =
                    solicitudes.where((s) => s.isPendiente).toList();
                final resueltas =
                    solicitudes.where((s) => !s.isPendiente).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (pendientes.isNotEmpty) ...[
                      Text(
                        'Pendientes (${pendientes.length})',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.orange,
                            ),
                      ),
                      const SizedBox(height: 12),
                      ...pendientes
                          .map((s) => _SolicitudCard(solicitud: s)),
                      const SizedBox(height: 24),
                    ],
                    if (resueltas.isNotEmpty) ...[
                      Text(
                        'Resueltas (${resueltas.length})',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      ...resueltas
                          .map((s) => _SolicitudCard(solicitud: s)),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SolicitudCard extends StatelessWidget {
  final Solicitud solicitud;

  const _SolicitudCard({required this.solicitud});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'es');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    solicitud.nombreCompleto,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _EstadoChip(estado: solicitud.estado),
              ],
            ),
            const SizedBox(height: 12),
            _InfoLine(icon: Icons.email, text: solicitud.email),
            if (solicitud.telefono != null && solicitud.telefono!.isNotEmpty)
              _InfoLine(icon: Icons.phone, text: solicitud.telefono!),
            if (solicitud.dni != null && solicitud.dni!.isNotEmpty)
              _InfoLine(icon: Icons.badge, text: 'DNI: ${solicitud.dni}'),
            if (solicitud.localidad != null && solicitud.localidad!.isNotEmpty)
              _InfoLine(
                  icon: Icons.location_city, text: solicitud.localidad!),
            if (solicitud.motivacion != null &&
                solicitud.motivacion!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Motivación: ${solicitud.motivacion}',
                  style: const TextStyle(fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: 8),
            Text(
              'Solicitado: ${dateFormat.format(solicitud.fechaSolicitud)}',
              style:
                  const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            if (solicitud.isPendiente) ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        _showRechazarDialog(context, solicitud.id),
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: const Text('Rechazar',
                        style: TextStyle(color: Colors.red)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _aprobar(context, solicitud.id),
                    icon: const Icon(Icons.check),
                    label: const Text('Aprobar'),
                  ),
                ],
              ),
            ],
            if (solicitud.isRechazada &&
                solicitud.motivoRechazo != null &&
                solicitud.motivoRechazo!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Motivo rechazo: ${solicitud.motivoRechazo}',
                  style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }

  void _aprobar(BuildContext context, String solicitudId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aprobar solicitud'),
        content: Text(
            '¿Aprobar la solicitud de ${solicitud.nombreCompleto}? '
            'Se creará un nuevo cofrade con sus datos.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Aprobar')),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final adminName =
          context.read<AuthService>().cofrade?.nombreCompleto ?? 'Admin';
      await context
          .read<FirestoreService>()
          .aprobarSolicitud(solicitudId, adminName);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud aprobada. Cofrade creado.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showRechazarDialog(BuildContext context, String solicitudId) {
    final motivoController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar solicitud'),
        content: TextField(
          controller: motivoController,
          decoration: const InputDecoration(
            labelText: 'Motivo del rechazo',
            hintText: 'Explica el motivo...',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await context.read<FirestoreService>().rechazarSolicitud(
                      solicitudId,
                      motivoController.text.trim(),
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Solicitud rechazada.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Rechazar'),
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
    IconData icon;
    switch (estado) {
      case 'aprobada':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'rechazada':
        color = Colors.red;
        icon = Icons.cancel;
        break;
      default:
        color = Colors.orange;
        icon = Icons.hourglass_top;
    }
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(
        estado[0].toUpperCase() + estado.substring(1),
        style: TextStyle(fontSize: 12, color: color),
      ),
      backgroundColor: color.withAlpha(20),
      side: BorderSide.none,
      padding: EdgeInsets.zero,
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Flexible(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
