import 'package:flutter/material.dart';
import 'package:boanerges1714/screens/treasury/treasury_placeholder_screen.dart';

class IndividualTrackingScreen extends StatelessWidget {
  const IndividualTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TreasuryPlaceholderScreen(
      title: 'Seguimiento individual',
      subtitle:
          'Base preparada para consultar el histórico por cofrade, estado de cuenta y detalle de movimientos.',
      icon: Icons.person_search,
      items: [
        'Histórico por cofrade',
        'Estado de cuenta',
        'Detalle de movimientos',
      ],
    );
  }
}

class AccountingScreen extends StatelessWidget {
  const AccountingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TreasuryPlaceholderScreen(
      title: 'Contabilidad',
      subtitle:
          'Base preparada para balance anual, presupuesto y centros de coste.',
      icon: Icons.bar_chart,
      items: [
        'Balance anual',
        'Presupuesto',
        'Centros de coste',
      ],
    );
  }
}

class TreasuryControlScreen extends StatelessWidget {
  const TreasuryControlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TreasuryPlaceholderScreen(
      title: 'Soporte y control',
      subtitle:
          'Base preparada para documentación económica, auditoría, notificaciones y roles.',
      icon: Icons.admin_panel_settings,
      items: [
        'Documentación económica',
        'Auditoría',
        'Notificaciones',
        'Roles y permisos',
      ],
    );
  }
}
