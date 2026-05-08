import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/auth_service.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _loading = false;

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
                  Icon(Icons.mark_email_unread_outlined,
                      size: 56, color: AppTheme.primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    'Verifica tu correo electrónico',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Para poder acceder a la aplicación, necesitamos confirmar que este correo te pertenece. Te hemos enviado un enlace de verificación.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _resend,
                        icon: const Icon(Icons.send_outlined),
                        label: const Text('Reenviar correo de verificación'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _loading ? null : _check,
                        icon: const Icon(Icons.verified_outlined),
                        label: const Text('Ya he verificado mi correo'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _loading ? null : () => auth.signOut(),
                    child: const Text('Cerrar sesión'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _resend() async {
    setState(() => _loading = true);
    try {
      await context.read<AuthService>().sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Correo de verificación reenviado.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _check() async {
    setState(() => _loading = true);
    final verified =
        await context.read<AuthService>().reloadAndCheckEmailVerification();
    if (mounted) {
      setState(() => _loading = false);
      if (!verified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El correo todavía no aparece como verificado.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
}
