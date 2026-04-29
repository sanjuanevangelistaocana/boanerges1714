import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/models/treasury.dart';
import 'package:boanerges1714/services/treasury/treasury_repository.dart';

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
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 760;
                final cards = [
                  _SummaryCard(
                    title: 'Año actual',
                    value: '${summary.year}',
                    icon: Icons.calendar_today,
                    color: Colors.blue.shade700,
                  ),
                  _SummaryCard(
                    title: 'Cuota anual',
                    value: '${summary.annualFeeAmount.toStringAsFixed(2)} €',
                    icon: Icons.euro,
                    color: AppTheme.primaryColor,
                  ),
                  _SummaryCard(
                    title: 'Facturas',
                    value: '${summary.totalInvoicesCount}',
                    icon: Icons.description,
                    color: Colors.blue.shade700,
                  ),
                  _SummaryCard(
                    title: 'Importe total',
                    value:
                        '${summary.totalInvoicesAmount.toStringAsFixed(2)} €',
                    icon: Icons.summarize,
                    color: AppTheme.primaryColor,
                  ),
                  _SummaryCard(
                    title: 'Facturas borrador',
                    value: '${summary.draftInvoicesCount}',
                    icon: Icons.edit_document,
                    color: Colors.blue.shade700,
                  ),
                  _SummaryCard(
                    title: 'Facturas aprobadas',
                    value: '${summary.approvedInvoicesCount}',
                    icon: Icons.verified,
                    color: AppTheme.accentColor,
                  ),
                  _SummaryCard(
                    title: 'Pendiente de cobro',
                    value: '${summary.pendingAmount.toStringAsFixed(2)} €',
                    icon: Icons.schedule,
                    color: Colors.amber.shade800,
                  ),
                  _SummaryCard(
                    title: 'Cobrado',
                    value: '${summary.paidAmount.toStringAsFixed(2)} €',
                    icon: Icons.check_circle,
                    color: AppTheme.accentColor,
                  ),
                  _SummaryCard(
                    title: 'Aprobado',
                    value: '${summary.approvedAmount.toStringAsFixed(2)} €',
                    icon: Icons.fact_check,
                    color: AppTheme.accentColor,
                  ),
                  _SummaryCard(
                    title: 'Devuelto / impagado',
                    value: '${summary.returnedAmount.toStringAsFixed(2)} €',
                    icon: Icons.error_outline,
                    color: Colors.red.shade700,
                  ),
                  _SummaryCard(
                    title: 'Domiciliado',
                    value:
                        '${summary.bankInvoicesCount} · ${summary.bankAmount.toStringAsFixed(2)} €',
                    icon: Icons.account_balance,
                    color: Colors.blue.shade700,
                  ),
                  _SummaryCard(
                    title: 'Efectivo',
                    value:
                        '${summary.cashInvoicesCount} · ${summary.cashAmount.toStringAsFixed(2)} €',
                    icon: Icons.payments,
                    color: Colors.amber.shade800,
                  ),
                  _SummaryCard(
                    title: 'Resultado anual',
                    value: '${summary.annualResult.toStringAsFixed(2)} €',
                    icon: Icons.account_balance,
                    color: summary.annualResult >= 0
                        ? AppTheme.accentColor
                        : Colors.red.shade700,
                  ),
                ];
                if (isWide) {
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.45,
                    children: cards,
                  );
                }
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.25,
                  children: cards,
                );
              },
            ),
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

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
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
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 22),
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
