import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/models/cuota.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final firestoreService = context.read<FirestoreService>();
    final cofrade = authService.cofrade;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bienvenido, ${cofrade?.nombre ?? 'Cofrade'}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            if (cofrade?.estado == 'pendiente')
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.hourglass_top, color: Colors.orange),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tu cuenta está pendiente de aprobación por la Junta Directiva.',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            // Quick actions
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _DashboardCard(
                  icon: Icons.person,
                  title: 'Mi Perfil',
                  subtitle: 'Ver y editar mis datos',
                  onTap: () => context.go('/profile'),
                ),
                _DashboardCard(
                  icon: Icons.payment,
                  title: 'Mis Cuotas',
                  subtitle: 'Estado de pagos',
                  onTap: () => context.go('/cuotas'),
                ),
                _DashboardCard(
                  icon: Icons.folder,
                  title: 'Documentos',
                  subtitle: 'Actas y estatutos',
                  onTap: () => context.go('/documents'),
                ),
                _DashboardCard(
                  icon: Icons.event,
                  title: 'Eventos',
                  subtitle: 'Próximas actividades',
                  onTap: () => context.go('/events'),
                ),
                if (authService.isAdmin)
                  _DashboardCard(
                    icon: Icons.admin_panel_settings,
                    title: 'Administración',
                    subtitle: 'Panel de gestión',
                    onTap: () => context.go('/admin'),
                    isAdmin: true,
                  ),
              ],
            ),
            const SizedBox(height: 32),
            // Cuotas summary
            if (cofrade != null) ...[
              Text('Resumen de Cuotas',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              StreamBuilder<List<Cuota>>(
                stream: firestoreService.getCuotasCofrade(cofrade.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final cuotas = snapshot.data ?? [];
                  if (cuotas.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No hay cuotas registradas.'),
                      ),
                    );
                  }
                  final pendientes =
                      cuotas.where((c) => c.isPendiente).length;
                  final pagadas = cuotas.where((c) => c.isPagada).length;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _CuotaStat(
                            label: 'Pagadas',
                            count: pagadas,
                            color: Colors.green,
                            icon: Icons.check_circle,
                          ),
                          _CuotaStat(
                            label: 'Pendientes',
                            count: pendientes,
                            color: Colors.orange,
                            icon: Icons.pending,
                          ),
                          _CuotaStat(
                            label: 'Total',
                            count: cuotas.length,
                            color: AppTheme.primaryColor,
                            icon: Icons.receipt_long,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isAdmin;

  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Card(
        color: isAdmin ? AppTheme.primaryColor.withAlpha(25) : null,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(icon,
                    size: 36,
                    color:
                        isAdmin ? AppTheme.primaryColor : AppTheme.primaryLight),
                const SizedBox(height: 8),
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CuotaStat extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _CuotaStat({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text('$count',
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
      ],
    );
  }
}
