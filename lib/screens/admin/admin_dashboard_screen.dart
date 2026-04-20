import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/models/cofrade.dart';
import 'package:boanerges1714/models/solicitud.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Panel de Administración',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            // Stats
            StreamBuilder<List<Cofrade>>(
              stream: firestoreService.getCofrades(),
              builder: (context, snapshot) {
                final cofrades = snapshot.data ?? [];
                final activos =
                    cofrades.where((c) => c.estado == 'activo').length;
                final pendientes =
                    cofrades.where((c) => c.estado == 'pendiente').length;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _StatCard(
                      title: 'Total Cofrades',
                      value: '${cofrades.length}',
                      icon: Icons.people,
                      color: AppTheme.primaryColor,
                    ),
                    _StatCard(
                      title: 'Activos',
                      value: '$activos',
                      icon: Icons.check_circle,
                      color: Colors.green,
                    ),
                    _StatCard(
                      title: 'Pendientes',
                      value: '$pendientes',
                      icon: Icons.pending,
                      color: Colors.orange,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            // Solicitudes pendientes badge
            StreamBuilder<List<Solicitud>>(
              stream: firestoreService.getSolicitudesPendientes(),
              builder: (context, snapshot) {
                final pendientes = snapshot.data?.length ?? 0;
                if (pendientes == 0) return const SizedBox.shrink();
                return Card(
                  color: Colors.orange[50],
                  child: ListTile(
                    leading: Badge(
                      label: Text('$pendientes'),
                      child: const Icon(Icons.person_add,
                          color: Colors.orange),
                    ),
                    title: Text(
                        '$pendientes solicitud${pendientes > 1 ? 'es' : ''} de alta pendiente${pendientes > 1 ? 's' : ''}'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => context.go('/admin/solicitudes'),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            // Quick actions
            Text('Gestión',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _AdminActionCard(
                  icon: Icons.people,
                  title: 'Gestionar Cofrades',
                  subtitle: 'Alta, baja, edición de cofrades',
                  onTap: () => context.go('/admin/cofrades'),
                ),
                _AdminActionCard(
                  icon: Icons.event_note,
                  title: 'Gestionar Eventos',
                  subtitle: 'Crear y editar eventos',
                  onTap: () => context.go('/admin/events'),
                ),
                _AdminActionCard(
                  icon: Icons.article,
                  title: 'Gestionar Noticias',
                  subtitle: 'Publicar y editar noticias',
                  onTap: () => context.go('/admin/news'),
                ),
                _AdminActionCard(
                  icon: Icons.notifications_active,
                  title: 'Enviar Notificación',
                  subtitle: 'Notificar a los cofrades',
                  onTap: () => context.go('/admin/notifications'),
                ),
                _AdminActionCard(
                  icon: Icons.person_add,
                  title: 'Solicitudes de Alta',
                  subtitle: 'Aprobar o rechazar solicitudes',
                  onTap: () => context.go('/admin/solicitudes'),
                ),
                _AdminActionCard(
                  icon: Icons.how_to_vote,
                  title: 'Convocatorias',
                  subtitle: 'Crear y gestionar convocatorias',
                  onTap: () => context.go('/admin/convocatorias'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(value,
                  style: TextStyle(
                      fontSize: 32, fontWeight: FontWeight.bold, color: color)),
              Text(title,
                  style: const TextStyle(color: AppTheme.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AdminActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 36, color: AppTheme.primaryColor),
                const SizedBox(height: 12),
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
