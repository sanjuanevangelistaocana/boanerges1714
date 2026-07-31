import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/models/loteria.dart';
import 'package:boanerges1714/widgets/responsive_data_table.dart';

class CampanaDashboardScreen extends StatelessWidget {
  final String campanaId;
  const CampanaDashboardScreen({super.key, required this.campanaId});

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();

    return StreamBuilder<List<AsignacionLoteria>>(
      stream: fs.getAsignaciones(campanaId),
      builder: (context, asigSnap) {
        return StreamBuilder<List<Sabana>>(
          stream: fs.getSabanas(campanaId),
          builder: (context, sabSnap) {
            return StreamBuilder<List<VendedorLoteria>>(
              stream: fs.getVendedoresLoteria(),
              builder: (context, vendSnap) {
                return FutureBuilder<CampanaLoteria?>(
                  future: fs.getCampanaById(campanaId),
                  builder: (context, campSnap) {
                    if (campSnap.connectionState == ConnectionState.waiting &&
                        !campSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final campana = campSnap.data;
                    final sabanas = sabSnap.data ?? [];
                    final asignaciones = asigSnap.data ?? [];
                    final vendedores = vendSnap.data ?? [];
                    final vendMap = {for (final v in vendedores) v.id: v};
                    final totalSabanas = sabanas.length;
                    final totalDecimos =
                        sabanas.fold<int>(0, (s, sb) => s + sb.totalDecimos);
                    final sabanasDisponibles =
                        sabanas.where((s) => s.estado == 'disponible').length;
                    final sabanasAsignadas =
                        sabanas.where((s) => s.estado == 'asignada').length;

                    final totalAsignados = asignaciones.fold<int>(
                        0, (s, a) => s + a.decimosAsignados);
                    final totalVendidos = asignaciones.fold<int>(
                        0, (s, a) => s + a.decimosVendidos);
                    final totalDevueltos = asignaciones.fold<int>(
                        0, (s, a) => s + a.decimosDevueltos);
                    final totalDisponibles =
                        totalAsignados - totalVendidos - totalDevueltos;

                    final precioVenta = campana?.precioVenta ?? 0;
                    final precioBase = campana?.precioDecimoBase ?? 0;
                    final ingresosEsperados = totalAsignados * precioVenta;
                    final ingresosReales = totalVendidos * precioVenta;
                    final costeTotal =
                        sabanas.fold<double>(0, (s, sb) => s + sb.precioCompra);
                    final beneficioEsperado = ingresosEsperados - costeTotal;
                    final beneficioReal = ingresosReales -
                        costeTotal +
                        (totalDevueltos * precioBase);

                    final pendientesPago =
                        sabanas.where((s) => !s.pagadaAdministracion).length;
                    final pctVentaGlobal = totalAsignados > 0
                        ? (totalVendidos / totalAsignados * 100)
                        : 0.0;

                    // Vendor table data
                    final vendedorStats = <String, _VendStats>{};
                    for (final a in asignaciones) {
                      final key = a.vendedorId;
                      final existing = vendedorStats[key];
                      if (existing != null) {
                        vendedorStats[key] = _VendStats(
                          asignados: existing.asignados + a.decimosAsignados,
                          vendidos: existing.vendidos + a.decimosVendidos,
                          devueltos: existing.devueltos + a.decimosDevueltos,
                          lastUpdate: a.ultimaActualizacion != null &&
                                  (existing.lastUpdate == null ||
                                      a.ultimaActualizacion!
                                          .isAfter(existing.lastUpdate!))
                              ? a.ultimaActualizacion
                              : existing.lastUpdate,
                        );
                      } else {
                        vendedorStats[key] = _VendStats(
                          asignados: a.decimosAsignados,
                          vendidos: a.decimosVendidos,
                          devueltos: a.decimosDevueltos,
                          lastUpdate: a.ultimaActualizacion,
                        );
                      }
                    }

                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 28, horizontal: 24),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(colors: [
                                AppTheme.primaryDark,
                                AppTheme.primaryColor
                              ]),
                            ),
                            child: Center(
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 1000),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.dashboard,
                                            color: Colors.white, size: 28),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'Dashboard · ${campana?.nombre ?? ""}',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (campana != null) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'Nº ${campana.numeroLoteria} · ${campana.precioVenta.toStringAsFixed(2)}€/décimo · ${campana.administracionNombre}',
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13),
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
                                constraints:
                                    const BoxConstraints(maxWidth: 1000),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // KPI cards
                                    _SectionTitle(title: 'Inventario'),
                                    const SizedBox(height: 12),
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        final isWide =
                                            constraints.maxWidth > 600;
                                        final cards = [
                                          _KpiCard(
                                              title: 'Sábanas',
                                              value: '$totalSabanas',
                                              subtitle:
                                                  '$sabanasDisponibles disponibles · $sabanasAsignadas asignadas',
                                              icon: Icons.receipt_long,
                                              color: AppTheme.primaryColor),
                                          _KpiCard(
                                              title: 'Décimos Totales',
                                              value: '$totalDecimos',
                                              subtitle:
                                                  '$totalAsignados asignados · ${totalDecimos - totalAsignados} sin asignar',
                                              icon: Icons.confirmation_number,
                                              color: AppTheme.accentColor),
                                          _KpiCard(
                                              title: 'Vendidos',
                                              value: '$totalVendidos',
                                              subtitle:
                                                  '${pctVentaGlobal.toStringAsFixed(1)}% de asignados',
                                              icon: Icons.trending_up,
                                              color: Colors.green.shade700),
                                          _KpiCard(
                                              title: 'Disponibles',
                                              value: '$totalDisponibles',
                                              subtitle:
                                                  '$totalDevueltos devueltos',
                                              icon: Icons.inventory,
                                              color: Colors.orange.shade700),
                                        ];
                                        if (isWide) {
                                          return Row(
                                            children: cards
                                                .map((c) => Expanded(
                                                    child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 4),
                                                        child: c)))
                                                .toList(),
                                          );
                                        }
                                        return Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: cards
                                              .map((c) => SizedBox(
                                                  width: (constraints.maxWidth -
                                                          8) /
                                                      2,
                                                  child: c))
                                              .toList(),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 24),

                                    // Economic metrics
                                    _SectionTitle(title: 'Económico'),
                                    const SizedBox(height: 12),
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        final isWide =
                                            constraints.maxWidth > 600;
                                        final cards = [
                                          _KpiCard(
                                              title: 'Coste Total',
                                              value:
                                                  '${costeTotal.toStringAsFixed(0)}€',
                                              subtitle:
                                                  '$pendientesPago sábanas sin pagar',
                                              icon: Icons.shopping_cart,
                                              color: Colors.red.shade700),
                                          _KpiCard(
                                              title: 'Ingresos Esperados',
                                              value:
                                                  '${ingresosEsperados.toStringAsFixed(0)}€',
                                              subtitle:
                                                  'Si se venden todos los asignados',
                                              icon: Icons.euro,
                                              color: AppTheme.primaryColor),
                                          _KpiCard(
                                              title: 'Ingresos Reales',
                                              value:
                                                  '${ingresosReales.toStringAsFixed(0)}€',
                                              subtitle:
                                                  '$totalVendidos décimos vendidos',
                                              icon: Icons.paid,
                                              color: AppTheme.accentColor),
                                          _KpiCard(
                                              title: 'Beneficio',
                                              value:
                                                  '${beneficioReal.toStringAsFixed(0)}€',
                                              subtitle:
                                                  'Esperado: ${beneficioEsperado.toStringAsFixed(0)}€',
                                              icon: Icons.trending_up,
                                              color: beneficioReal >= 0
                                                  ? Colors.green.shade700
                                                  : Colors.red.shade700),
                                        ];
                                        if (isWide) {
                                          return Row(
                                            children: cards
                                                .map((c) => Expanded(
                                                    child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 4),
                                                        child: c)))
                                                .toList(),
                                          );
                                        }
                                        return Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: cards
                                              .map((c) => SizedBox(
                                                  width: (constraints.maxWidth -
                                                          8) /
                                                      2,
                                                  child: c))
                                              .toList(),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 24),

                                    _SectionTitle(
                                        title: 'Trazabilidad de pagos'),
                                    const SizedBox(height: 12),
                                    StreamBuilder<Map<String, dynamic>>(
                                      stream:
                                          fs.getLoteriaCampanaStats(campanaId),
                                      builder: (context, paySnap) {
                                        final p = paySnap.data ?? const {};
                                        final cards = [
                                          _KpiCard(
                                              title: 'Total vendido',
                                              value:
                                                  '${((p['importe_vendido'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}€',
                                              subtitle:
                                                  '${p['vendidos'] ?? 0} décimos',
                                              icon: Icons.sell,
                                              color: AppTheme.accentColor),
                                          _KpiCard(
                                              title: 'Cobrado vendedores',
                                              value:
                                                  '${((p['importe_cobrado'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}€',
                                              subtitle:
                                                  'Pendiente: ${((p['importe_pendiente_cobrar'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}€',
                                              icon: Icons.payments,
                                              color: Colors.green.shade700),
                                          _KpiCard(
                                              title: 'A Cofradía',
                                              value:
                                                  '${((p['entregado_cofradia'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}€',
                                              subtitle:
                                                  'Pendiente: ${((p['pendiente_entregar_cofradia'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}€',
                                              icon: Icons.savings,
                                              color: Colors.purple.shade700),
                                          _KpiCard(
                                              title: 'A Administración',
                                              value:
                                                  '${((p['entregado_administracion'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}€',
                                              subtitle:
                                                  'Pendiente: ${((p['pendiente_entregar_administracion'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}€',
                                              icon: Icons.account_balance,
                                              color: Colors.blue.shade700),
                                        ];
                                        return LayoutBuilder(
                                          builder: (context, constraints) {
                                            final isWide =
                                                constraints.maxWidth > 600;
                                            if (isWide) {
                                              return Row(
                                                children: cards
                                                    .map((c) => Expanded(
                                                        child: Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        4),
                                                            child: c)))
                                                    .toList(),
                                              );
                                            }
                                            return Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: cards
                                                  .map((c) => SizedBox(
                                                      width: (constraints
                                                                  .maxWidth -
                                                              8) /
                                                          2,
                                                      child: c))
                                                  .toList(),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    StreamBuilder<List<DecimoLoteria>>(
                                      stream: fs.getDecimosCampana(campanaId),
                                      builder: (context, decSnap) {
                                        final holders =
                                            <String, _HolderStats>{};
                                        for (final d in decSnap.data ??
                                            <DecimoLoteria>[]) {
                                          if (!d.paidToBrotherhood ||
                                              (d.brotherhoodHolderId ?? '')
                                                  .isEmpty) continue;
                                          final key = d.brotherhoodHolderId!;
                                          final current = holders[key] ??
                                              _HolderStats(
                                                  name:
                                                      d.brotherhoodHolderName ??
                                                          'Sin nombre');
                                          holders[key] = _HolderStats(
                                            name: current.name,
                                            amount:
                                                current.amount + d.precioVenta,
                                            count: current.count + 1,
                                          );
                                        }
                                        if (holders.isEmpty)
                                          return const SizedBox.shrink();
                                        return Card(
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              side: BorderSide(
                                                  color: Colors.grey.shade200)),
                                          child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                    'Dinero en manos de cofrades',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold)),
                                                const SizedBox(height: 8),
                                                ...holders.values.map((h) =>
                                                    ListTile(
                                                      dense: true,
                                                      contentPadding:
                                                          EdgeInsets.zero,
                                                      leading: const Icon(
                                                          Icons.account_circle,
                                                          color: AppTheme
                                                              .primaryColor),
                                                      title: Text(h.name),
                                                      subtitle: Text(
                                                          '${h.count} décimos'),
                                                      trailing: Text(
                                                          '${h.amount.toStringAsFixed(2)}€',
                                                          style: const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold)),
                                                    )),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 24),

                                    // Progress bar
                                    _SectionTitle(title: 'Progreso de Ventas'),
                                    const SizedBox(height: 12),
                                    Card(
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          side: BorderSide(
                                              color: Colors.grey.shade200)),
                                      child: Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Column(
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                    '$totalVendidos/$totalAsignados décimos vendidos',
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600)),
                                                Text(
                                                    '${pctVentaGlobal.toStringAsFixed(1)}%',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: AppTheme
                                                            .accentColor,
                                                        fontSize: 18)),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              child: LinearProgressIndicator(
                                                value: totalAsignados > 0
                                                    ? totalVendidos /
                                                        totalAsignados
                                                    : 0,
                                                backgroundColor:
                                                    Colors.grey.shade200,
                                                color: AppTheme.accentColor,
                                                minHeight: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),

                                    // Vendor table
                                    _SectionTitle(title: 'Tabla de Vendedores'),
                                    const SizedBox(height: 12),
                                    Card(
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          side: BorderSide(
                                              color: Colors.grey.shade200)),
                                      child: vendedorStats.isEmpty
                                          ? const Padding(
                                              padding: EdgeInsets.all(20),
                                              child: Text(
                                                  'No hay vendedores con asignaciones.'),
                                            )
                                          : ResponsiveDataTable(
                                              columnSpacing: 20,
                                              columns: const [
                                                ResponsiveTableColumn(
                                                    label: 'Vendedor',
                                                    mobilePriority: 0),
                                                ResponsiveTableColumn(
                                                    label: 'Tipo',
                                                    mobilePriority: 1),
                                                ResponsiveTableColumn(
                                                    label: 'Asignados',
                                                    mobilePriority: 2,
                                                    numeric: true),
                                                ResponsiveTableColumn(
                                                    label: 'Vendidos',
                                                    mobilePriority: 2,
                                                    numeric: true),
                                                ResponsiveTableColumn(
                                                    label: 'Devueltos',
                                                    mobilePriority: 3,
                                                    numeric: true),
                                                ResponsiveTableColumn(
                                                    label: 'Disponibles',
                                                    mobilePriority: 2,
                                                    numeric: true),
                                                ResponsiveTableColumn(
                                                    label: '% Venta',
                                                    mobilePriority: 1,
                                                    numeric: true),
                                                ResponsiveTableColumn(
                                                    label: 'Última Act.',
                                                    mobilePriority: 3),
                                              ],
                                              rows: [
                                                for (final entry
                                                    in vendedorStats.entries)
                                                  ResponsiveTableRow(
                                                    cells: [
                                                      Text(vendMap[entry.key]
                                                              ?.nombre ??
                                                          '?'),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          horizontal: 8,
                                                          vertical: 2,
                                                        ),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: (vendMap[entry
                                                                              .key]
                                                                          ?.isCofrade ==
                                                                      true
                                                                  ? AppTheme
                                                                      .accentColor
                                                                  : Colors
                                                                      .orange)
                                                              .withAlpha(20),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(4),
                                                        ),
                                                        child: Text(
                                                          vendMap[entry.key]
                                                                      ?.isCofrade ==
                                                                  true
                                                              ? 'Cofrade'
                                                              : 'Externo',
                                                          style:
                                                              const TextStyle(
                                                                  fontSize: 11),
                                                        ),
                                                      ),
                                                      Text(
                                                          '${entry.value.asignados}'),
                                                      Text(
                                                          '${entry.value.vendidos}',
                                                          style: const TextStyle(
                                                              color: AppTheme
                                                                  .accentColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold)),
                                                      Text(
                                                        '${entry.value.devueltos}',
                                                        style: TextStyle(
                                                          color: entry.value
                                                                      .devueltos >
                                                                  0
                                                              ? Colors
                                                                  .red.shade600
                                                              : null,
                                                        ),
                                                      ),
                                                      Text(
                                                        '${entry.value.asignados - entry.value.vendidos - entry.value.devueltos}',
                                                      ),
                                                      Text(
                                                        '${(entry.value.asignados > 0 ? entry.value.vendidos / entry.value.asignados * 100 : 0).toStringAsFixed(0)}%',
                                                      ),
                                                      Text(
                                                        entry.value.lastUpdate !=
                                                                null
                                                            ? DateFormat(
                                                                    'dd/MM HH:mm')
                                                                .format(entry
                                                                    .value
                                                                    .lastUpdate!)
                                                            : 'Sin datos',
                                                        style: const TextStyle(
                                                            fontSize: 12),
                                                      ),
                                                    ],
                                                  ),
                                              ],
                                            ),
                                    ),
                                    const SizedBox(height: 24),

                                    // Alertas
                                    _buildAlertas(
                                        vendedorStats, vendMap, asignaciones),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAlertas(
      Map<String, _VendStats> vendedorStats,
      Map<String, VendedorLoteria> vendMap,
      List<AsignacionLoteria> asignaciones) {
    final alertas = <Widget>[];

    // Sin actualizar (> 7 días)
    final now = DateTime.now();
    for (final entry in vendedorStats.entries) {
      final stats = entry.value;
      if (stats.lastUpdate != null &&
          now.difference(stats.lastUpdate!).inDays > 7 &&
          stats.asignados > stats.vendidos + stats.devueltos) {
        final vend = vendMap[entry.key];
        alertas.add(_AlertTile(
          icon: Icons.warning_amber,
          color: Colors.orange.shade700,
          text:
              '${vend?.nombre ?? "?"} no actualiza desde hace ${now.difference(stats.lastUpdate!).inDays} días',
        ));
      }
    }

    // Inconsistencias
    for (final a in asignaciones) {
      if (a.decimosVendidos + a.decimosDevueltos > a.decimosAsignados) {
        final vend = vendMap[a.vendedorId];
        alertas.add(_AlertTile(
          icon: Icons.error_outline,
          color: Colors.red.shade700,
          text:
              'Inconsistencia: ${vend?.nombre ?? "?"} tiene vendidos+devueltos > asignados',
        ));
      }
    }

    if (alertas.isEmpty) {
      return Card(
        elevation: 0,
        color: AppTheme.accentColor.withAlpha(10),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppTheme.accentColor.withAlpha(40))),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.check_circle_outline, color: AppTheme.accentColor),
              SizedBox(width: 12),
              Text('Sin alertas. Todo funciona correctamente.',
                  style: TextStyle(color: AppTheme.accentColor)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Alertas'),
        const SizedBox(height: 12),
        ...alertas,
      ],
    );
  }
}

class _VendStats {
  final int asignados;
  final int vendidos;
  final int devueltos;
  final DateTime? lastUpdate;
  _VendStats(
      {required this.asignados,
      required this.vendidos,
      required this.devueltos,
      this.lastUpdate});
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  const _KpiCard(
      {required this.title,
      required this.value,
      required this.subtitle,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: color.withAlpha(20),
                      borderRadius: BorderRadius.circular(6)),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary))),
              ],
            ),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _AlertTile(
      {required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: color.withAlpha(10),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: color.withAlpha(40))),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
                child:
                    Text(text, style: TextStyle(color: color, fontSize: 13))),
          ],
        ),
      ),
    );
  }
}

class _HolderStats {
  final String name;
  final double amount;
  final int count;

  const _HolderStats({
    required this.name,
    this.amount = 0,
    this.count = 0,
  });
}
