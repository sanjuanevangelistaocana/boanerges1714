import 'dart:math' as math;
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
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bienvenido, ${cofrade?.nombre ?? 'Cofrade'}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            if (authService.hasMultipleCofrades) ...[
              const SizedBox(height: 12),
              _CofradeSelectorCard(
                cofrades: authService.cofrades,
                selectedCofrade: cofrade,
                onSelect: (id) => authService.selectCofrade(id),
              ),
            ],
            if (cofrade?.estado == 'Pendiente' || cofrade?.estado == 'pendiente')
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
                        'Tu cuenta est\u00e1 pendiente de aprobaci\u00f3n por la Junta Directiva.',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _DashboardCard(icon: Icons.person, title: 'Mi Perfil', subtitle: 'Ver y editar mis datos', onTap: () => context.go('/profile')),
                _DashboardCard(icon: Icons.payment, title: 'Mis Cuotas', subtitle: 'Estado de pagos', onTap: () => context.go('/cuotas')),
                _DashboardCard(icon: Icons.folder, title: 'Documentos', subtitle: 'Actas y estatutos', onTap: () => context.go('/documents')),
                _DashboardCard(icon: Icons.event, title: 'Eventos', subtitle: 'Pr\u00f3ximas actividades', onTap: () => context.go('/events')),
                _DashboardCard(icon: Icons.how_to_vote, title: 'Convocatorias', subtitle: 'Responde consultas', onTap: () => context.go('/convocatorias')),
                if (authService.isAdmin)
                  _DashboardCard(icon: Icons.admin_panel_settings, title: 'Administraci\u00f3n', subtitle: 'Panel de gesti\u00f3n', onTap: () => context.go('/admin'), isAdmin: true),
              ],
            ),
            const SizedBox(height: 32),
            _CofradiaInfographicSection(firestoreService: firestoreService),
            const SizedBox(height: 32),
            _ActiveConvocatoriasSection(firestoreService: firestoreService),
            const SizedBox(height: 32),
            _PrivateNewsSection(firestoreService: firestoreService),
            const SizedBox(height: 32),
            if (cofrade != null) ...[
              Text('Resumen de Cuotas', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              StreamBuilder<List<Cuota>>(
                stream: firestoreService.getCuotasCofrade(cofrade.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final cuotas = snapshot.data ?? [];
                  if (cuotas.isEmpty) {
                    return const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('No hay cuotas registradas.')));
                  }
                  final pendientes = cuotas.where((c) => c.isPendiente).length;
                  final pagadas = cuotas.where((c) => c.isPagada).length;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatIcon(label: 'Pagadas', count: pagadas, color: Colors.green, icon: Icons.check_circle),
                          _StatIcon(label: 'Pendientes', count: pendientes, color: Colors.orange, icon: Icons.pending),
                          _StatIcon(label: 'Total', count: cuotas.length, color: AppTheme.primaryColor, icon: Icons.receipt_long),
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

class _CofradiaInfographicSection extends StatelessWidget {
  final FirestoreService firestoreService;
  const _CofradiaInfographicSection({required this.firestoreService});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tu Cofrad\u00eda en Cifras', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        StreamBuilder<List<Cofrade>>(
          stream: firestoreService.getAllCofradesStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Card(child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())));
            }
            final allCofrades = snapshot.data ?? [];
            if (allCofrades.isEmpty) {
              return const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('No hay datos de cofrades disponibles.')));
            }

            final activos = allCofrades.where((c) => c.isActivo).toList();
            final bajas = allCofrades.where((c) => c.isBaja).toList();

            final edades = activos.where((c) => c.edad != null && c.edad! > 0).map((c) => c.edad!).toList();
            final mediaEdad = edades.isNotEmpty ? (edades.reduce((a, b) => a + b) / edades.length) : 0.0;

            final hombres = activos.where((c) => c.genero?.toUpperCase() == 'H' || c.genero?.toUpperCase() == 'HOMBRE' || c.genero?.toUpperCase() == 'MASCULINO').length;
            final mujeres = activos.where((c) => c.genero?.toUpperCase() == 'M' || c.genero?.toUpperCase() == 'MUJER' || c.genero?.toUpperCase() == 'F' || c.genero?.toUpperCase() == 'FEMENINO').length;

            final aniosHermandadList = activos.where((c) => c.aniosHermandad != null && c.aniosHermandad! > 0).map((c) => c.aniosHermandad!).toList();
            final maxAnios = aniosHermandadList.isNotEmpty ? aniosHermandadList.reduce(math.max) : 0;

            final aniosAlta = activos.where((c) => c.anioAlta != null && c.anioAlta! > 0).map((c) => c.anioAlta!).toList();
            final minAnioAlta = aniosAlta.isNotEmpty ? aniosAlta.reduce(math.min) : 0;

            final gdprFirmados = activos.where((c) => c.gdprFirmado).length;
            final conTunica = activos.where((c) => c.tieneTunicaPropia).length;
            final conCuota = activos.where((c) => c.tieneCuota).length;

            final ageRanges = <String, int>{'0-17': 0, '18-30': 0, '31-45': 0, '46-60': 0, '61-75': 0, '75+': 0};
            for (final edad in edades) {
              if (edad <= 17) { ageRanges['0-17'] = ageRanges['0-17']! + 1; }
              else if (edad <= 30) { ageRanges['18-30'] = ageRanges['18-30']! + 1; }
              else if (edad <= 45) { ageRanges['31-45'] = ageRanges['31-45']! + 1; }
              else if (edad <= 60) { ageRanges['46-60'] = ageRanges['46-60']! + 1; }
              else if (edad <= 75) { ageRanges['61-75'] = ageRanges['61-75']! + 1; }
              else { ageRanges['75+'] = ageRanges['75+']! + 1; }
            }

            return Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Wrap(
                          spacing: 24, runSpacing: 16, alignment: WrapAlignment.spaceAround,
                          children: [
                            _BigStat(value: '${activos.length}', label: 'Hermanos\nActivos', icon: Icons.people, color: Colors.green),
                            _BigStat(value: '${allCofrades.length}', label: 'Total\nCofrades', icon: Icons.groups, color: AppTheme.primaryColor),
                            _BigStat(value: mediaEdad > 0 ? mediaEdad.toStringAsFixed(1) : '-', label: 'Media\nEdad', icon: Icons.cake, color: Colors.orange),
                            _BigStat(value: maxAnios > 0 ? '$maxAnios' : '-', label: 'M\u00e1x. A\u00f1os\nHermandad', icon: Icons.emoji_events, color: AppTheme.accentColor),
                          ],
                        ),
                        if (minAnioAlta > 0) ...[
                          const SizedBox(height: 8),
                          Text('Cofrade m\u00e1s antiguo desde $minAnioAlta', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _GenderCard(hombres: hombres, mujeres: mujeres, total: activos.length)),
                      const SizedBox(width: 16),
                      Expanded(child: _EstadoCard(conCuota: conCuota, gdprFirmados: gdprFirmados, conTunica: conTunica, totalActivos: activos.length, totalBajas: bajas.length)),
                    ],
                  )
                else ...[
                  _GenderCard(hombres: hombres, mujeres: mujeres, total: activos.length),
                  const SizedBox(height: 16),
                  _EstadoCard(conCuota: conCuota, gdprFirmados: gdprFirmados, conTunica: conTunica, totalActivos: activos.length, totalBajas: bajas.length),
                ],
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Distribuci\u00f3n por Edad', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 16),
                        _AgeBarChart(ageRanges: ageRanges),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _GenderCard extends StatelessWidget {
  final int hombres;
  final int mujeres;
  final int total;
  const _GenderCard({required this.hombres, required this.mujeres, required this.total});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text('Distribuci\u00f3n por G\u00e9nero', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 16),
            SizedBox(
              height: 120, width: 120,
              child: CustomPaint(
                painter: _DonutChartPainter(hombres: hombres, mujeres: mujeres, sinDato: total - hombres - mujeres),
                child: Center(child: Text('$total', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary))),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendDot(color: Colors.blue[700]!, label: 'Hombres ($hombres)'),
                const SizedBox(width: 16),
                _LegendDot(color: Colors.pink[400]!, label: 'Mujeres ($mujeres)'),
              ],
            ),
            if (total - hombres - mujeres > 0) ...[
              const SizedBox(height: 4),
              _LegendDot(color: Colors.grey[300]!, label: 'Sin dato (${total - hombres - mujeres})'),
            ],
          ],
        ),
      ),
    );
  }
}

class _EstadoCard extends StatelessWidget {
  final int conCuota;
  final int gdprFirmados;
  final int conTunica;
  final int totalActivos;
  final int totalBajas;
  const _EstadoCard({required this.conCuota, required this.gdprFirmados, required this.conTunica, required this.totalActivos, required this.totalBajas});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Estado de la Cofrad\u00eda', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 16),
            _ProgressStat(label: 'Cuotas al d\u00eda', value: conCuota, total: totalActivos, color: Colors.green),
            const SizedBox(height: 12),
            _ProgressStat(label: 'GDPR firmado', value: gdprFirmados, total: totalActivos, color: Colors.blue),
            const SizedBox(height: 12),
            _ProgressStat(label: 'T\u00fanica propia', value: conTunica, total: totalActivos, color: AppTheme.primaryColor),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.person_off, size: 16, color: Colors.red),
                const SizedBox(width: 8),
                Text('$totalBajas bajas registradas', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final int hombres;
  final int mujeres;
  final int sinDato;
  _DonutChartPainter({required this.hombres, required this.mujeres, required this.sinDato});

  @override
  void paint(Canvas canvas, Size size) {
    final total = hombres + mujeres + sinDato;
    if (total == 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    const strokeWidth = 20.0;
    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = strokeWidth..strokeCap = StrokeCap.butt;
    double startAngle = -math.pi / 2;

    if (hombres > 0) {
      final sweep = (hombres / total) * 2 * math.pi;
      paint.color = Colors.blue[700]!;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += sweep;
    }
    if (mujeres > 0) {
      final sweep = (mujeres / total) * 2 * math.pi;
      paint.color = Colors.pink[400]!;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += sweep;
    }
    if (sinDato > 0) {
      final sweep = (sinDato / total) * 2 * math.pi;
      paint.color = Colors.grey[300]!;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.hombres != hombres || oldDelegate.mujeres != mujeres || oldDelegate.sinDato != sinDato;
  }
}

class _AgeBarChart extends StatelessWidget {
  final Map<String, int> ageRanges;
  const _AgeBarChart({required this.ageRanges});

  @override
  Widget build(BuildContext context) {
    final maxVal = ageRanges.values.fold(0, math.max);
    if (maxVal == 0) {
      return const Text('No hay datos de edad disponibles.', style: TextStyle(color: AppTheme.textSecondary));
    }
    final colors = [Colors.blue[300]!, Colors.green[400]!, Colors.amber[400]!, Colors.orange[400]!, Colors.red[300]!, Colors.purple[300]!];

    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: ageRanges.entries.toList().asMap().entries.map((entry) {
          final idx = entry.key;
          final range = entry.value;
          final fraction = maxVal > 0 ? range.value / maxVal : 0.0;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('${range.value}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    height: 80 * fraction,
                    decoration: BoxDecoration(color: colors[idx % colors.length], borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                  ),
                  const SizedBox(height: 4),
                  Text(range.key, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const _BigStat({required this.value, required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _ProgressStat extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  final Color color;
  const _ProgressStat({required this.label, required this.value, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? value / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13)),
            Text('$value/$total', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: pct, backgroundColor: Colors.grey[200], color: color, minHeight: 8),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
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
            Expanded(child: Text('Convocatorias Activas', style: Theme.of(context).textTheme.headlineSmall)),
            TextButton(onPressed: () => context.go('/convocatorias'), child: const Text('Ver todas')),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<Convocatoria>>(
          stream: firestoreService.getConvocatoriasActivas(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            final convocatorias = snapshot.data ?? [];
            if (convocatorias.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('No hay convocatorias activas.')));
            return Column(
              children: convocatorias.take(3).map((c) {
                final dateFormat = DateFormat('dd/MM/yyyy');
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(c.tipo == 'procesion' ? Icons.church : c.tipo == 'evento' ? Icons.event : Icons.how_to_vote, color: AppTheme.primaryColor),
                    title: Text(c.titulo),
                    subtitle: Text('L\u00edmite: ${dateFormat.format(c.fechaLimite)} \u00b7 ${c.totalRespuestas} respuestas'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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
        Text('Noticias para Cofrades', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        StreamBuilder<List<Noticia>>(
          stream: firestoreService.getNoticiasCofrades(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            final noticias = snapshot.data ?? [];
            if (noticias.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('No hay noticias privadas.')));
            return Column(
              children: noticias.map((n) {
                final dateFormat = DateFormat('dd/MM/yyyy');
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.article, color: AppTheme.primaryColor),
                    title: Text(n.titulo),
                    subtitle: Text(dateFormat.format(n.fecha)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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
  const _CofradeSelectorCard({required this.cofrades, required this.selectedCofrade, required this.onSelect});

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
                Text('Cofrades vinculados a tu cuenta', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
              ],
            ),
            const SizedBox(height: 12),
            ...cofrades.map((cofrade) {
              final isSelected = cofrade.id == selectedCofrade?.id;
              final isTutelado = cofrade.tuteladoDigital != null && cofrade.tuteladoDigital!.isNotEmpty;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: isSelected ? const BorderSide(color: AppTheme.primaryColor) : BorderSide.none,
                  ),
                  tileColor: isSelected ? AppTheme.primaryColor.withAlpha(25) : null,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: isSelected ? AppTheme.primaryColor : Colors.grey[300],
                    child: Text(cofrade.nombre.isNotEmpty ? cofrade.nombre[0].toUpperCase() : '?', style: TextStyle(color: isSelected ? Colors.white : Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  title: Text(cofrade.nombreCompleto, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                  subtitle: Text(isTutelado ? 'Tutelado \u00b7 N\u00ba ${cofrade.numero ?? "-"}' : 'N\u00ba ${cofrade.numero ?? "-"}'),
                  trailing: isSelected ? const Icon(Icons.check_circle, color: AppTheme.primaryColor) : null,
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
  const _DashboardCard({required this.icon, required this.title, required this.subtitle, required this.onTap, this.isAdmin = false});

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
                Icon(icon, size: 36, color: isAdmin ? AppTheme.primaryColor : AppTheme.primaryLight),
                const SizedBox(height: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatIcon extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  const _StatIcon({required this.label, required this.count, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text('$count', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
      ],
    );
  }
}
