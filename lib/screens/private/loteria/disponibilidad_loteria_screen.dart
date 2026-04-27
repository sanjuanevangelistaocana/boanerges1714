import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/models/loteria.dart';

class DisponibilidadLoteriaScreen extends StatelessWidget {
  const DisponibilidadLoteriaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();

    return StreamBuilder<CampanaLoteria?>(
      stream: fs.getCampanaActiva(),
      builder: (context, campSnap) {
        final campana = campSnap.data;

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
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.confirmation_number, color: Colors.white, size: 28),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text('Lotería de Navidad · Disponibilidad',
                                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        if (campana != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${campana.nombre} · Nº ${campana.numeroLoteria} · ${campana.precioVenta.toStringAsFixed(2)}€/décimo',
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
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: campana == null
                        ? Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(40),
                              child: Column(
                                children: [
                                  Icon(Icons.info_outline, size: 48, color: AppTheme.textSecondary),
                                  SizedBox(height: 12),
                                  Text('No hay campaña de lotería activa',
                                      style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
                                ],
                              ),
                            ),
                          )
                        : _DisponibilidadContent(campanaId: campana.id, fs: fs),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DisponibilidadContent extends StatelessWidget {
  final String campanaId;
  final FirestoreService fs;
  const _DisponibilidadContent({required this.campanaId, required this.fs});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AsignacionLoteria>>(
      stream: fs.getAsignaciones(campanaId),
      builder: (context, asigSnap) {
        return StreamBuilder<List<VendedorLoteria>>(
          stream: fs.getVendedoresLoteria(),
          builder: (context, vendSnap) {
            final asignaciones = asigSnap.data ?? [];
            final vendedores = vendSnap.data ?? [];
            final vendMap = {for (final v in vendedores) v.id: v};

            // Aggregate by vendedor
            final vendedorDisp = <String, int>{};
            final vendedorTotal = <String, int>{};
            for (final a in asignaciones) {
              final disp = a.decimosDisponibles;
              vendedorDisp[a.vendedorId] = (vendedorDisp[a.vendedorId] ?? 0) + disp;
              vendedorTotal[a.vendedorId] = (vendedorTotal[a.vendedorId] ?? 0) + a.decimosAsignados;
            }

            final totalDisponibles = vendedorDisp.values.fold<int>(0, (s, v) => s + v);
            final totalGlobal = vendedorTotal.values.fold<int>(0, (s, v) => s + v);

            // Sort by disponibles descending
            final sortedVendedorIds = vendedorDisp.keys.toList()
              ..sort((a, b) => (vendedorDisp[b] ?? 0).compareTo(vendedorDisp[a] ?? 0));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Global summary
                Card(
                  elevation: 0,
                  color: totalDisponibles > 0 ? AppTheme.accentColor.withAlpha(10) : Colors.orange.withAlpha(10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: (totalDisponibles > 0 ? AppTheme.accentColor : Colors.orange).withAlpha(40)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (totalDisponibles > 0 ? AppTheme.accentColor : Colors.orange).withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            totalDisponibles > 0 ? Icons.check_circle : Icons.warning_amber,
                            color: totalDisponibles > 0 ? AppTheme.accentColor : Colors.orange.shade700,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                totalDisponibles > 0
                                    ? '$totalDisponibles décimos disponibles'
                                    : 'No quedan décimos disponibles',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: totalDisponibles > 0 ? AppTheme.accentColor : Colors.orange.shade700,
                                ),
                              ),
                              Text(
                                'De un total de $totalGlobal décimos asignados',
                                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Info text
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Contacta con cualquier vendedor que tenga décimos disponibles para adquirir tu lotería de Navidad.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Vendedores list
                Text('Vendedores', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                if (sortedVendedorIds.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No hay vendedores con asignaciones.'),
                    ),
                  )
                else
                  ...sortedVendedorIds.map((vendedorId) {
                    final vendedor = vendMap[vendedorId];
                    final disponibles = vendedorDisp[vendedorId] ?? 0;
                    final total = vendedorTotal[vendedorId] ?? 0;
                    final hasStock = disponibles > 0;

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: hasStock ? AppTheme.accentColor.withAlpha(60) : Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: (hasStock ? AppTheme.accentColor : Colors.grey).withAlpha(15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                vendedor?.isCofrade == true ? Icons.person : Icons.store,
                                color: hasStock ? AppTheme.accentColor : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(vendedor?.nombre ?? '?',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  Text(
                                    '${vendedor?.isCofrade == true ? "Cofrade" : "Establecimiento"}${vendedor?.telefono.isNotEmpty == true ? " · ${vendedor!.telefono}" : ""}',
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '$disponibles',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22,
                                    color: hasStock ? AppTheme.accentColor : Colors.grey,
                                  ),
                                ),
                                Text(
                                  hasStock ? 'disponibles' : 'agotado',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: hasStock ? AppTheme.accentColor : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            );
          },
        );
      },
    );
  }
}
