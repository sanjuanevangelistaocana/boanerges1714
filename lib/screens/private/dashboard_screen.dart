import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/models/cofrade.dart';
import 'package:boanerges1714/models/cuota.dart';
import 'package:boanerges1714/models/noticia.dart';
import 'package:boanerges1714/models/convocatoria.dart';

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
            // Cofrade selector for tutelados digitales
            if (authService.hasMultipleCofrades) ...[
              const SizedBox(height: 12),
              _CofradeSelectorCard(
                cofrades: authService.cofrades,
                selectedCofrade: cofrade,
                onSelect: (id) => authService.selectCofrade(id),
              ),
            ],
            if (cofrade?.estado == 'Pendiente' ||
                cofrade?.estado == 'pendiente')
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
                _DashboardCard(
                  icon: Icons.how_to_vote,
                  title: 'Convocatorias',
                  subtitle: 'Responde consultas',
                  onTap: () => context.go('/convocatorias'),
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
            // Cofradía stats
            _CofradiaStatsSection(firestoreService: firestoreService),
            const SizedBox(height: 32),
            // Active convocatorias
            _ActiveConvocatoriasSection(firestoreService: firestoreService),
            const SizedBox(height: 32),
            // Private news
            _PrivateNewsSection(firestoreService: firestoreService),
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

class _CofradiaStatsSection extends StatelessWidget {
  final FirestoreService firestoreService;

  const _CofradiaStatsSection({required this.firestoreService});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tu Cofradía',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        FutureBuilder<List<int>>(
          future: Future.wait([
            firestoreService.getCofradesActivosCount(),
            firestoreService.getTotalCofradesCount(),
          ]),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            final activos = snapshot.data?[0] ?? 0;
            final total = snapshot.data?[1] ?? 0;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _CuotaStat(
                      label: 'Activos',
                      count: activos,
                      color: Colors.green,
                      icon: Icons.people,
                    ),
                    _CuotaStat(
                      label: 'Total',
                      count: total,
                      color: AppTheme.primaryColor,
                      icon: Icons.groups,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ActiveConvocatoriasSection extends StatelessWidget {
  final FirestoreService firestoreService;

  const _ActiveConvocatoriasSection({required this.firestoreService});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Convocatorias Activas',
                  style: Theme.of(context).textTheme.headlineSmall),
            ),
            TextButton(
              onPressed: () => context.go('/convocatorias'),
              child: const Text('Ver todas'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<Convocatoria>>(
          stream: firestoreService.getConvocatoriasActivas(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final convocatorias = snapshot.data ?? [];
            if (convocatorias.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No hay convocatorias activas.'),
                ),
              );
            }
            return Column(
              children: convocatorias.take(3).map((c) {
                final dateFormat = DateFormat('dd/MM/yyyy');
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      c.tipo == 'procesion'
                          ? Icons.church
                          : c.tipo == 'evento'
                              ? Icons.event
                              : Icons.how_to_vote,
                      color: AppTheme.primaryColor,
                    ),
                    title: Text(c.titulo),
                    subtitle: Text(
                        'Límite: ${dateFormat.format(c.fechaLimite)} · '
                        '${c.totalRespuestas} respuestas'),
                    trailing:
                        const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => context.go('/convocatorias'),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _PrivateNewsSection extends StatelessWidget {
  final FirestoreService firestoreService;

  const _PrivateNewsSection({required this.firestoreService});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Noticias para Cofrades',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        StreamBuilder<List<Noticia>>(
          stream: firestoreService.getNoticiasCofrades(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final noticias = snapshot.data ?? [];
            if (noticias.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No hay noticias privadas.'),
                ),
              );
            }
            return Column(
              children: noticias.map((n) {
                final dateFormat = DateFormat('dd/MM/yyyy');
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.article,
                        color: AppTheme.primaryColor),
                    title: Text(n.titulo),
                    subtitle: Text(dateFormat.format(n.fecha)),
                    trailing:
                        const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => context.go('/news'),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _CofradeSelectorCard extends StatelessWidget {
  final List<Cofrade> cofrades;
  final Cofrade? selectedCofrade;
  final void Function(String) onSelect;

  const _CofradeSelectorCard({
    required this.cofrades,
    required this.selectedCofrade,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.primaryColor.withAlpha(15),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.people, size: 20, color: AppTheme.primaryColor),
                SizedBox(width: 8),
                Text(
                  'Cofrades vinculados a tu cuenta',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...cofrades.map((cofrade) {
              final isSelected = cofrade.id == selectedCofrade?.id;
              final isTutelado = cofrade.tuteladoDigital != null &&
                  cofrade.tuteladoDigital!.isNotEmpty;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: isSelected
                        ? const BorderSide(color: AppTheme.primaryColor)
                        : BorderSide.none,
                  ),
                  tileColor: isSelected
                      ? AppTheme.primaryColor.withAlpha(25)
                      : null,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: isSelected
                        ? AppTheme.primaryColor
                        : Colors.grey[300],
                    child: Text(
                      cofrade.nombre.isNotEmpty
                          ? cofrade.nombre[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[600],
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  title: Text(
                    cofrade.nombreCompleto,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    isTutelado
                        ? 'Tutelado · Nº ${cofrade.numero ?? "-"}'
                        : 'Nº ${cofrade.numero ?? "-"}',
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle,
                          color: AppTheme.primaryColor)
                      : null,
                  onTap: () => onSelect(cofrade.id),
                ),
              );
            }),
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
