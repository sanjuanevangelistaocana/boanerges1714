import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/firestore_service.dart';

class InformeFestividadScreen extends StatelessWidget {
  final String edicionId;
  const InformeFestividadScreen({super.key, required this.edicionId});

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();

    return SingleChildScrollView(
      child: Column(
        children: [
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
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.analytics, color: Colors.white70, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Informe de la Festividad',
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: FutureBuilder<Map<String, dynamic>?>(
                future: fs.getFestividadEdicion(edicionId),
                builder: (context, edSnap) {
                  if (edSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final edicion = edSnap.data;
                  if (edicion == null) {
                    return const Center(child: Text('Edición no encontrada.'));
                  }
                  return StreamBuilder<List<Map<String, dynamic>>>(
                    stream: fs.getFestividadInscripciones(edicionId),
                    builder: (context, inscSnap) {
                      if (inscSnap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return StreamBuilder<List<Map<String, dynamic>>>(
                        stream: fs.getFestividadMenus(edicionId),
                        builder: (context, menuSnap) {
                          final inscripciones = inscSnap.data ?? [];
                          final menus = menuSnap.data ?? [];
                          return _InformeContent(
                            edicion: edicion,
                            inscripciones: inscripciones,
                            menus: menus,
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InformeContent extends StatelessWidget {
  final Map<String, dynamic> edicion;
  final List<Map<String, dynamic>> inscripciones;
  final List<Map<String, dynamic>> menus;
  const _InformeContent({
    required this.edicion,
    required this.inscripciones,
    required this.menus,
  });

  Map<String, dynamic> _calcKpis() {
    final activas = inscripciones.where((i) => i['estado'] != 'cancelada').toList();
    final List<Map<String, dynamic>> todosAsistentes = [];
    for (final i in activas) {
      final asist = List<Map<String, dynamic>>.from(
          (i['asistentes'] as List<dynamic>?) ?? []);
      todosAsistentes.addAll(asist);
    }

    final hermanos = todosAsistentes.where((a) => a['tipo'] == 'hermano').length;
    final invitados = todosAsistentes.where((a) => a['tipo'] == 'invitado').length;
    final protocolo = todosAsistentes.where((a) => a['tipo'] == 'protocolo').length;
    final conAlergias = todosAsistentes.where((a) =>
        (a['alergias'] ?? '').toString().trim().isNotEmpty).length;

    final precioInvitado = (edicion['precio_invitado'] as num?)?.toDouble() ?? 27.0;
    final precioHermano = (edicion['precio_hermano'] as num?)?.toDouble() ?? 5.0;

    double recaudacionPrevista = 0;
    double recaudacionConfirmada = 0;
    double pendienteCobro = 0;
    double subvencionTotal = 0;

    for (final i in activas) {
      final total = (i['total'] as num?)?.toDouble() ?? 0;
      recaudacionPrevista += total;
      if (i['payment_status'] == 'pagado') {
        recaudacionConfirmada += total;
      } else if (i['payment_status'] != 'exento') {
        pendienteCobro += total;
      }
    }

    for (final a in todosAsistentes) {
      if (a['tipo'] == 'hermano') {
        subvencionTotal += precioInvitado - precioHermano;
      } else if (a['tipo'] == 'protocolo') {
        subvencionTotal += precioInvitado;
      }
    }

    final costeRealTotal = todosAsistentes.length * precioInvitado;
    final ingresoMedio = todosAsistentes.isNotEmpty
        ? recaudacionPrevista / todosAsistentes.length : 0.0;
    final costeMedio = todosAsistentes.isNotEmpty
        ? costeRealTotal / todosAsistentes.length : 0.0;

    // Menu breakdown
    final menuCounts = <String, int>{};
    for (final a in todosAsistentes) {
      final menuId = a['menu_id'] ?? 'sin_menu';
      menuCounts[menuId] = (menuCounts[menuId] ?? 0) + 1;
    }

    return {
      'total_inscripciones': activas.length,
      'total_asistentes': todosAsistentes.length,
      'hermanos': hermanos,
      'invitados': invitados,
      'protocolo': protocolo,
      'con_alergias': conAlergias,
      'recaudacion_prevista': recaudacionPrevista,
      'recaudacion_confirmada': recaudacionConfirmada,
      'pendiente_cobro': pendienteCobro,
      'coste_real_total': costeRealTotal,
      'subvencion_total': subvencionTotal,
      'ingreso_medio': ingresoMedio,
      'coste_medio': costeMedio,
      'menu_counts': menuCounts,
      'todos_asistentes': todosAsistentes,
      'activas': activas,
    };
  }

  void _exportCsv() {
    final kpis = _calcKpis();
    final activas = kpis['activas'] as List<Map<String, dynamic>>;
    final buf = StringBuffer();

    buf.writeln('Inscripcion ID;Cofrade;Asistente Nombre;Asistente Apellidos;Tipo;Menu;Alergias;Observaciones;Precio;Estado Pago');

    for (final i in activas) {
      final asistentes = List<Map<String, dynamic>>.from(
          (i['asistentes'] as List<dynamic>?) ?? []);
      for (final a in asistentes) {
        buf.writeln([
          i['id'] ?? '',
          i['cofrade_nombre'] ?? '',
          a['nombre'] ?? '',
          a['apellidos'] ?? '',
          a['tipo'] ?? '',
          a['menu_nombre'] ?? '',
          (a['alergias'] ?? '').toString().replaceAll(';', ',').replaceAll('\n', ' '),
          (a['observaciones'] ?? '').toString().replaceAll(';', ',').replaceAll('\n', ' '),
          (a['precio_aplicado'] as num? ?? 0).toStringAsFixed(2),
          i['payment_status'] ?? 'pendiente',
        ].join(';'));
      }
    }

    final bytes = utf8.encode(buf.toString());
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'festividad_sje_${edicion['anio'] ?? ''}.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final kpis = _calcKpis();
    final fmt = DateFormat('dd/MM/yyyy');
    final fecha = (edicion['fecha'] as Timestamp?)?.toDate();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Event info
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(edicion['nombre'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 4),
                      Text(
                        '${fecha != null ? fmt.format(fecha) : ""} · ${edicion['lugar'] ?? ""}',
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _exportCsv,
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Exportar CSV'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // KPIs grid
        Row(
          children: [
            Container(
                width: 4, height: 24,
                decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 10),
            Text('KPIs', style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.8,
          children: [
            _KpiCard(title: 'Total asistentes', value: '${kpis['total_asistentes']}',
                icon: Icons.groups, color: AppTheme.primaryColor),
            _KpiCard(title: 'Hermanos/as', value: '${kpis['hermanos']}',
                icon: Icons.person, color: AppTheme.accentColor),
            _KpiCard(title: 'Invitados/as', value: '${kpis['invitados']}',
                icon: Icons.person_outline, color: Colors.orange.shade700),
            _KpiCard(title: 'Protocolo', value: '${kpis['protocolo']}',
                icon: Icons.stars, color: Colors.purple),
            _KpiCard(title: 'Con alergias', value: '${kpis['con_alergias']}',
                icon: Icons.warning_amber, color: Colors.red.shade400),
            _KpiCard(title: 'Inscripciones', value: '${kpis['total_inscripciones']}',
                icon: Icons.confirmation_number, color: AppTheme.primaryColor),
          ],
        ),
        const SizedBox(height: 24),

        // Financial KPIs
        Row(
          children: [
            Container(
                width: 4, height: 24,
                decoration: BoxDecoration(color: AppTheme.accentColor, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 10),
            Text('Control Económico', style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.8,
          children: [
            _KpiCard(title: 'Recaudación prevista', value: '${(kpis['recaudacion_prevista'] as double).toStringAsFixed(2)} €',
                icon: Icons.euro, color: AppTheme.primaryColor),
            _KpiCard(title: 'Recaudación confirmada', value: '${(kpis['recaudacion_confirmada'] as double).toStringAsFixed(2)} €',
                icon: Icons.check_circle, color: AppTheme.accentColor),
            _KpiCard(title: 'Pendiente cobro', value: '${(kpis['pendiente_cobro'] as double).toStringAsFixed(2)} €',
                icon: Icons.pending, color: Colors.orange.shade700),
            _KpiCard(title: 'Coste real estimado', value: '${(kpis['coste_real_total'] as double).toStringAsFixed(2)} €',
                icon: Icons.receipt_long, color: Colors.red.shade400),
            _KpiCard(title: 'Subvención hermandad', value: '${(kpis['subvencion_total'] as double).toStringAsFixed(2)} €',
                icon: Icons.volunteer_activism, color: Colors.purple),
            _KpiCard(title: 'Ingreso medio', value: '${(kpis['ingreso_medio'] as double).toStringAsFixed(2)} €',
                icon: Icons.trending_up, color: AppTheme.primaryColor),
            _KpiCard(title: 'Coste medio', value: '${(kpis['coste_medio'] as double).toStringAsFixed(2)} €',
                icon: Icons.trending_down, color: Colors.red.shade400),
          ],
        ),
        const SizedBox(height: 24),

        // Menu breakdown
        Row(
          children: [
            Container(
                width: 4, height: 24,
                decoration: BoxDecoration(color: Colors.orange.shade700, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 10),
            Text('Desglose por Menú', style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
        const SizedBox(height: 16),
        _MenuBreakdown(menuCounts: kpis['menu_counts'] as Map<String, int>, menus: menus,
            totalAsistentes: kpis['total_asistentes'] as int),
        const SizedBox(height: 24),

        // Alergias list
        _AlergiasSection(
            asistentes: kpis['todos_asistentes'] as List<Map<String, dynamic>>,
            inscripciones: kpis['activas'] as List<Map<String, dynamic>>),
        const SizedBox(height: 24),

        // Full attendee table
        Row(
          children: [
            Container(
                width: 4, height: 24,
                decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 10),
            Expanded(child: Text('Listado completo de asistentes', style: Theme.of(context).textTheme.headlineSmall)),
          ],
        ),
        const SizedBox(height: 16),
        _AsistentesTable(
            inscripciones: kpis['activas'] as List<Map<String, dynamic>>,
            menus: menus),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withAlpha(40)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(6)),
                  child: Icon(icon, size: 16, color: color),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            ),
            Text(title, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _MenuBreakdown extends StatelessWidget {
  final Map<String, int> menuCounts;
  final List<Map<String, dynamic>> menus;
  final int totalAsistentes;
  const _MenuBreakdown({required this.menuCounts, required this.menus, required this.totalAsistentes});

  @override
  Widget build(BuildContext context) {
    if (menuCounts.isEmpty) {
      return const Text('No hay datos de menús.', style: TextStyle(color: AppTheme.textSecondary));
    }
    final colors = [AppTheme.accentColor, AppTheme.primaryColor, Colors.orange.shade700, Colors.purple, Colors.teal];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ...menuCounts.entries.toList().asMap().entries.map((entry) {
              final idx = entry.key;
              final menuId = entry.value.key;
              final count = entry.value.value;
              final pct = totalAsistentes > 0 ? count / totalAsistentes : 0.0;
              final menuData = menus.where((m) => m['id'] == menuId).toList();
              final nombre = menuData.isNotEmpty ? menuData.first['nombre'] ?? menuId : menuId;
              final color = colors[idx % colors.length];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(nombre, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        Text('$count (${(pct * 100).toStringAsFixed(0)}%)',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        backgroundColor: Colors.grey.shade200,
                        color: color,
                        minHeight: 8,
                      ),
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
}

class _AlergiasSection extends StatelessWidget {
  final List<Map<String, dynamic>> asistentes;
  final List<Map<String, dynamic>> inscripciones;
  const _AlergiasSection({required this.asistentes, required this.inscripciones});

  @override
  Widget build(BuildContext context) {
    final conAlergias = <Map<String, dynamic>>[];
    for (final i in inscripciones) {
      final asist = List<Map<String, dynamic>>.from(
          (i['asistentes'] as List<dynamic>?) ?? []);
      for (final a in asist) {
        if ((a['alergias'] ?? '').toString().trim().isNotEmpty) {
          conAlergias.add({...a, 'inscripcion_nombre': i['cofrade_nombre']});
        }
      }
    }

    if (conAlergias.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
                width: 4, height: 24,
                decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 10),
            Text('Alergias e Intolerancias', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${conAlergias.length}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade700)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          color: Colors.red.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.red.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: conAlergias.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber, size: 16, color: Colors.red.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                          children: [
                            TextSpan(text: '${a['nombre']} ${a['apellidos']}: ',
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            TextSpan(text: a['alergias']),
                          ],
                        ),
                      ),
                    ),
                    Text(a['menu_nombre'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  ],
                ),
              )).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _AsistentesTable extends StatelessWidget {
  final List<Map<String, dynamic>> inscripciones;
  final List<Map<String, dynamic>> menus;
  const _AsistentesTable({required this.inscripciones, required this.menus});

  @override
  Widget build(BuildContext context) {
    final rows = <_TableRow>[];
    for (final i in inscripciones) {
      final asistentes = List<Map<String, dynamic>>.from(
          (i['asistentes'] as List<dynamic>?) ?? []);
      for (final a in asistentes) {
        rows.add(_TableRow(
          nombre: '${a['nombre']} ${a['apellidos']}',
          tipo: a['tipo'] ?? '',
          menu: a['menu_nombre'] ?? '',
          alergias: a['alergias'] ?? '',
          precio: (a['precio_aplicado'] as num? ?? 0).toDouble(),
          inscripcionNombre: i['cofrade_nombre'] ?? '',
          pago: i['payment_status'] ?? 'pendiente',
        ));
      }
    }

    if (rows.isEmpty) {
      return const Text('No hay asistentes.', style: TextStyle(color: AppTheme.textSecondary));
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppTheme.primaryColor.withAlpha(10)),
          columnSpacing: 16,
          columns: const [
            DataColumn(label: Text('Nombre', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Tipo', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Menú', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Alergias', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Precio', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
            DataColumn(label: Text('Inscripción de', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Pago', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: rows.map((r) => DataRow(cells: [
            DataCell(Text(r.nombre, style: const TextStyle(fontSize: 13))),
            DataCell(_TipoBadge(tipo: r.tipo)),
            DataCell(Text(r.menu, style: const TextStyle(fontSize: 13))),
            DataCell(SizedBox(
              width: 120,
              child: Text(r.alergias, style: TextStyle(fontSize: 12,
                  color: r.alergias.isNotEmpty ? Colors.red.shade600 : AppTheme.textSecondary),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            )),
            DataCell(Text('${r.precio.toStringAsFixed(2)} €', style: const TextStyle(fontSize: 13))),
            DataCell(Text(r.inscripcionNombre, style: const TextStyle(fontSize: 12))),
            DataCell(_PagoBadge(status: r.pago)),
          ])).toList(),
        ),
      ),
    );
  }
}

class _TableRow {
  final String nombre;
  final String tipo;
  final String menu;
  final String alergias;
  final double precio;
  final String inscripcionNombre;
  final String pago;
  const _TableRow({
    required this.nombre,
    required this.tipo,
    required this.menu,
    required this.alergias,
    required this.precio,
    required this.inscripcionNombre,
    required this.pago,
  });
}

class _TipoBadge extends StatelessWidget {
  final String tipo;
  const _TipoBadge({required this.tipo});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (tipo) {
      case 'hermano': color = AppTheme.accentColor; label = 'Hermano/a'; break;
      case 'invitado': color = AppTheme.primaryColor; label = 'Invitado/a'; break;
      case 'protocolo': color = Colors.purple; label = 'Protocolo'; break;
      default: color = Colors.grey; label = tipo;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _PagoBadge extends StatelessWidget {
  final String status;
  const _PagoBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'pagado': color = AppTheme.accentColor; label = 'Pagado'; break;
      case 'exento': color = Colors.blue; label = 'Exento'; break;
      default: color = Colors.orange; label = 'Pendiente';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
