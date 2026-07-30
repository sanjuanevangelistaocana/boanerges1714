import 'package:flutter/material.dart';
import 'package:boanerges1714/config/theme.dart';

class LegalScreen extends StatelessWidget {
  final String title;
  final String summary;

  const LegalScreen({
    super.key,
    required this.title,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 12),
                  Text(
                    'Página pendiente de revisión legal.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 20),
                  Text(summary, style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 20),
                  Text(
                    'La Junta deberá completar esta página con la identidad del responsable, '
                    'los datos legales aplicables, finalidades, bases jurídicas, plazos '
                    'y demás información que corresponda antes de su publicación definitiva.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      height: 1.6,
                    ),
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
