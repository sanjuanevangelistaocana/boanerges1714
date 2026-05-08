import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/services/auth_service.dart';

class ProfileSelectionScreen extends StatelessWidget {
  const ProfileSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final profiles = auth.selectableCofrades;
    final validProfiles = auth.accessibleCofrades;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selecciona perfil',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Este email está asociado a varios cofrades. Elige el perfil con el que quieres acceder antes de continuar.',
              ),
              const SizedBox(height: 20),
              if (validProfiles.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(Icons.lock_outline, size: 40),
                        const SizedBox(height: 12),
                        const Text(
                          'No hay ningún perfil activo disponible para esta cuenta.',
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: auth.signOut,
                          child: const Text('Cerrar sesión'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...profiles.map(
                  (cofrade) {
                    final disabled = cofrade.hasConsentAccessBlocked;
                    final statusText =
                        cofrade.gdprDigitalStatus == 'revocation_requested'
                            ? 'Revocación solicitada'
                            : cofrade.gdprDigitalStatus == 'revoked'
                                ? 'Consentimiento revocado'
                                : cofrade.estado;
                    return Opacity(
                      opacity: disabled ? 0.55 : 1,
                      child: Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              cofrade.numero?.toString() ?? '-',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          title: Text(cofrade.nombreCompleto),
                          subtitle: Text(
                            'Nº ${cofrade.numero ?? "-"} · $statusText',
                          ),
                          trailing: disabled
                              ? const Icon(Icons.lock_outline)
                              : const Icon(Icons.chevron_right),
                          onTap: disabled
                              ? null
                              : () {
                                  auth.selectCofrade(cofrade.id);
                                  context.go('/dashboard');
                                },
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
