import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/models/cofrade.dart';
import 'package:boanerges1714/models/solicitud.dart';
import 'package:boanerges1714/models/convocatoria.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return SingleChildScrollView(
      child: Column(
        children: [
          // Professional header
          Container(
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
                  Icon(Icons.admin_panel_settings,
                      color: Colors.white70, size: 28),
                  SizedBox(width: 12),
                  Text('Panel de Administraci\u00f3n',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats summary
                  StreamBuilder<List<Cofrade>>(
                    stream: firestoreService.getCofrades(),
                    builder: (context, snapshot) {
                      final cofrades = (snapshot.data ?? [])
                          .where((c) =>
                              !c.esCuentaServicio && !c.id.startsWith('ADM-'))
                          .toList();
                      final activos = cofrades.where((c) => c.isActivo).length;
                      final pendientes = cofrades
                          .where((c) => c.estado.toLowerCase() == 'pendiente')
                          .length;
                      final bajas = cofrades.where((c) => c.isBaja).length;
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200)),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _StatTile(
                                  value: '${cofrades.length}',
                                  label: 'Total',
                                  icon: Icons.groups,
                                  color: AppTheme.primaryColor),
                              Container(
                                  width: 1,
                                  height: 60,
                                  color: Colors.grey.shade200),
                              _StatTile(
                                  value: '$activos',
                                  label: 'Activos',
                                  icon: Icons.people,
                                  color: AppTheme.accentColor),
                              Container(
                                  width: 1,
                                  height: 60,
                                  color: Colors.grey.shade200),
                              _StatTile(
                                  value: '$pendientes',
                                  label: 'Pendientes',
                                  icon: Icons.pending,
                                  color: Colors.orange.shade700),
                              Container(
                                  width: 1,
                                  height: 60,
                                  color: Colors.grey.shade200),
                              _StatTile(
                                  value: '$bajas',
                                  label: 'Bajas',
                                  icon: Icons.person_off,
                                  color: Colors.red.shade400),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  // Solicitudes pendientes
                  StreamBuilder<List<Solicitud>>(
                    stream: firestoreService.getSolicitudesPendientes(),
                    builder: (context, snapshot) {
                      final pendientes = snapshot.data?.length ?? 0;
                      if (pendientes == 0) return const SizedBox.shrink();
                      return Card(
                        elevation: 0,
                        color: Colors.orange.shade50,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.orange.shade200)),
                        child: ListTile(
                          leading: Badge(
                            label: Text('$pendientes'),
                            child: Icon(Icons.person_add,
                                color: Colors.orange.shade700),
                          ),
                          title: Text(
                              '$pendientes solicitud${pendientes > 1 ? 'es' : ''} de alta pendiente${pendientes > 1 ? 's' : ''}'),
                          trailing:
                              const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () => context.go('/admin/solicitudes'),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  // Convocatorias drilldown
                  _ConvocatoriasDrilldown(firestoreService: firestoreService),
                  const SizedBox(height: 28),
                  // Quick actions
                  Row(
                    children: [
                      Container(
                          width: 4,
                          height: 24,
                          decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 10),
                      Text('Gesti\u00f3n',
                          style: Theme.of(context).textTheme.headlineSmall),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount:
                        MediaQuery.of(context).size.width > 700 ? 3 : 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      _AdminActionCard(
                          icon: Icons.people,
                          title: 'Cofrades',
                          subtitle: 'Alta, baja, edici\u00f3n',
                          onTap: () => context.go('/admin/cofrades')),
                      _AdminActionCard(
                          icon: Icons.event_note,
                          title: 'Eventos',
                          subtitle: 'Festividad, palmas y eventos',
                          onTap: () => context.go('/admin/eventos')),
                      _AdminActionCard(
                          icon: Icons.article,
                          title: 'Noticias',
                          subtitle: 'Publicar y editar',
                          onTap: () => context.go('/admin/news')),
                      _AdminActionCard(
                          icon: Icons.notifications_active,
                          title: 'Notificaciones',
                          subtitle: 'Enviar avisos',
                          onTap: () => context.go('/admin/notifications')),
                      StreamBuilder<int>(
                        stream: firestoreService
                            .getSolicitudesPendientesCountStream(),
                        builder: (context, snap) => _AdminActionCard(
                          icon: Icons.person_add,
                          title: 'Solicitudes',
                          subtitle: 'Aprobar o rechazar',
                          badgeCount: snap.data ?? 0,
                          onTap: () => context.go('/admin/solicitudes'),
                        ),
                      ),
                      _AdminActionCard(
                          icon: Icons.how_to_vote,
                          title: 'Consultas',
                          subtitle: 'Crear y gestionar',
                          onTap: () => context.go('/admin/convocatorias')),
                      StreamBuilder<int>(
                        stream: firestoreService
                            .getPendingConversationsForAdminCountStream(),
                        builder: (context, snap) => _AdminActionCard(
                          icon: Icons.forum_outlined,
                          title: 'Mensajería',
                          subtitle: 'Conversaciones y peticiones',
                          badgeCount: snap.data ?? 0,
                          onTap: () => context.go('/admin/sugerencias'),
                        ),
                      ),
                      StreamBuilder<int>(
                        stream:
                            firestoreService.getAnunciosPendientesCountStream(),
                        builder: (context, snap) => _AdminActionCard(
                          icon: Icons.campaign,
                          title: 'Tablón',
                          subtitle: 'Moderar anuncios',
                          badgeCount: snap.data ?? 0,
                          onTap: () => context.go('/admin/tablon'),
                        ),
                      ),
                      _AdminActionCard(
                          icon: Icons.checkroom,
                          title: 'T\u00fanicas',
                          subtitle: 'Proveedores',
                          onTap: () => context.go('/admin/tunicas')),
                      _AdminActionCard(
                          icon: Icons.volunteer_activism,
                          title: 'Banco T\u00fanicas',
                          subtitle: 'Ofertas y demandas',
                          onTap: () => context.go('/admin/banco-tunicas')),
                      _AdminActionCard(
                          icon: Icons.folder_open,
                          title: 'Documentos',
                          subtitle: 'Docs y revistas',
                          onTap: () => context.go('/admin/documentos')),
                      _AdminActionCard(
                          icon: Icons.confirmation_number,
                          title: 'Lotería Navidad',
                          subtitle: 'Campañas y ventas',
                          onTap: () => context.go('/admin/loteria')),
                      _AdminActionCard(
                          icon: Icons.account_balance_wallet,
                          title: 'Tesorería',
                          subtitle: 'Cuotas y contabilidad',
                          onTap: () => context.go('/treasury')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const _StatTile(
      {required this.value,
      required this.label,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style:
                const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }
}

class _ConvocatoriasDrilldown extends StatefulWidget {
  final FirestoreService firestoreService;
  const _ConvocatoriasDrilldown({required this.firestoreService});

  @override
  State<_ConvocatoriasDrilldown> createState() =>
      _ConvocatoriasDrilldownState();
}

class _ConvocatoriasDrilldownState extends State<_ConvocatoriasDrilldown> {
  String? _expandedId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                    color: Colors.orange.shade700,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 10),
            Expanded(
                child: Text('Resumen de Consultas y Encuestas',
                    style: Theme.of(context).textTheme.headlineSmall)),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<Convocatoria>>(
          stream: widget.firestoreService.getConvocatoriasActivas(),
          builder: (context, activeSnap) {
            return StreamBuilder<List<Convocatoria>>(
              stream: widget.firestoreService.getAllConvocatorias(),
              builder: (context, allSnap) {
                if (allSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final allConvocatorias = allSnap.data ?? [];
                final activas = (activeSnap.data ?? []).length;

                if (allConvocatorias.isEmpty) {
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200)),
                    child: const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No hay consultas creadas.')),
                  );
                }

                final cerradas = allConvocatorias.length - activas;
                final totalResp = allConvocatorias.fold<int>(
                    0, (sum, c) => sum + c.totalRespuestas);

                return Column(
                  children: [
                    // Summary stats
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _MiniStat(
                                value: '${allConvocatorias.length}',
                                label: 'Total',
                                color: AppTheme.primaryColor),
                            _MiniStat(
                                value: '$activas',
                                label: 'Activas',
                                color: AppTheme.accentColor),
                            _MiniStat(
                                value: '$cerradas',
                                label: 'Cerradas',
                                color: Colors.grey.shade600),
                            _MiniStat(
                                value: '$totalResp',
                                label: 'Respuestas',
                                color: Colors.orange.shade700),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Drilldown list
                    ...allConvocatorias.map((c) {
                      final isExpanded = _expandedId == c.id;
                      final fmt = DateFormat('dd/MM/yyyy');
                      final isActive = c.isVigente;
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                                color: isExpanded
                                    ? AppTheme.primaryColor.withAlpha(80)
                                    : Colors.grey.shade200)),
                        child: Column(
                          children: [
                            ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                    color: (isActive
                                            ? AppTheme.accentColor
                                            : Colors.grey)
                                        .withAlpha(20),
                                    borderRadius: BorderRadius.circular(8)),
                                child: Icon(
                                    c.tipo == 'procesion'
                                        ? Icons.church
                                        : c.tipo == 'evento'
                                            ? Icons.event
                                            : Icons.how_to_vote,
                                    color: isActive
                                        ? AppTheme.accentColor
                                        : Colors.grey.shade600),
                              ),
                              title: Text(c.titulo,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                '${isActive ? "Activa" : "Cerrada"} \u00b7 L\u00edmite: ${fmt.format(c.fechaLimite)} \u00b7 ${c.totalRespuestas} resp.',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: isActive
                                        ? AppTheme.accentColor
                                        : AppTheme.textSecondary),
                              ),
                              trailing: Icon(
                                  isExpanded
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  color: AppTheme.textSecondary),
                              onTap: () => setState(
                                  () => _expandedId = isExpanded ? null : c.id),
                            ),
                            if (isExpanded)
                              _ConvocatoriaDetail(
                                  convocatoria: c,
                                  firestoreService: widget.firestoreService),
                          ],
                        ),
                      );
                    }),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _ConvocatoriaDetail extends StatelessWidget {
  final Convocatoria convocatoria;
  final FirestoreService firestoreService;
  const _ConvocatoriaDetail(
      {required this.convocatoria, required this.firestoreService});

  @override
  Widget build(BuildContext context) {
    final opciones = convocatoria.opciones;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 8),
          Text('Desglose de respuestas',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.grey.shade700)),
          const SizedBox(height: 12),
          StreamBuilder<List<RespuestaConvocatoria>>(
            stream: firestoreService.getRespuestas(convocatoria.id),
            builder: (context, snapshot) {
              final respuestas = snapshot.data ?? [];
              final total = respuestas.length;

              if (total == 0) {
                return const Text('A\u00fan no hay respuestas.',
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 13));
              }

              final conteo = <String, int>{};
              for (final r in respuestas) {
                conteo[r.respuesta] = (conteo[r.respuesta] ?? 0) + 1;
              }

              return Column(
                children: [
                  ...opciones.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final opcion = entry.value;
                    final count = conteo[opcion] ?? 0;
                    final pct = total > 0 ? count / total : 0.0;
                    final colors = [
                      AppTheme.accentColor,
                      AppTheme.primaryColor,
                      Colors.orange.shade700,
                      Colors.brown.shade600,
                      AppTheme.primaryLight
                    ];
                    final color = colors[idx % colors.length];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(opcion,
                                  style: const TextStyle(fontSize: 13)),
                              Text(
                                  '$count/$total (${(pct * 100).toStringAsFixed(0)}%)',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: color)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                                value: pct,
                                backgroundColor: Colors.grey.shade200,
                                color: color,
                                minHeight: 6),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.people, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text('Total: $total respuestas',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600)),
                    ],
                  ),
                ],
              );
            },
          ),
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
                fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style:
                const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }
}

class _AdminActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final int badgeCount;

  const _AdminActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              badgeCount > 0
                  ? Badge(
                      label: Text('$badgeCount',
                          style: const TextStyle(fontSize: 11)),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withAlpha(15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child:
                            Icon(icon, size: 28, color: AppTheme.primaryColor),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withAlpha(15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 28, color: AppTheme.primaryColor),
                    ),
              const SizedBox(height: 10),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
