import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/auth_service.dart';

class AccessDisabledScreen extends StatelessWidget {
  const AccessDisabledScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline,
                      size: 54, color: Colors.red.shade700),
                  const SizedBox(height: 16),
                  Text(
                    'Acceso deshabilitado',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    auth.accessDisabledMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () => auth.signOut(),
                    icon: const Icon(Icons.logout),
                    label: const Text('Cerrar sesión'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
