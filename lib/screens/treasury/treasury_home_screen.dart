import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/screens/treasury/treasury_dashboard_screen.dart';
import 'package:boanerges1714/services/auth_service.dart';

class TreasuryHomeScreen extends StatelessWidget {
  const TreasuryHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final canManage = auth.canManageTreasury;

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
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount:
                        MediaQuery.of(context).size.width > 760 ? 3 : 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.45,
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
                      _TreasuryModuleCard(
                        icon: Icons.settings,
                        title: 'Configuración',
                        subtitle: 'Cuotas, campaña y categorías',
                        route: '/treasury/settings',
                        enabled: canManage,
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
  final bool enabled;

  const _TreasuryModuleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
    this.enabled = true,
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
        onTap: enabled ? () => context.go(route) : null,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: enabled
                      ? AppTheme.primaryColor.withAlpha(15)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: enabled ? AppTheme.primaryColor : Colors.grey,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: enabled ? AppTheme.textPrimary : Colors.grey,
                      )),
                  const SizedBox(height: 4),
                  Text(
                    enabled ? subtitle : 'Solo tesorería/admin',
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
