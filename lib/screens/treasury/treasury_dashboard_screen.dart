import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/models/treasury.dart';
import 'package:boanerges1714/services/treasury/treasury_repository.dart';
import 'package:boanerges1714/widgets/responsive_layout.dart';

class TreasuryDashboardScreen extends StatelessWidget {
  final int? year;
  const TreasuryDashboardScreen({super.key, this.year});

  @override
  Widget build(BuildContext context) {
    final selectedYear = year ?? DateTime.now().year;
    final repository = context.read<TreasuryRepository>();

    return StreamBuilder<TreasuryDashboardSummary>(
      stream: repository.watchDashboardSummary(selectedYear),
      builder: (context, snap) {
        final summary = snap.data ??
            TreasuryDashboardSummary(
              year: selectedYear,
            );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text('Dashboard',
                    style: Theme.of(context).textTheme.headlineSmall),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<TreasurySettings?>(
              stream: repository.watchSettingsByYear(selectedYear),
              builder: (context, settingsSnap) {
                final settings = settingsSnap.data;
                return _CampaignCard(
                  year: selectedYear,
                  settings: settings,
                );
              },
            ),
            const SizedBox(height: 16),
            _DashboardKpiSections(summary: summary),
            const SizedBox(height: 16),
            _DashboardCharts(summary: summary),
          ],
        );
      },
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final int year;
  final TreasurySettings? settings;

  const _CampaignCard({required this.year, this.settings});

  @override
  Widget build(BuildContext context) {
    final active = settings?.isActive == true;
    return Card(
      elevation: 0,
      color: active ? AppTheme.accentColor.withAlpha(12) : Colors.blue.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: active
              ? AppTheme.accentColor.withAlpha(70)
              : Colors.blue.shade100,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: active
                    ? AppTheme.accentColor.withAlpha(25)
                    : Colors.blue.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                active ? Icons.campaign : Icons.info_outline,
                color: active ? AppTheme.accentColor : Colors.blue.shade700,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    active
                        ? 'Campaña de tesorería activa'
                        : 'Campaña no activa',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    settings == null
                        ? 'No hay configuración para $year.'
                        : 'Cuota ${settings!.annualFeeAmount.toStringAsFixed(2)} € · Validación ${_fmt(settings!.validationStartDate)} - ${_fmt(settings!.validationEndDate)}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime? date) {
    if (date == null) return 'sin fecha';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _DashboardKpiSections extends StatelessWidget {
  final TreasuryDashboardSummary summary;

  const _DashboardKpiSections({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DashboardSection(
          title: 'Cobro anual',
          cards: [
            _SummaryCard(
              title: 'Cuota anual',
              value: '${summary.annualFeeAmount.toStringAsFixed(2)} €',
              icon: Icons.euro,
              color: AppTheme.primaryColor,
              help: 'Importe base configurado para el ejercicio.',
            ),
            _SummaryCard(
              title: 'Precuotas',
              value: '${summary.feeDraftsCount}',
              icon: Icons.assignment,
              color: AppTheme.primaryColor,
              help: 'Cofrades con cuota provisional generada.',
            ),
            _SummaryCard(
              title: 'Precuotas aprobadas',
              value: '${summary.feeDraftsApprovedCount}',
              icon: Icons.receipt,
              color: AppTheme.accentColor,
              help: 'Precuotas listas para validación o facturación.',
            ),
          ],
        ),
        _DashboardSection(
          title: 'Validación bancaria',
          cards: [
            _SummaryCard(
              title: 'Pendientes',
              value: '${summary.bankValidationPendingCount}',
              icon: Icons.pending_actions,
              color: Colors.amber.shade800,
              help: 'Cofrades que aún no han confirmado sus datos bancarios.',
            ),
            _SummaryCard(
              title: 'Confirmadas',
              value: '${summary.bankValidationValidatedCount}',
              icon: Icons.check_circle,
              color: AppTheme.accentColor,
              help: 'Validaciones confirmadas por el cofrade.',
            ),
            _SummaryCard(
              title: 'IBAN modificado',
              value: '${summary.bankValidationModifiedCount}',
              icon: Icons.edit,
              color: Colors.blueGrey.shade700,
              help: 'Validaciones con datos bancarios actualizados.',
            ),
          ],
        ),
        _DashboardSection(
          title: 'Facturación',
          cards: [
            _SummaryCard(
              title: 'Facturas',
              value: '${summary.totalInvoicesCount}',
              icon: Icons.description,
              color: AppTheme.primaryColor,
              help: 'Facturas definitivas creadas.',
            ),
            _SummaryCard(
              title: 'Importe facturado',
              value: '${summary.totalInvoicesAmount.toStringAsFixed(2)} €',
              icon: Icons.summarize,
              color: AppTheme.primaryColor,
              help: 'Total emitido en facturas definitivas.',
            ),
            _SummaryCard(
              title: 'No validadas',
              value: '${summary.finalInvoicesWithUnvalidatedCount}',
              icon: Icons.warning_amber,
              color: Colors.red.shade700,
              help: 'Facturas generadas con datos no confirmados.',
            ),
          ],
        ),
        _DashboardSection(
          title: 'Remesas y cobros',
          cards: [
            _SummaryCard(
              title: 'Remesas',
              value:
                  '${summary.remittancesCount} · ${summary.remittancesAmount.toStringAsFixed(2)} €',
              icon: Icons.table_view,
              color: AppTheme.primaryColor,
              help:
                  'Importe enviado al banco. No equivale a dinero cobrado hasta registrar el resultado.',
            ),
            _SummaryCard(
              title: 'Pendientes',
              value: '${summary.collectionPendingCount}',
              icon: Icons.hourglass_bottom,
              color: Colors.amber.shade800,
              help: 'Recibos de remesa pendientes de resultado.',
            ),
            _SummaryCard(
              title: 'Rechazados',
              value: '${summary.collectionRejectedCount}',
              icon: Icons.report_problem,
              color: Colors.red.shade700,
              help: 'Recibos devueltos por el banco.',
            ),
            _SummaryCard(
              title: 'Cobros manuales',
              value:
                  '${summary.manualPaymentsCount} · ${summary.manualPaymentsAmount.toStringAsFixed(2)} €',
              icon: Icons.payments,
              color: Colors.blueGrey.shade700,
              help:
                  'Cobros por efectivo, Bizum o transferencia aplicados a facturas existentes.',
            ),
          ],
        ),
        _DashboardSection(
          title: 'Contabilidad',
          cards: [
            _SummaryCard(
              title: 'Cobrado',
              value: '${summary.paidAmount.toStringAsFixed(2)} €',
              icon: Icons.check_circle,
              color: AppTheme.accentColor,
              help: 'Importe realmente cobrado.',
            ),
            _SummaryCard(
              title: 'Impagado',
              value: '${summary.returnedAmount.toStringAsFixed(2)} €',
              icon: Icons.error_outline,
              color: Colors.red.shade700,
              help: 'Importe rechazado o devuelto.',
            ),
            _SummaryCard(
              title: 'Resultado',
              value: '${summary.annualResult.toStringAsFixed(2)} €',
              icon: Icons.account_balance,
              color: summary.annualResult >= 0
                  ? AppTheme.accentColor
                  : Colors.red.shade700,
              help: 'Ingresos cobrados menos gastos registrados.',
            ),
          ],
        ),
      ],
    );
  }
}

class _DashboardSection extends StatelessWidget {
  final String title;
  final List<Widget> cards;

  const _DashboardSection({required this.title, required this.cards});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ResponsiveGrid(
            smallColumns: 1,
            mediumColumns: 2,
            largeColumns: 4,
            wideColumns: 4,
            children: cards,
          ),
        ],
      ),
    );
  }
}

class _DashboardCharts extends StatelessWidget {
  final TreasuryDashboardSummary summary;

  const _DashboardCharts({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _SimpleBarChart(
          title: 'Distribución cobros',
          items: [
            _ChartItem(
                'Domiciliación', summary.bankAmount, AppTheme.primaryColor),
            _ChartItem('Manual', summary.manualPaymentsAmount,
                Colors.blueGrey.shade700),
          ],
        ),
        _SimpleBarChart(
          title: 'Estado de cobros',
          items: [
            _ChartItem('Pendiente', summary.collectionPendingCount.toDouble(),
                Colors.amber.shade800),
            _ChartItem('Cobrado', summary.collectionPaidCount.toDouble(),
                AppTheme.accentColor),
            _ChartItem('Rechazado', summary.collectionRejectedCount.toDouble(),
                Colors.red.shade700),
          ],
        ),
        _SimpleBarChart(
          title: 'Ingresos y gastos',
          items: [
            _ChartItem('Ingresos', summary.incomeAmount, AppTheme.accentColor),
            _ChartItem('Gastos', summary.expenseAmount, Colors.red.shade700),
          ],
        ),
      ],
    );
  }
}

class _ChartItem {
  final String label;
  final double value;
  final Color color;
  const _ChartItem(this.label, this.value, this.color);
}

class _SimpleBarChart extends StatelessWidget {
  final String title;
  final List<_ChartItem> items;

  const _SimpleBarChart({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final maxValue = items.fold<double>(
      0,
      (max, item) => item.value > max ? item.value : max,
    );
    return SizedBox(
      width: 340,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              ...items.map((item) {
                final factor = maxValue <= 0 ? 0.0 : item.value / maxValue;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(item.label)),
                          Text(item.value.toStringAsFixed(2)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: factor,
                          minHeight: 8,
                          color: item.color,
                          backgroundColor: Colors.grey.shade100,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String help;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.help = '',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const Spacer(),
                if (help.isNotEmpty)
                  Tooltip(
                    message: help,
                    child: Icon(
                      Icons.help_outline,
                      size: 18,
                      color: Colors.grey.shade500,
                    ),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
