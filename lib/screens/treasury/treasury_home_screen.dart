import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/screens/treasury/treasury_dashboard_screen.dart';
import 'package:boanerges1714/widgets/responsive_layout.dart';

class TreasuryHomeScreen extends StatelessWidget {
  const TreasuryHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
            child: const Padding(
              padding: EdgeInsets.fromLTRB(32, 28, 32, 24),
              child: Row(
                children: [
                  Icon(Icons.account_balance_wallet,
                      color: Colors.white70, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tesorería',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TreasuryDashboardScreen(year: DateTime.now().year),
                  const SizedBox(height: 28),
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
                      Text('Submódulos',
                          style: Theme.of(context).textTheme.headlineSmall),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ResponsiveGrid(
                    smallColumns: 1,
                    mediumColumns: 2,
                    largeColumns: 3,
                    wideColumns: 3,
                    children: [
                      const _TreasuryModuleCard(
                        icon: Icons.receipt_long,
                        title: 'Facturación y cobros',
                        subtitle: 'Facturas, validación, remesas e impagos',
                        route: '/treasury/billing',
                      ),
                      const _TreasuryModuleCard(
                        icon: Icons.person_search,
                        title: 'Seguimiento individual',
                        subtitle: 'Histórico, estado de cuenta y movimientos',
                        route: '/treasury/tracking',
                      ),
                      const _TreasuryModuleCard(
                        icon: Icons.bar_chart,
                        title: 'Contabilidad',
                        subtitle: 'Balance, presupuesto y centros de coste',
                        route: '/treasury/accounting',
                      ),
                      const _TreasuryModuleCard(
                        icon: Icons.admin_panel_settings,
                        title: 'Soporte y control',
                        subtitle: 'Documentación, auditoría y notificaciones',
                        route: '/treasury/control',
                      ),
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

class _TreasuryModuleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  const _TreasuryModuleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go(route),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppTheme.primaryColor),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      )),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
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
      ),
    );
  }
}
